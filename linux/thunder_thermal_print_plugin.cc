#include <flutter_linux/flutter_linux.h>

#include <gtk/gtk.h>
#include <glib.h>

#include <cstring>
#include <string>
#include <vector>
#include <thread>
#include <mutex>
#include <atomic>
#include <map>
#include <algorithm>

// POSIX headers
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <errno.h>
#include <ifaddrs.h>
#include <netinet/in.h>

// libusb
#include <libusb.h>

// CUPS
#include <cups/cups.h>
#include <cups/ppd.h>

constexpr char kChannelName[] = "id.thunderlab.thunder_thermal_print";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
static FlMethodResponse* MakeError(const gchar* code,
                                   const gchar* message,
                                   const gchar* details = nullptr) {
    g_autoptr(FlValue) detail_val = fl_value_new_string(details ? details : "");
    return fl_method_error_response_new(code, message, detail_val);
}

static FlMethodResponse* MakeSuccess(FlValue* value) {
    return fl_method_success_response_new(value);
}

static FlMethodResponse* MakeSuccessBool(bool val) {
    return fl_method_success_response_new(fl_value_new_bool(val));
}

// ---------------------------------------------------------------------------
// Connection state
// ---------------------------------------------------------------------------
enum class ConnectionType { kNone, kNetwork, kUsb };

struct ConnectionState {
    std::mutex mutex;
    ConnectionType type = ConnectionType::kNone;

    // Network
    int tcpSocket = -1;
    std::string tcpHost;
    int tcpPort = 0;

    // USB
    libusb_device_handle* usbHandle = nullptr;
    int usbInterface = 0;
    int usbEndpointOut = 0;
    std::string usbPath;

    bool IsConnected() {
        if (type == ConnectionType::kNetwork) {
            // Check if socket is still valid
            int err = 0;
            socklen_t len = sizeof(err);
            if (getsockopt(tcpSocket, SOL_SOCKET, SO_ERROR, &err, &len) != 0) {
                return false;
            }
            return tcpSocket >= 0;
        }
        if (type == ConnectionType::kUsb) {
            return usbHandle != nullptr;
        }
        return false;
    }

    void Reset() {
        if (type == ConnectionType::kNetwork && tcpSocket >= 0) {
            close(tcpSocket);
            tcpSocket = -1;
        }
        if (type == ConnectionType::kUsb && usbHandle != nullptr) {
            libusb_release_interface(usbHandle, usbInterface);
            libusb_close(usbHandle);
            usbHandle = nullptr;
        }
        type = ConnectionType::kNone;
        tcpHost.clear();
        tcpPort = 0;
        usbPath.clear();
        usbInterface = 0;
        usbEndpointOut = 0;
    }
};

static ConnectionState g_connection;
static libusb_context* g_usbContext = nullptr;
static bool g_usbInitialized = false;

