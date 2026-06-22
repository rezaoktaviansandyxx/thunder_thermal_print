#define WIN32_LEAN_AND_MEAN
#define _WINSOCK_DEPRECATED_NO_WARNINGS
#define _CRT_NONSTDC_NO_DEPRECATE
#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>

#include "thunder_thermal_print_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <flutter/plugin_registrar_windows.h>
#include <setupapi.h>
#include <devpkey.h>
#include <string>
#include <vector>
#include <thread>
#include <mutex>
#include <atomic>
#include <chrono>
#include <sstream>

#pragma comment(lib, "setupapi.lib")
#pragma comment(lib, "ws2_32.lib")

namespace {

constexpr char kChannelName[] = "id.thunderlab.thunder_thermal_print";

// ---------------------------------------------------------------------------
// Helper: throw a FlutterError via the result
// ---------------------------------------------------------------------------
inline void ReplyError(flutter::MethodResult<flutter::EncodableValue>& result,
                      const std::string& code,
                      const std::string& message,
                      const std::string& details = "") {
    result.Error(code, message, flutter::EncodableValue(details));
}

inline void ReplySuccess(flutter::MethodResult<flutter::EncodableValue>& result,
                         const flutter::EncodableValue& value) {
    result.Success(value);
}

// ---------------------------------------------------------------------------
// Helper: string conversion
// ---------------------------------------------------------------------------
// Case-insensitive wide string find
const wchar_t* Wcsistr(const wchar_t* str, const wchar_t* substr) {
    if (!str || !substr) return nullptr;
    size_t len = wcslen(substr);
    if (len == 0) return str;
    while (*str) {
        if (_wcsnicmp(str, substr, len) == 0) return str;
        ++str;
    }
    return nullptr;
}

std::string WideToUtf8(const std::wstring& wide) {
    if (wide.empty()) return "";
    int size = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), (int)wide.size(),
                                   nullptr, 0, nullptr, nullptr);
    std::string result(size, 0);
    WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), (int)wide.size(),
                        &result[0], size, nullptr, nullptr);
    return result;
}

// ---------------------------------------------------------------------------
// Connection state holder
// ---------------------------------------------------------------------------
enum class ConnectionType { kNone, kNetwork, kUsb };

struct ConnectionState {
    std::mutex mutex;
    ConnectionType type = ConnectionType::kNone;

    // Network
    SOCKET tcpSocket = INVALID_SOCKET;
    std::string tcpHost;
    int tcpPort = 0;

    // USB
    HANDLE usbHandle = INVALID_HANDLE_VALUE;
    std::string usbPath;

    bool IsConnected() {
        if (type == ConnectionType::kNetwork) {
            return tcpSocket != INVALID_SOCKET;
        }
        if (type == ConnectionType::kUsb) {
            return usbHandle != INVALID_HANDLE_VALUE;
        }
        return false;
    }

    void Reset() {
        if (type == ConnectionType::kNetwork && tcpSocket != INVALID_SOCKET) {
            closesocket(tcpSocket);
            tcpSocket = INVALID_SOCKET;
        }
        if (type == ConnectionType::kUsb && usbHandle != INVALID_HANDLE_VALUE) {
            CloseHandle(usbHandle);
            usbHandle = INVALID_HANDLE_VALUE;
        }
        type = ConnectionType::kNone;
        tcpHost.clear();
        tcpPort = 0;
        usbPath.clear();
    }
};

static ConnectionState g_connection;
static bool g_winsock_initialized = false;

