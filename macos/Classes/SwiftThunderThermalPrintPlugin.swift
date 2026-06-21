import Cocoa
import FlutterMacOS
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib
import Network

public class SwiftThunderThermalPrintPlugin: NSObject, FlutterPlugin {
  
  private let channelName = "id.thunderlab.thunder_thermal_print"
  private let eventConnectionStateName = "id.thunderlab.thunder_thermal_print/connection_state"
  private let eventDeviceEventsName = "id.thunderlab.thunder_thermal_print/device_events"
  
  private var methodChannel: FlutterMethodChannel?
  private var connectionStateEventChannel: FlutterEventChannel?
  private var deviceEventsEventChannel: FlutterEventChannel?
  
  private var connectionStateSink: FlutterEventSink?
  private var deviceEventsSink: FlutterEventSink?
  
  private var networkManager: NetworkPrinterManager?
  
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SwiftThunderThermalPrintPlugin()
    instance.setupChannels(registrar: registrar)
    registrar.add(instance)
  }
  
  private func setupChannels(registrar: FlutterPluginRegistrar) {
    methodChannel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger
    )
    
    connectionStateEventChannel = FlutterEventChannel(
      name: eventConnectionStateName,
      binaryMessenger: registrar.messenger
    )
    
    deviceEventsEventChannel = FlutterEventChannel(
      name: eventDeviceEventsName,
      binaryMessenger: registrar.messenger
    )
    
    methodChannel?.setMethodCallHandler(handleMethodCall)
    
    connectionStateEventChannel?.setStreamHandler(ConnectionStateStreamHandler())
    deviceEventsEventChannel?.setStreamHandler(DeviceEventsStreamHandler())
  }
  
  private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    
    switch call.method {
    case "scanBluetooth":
      handleScanBluetooth(result: result)
      
    case "scanBle":
      result(FlutterError(code: "NOT_SUPPORTED", message: "BLE scanning not implemented on macOS yet", details: nil))
      
    case "scanUsb":
      handleScanUsb(result: result)
      
    case "scanNetwork":
      let subnet = args?["subnet"] as? String
      let timeoutMs = args?["timeoutMs"] as? Int ?? 5000
      handleScanNetwork(subnet: subnet, timeoutMs: timeoutMs, result: result)
      
    case "connectBluetooth":
      result(FlutterError(code: "NOT_SUPPORTED", message: "Bluetooth Classic not implemented on macOS yet", details: nil))
      
    case "connectBle":
      result(FlutterError(code: "NOT_SUPPORTED", message: "BLE not implemented on macOS yet", details: nil))
      
    case "connectUsb":
      let vendorId = args?["vendorId"] as? Int ?? 0
      let productId = args?["productId"] as? Int ?? 0
      let autoReconnect = args?["autoReconnect"] as? Bool ?? false
      handleConnectUsb(vendorId: vendorId, productId: productId, autoReconnect: autoReconnect, result: result)
      
    case "connectNetwork":
      let ipAddress = args?["ipAddress"] as? String ?? ""
      let port = args?["port"] as? Int ?? 9100
      let autoReconnect = args?["autoReconnect"] as? Bool ?? false
      handleConnectNetwork(ipAddress: ipAddress, port: port, autoReconnect: autoReconnect, result: result)
      
    case "disconnect":
      handleDisconnect(result: result)
      
    case "isConnected":
      handleIsConnected(result: result)
      
    case "getStatus":
      handleGetStatus(result: result)
      
    case "printBytes":
      handlePrintBytes(args: args, result: result)
      
    case "printText":
      handlePrintText(args: args, result: result)
      
    case "printLines":
      handlePrintLines(args: args, result: result)
      
    case "printQrCode":
      result(FlutterError(code: "NOT_SUPPORTED", message: "Use printBytes with pre-encoded QR code ESC/POS bytes", details: nil))
      
    case "printBarcode":
      result(FlutterError(code: "NOT_SUPPORTED", message: "Use printBytes with pre-encoded barcode ESC/POS bytes", details: nil))
      
    case "printImage":
      result(FlutterError(code: "NOT_SUPPORTED", message: "Use printBytes with pre-encoded image ESC/POS bytes", details: nil))
      
    case "printPdf":
      result(FlutterError(code: "NOT_SUPPORTED", message: "PDF printing not supported on macOS", details: nil))
      
    case "printReceipt":
      handlePrintReceipt(args: args, result: result)
      
    case "openCashDrawer":
      handleOpenCashDrawer(args: args, result: result)
      
    case "requestPermissions":
      result(true)
      
    case "checkPermissions":
      result(true)
      
    case "getPlatformVersion":
      let osVersion = ProcessInfo.processInfo.operatingSystemVersion
      result("macOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")
      
    case "isFeatureSupported":
      handleIsFeatureSupported(args: args, result: result)
      
    case "startBackgroundMonitoring":
      result(FlutterError(code: "NOT_SUPPORTED", message: "Background monitoring not supported on macOS", details: nil))
      
    case "stopBackgroundMonitoring":
      result(false)
      
    case "isBackgroundMonitoringActive":
      result(false)
      
    case "savePrinterProfile":
      handleSaveProfile(args: args, result: result)
      
    case "loadPrinterProfile":
      handleLoadProfile(args: args, result: result)
      
    case "setDefaultPrinter":
      handleSetDefaultPrinter(args: args, result: result)
      
    case "getPairedDevices":
      result([])
      
    case "getPrinterCapabilities":
      result([
        "supportsImage": true,
        "supportsQRCode": true,
        "supportsBarcode": true,
        "maxPrintWidth": 384
      ])
      
    case "getPrintedBytesCount":
      result(0)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  // ---- Scanning ----
  
  private func handleScanBluetooth(result: @escaping FlutterResult) {
    // macOS Bluetooth Classic scanning requires IOBluetooth
    // For now, return empty list
    result([])
  }
  
  private func handleScanUsb(result: @escaping FlutterResult) {
    var devices: [[String: Any]] = []
    
    let matchDict = IOServiceMatching(kIOUSBDeviceClassName)
    let iterator = UnsafeMutablePointer<io_iterator_t>.allocate(capacity: 1)
    defer { iterator.deallocate() }
    
    let kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, matchDict, iterator)
    if kernResult == KERN_SUCCESS {
      var index = 0
      while true {
        let service = IOIteratorNext(iterator.pointee)
        if service == IO_OBJECT_NULL { break }
        
        var name: String = "USB Device"
        var vendorId: Int = 0
        var productId: Int = 0
        
        if let productName = IORegistryEntrySearchCFProperty(
          service,
          kIOServicePlane,
          "USB Product Name" as CFString,
          kCFAllocatorDefault,
          UInt32(kIORegistryIterateRecursively)
        ) as? String {
          name = productName
        }
        
        if let vendorIdNum = IORegistryEntrySearchCFProperty(
          service,
          kIOServicePlane,
          "idVendor" as CFString,
          kCFAllocatorDefault,
          UInt32(kIORegistryIterateRecursively)
        ) as? NSNumber {
          vendorId = vendorIdNum.intValue
        }
        
        if let productIdNum = IORegistryEntrySearchCFProperty(
          service,
          kIOServicePlane,
          "idProduct" as CFString,
          kCFAllocatorDefault,
          UInt32(kIORegistryIterateRecursively)
        ) as? NSNumber {
          productId = productIdNum.intValue
        }
        
        IOObjectRelease(service)
        
        let device: [String: Any] = [
          "name": name,
          "address": "usb_\(index)",
          "connectionType": "usb",
          "rssi": NSNull(),
          "vendorId": vendorId,
          "productId": productId,
          "isConnected": false,
          "metadata": [:]
        ]
        devices.append(device)
        index += 1
      }
    }
    
    result(devices)
  }
  
  private func handleScanNetwork(subnet: String?, timeoutMs: Int, result: @escaping FlutterResult) {
    var devices: [[String: Any]] = []
    
    let baseSubnet = subnet ?? "192.168.1"
    let ports = [9100, 9101, 9102, 8080, 631]
    
    // Simple sequential scan (for production, use concurrent)
    for i in 1...254 {
      for port in ports {
        let host = "\(baseSubnet).\(i)"
        if checkPort(host: host, port: port, timeoutMs: 500) {
          let device: [String: Any] = [
            "name": host,
            "address": "\(host):\(port)",
            "connectionType": "network",
            "rssi": 0,
            "vendorId": NSNull(),
            "productId": NSNull(),
            "isConnected": false,
            "metadata": [:]
          ]
          devices.append(device)
        }
      }
    }
    
    result(devices)
  }
  
  private func checkPort(host: String, port: Int, timeoutMs: Int) -> Bool {
    let nwHost = NWEndpoint.Host(host)
    let nwPort = NWEndpoint.Port(rawValue: UInt(port))!
    let connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
    
    let group = DispatchGroup()
    group.enter()
    
    var success = false
    
    connection.stateUpdateHandler = { state in
      switch state {
      case .ready:
        success = true
        connection.cancel()
        group.leave()
      case .failed(_):
        connection.cancel()
        group.leave()
      default:
        break
      }
    }
    
    connection.start(queue: .global())
    
    // Wait for timeout
    DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(timeoutMs)) {
      if connection.state != .ready {
        connection.cancel()
        group.leave()
      }
    }
    
    _ = group.wait(timeout: .now() + .milliseconds(timeoutMs + 100))
    return success
  }
  
  // ---- Connection ----
  
  private func handleConnectUsb(vendorId: Int, productId: Int, autoReconnect: Bool, result: @escaping FlutterResult) {
    // USB connection via IOKit
    // For now, return not implemented - requires full USB implementation
    result(FlutterError(code: "NOT_IMPLEMENTED", message: "USB connection requires full IOKit implementation", details: nil))
  }
  
  private func handleConnectNetwork(ipAddress: String, port: Int, autoReconnect: Bool, result: @escaping FlutterResult) {
    if networkManager == nil {
      networkManager = NetworkPrinterManager()
    }
    
    networkManager?.connect(ipAddress: ipAddress, port: port, autoReconnect: autoReconnect) { success in
      if success {
        self.emitConnectionState("connected")
        result(true)
      } else {
        result(FlutterError(code: "CONNECTION_FAILED", message: "Failed to connect to \(ipAddress):\(port)", details: nil))
      }
    }
  }
  
  private func handleDisconnect(result: @escaping FlutterResult) {
    networkManager?.disconnect()
    emitConnectionState("disconnected")
    result(true)
  }
  
  private func handleIsConnected(result: @escaping FlutterResult) {
    let connected = networkManager?.isConnected ?? false
    result(connected)
  }
  
  // ---- Status ----
  
  private func handleGetStatus(result: @escaping FlutterResult) {
    let status: [String: Any] = [
      "online": networkManager?.isConnected ?? false,
      "paperOut": false,
      "paperNearEnd": false,
      "coverOpen": false,
      "drawerOpen": false,
      "batteryLow": false,
      "batteryLevel": NSNull(),
      "errorCode": NSNull(),
      "errorMessage": NSNull()
    ]
    result(status)
  }
  
  // ---- Printing ----
  
  private func handlePrintBytes(args: [String: Any]?, result: @escaping FlutterResult) {
    guard let args = args,
          let byteList = args["bytes"] as? [Int] else {
      result(FlutterError(code: "INVALID_ARGS", message: "bytes is required", details: nil))
      return
    }
    
    let data = Data(byteList.map { UInt8($0) })
    
    if let networkManager = networkManager, networkManager.isConnected {
      networkManager.sendData(data) { success in
        result(success)
      }
    } else {
      result(FlutterError(code: "NOT_CONNECTED", message: "No printer connected", details: nil))
    }
  }
  
  private func handlePrintText(args: [String: Any]?, result: @escaping FlutterResult) {
    guard let args = args,
          let text = args["text"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "text is required", details: nil))
      return
    }
    
    let encoder = EscPosEncoder()
    let data = encoder.text(text) + encoder.feed(3)
    
    if let networkManager = networkManager, networkManager.isConnected {
      networkManager.sendData(Data(data)) { success in
        result(success)
      }
    } else {
      result(FlutterError(code: "NOT_CONNECTED", message: "No printer connected", details: nil))
    }
  }
  
  private func handlePrintLines(args: [String: Any]?, result: @escaping FlutterResult) {
    guard let args = args,
          let lines = args["lines"] as? [String] else {
      result(FlutterError(code: "INVALID_ARGS", message: "lines is required", details: nil))
      return
    }
    
    let encoder = EscPosEncoder()
    var data = encoder.initialize()
    for line in lines {
      data.append(contentsOf: encoder.text(line))
      data.append(contentsOf: encoder.feed(1))
    }
    data.append(contentsOf: encoder.feed(3))
    
    if let networkManager = networkManager, networkManager.isConnected {
      networkManager.sendData(Data(data)) { success in
        result(success)
      }
    } else {
      result(FlutterError(code: "NOT_CONNECTED", message: "No printer connected", details: nil))
    }
  }
  
  private func handlePrintReceipt(args: [String: Any]?, result: @escaping FlutterResult) {
    guard let args = args,
          let receiptBytes = args["receiptBytes"] as? FlutterStandardTypedData else {
      result(FlutterError(code: "INVALID_ARGS", message: "receiptBytes is required", details: nil))
      return
    }
    
    if let networkManager = networkManager, networkManager.isConnected {
      networkManager.sendData(receiptBytes.data) { success in
        result(success)
      }
    } else {
      result(FlutterError(code: "NOT_CONNECTED", message: "No printer connected", details: nil))
    }
  }
  
  private func handleOpenCashDrawer(args: [String: Any]?, result: @escaping FlutterResult) {
    let pin = args?["pin"] as? Int ?? 0
    let command: [UInt8] = pin == 1 ? [0x1B, 0x70, 0x01] : [0x1B, 0x70, 0x00]
    
    if let networkManager = networkManager, networkManager.isConnected {
      networkManager.sendData(Data(command)) { success in
        result(success)
      }
    } else {
      result(FlutterError(code: "NOT_CONNECTED", message: "No printer connected", details: nil))
    }
  }
  
  // ---- Feature Support ----
  
  private func handleIsFeatureSupported(args: [String: Any]?, result: @escaping FlutterResult) {
    guard let args = args,
          let feature = args["feature"] as? String else {
      result(false)
      return
    }
    
    switch feature {
    case "bluetooth": result(true)
    case "ble": result(false)
    case "usb": result(true)
    case "network": result(true)
    case "qrCode", "barcode", "image", "cashDrawer": result(true)
    case "pdf": result(false)
    default: result(false)
    }
  }
  
  // ---- Printer Profiles ----
  
  private func handleSaveProfile(args: [String: Any]?, result: @escaping FlutterResult) {
    guard let args = args,
          let device = args["device"] as? [String: Any],
          let id = device["id"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "device is required", details: nil))
      return
    }
    
    UserDefaults.standard.set(device, forKey: "printer_profile_\(id)")
    result(true)
  }
  
  private func handleLoadProfile(args: [String: Any]?, result: @escaping FlutterResult) {
    guard let args = args,
          let id = args["id"] as? String else {
      result(FlutterError(code: "INVALID_ARGS", message: "id is required", details: nil))
      return
    }
    
    let profile = UserDefaults.standard.dictionary(forKey: "printer_profile_\(id)")
    result(profile ?? NSNull())
  }
  
  private func handleSetDefaultPrinter(args: [String: Any]?, result: @escaping FlutterResult) {
    guard let args = args,
          let device = args["device"] as? [String: Any] else {
      result(FlutterError(code: "INVALID_ARGS", message: "device is required", details: nil))
      return
    }
    
    UserDefaults.standard.set(device, forKey: "default_printer")
    result(true)
  }
  
  // ---- Event Emission ----
  
  private func emitConnectionState(_ state: String) {
    connectionStateSink?.success(state)
  }
  
  private func emitDeviceEvent(_ event: [String: Any]) {
    deviceEventsSink?.success(event)
  }
}

// Stream Handlers
class ConnectionStateStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    return nil
  }
  
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    return nil
  }
}

class DeviceEventsStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    return nil
  }
  
  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    return nil
  }
}