bool EnsureUsb() {
    if (g_usbInitialized) return true;
    int rc = libusb_init(&g_usbContext);
    if (rc == 0) {
        g_usbInitialized = true;
        return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// scanUsb – enumerate USB devices via libusb
// ---------------------------------------------------------------------------
FlValue* ScanUsb() {
    g_autoptr(FlValue) list = fl_value_new_list();

    if (!EnsureUsb()) {
        return list;
    }

    libusb_device** devices = nullptr;
    ssize_t count = libusb_get_device_list(g_usbContext, &devices);

    for (ssize_t i = 0; i < count; ++i) {
        libusb_device* dev = devices[i];
        struct libusb_device_descriptor desc;
        if (libusb_get_device_descriptor(dev, &desc) != 0) continue;

        g_autoptr(FlValue) map = fl_value_new_map();
        fl_value_set_string(map, "name",
            fl_value_new_string("USB Device"));
        fl_value_set_string(map, "address",
            fl_value_new_string(std::to_string(i).c_str()));
        fl_value_set_string(map, "connectionType",
            fl_value_new_string("usb"));
        fl_value_set_string(map, "rssi",
            fl_value_new_null());
        fl_value_set_string(map, "vendorId",
            fl_value_new_int(desc.idVendor));
        fl_value_set_string(map, "productId",
            fl_value_new_int(desc.idProduct));
        fl_value_set_string(map, "isConnected",
            fl_value_new_bool(false));

        g_autoptr(FlValue) metadata = fl_value_new_map();
        fl_value_set_string(metadata, "busNumber",
            fl_value_new_int(libusb_get_bus_number(dev)));
        fl_value_set_string(metadata, "deviceAddress",
            fl_value_new_int(libusb_get_device_address(dev)));
        fl_value_set_string(map, "metadata", metadata);

        fl_value_append(list, map);
    }

    libusb_free_device_list(devices, 1);
    return list;
}

// ---------------------------------------------------------------------------
// scanNetwork – TCP port scan on local subnet
// ---------------------------------------------------------------------------
FlValue* ScanNetwork(const std::string& subnet) {
    g_autoptr(FlValue) list = fl_value_new_list();

    std::string baseSubnet = subnet;
    if (baseSubnet.empty()) {
        struct ifaddrs* ifAddrStruct = nullptr;
        if (getifaddrs(&ifAddrStruct) != 0) return list;

        for (struct ifaddrs* ifa = ifAddrStruct; ifa != nullptr; ifa = ifa->ifa_next) {
            if (!ifa->ifa_addr || ifa->ifa_addr->sa_family != AF_INET) continue;
            // Skip loopback
            if (ifa->ifa_flags & IFF_LOOPBACK) continue;

            struct sockaddr_in* addr = (struct sockaddr_in*)ifa->ifa_addr;
            std::string ip = inet_ntoa(addr->sin_addr);
            auto dot = ip.rfind('.');
            if (dot != std::string::npos) {
                baseSubnet = ip.substr(0, dot);
                break;
            }
        }
        freeifaddrs(ifAddrStruct);
    }

    if (baseSubnet.empty()) {
        baseSubnet = "192.168.1";
    }

    const std::vector<int> ports = {9100, 9101, 9102, 8080, 631};

    for (int i = 1; i <= 254; ++i) {
        for (int port : ports) {
            std::string host = baseSubnet + "." + std::to_string(i);

            int sock = socket(AF_INET, SOCK_STREAM, 0);
            if (sock < 0) continue;

            // Non-blocking connect with 1s timeout
            int flags = fcntl(sock, F_GETFL, 0);
            fcntl(sock, F_SETFL, flags | O_NONBLOCK);

            struct sockaddr_in addr;
            memset(&addr, 0, sizeof(addr));
            addr.sin_family = AF_INET;
            addr.sin_port = htons(port);
            addr.sin_addr.s_addr = inet_addr(host.c_str());

            int rc = connect(sock, (struct sockaddr*)&addr, sizeof(addr));
            if (rc < 0 && errno != EINPROGRESS) {
                close(sock);
                continue;
            }

            struct pollfd pfd;
            pfd.fd = sock;
            pfd.events = POLLOUT;
            int pollRc = poll(&pfd, 1, 1000);  // 1 second timeout

            bool connected = false;
            if (pollRc > 0) {
                int err = 0;
                socklen_t len = sizeof(err);
                getsockopt(sock, SOL_SOCKET, SO_ERROR, &err, &len);
                connected = (err == 0);
            }

            close(sock);

            if (connected) {
                g_autoptr(FlValue) map = fl_value_new_map();
                fl_value_set_string(map, "name",
                    fl_value_new_string(host.c_str()));
                fl_value_set_string(map, "address",
                    fl_value_new_string((host + ":" + std::to_string(port)).c_str()));
                fl_value_set_string(map, "connectionType",
                    fl_value_new_string("network"));
                fl_value_set_string(map, "rssi",
                    fl_value_new_int(0));
                fl_value_set_string(map, "vendorId",
                    fl_value_new_null());
                fl_value_set_string(map, "productId",
                    fl_value_new_null());
                fl_value_set_string(map, "isConnected",
                    fl_value_new_bool(false));

                g_autoptr(FlValue) metadata = fl_value_new_map();
                fl_value_set_string(map, "metadata", metadata);

                fl_value_append(list, map);
            }
        }
    }

    return list;
}

// ---------------------------------------------------------------------------
// connectNetwork
// ---------------------------------------------------------------------------
bool ConnectNetwork(const std::string& host, int port, std::string& errorMsg) {
    std::lock_guard<std::mutex> lock(g_connection.mutex);
    g_connection.Reset();

    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        errorMsg = "Failed to create socket: " + std::string(strerror(errno));
        return false;
    }

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    addr.sin_addr.s_addr = inet_addr(host.c_str());

    // Non-blocking connect with 10s timeout
    int flags = fcntl(sock, F_GETFL, 0);
    fcntl(sock, F_SETFL, flags | O_NONBLOCK);

    int rc = connect(sock, (struct sockaddr*)&addr, sizeof(addr));
    if (rc < 0 && errno != EINPROGRESS) {
        close(sock);
        errorMsg = "Connection failed: " + std::string(strerror(errno));
        return false;
    }

    struct pollfd pfd;
    pfd.fd = sock;
    pfd.events = POLLOUT;
    int pollRc = poll(&pfd, 1, 10000);  // 10 second timeout

    if (pollRc <= 0) {
        close(sock);
        errorMsg = "Connection timed out";
        return false;
    }

    int err = 0;
    socklen_t len = sizeof(err);
    getsockopt(sock, SOL_SOCKET, SO_ERROR, &err, &len);
    if (err != 0) {
        close(sock);
        errorMsg = "Connection failed: " + std::string(strerror(err));
        return false;
    }

    // Restore blocking mode
    fcntl(sock, F_SETFL, flags);

    g_connection.type = ConnectionType::kNetwork;
    g_connection.tcpSocket = sock;
    g_connection.tcpHost = host;
    g_connection.tcpPort = port;
    return true;
}

// ---------------------------------------------------------------------------
// connectUsb
// ---------------------------------------------------------------------------
bool ConnectUsb(int vendorId, int productId, std::string& errorMsg) {
    if (!EnsureUsb()) {
        errorMsg = "libusb initialization failed";
        return false;
    }

    std::lock_guard<std::mutex> lock(g_connection.mutex);
    g_connection.Reset();

    libusb_device_handle* handle = nullptr;
    int rc = libusb_open_device_with_vid_pid(g_usbContext, vendorId, productId, &handle);
    if (rc != 0 || handle == nullptr) {
        errorMsg = "USB device VID:" + std::to_string(vendorId) +
                   " PID:" + std::to_string(productId) +
                   " not found (error " + std::to_string(rc) + ")";
        return false;
    }

    // Detach kernel driver if active
    if (libusb_kernel_driver_active(handle, 0) == 1) {
        libusb_detach_kernel_driver(handle, 0);
    }

    rc = libusb_claim_interface(handle, 0);
    if (rc != 0) {
        libusb_close(handle);
        errorMsg = "Failed to claim USB interface: error " + std::to_string(rc);
        return false;
    }

    // Find bulk OUT endpoint
    struct libusb_config_descriptor* config = nullptr;
    libusb_get_active_config_descriptor(
        libusb_get_device(handle), &config);

    int epOut = -1;
    if (config) {
        for (int i = 0; i < config->bNumInterfaces; ++i) {
            const struct libusb_interface& iface = config->interface[i];
            for (int j = 0; j < iface.num_altsetting; ++j) {
                const struct libusb_interface_descriptor& alt = iface.altsetting[j];
                if (alt.bInterfaceClass == LIBUSB_CLASS_PRINTER ||
                    alt.bInterfaceClass == LIBUSB_CLASS_VENDOR_SPEC) {
                    for (int k = 0; k < alt.bNumEndpoints; ++k) {
                        const struct libusb_endpoint_descriptor& ep = alt.endpoint[k];
                        if ((ep.bmAttributes & LIBUSB_TRANSFER_TYPE_MASK) == LIBUSB_TRANSFER_TYPE_BULK &&
                            !(ep.bEndpointAddress & LIBUSB_ENDPOINT_IN)) {
                            epOut = ep.bEndpointAddress;
                            break;
                        }
                    }
                    break;
                }
            }
            if (epOut >= 0) break;
        }
        libusb_free_config_descriptor(config);
    }

    if (epOut < 0) {
        // Fallback: try endpoint 1 OUT
        epOut = 0x01;
    }

    g_connection.type = ConnectionType::kUsb;
    g_connection.usbHandle = handle;
    g_connection.usbInterface = 0;
    g_connection.usbEndpointOut = epOut;
    return true;
}

// ---------------------------------------------------------------------------
// Write data
// ---------------------------------------------------------------------------
bool WriteData(const std::vector<uint8_t>& data, std::string& errorMsg) {
    std::lock_guard<std::mutex> lock(g_connection.mutex);

    if (!g_connection.IsConnected()) {
        errorMsg = "Not connected to any printer";
        return false;
    }

    if (g_connection.type == ConnectionType::kNetwork) {
        size_t totalSent = 0;
        while (totalSent < data.size()) {
            ssize_t sent = send(g_connection.tcpSocket,
                                data.data() + totalSent,
                                data.size() - totalSent, 0);
            if (sent < 0) {
                errorMsg = "Network send failed: " + std::string(strerror(errno));
                return false;
            }
            totalSent += sent;
        }
        return true;
    }

    if (g_connection.type == ConnectionType::kUsb && g_connection.usbHandle) {
        int transferred = 0;
        int rc = libusb_bulk_transfer(g_connection.usbHandle,
                                        g_connection.usbEndpointOut,
                                        const_cast<uint8_t*>(data.data()),
                                        static_cast<int>(data.size()),
                                        &transferred, 5000);
        if (rc != 0 || transferred != static_cast<int>(data.size())) {
            errorMsg = "USB write failed: error " + std::to_string(rc);
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
static void method_call_cb(FlMethodChannel* channel,
                            FlMethodCall* method_call,
                            gpointer user_data) {
    const gchar* method = fl_method_call_get_name(method_call);
    FlValue* args = fl_method_call_get_args(method_call);

    // -----------------------------------------------------------------------
    // scanUsb
    // -----------------------------------------------------------------------
    if (strcmp(method, "scanUsb") == 0) {
        g_autoptr(FlValue) list = ScanUsb();
        fl_method_call_respond_success(method_call, list, nullptr);
        return;
    }

    // -----------------------------------------------------------------------
    // scanNetwork
    // -----------------------------------------------------------------------
    if (strcmp(method, "scanNetwork") == 0) {
        std::string subnet;
        if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
            FlValue* subnetVal = fl_value_lookup_string(args, "subnet");
            if (subnetVal && fl_value_get_type(subnetVal) == FL_VALUE_TYPE_STRING) {
                subnet = fl_value_get_string(subnetVal);
            }
        }
        g_autoptr(FlValue) list = ScanNetwork(subnet);
        fl_method_call_respond_success(method_call, list, nullptr);
        return;
    }

    // -----------------------------------------------------------------------
    // connectNetwork
    // -----------------------------------------------------------------------
    if (strcmp(method, "connectNetwork") == 0) {
        if (!args || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
            fl_method_call_respond_error(method_call, "INVALID_ARGUMENT",
                                           "Arguments required", nullptr, nullptr);
            return;
        }
        FlValue* hostVal = fl_value_lookup_string(args, "ipAddress");
        FlValue* portVal = fl_value_lookup_string(args, "port");
        if (!hostVal || fl_value_get_type(hostVal) != FL_VALUE_TYPE_STRING) {
            fl_method_call_respond_error(method_call, "INVALID_ARGUMENT",
                                           "ipAddress is required", nullptr, nullptr);
            return;
        }
        std::string host = fl_value_get_string(hostVal);
        int port = 9100;
        if (portVal && fl_value_get_type(portVal) == FL_VALUE_TYPE_INT) {
            port = fl_value_get_int(portVal);
        }
        std::string errorMsg;
        if (ConnectNetwork(host, port, errorMsg)) {
            fl_method_call_respond_success(method_call, fl_value_new_bool(true), nullptr);
        } else {
            fl_method_call_respond_error(method_call, "CONNECTION_FAILED",
                                           errorMsg.c_str(), nullptr, nullptr);
        }
        return;
    }

    // -----------------------------------------------------------------------
    // connectUsb
    // -----------------------------------------------------------------------
    if (strcmp(method, "connectUsb") == 0) {
        if (!args || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
            fl_method_call_respond_error(method_call, "INVALID_ARGUMENT",
                                           "Arguments required", nullptr, nullptr);
            return;
        }
        FlValue* vidVal = fl_value_lookup_string(args, "vendorId");
        FlValue* pidVal = fl_value_lookup_string(args, "productId");
        if (!vidVal || !pidVal ||
            fl_value_get_type(vidVal) != FL_VALUE_TYPE_INT ||
            fl_value_get_type(pidVal) != FL_VALUE_TYPE_INT) {
            fl_method_call_respond_error(method_call, "INVALID_ARGUMENT",
                                           "vendorId and productId required", nullptr, nullptr);
            return;
        }
        int vendorId = fl_value_get_int(vidVal);
        int productId = fl_value_get_int(pidVal);
        std::string errorMsg;
        if (ConnectUsb(vendorId, productId, errorMsg)) {
            fl_method_call_respond_success(method_call, fl_value_new_bool(true), nullptr);
        } else {
            fl_method_call_respond_error(method_call, "CONNECTION_FAILED",
                                           errorMsg.c_str(), nullptr, nullptr);
        }
        return;
    }

    // -----------------------------------------------------------------------
    // printBytes
    // -----------------------------------------------------------------------
    if (strcmp(method, "printBytes") == 0) {
        if (!args || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
            fl_method_call_respond_error(method_call, "INVALID_ARGUMENT",
                                           "Arguments required", nullptr, nullptr);
            return;
        }
        FlValue* bytesVal = fl_value_lookup_string(args, "bytes");
        if (!bytesVal || fl_value_get_type(bytesVal) != FL_VALUE_TYPE_LIST) {
            fl_method_call_respond_error(method_call, "INVALID_DATA",
                                           "bytes must be a List<int>", nullptr, nullptr);
            return;
        }
        std::vector<uint8_t> data;
        size_t len = fl_value_get_length(bytesVal);
        data.reserve(len);
        for (size_t i = 0; i < len; ++i) {
            data.push_back(static_cast<uint8_t>(fl_value_get_int(fl_value_get_list_value(bytesVal, i))));
        }
        std::string errorMsg;
        if (WriteData(data, errorMsg)) {
            fl_method_call_respond_success(method_call, fl_value_new_bool(true), nullptr);
        } else {
            fl_method_call_respond_error(method_call, "WRITE_FAILED",
                                           errorMsg.c_str(), nullptr, nullptr);
        }
        return;
    }

    // -----------------------------------------------------------------------
    // printText
    // -----------------------------------------------------------------------
    if (strcmp(method, "printText") == 0) {
        if (!args || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
            fl_method_call_respond_error(method_call, "INVALID_ARGUMENT",
                                           "Arguments required", nullptr, nullptr);
            return;
        }
        FlValue* textVal = fl_value_lookup_string(args, "text");
        if (!textVal || fl_value_get_type(textVal) != FL_VALUE_TYPE_STRING) {
            fl_method_call_respond_error(method_call, "INVALID_ARGUMENT",
                                           "text is required", nullptr, nullptr);
            return;
        }
        std::string text = fl_value_get_string(textVal);
        text += "\n";
        std::vector<uint8_t> data(text.begin(), text.end());
        std::string errorMsg;
        if (WriteData(data, errorMsg)) {
            fl_method_call_respond_success(method_call, fl_value_new_bool(true), nullptr);
        } else {
            fl_method_call_respond_error(method_call, "WRITE_FAILED",
                                           errorMsg.c_str(), nullptr, nullptr);
        }
        return;
    }

    // -----------------------------------------------------------------------
    // printLines
    // -----------------------------------------------------------------------
    if (strcmp(method, "printLines") == 0) {
        if (!args || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
            fl_method_call_respond_error(method_call, "INVALID_ARGUMENT",
                                           "Arguments required", nullptr, nullptr);
            return;
        }
        FlValue* linesVal = fl_value_lookup_string(args, "lines");
        if (!linesVal || fl_value_get_type(linesVal) != FL_VALUE_TYPE_LIST) {
            fl_method_call_respond_error(method_call, "INVALID_DATA",
                                           "lines must be a List<String>", nullptr, nullptr);
            return;
        }
        std::string payload;
        size_t len = fl_value_get_length(linesVal);
        for (size_t i = 0; i < len; ++i) {
            FlValue* lineVal = fl_value_get_list_value(linesVal, i);
            if (fl_value_get_type(lineVal) == FL_VALUE_TYPE_STRING) {
                payload += fl_value_get_string(lineVal);
                payload += "\n";
            }
        }
        payload += "\n";
        std::vector<uint8_t> data(payload.begin(), payload.end());
        std::string errorMsg;
        if (WriteData(data, errorMsg)) {
            fl_method_call_respond_success(method_call, fl_value_new_bool(true), nullptr);
        } else {
            fl_method_call_respond_error(method_call, "WRITE_FAILED",
                                           errorMsg.c_str(), nullptr, nullptr);
        }
        return;
    }

    // -----------------------------------------------------------------------
    // disconnect
    // -----------------------------------------------------------------------
    if (strcmp(method, "disconnect") == 0) {
        {
            std::lock_guard<std::mutex> lock(g_connection.mutex);
            g_connection.Reset();
        }
        fl_method_call_respond_success(method_call, fl_value_new_bool(true), nullptr);
        return;
    }

    // -----------------------------------------------------------------------
    // isConnected
    // -----------------------------------------------------------------------
    if (strcmp(method, "isConnected") == 0) {
        std::lock_guard<std::mutex> lock(g_connection.mutex);
        fl_method_call_respond_success(method_call,
                                       fl_value_new_bool(g_connection.IsConnected()), nullptr);
        return;
    }

    // -----------------------------------------------------------------------
    // getStatus
    // -----------------------------------------------------------------------
    if (strcmp(method, "getStatus") == 0) {
        std::lock_guard<std::mutex> lock(g_connection.mutex);
        g_autoptr(FlValue) map = fl_value_new_map();
        fl_value_set_string(map, "online",
            fl_value_new_bool(g_connection.IsConnected()));
        fl_value_set_string(map, "paperOut", fl_value_new_bool(false));
        fl_value_set_string(map, "paperNearEnd", fl_value_new_bool(false));
        fl_value_set_string(map, "coverOpen", fl_value_new_bool(false));
        fl_value_set_string(map, "drawerOpen", fl_value_new_bool(false));
        fl_value_set_string(map, "batteryLow", fl_value_new_bool(false));
        fl_value_set_string(map, "batteryLevel", fl_value_new_null());
        fl_value_set_string(map, "errorCode", fl_value_new_null());
        fl_value_set_string(map, "errorMessage", fl_value_new_null());
        fl_method_call_respond_success(method_call, map, nullptr);
        return;
    }

    // -----------------------------------------------------------------------
    // Bluetooth – not supported on Linux desktop
    // -----------------------------------------------------------------------
    if (strcmp(method, "scanBluetooth") == 0 || strcmp(method, "connectBluetooth") == 0) {
        fl_method_call_respond_error(method_call, "NOT_SUPPORTED",
            "Bluetooth Classic is not supported on Linux desktop in this version",
            "bluetooth", nullptr);
        return;
    }

    // -----------------------------------------------------------------------
    // BLE – not supported on Linux desktop
    // -----------------------------------------------------------------------
    if (strcmp(method, "scanBle") == 0 || strcmp(method, "connectBle") == 0) {
        fl_method_call_respond_error(method_call, "NOT_SUPPORTED",
            "Bluetooth Low Energy (BLE) is not supported on Linux desktop in this version",
            "ble", nullptr);
        return;
    }

    // -----------------------------------------------------------------------
    // openCashDrawer – send ESC/POS pulse directly
    // -----------------------------------------------------------------------
    if (strcmp(method, "openCashDrawer") == 0) {
        int pin = 0;
        if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
            FlValue* pinVal = fl_value_lookup_string(args, "pin");
            if (pinVal && fl_value_get_type(pinVal) == FL_VALUE_TYPE_INT) {
                pin = fl_value_get_int(pinVal);
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
            fl_method_call_respond_success(method_call, fl_value_new_bool(true), nullptr);
        } else {
            fl_method_call_respond_error(method_call, "WRITE_FAILED",
                                           errorMsg.c_str(), nullptr, nullptr);
        }
        return;
    }

    // -----------------------------------------------------------------------
    // printQrCode / printBarcode / printImage / printPdf / printReceipt
    // -----------------------------------------------------------------------
    if (strcmp(method, "printQrCode") == 0 ||
        strcmp(method, "printBarcode") == 0 ||
        strcmp(method, "printImage") == 0 ||
        strcmp(method, "printPdf") == 0 ||
        strcmp(method, "printReceipt") == 0) {
        fl_method_call_respond_error(method_call, "NOT_SUPPORTED",
            std::string("Method '") + method + "' must send pre-encoded bytes via printBytes on Linux",
            method, nullptr);
        return;
    }

    // -----------------------------------------------------------------------
    // requestPermissions / checkPermissions
    // -----------------------------------------------------------------------
    if (strcmp(method, "requestPermissions") == 0 ||
        strcmp(method, "checkPermissions") == 0) {
        fl_method_call_respond_success(method_call, fl_value_new_bool(true), nullptr);
        return;
    }

    // -----------------------------------------------------------------------
    // getPlatformVersion
    // -----------------------------------------------------------------------
    if (strcmp(method, "getPlatformVersion") == 0) {
        fl_method_call_respond_success(method_call,
            fl_value_new_string("Linux 1.0.0"), nullptr);
        return;
    }

    // -----------------------------------------------------------------------
    // isFeatureSupported
    // -----------------------------------------------------------------------
    if (strcmp(method, "isFeatureSupported") == 0) {
        bool supported = false;
        if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
            FlValue* featureVal = fl_value_lookup_string(args, "feature");
            if (featureVal && fl_value_get_type(featureVal) == FL_VALUE_TYPE_STRING) {
                std::string feature = fl_value_get_string(featureVal);
                if (feature == "network") supported = true;
                if (feature == "usb") supported = true;
                if (feature == "qrCode" || feature == "barcode" ||
                    feature == "image" || feature == "pdf" ||
                    feature == "cashDrawer") supported = true;
                if (feature == "bluetooth" || feature == "ble") supported = false;
            }
        }
        fl_method_call_respond_success(method_call, fl_value_new_bool(supported), nullptr);
        return;
    }

    // -----------------------------------------------------------------------
    // Unhandled
    // -----------------------------------------------------------------------
    fl_method_call_respond_not_implemented(method_call, nullptr);
}

// ---------------------------------------------------------------------------
// Plugin registration
// ---------------------------------------------------------------------------
void thunder_thermal_print_plugin_class_init(FluderThermalPrintPluginClass* klass) {}

void thunder_thermal_print_plugin_init(ThunderThermalPrintPlugin* self) {}

gboolean thunder_thermal_print_plugin_handle_method_call(
    ThunderThermalPrintPlugin* self,
    FlMethodCall* method_call) {
    // Delegate to static callback
    method_call_cb(nullptr, method_call, nullptr);
    return TRUE;
}

// C API
ThunderThermalPrintPlugin* thunder_thermal_print_plugin_new(
    FlPluginRegistrar* registrar) {
    g_autoptr(FlPluginRegistrar) reg = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));
    ThunderThermalPrintPlugin* self = THUNDER_THERMAL_PRINT_PLUGIN(
        g_object_new(thunder_thermal_print_plugin_get_type(), nullptr));

    FlView* view = fl_plugin_registrar_get_view(reg);
    g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
        fl_plugin_registrar_get_messenger(reg),
        kChannelName,
        FL_METHOD_CODEC(fl_standard_method_codec_new()));

    fl_method_channel_set_method_call_handler(
        channel,
        method_call_cb,
        g_object_ref(self),
        g_object_unref);

    return self;
}

// GType boilerplate
G_DEFINE_TYPE(ThunderThermalPrintPlugin, thunder_thermal_print_plugin, g_object_get_type())

static void thunder_thermal_print_plugin_class_init(ThunderThermalPrintPluginClass* klass) {}

static void thunder_thermal_print_plugin_init(ThunderThermalPrintPlugin* self) {}

// Export the plugin
void thunder_thermal_print_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
    thunder_thermal_print_plugin_new(registrar);
}