bool EnsureWinsock() {
    if (g_winsock_initialized) return true;
    WSADATA wsaData;
    int rc = WSAStartup(MAKEWORD(2, 2), &wsaData);
    if (rc == 0) {
        g_winsock_initialized = true;
        return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// scanUsb – enumerate USB devices via SetupAPI
// ---------------------------------------------------------------------------
flutter::EncodableList ScanUsb() {
    flutter::EncodableList devices;

    HDEVINFO hDevInfo = SetupDiGetClassDevs(
        nullptr, TEXT("USB"), nullptr, DIGCF_PRESENT | DIGCF_ALLCLASSES);
    if (hDevInfo == INVALID_HANDLE_VALUE) return devices;

    SP_DEVINFO_DATA devInfoData;
    devInfoData.cbSize = sizeof(SP_DEVINFO_DATA);

    for (DWORD i = 0;
         SetupDiEnumDeviceInfo(hDevInfo, i, &devInfoData);
         ++i) {
        WCHAR buffer[256] = {0};
        if (!SetupDiGetDeviceRegistryPropertyW(
                hDevInfo, &devInfoData, SPDRP_DEVICEDESC,
                nullptr, (PBYTE)buffer, sizeof(buffer), nullptr)) {
            continue;
        }
        std::wstring name(buffer);

        // Try to get hardware ID for vendor/product extraction
        WCHAR hwid[512] = {0};
        bool hasHwId = SetupDiGetDeviceRegistryPropertyW(
            hDevInfo, &devInfoData, SPDRP_HARDWAREID,
            nullptr, (PBYTE)hwid, sizeof(hwid), nullptr);

        // Extract VID/PID if present
        int vendorId = 0, productId = 0;
        if (hasHwId) {
            std::wstring hw(hwid);
            auto vidPos = hw.find(L"VID_");
            auto pidPos = hw.find(L"PID_");
            if (vidPos != std::wstring::npos && vidPos + 8 < hw.size()) {
                std::wstringstream ss;
                ss << std::hex << hw.substr(vidPos + 4, 4);
                ss >> vendorId;
            }
            if (pidPos != std::wstring::npos && pidPos + 8 < hw.size()) {
                std::wstringstream ss;
                ss << std::hex << hw.substr(pidPos + 4, 4);
                ss >> productId;
            }
        }

        flutter::EncodableMap device;
        device[flutter::EncodableValue("name")] =
            flutter::EncodableValue(WideToUtf8(name));
        device[flutter::EncodableValue("address")] =
            flutter::EncodableValue(WideToUtf8(std::to_wstring(i)));
        device[flutter::EncodableValue("connectionType")] =
            flutter::EncodableValue("usb");
        device[flutter::EncodableValue("rssi")] =
            flutter::EncodableValue();  // null
        device[flutter::EncodableValue("vendorId")] =
            flutter::EncodableValue(vendorId);
        device[flutter::EncodableValue("productId")] =
            flutter::EncodableValue(productId);
        device[flutter::EncodableValue("isConnected")] =
            flutter::EncodableValue(false);
        device[flutter::EncodableValue("metadata")] =
            flutter::EncodableValue(flutter::EncodableMap());

        devices.push_back(flutter::EncodableValue(device));
    }

    SetupDiDestroyDeviceInfoList(hDevInfo);
    return devices;
}

// ---------------------------------------------------------------------------
// scanNetwork – TCP port 9100 scan on local subnet
// ---------------------------------------------------------------------------
flutter::EncodableList ScanNetwork(const std::string& subnet) {
    flutter::EncodableList devices;
    if (!EnsureWinsock()) return devices;

    // Determine local IP if subnet not provided
    std::string baseSubnet = subnet;
    if (baseSubnet.empty()) {
        char hostname[256] = {0};
        if (gethostname(hostname, sizeof(hostname)) != 0) return devices;
        hostent* he = gethostbyname(hostname);
        if (!he) return devices;
        struct in_addr addr;
        addr.s_addr = *(u_long*)he->h_addr_list[0];
        std::string ip = inet_ntoa(addr);
        auto dot = ip.rfind('.');
        baseSubnet = (dot != std::string::npos) ? ip.substr(0, dot) : "192.168.1";
    }

    const std::vector<int> ports = {9100, 9101, 9102, 8080, 631};

    // Scan in a background thread to avoid blocking
    std::mutex scanMutex;
    std::vector<std::thread> threads;

    for (int i = 1; i <= 254; ++i) {
        threads.emplace_back([i, &baseSubnet, &ports, &devices, &scanMutex]() {
            std::string host = baseSubnet + "." + std::to_string(i);
            for (int port : ports) {
                SOCKET sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
                if (sock == INVALID_SOCKET) continue;

                // Set non-blocking + timeout
                u_long mode = 1;
                ioctlsocket(sock, FIONBIO, &mode);

                struct sockaddr_in addr;
                addr.sin_family = AF_INET;
                addr.sin_port = htons(static_cast<u_short>(port));
                addr.sin_addr.s_addr = inet_addr(host.c_str());

                connect(sock, (struct sockaddr*)&addr, sizeof(addr));

                fd_set writeSet;
                FD_ZERO(&writeSet);
                FD_SET(sock, &writeSet);
                struct timeval tv;
                tv.tv_sec = 1;
                tv.tv_usec = 0;

                int selectRc = select(0, nullptr, &writeSet, nullptr, &tv);
                if (selectRc > 0) {
                    int err = 0;
                    int len = sizeof(err);
                    getsockopt(sock, SOL_SOCKET, SO_ERROR, (char*)&err, &len);
                    if (err == 0) {
                        std::lock_guard<std::mutex> lock(scanMutex);
                        flutter::EncodableMap device;
                        device[flutter::EncodableValue("name")] =
                            flutter::EncodableValue(host);
                        device[flutter::EncodableValue("address")] =
                            flutter::EncodableValue(host + ":" + std::to_string(port));
                        device[flutter::EncodableValue("connectionType")] =
                            flutter::EncodableValue("network");
                        device[flutter::EncodableValue("rssi")] =
                            flutter::EncodableValue(0);
                        device[flutter::EncodableValue("vendorId")] =
                            flutter::EncodableValue();
                        device[flutter::EncodableValue("productId")] =
                            flutter::EncodableValue();
                        device[flutter::EncodableValue("isConnected")] =
                            flutter::EncodableValue(false);
                        device[flutter::EncodableValue("metadata")] =
                            flutter::EncodableValue(flutter::EncodableMap());
                        devices.push_back(flutter::EncodableValue(device));
                    }
                }
                closesocket(sock);
            }
        });
    }

    for (auto& t : threads) {
        if (t.joinable()) t.join();
    }

    return devices;
}

// ---------------------------------------------------------------------------
// connectNetwork – TCP connection
// ---------------------------------------------------------------------------
bool ConnectNetwork(const std::string& host, int port, std::string& errorMsg) {
    if (!EnsureWinsock()) {
        errorMsg = "Winsock initialization failed";
        return false;
    }

    std::lock_guard<std::mutex> lock(g_connection.mutex);
    g_connection.Reset();

    SOCKET sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (sock == INVALID_SOCKET) {
        errorMsg = "Failed to create socket";
        return false;
    }

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(static_cast<u_short>(port));
    addr.sin_addr.s_addr = inet_addr(host.c_str());

    // Non-blocking connect with timeout
    u_long mode = 1;
    ioctlsocket(sock, FIONBIO, &mode);

    int rc = connect(sock, (struct sockaddr*)&addr, sizeof(addr));
    if (rc == SOCKET_ERROR) {
        int wsaErr = WSAGetLastError();
        if (wsaErr != WSAEWOULDBLOCK) {
            closesocket(sock);
            errorMsg = "Connection failed: error " + std::to_string(wsaErr);
            return false;
        }
    }

    fd_set writeSet;
    FD_ZERO(&writeSet);
    FD_SET(sock, &writeSet);
    struct timeval tv;
    tv.tv_sec = 10;
    tv.tv_usec = 0;

    int selectRc = select(0, nullptr, &writeSet, nullptr, &tv);
    if (selectRc <= 0) {
        closesocket(sock);
        errorMsg = "Connection timed out";
        return false;
    }

    int err = 0;
    int len = sizeof(err);
    getsockopt(sock, SOL_SOCKET, SO_ERROR, (char*)&err, &len);
    if (err != 0) {
        closesocket(sock);
        errorMsg = "Connection failed: socket error " + std::to_string(err);
        return false;
    }

    // Restore blocking mode for writes
    mode = 0;
    ioctlsocket(sock, FIONBIO, &mode);

    g_connection.type = ConnectionType::kNetwork;
    g_connection.tcpSocket = sock;
    g_connection.tcpHost = host;
    g_connection.tcpPort = port;
    return true;
}

// ---------------------------------------------------------------------------
// connectUsb – CreateFile
// ---------------------------------------------------------------------------
bool ConnectUsb(int vendorId, int productId, std::string& errorMsg) {
    std::lock_guard<std::mutex> lock(g_connection.mutex);
    g_connection.Reset();

    // Build USB device path
    std::wstring vidStr = L"VID_" + std::to_wstring(vendorId);
    std::wstring pidStr = L"PID_" + std::to_wstring(productId);

    HDEVINFO hDevInfo = SetupDiGetClassDevs(
        nullptr, TEXT("USB"), nullptr, DIGCF_PRESENT | DIGCF_ALLCLASSES);
    if (hDevInfo == INVALID_HANDLE_VALUE) {
        errorMsg = "Failed to enumerate USB devices";
        return false;
    }

    SP_DEVINFO_DATA devInfoData;
    devInfoData.cbSize = sizeof(SP_DEVINFO_DATA);
    bool found = false;
    std::wstring devicePath;

    for (DWORD i = 0;
         SetupDiEnumDeviceInfo(hDevInfo, i, &devInfoData);
         ++i) {
        WCHAR hwid[512] = {0};
        if (!SetupDiGetDeviceRegistryPropertyW(
                hDevInfo, &devInfoData, SPDRP_HARDWAREID,
                nullptr, (PBYTE)hwid, sizeof(hwid), nullptr)) {
            continue;
        }
        std::wstring hw(hwid);
        // Case-insensitive search
        if (Wcsistr(hw.c_str(), vidStr.c_str()) != nullptr &&
            Wcsistr(hw.c_str(), pidStr.c_str()) != nullptr) {
            // Get device interface path
            SP_DEVICE_INTERFACE_DATA ifaceData;
            ifaceData.cbSize = sizeof(SP_DEVICE_INTERFACE_DATA);

            // Try GUID_DEVINTERFACE_USB_DEVICE
            GUID usbGuid = {0xA5DCBF10, 0x6530, 0x11D2, {0x90, 0x1F, 0x00, 0xC0, 0x4F, 0xB9, 0x51, 0xED}};
            if (SetupDiEnumDeviceInterfaces(hDevInfo, nullptr, &usbGuid, i, &ifaceData)) {
                DWORD requiredSize = 0;
                SetupDiGetDeviceInterfaceDetailW(hDevInfo, &ifaceData, nullptr, 0, &requiredSize, nullptr);
                if (requiredSize > 0) {
                    std::vector<BYTE> detailBuffer(requiredSize);
                    SP_DEVICE_INTERFACE_DETAIL_DATA_W* detail =
                        reinterpret_cast<SP_DEVICE_INTERFACE_DETAIL_DATA_W*>(detailBuffer.data());
                    detail->cbSize = sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W);
                    if (SetupDiGetDeviceInterfaceDetailW(
                            hDevInfo, &ifaceData, detail, requiredSize, nullptr, &devInfoData)) {
                        devicePath = detail->DevicePath;
                        found = true;
                        break;
                    }
                }
            }
        }
    }

    SetupDiDestroyDeviceInfoList(hDevInfo);

    if (!found) {
        errorMsg = "USB device with VID:" + std::to_string(vendorId) +
                   " PID:" + std::to_string(productId) + " not found";
        return false;
    }

    HANDLE hDevice = CreateFileW(
        devicePath.c_str(),
        GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        nullptr,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL,
        nullptr);

    if (hDevice == INVALID_HANDLE_VALUE) {
        errorMsg = "Failed to open USB device: error " + std::to_string(GetLastError());
        return false;
    }

    g_connection.type = ConnectionType::kUsb;
    g_connection.usbHandle = hDevice;
    g_connection.usbPath = WideToUtf8(devicePath);
    return true;
}

// ---------------------------------------------------------------------------
// Write data to the active connection
// ---------------------------------------------------------------------------
bool WriteData(const std::vector<uint8_t>& data, std::string& errorMsg) {
    std::lock_guard<std::mutex> lock(g_connection.mutex);

    if (!g_connection.IsConnected()) {
        errorMsg = "Not connected to any printer";
        return false;
    }

    if (g_connection.type == ConnectionType::kNetwork) {
        int totalSent = 0;
        while (totalSent < (int)data.size()) {
            int sent = send(g_connection.tcpSocket,
                           reinterpret_cast<const char*>(data.data()) + totalSent,
                           (int)(data.size() - totalSent), 0);
            if (sent == SOCKET_ERROR) {
                errorMsg = "Network send failed: error " +
                           std::to_string(WSAGetLastError());
                return false;
            }
            totalSent += sent;
        }
        return true;
    }

    if (g_connection.type == ConnectionType::kUsb) {
        DWORD bytesWritten = 0;
        BOOL ok = WriteFile(g_connection.usbHandle,
                           data.data(), (DWORD)data.size(),
                           &bytesWritten, nullptr);
        if (!ok || bytesWritten != data.size()) {
            errorMsg = "USB write failed: error " + std::to_string(GetLastError());
            return false;
        }
        return true;
    }

    errorMsg = "No active connection";
    return false;
}

// ---------------------------------------------------------------------------
// Plugin class
// ---------------------------------------------------------------------------
class ThunderThermalPrintPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), kChannelName,
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<ThunderThermalPrintPlugin>();

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto& call, auto result) {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  ThunderThermalPrintPlugin() = default;

  ~ThunderThermalPrintPlugin() override {
      std::lock_guard<std::mutex> lock(g_connection.mutex);
      g_connection.Reset();
      if (g_winsock_initialized) {
          WSACleanup();
          g_winsock_initialized = false;
      }
  }

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const auto& method = method_call.method_name();
    const auto* args =
        std::get_if<flutter::EncodableMap>(method_call.arguments());

    // -----------------------------------------------------------------------
    // scanUsb
    // -----------------------------------------------------------------------
    if (method == "scanUsb") {
      auto devices = ScanUsb();
      ReplySuccess(*result, flutter::EncodableValue(devices));
      return;
    }

    // -----------------------------------------------------------------------
    // scanNetwork
    // -----------------------------------------------------------------------
    if (method == "scanNetwork") {
      std::string subnet;
      if (args) {
          auto it = args->find(flutter::EncodableValue("subnet"));
          if (it != args->end() && !it->second.IsNull()) {
              subnet = std::get<std::string>(it->second);
          }
      }
      auto devices = ScanNetwork(subnet);
      ReplySuccess(*result, flutter::EncodableValue(devices));
      return;
    }

    // -----------------------------------------------------------------------
    // connectNetwork
    // -----------------------------------------------------------------------
    if (method == "connectNetwork") {
      if (!args) {
          ReplyError(*result, "INVALID_ARGUMENT", "Arguments required");
          return;
      }
      auto hostIt = args->find(flutter::EncodableValue("ipAddress"));
      auto portIt = args->find(flutter::EncodableValue("port"));
      if (hostIt == args->end() || hostIt->second.IsNull()) {
          ReplyError(*result, "INVALID_ARGUMENT", "ipAddress is required");
          return;
      }
      std::string host = std::get<std::string>(hostIt->second);
      int port = 9100;
      if (portIt != args->end() && !portIt->second.IsNull()) {
          port = std::get<int>(portIt->second);
      }
      std::string errorMsg;
      if (ConnectNetwork(host, port, errorMsg)) {
          ReplySuccess(*result, flutter::EncodableValue(true));
      } else {
          ReplyError(*result, "CONNECTION_FAILED", errorMsg);
      }
      return;
    }

    // -----------------------------------------------------------------------
    // connectUsb
    // -----------------------------------------------------------------------
    if (method == "connectUsb") {
      if (!args) {
          ReplyError(*result, "INVALID_ARGUMENT", "Arguments required");
          return;
      }
      auto vidIt = args->find(flutter::EncodableValue("vendorId"));
      auto pidIt = args->find(flutter::EncodableValue("productId"));
      if (vidIt == args->end() || vidIt->second.IsNull() ||
          pidIt == args->end() || pidIt->second.IsNull()) {
          ReplyError(*result, "INVALID_ARGUMENT", "vendorId and productId required");
          return;
      }
      int vendorId = std::get<int>(vidIt->second);
      int productId = std::get<int>(pidIt->second);
      std::string errorMsg;
      if (ConnectUsb(vendorId, productId, errorMsg)) {
          ReplySuccess(*result, flutter::EncodableValue(true));
      } else {
          ReplyError(*result, "CONNECTION_FAILED", errorMsg);
      }
      return;
    }

    // -----------------------------------------------------------------------
    // printBytes
    // -----------------------------------------------------------------------
    if (method == "printBytes") {
      if (!args) {
          ReplyError(*result, "INVALID_ARGUMENT", "Arguments required");
          return;
      }
      auto bytesIt = args->find(flutter::EncodableValue("bytes"));
      if (bytesIt == args->end() || bytesIt->second.IsNull()) {
          ReplyError(*result, "INVALID_ARGUMENT", "bytes is required");
          return;
      }
      const auto* byteList = std::get_if<flutter::EncodableList>(&bytesIt->second);
      if (!byteList) {
          ReplyError(*result, "INVALID_DATA", "bytes must be a List<int>");
          return;
      }
      std::vector<uint8_t> data;
      data.reserve(byteList->size());
      for (const auto& val : *byteList) {
          data.push_back(static_cast<uint8_t>(std::get<int>(val)));
      }
      std::string errorMsg;
      if (WriteData(data, errorMsg)) {
          ReplySuccess(*result, flutter::EncodableValue(true));
      } else {
          ReplyError(*result, "WRITE_FAILED", errorMsg);
      }
      return;
    }

    // -----------------------------------------------------------------------
    // printText
    // -----------------------------------------------------------------------
    if (method == "printText") {
      if (!args) {
          ReplyError(*result, "INVALID_ARGUMENT", "Arguments required");
          return;
      }
      auto textIt = args->find(flutter::EncodableValue("text"));
      if (textIt == args->end() || textIt->second.IsNull()) {
          ReplyError(*result, "INVALID_ARGUMENT", "text is required");
          return;
      }
      std::string text = std::get<std::string>(textIt->second);
      // Append LF for line feed
      text += "\n";
      std::vector<uint8_t> data(text.begin(), text.end());
      std::string errorMsg;
      if (WriteData(data, errorMsg)) {
          ReplySuccess(*result, flutter::EncodableValue(true));
      } else {
          ReplyError(*result, "WRITE_FAILED", errorMsg);
      }
      return;
    }

    // -----------------------------------------------------------------------
    // printLines
    // -----------------------------------------------------------------------
    if (method == "printLines") {
      if (!args) {
          ReplyError(*result, "INVALID_ARGUMENT", "Arguments required");
          return;
      }
      auto linesIt = args->find(flutter::EncodableValue("lines"));
      if (linesIt == args->end() || linesIt->second.IsNull()) {
          ReplyError(*result, "INVALID_ARGUMENT", "lines is required");
          return;
      }
      const auto* lineList = std::get_if<flutter::EncodableList>(&linesIt->second);
      if (!lineList) {
          ReplyError(*result, "INVALID_DATA", "lines must be a List<String>");
          return;
      }
      std::string payload;
      for (const auto& val : *lineList) {
          payload += std::get<std::string>(val) + "\n";
      }
      payload += "\n";  // Extra feed after all lines
      std::vector<uint8_t> data(payload.begin(), payload.end());
      std::string errorMsg;
      if (WriteData(data, errorMsg)) {
          ReplySuccess(*result, flutter::EncodableValue(true));
      } else {
          ReplyError(*result, "WRITE_FAILED", errorMsg);
      }
      return;
    }

    // -----------------------------------------------------------------------
    // disconnect
    // -----------------------------------------------------------------------
    if (method == "disconnect") {
      {
          std::lock_guard<std::mutex> lock(g_connection.mutex);
          g_connection.Reset();
      }
      ReplySuccess(*result, flutter::EncodableValue(true));
      return;
    }

    // -----------------------------------------------------------------------
    // isConnected
    // -----------------------------------------------------------------------
    if (method == "isConnected") {
      std::lock_guard<std::mutex> lock(g_connection.mutex);
      ReplySuccess(*result, flutter::EncodableValue(g_connection.IsConnected()));
      return;
    }

    // -----------------------------------------------------------------------
    // getStatus
    // -----------------------------------------------------------------------
    if (method == "getStatus") {
      std::lock_guard<std::mutex> lock(g_connection.mutex);
      flutter::EncodableMap status;
      status[flutter::EncodableValue("online")] =
          flutter::EncodableValue(g_connection.IsConnected());
      status[flutter::EncodableValue("paperOut")] =
          flutter::EncodableValue(false);
      status[flutter::EncodableValue("paperNearEnd")] =
          flutter::EncodableValue(false);
      status[flutter::EncodableValue("coverOpen")] =
          flutter::EncodableValue(false);
      status[flutter::EncodableValue("drawerOpen")] =
          flutter::EncodableValue(false);
      status[flutter::EncodableValue("batteryLow")] =
          flutter::EncodableValue(false);
      status[flutter::EncodableValue("batteryLevel")] =
          flutter::EncodableValue();  // null
      status[flutter::EncodableValue("errorCode")] =
          flutter::EncodableValue();  // null
      status[flutter::EncodableValue("errorMessage")] =
          flutter::EncodableValue();  // null
      ReplySuccess(*result, flutter::EncodableValue(status));
      return;
    }

    // -----------------------------------------------------------------------
    // scanBluetooth / connectBluetooth – not supported on Windows
    // -----------------------------------------------------------------------
    if (method == "scanBluetooth" || method == "connectBluetooth") {
      ReplyError(*result, "NOT_SUPPORTED",
                 "Bluetooth Classic is not supported on Windows in this version",
                 "bluetooth");
      return;
    }

    // -----------------------------------------------------------------------
    // scanBle / connectBle – not supported on Windows
    // -----------------------------------------------------------------------
    if (method == "scanBle" || method == "connectBle") {
      ReplyError(*result, "NOT_SUPPORTED",
                 "Bluetooth Low Energy (BLE) is not supported on Windows in this version",
                 "ble");
      return;
    }

    // -----------------------------------------------------------------------
    // printQrCode, printBarcode, printImage, printPdf, printReceipt,
    // openCashDrawer, requestPermissions, checkPermissions
    // -----------------------------------------------------------------------
    if (method == "printQrCode" || method == "printBarcode" ||
        method == "printImage" || method == "printPdf" ||
        method == "printReceipt") {
      // Delegate to printBytes if we can get the bytes
      // For direct byte-based methods, they come through printBytes
      // These methods need encoding which is done on the Dart side
      ReplyError(*result, "NOT_SUPPORTED",
                 "Method '" + method + "' must send pre-encoded bytes via printBytes on Windows",
                 method);
      return;
    }

    if (method == "openCashDrawer") {
      // ESC/POS cash drawer pulse: 0x1B 0x70 0x00 for pin 0
      uint8_t pulse0[] = {0x1B, 0x70, 0x00};
      int pin = 0;
      if (args) {
          auto pinIt = args->find(flutter::EncodableValue("pin"));
          if (pinIt != args->end() && !pinIt->second.IsNull()) {
              pin = std::get<int>(pinIt->second);
          }
      }
      std::vector<uint8_t> data;
      if (pin == 1) {
          data = {0x1B, 0x70, 0x01};
      } else {
          data = {0x1B, 0x70, 0x00};
      }
      std::string errorMsg;
      if (WriteData(data, errorMsg)) {
          ReplySuccess(*result, flutter::EncodableValue(true));
      } else {
          ReplyError(*result, "WRITE_FAILED", errorMsg);
      }
      return;
    }

    if (method == "requestPermissions" || method == "checkPermissions") {
      // Windows desktop apps generally don't need runtime permissions
      // for USB/network. Always return true.
      ReplySuccess(*result, flutter::EncodableValue(true));
      return;
    }

    if (method == "getPlatformVersion") {
      ReplySuccess(*result, flutter::EncodableValue("Windows 1.0.0"));
      return;
    }

    if (method == "isFeatureSupported") {
      if (!args) {
          ReplySuccess(*result, flutter::EncodableValue(false));
          return;
      }
      auto featureIt = args->find(flutter::EncodableValue("feature"));
      if (featureIt == args->end() || featureIt->second.IsNull()) {
          ReplySuccess(*result, flutter::EncodableValue(false));
          return;
      }
      std::string feature = std::get<std::string>(featureIt->second);
      bool supported = false;
      if (feature == "network") supported = true;
      if (feature == "usb") supported = true;
      if (feature == "qrCode" || feature == "barcode" ||
          feature == "image" || feature == "pdf" ||
          feature == "cashDrawer") supported = true;  // via raw bytes
      if (feature == "bluetooth" || feature == "ble") supported = false;
      ReplySuccess(*result, flutter::EncodableValue(supported));
      return;
    }

    // -----------------------------------------------------------------------
    // Unknown method
    // -----------------------------------------------------------------------
    result->NotImplemented();
  }
};

}  // namespace

// ---------------------------------------------------------------------------
// C API registration entry point
// ---------------------------------------------------------------------------
void ThunderThermalPrintPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  ThunderThermalPrintPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
