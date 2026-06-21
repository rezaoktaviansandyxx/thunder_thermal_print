import Flutter
import UIKit
import CoreBluetooth

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    
    // Method Channel
    let channel = FlutterMethodChannel(name: "id.thunderlab.thunder_thermal_print",
                                       binaryMessenger: controller.binaryMessenger)
    
    // Event Channels
    let connectionStateChannel = FlutterEventChannel(name: "id.thunderlab.thunder_thermal_print/connection_state",
                                                     binaryMessenger: controller.binaryMessenger)
    
    let deviceEventsChannel = FlutterEventChannel(name: "id.thunderlab.thunder_thermal_print/device_events",
                                                  binaryMessenger: controller.binaryMessenger)
    
    // Initialize managers
    let bleManager = BlePrinterManager()
    let networkManager = NetworkPrinterManager()
    
    // Set up method channel handler
    channel.setMethodCallHandler({ [weak bleManager, weak networkManager]
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      
      guard let manager = bleManager else {
        result(FlutterError(code: "NOT_INITIALIZED",
                           message: "BLE manager not initialized",
                           details: nil))
        return
      }
      
      switch call.method {
      // Scanning
      case "scanBle":
        let timeoutMs = (call.arguments as? [String: Any])?["timeoutMs"] as? Int ?? 10000
        manager.startScan(timeoutMs: timeoutMs) { devices in
          result(devices)
        }
        
      case "scanBluetooth":
        // iOS only supports BLE, not classic Bluetooth
        result(FlutterError(code: "NOT_SUPPORTED",
                           message: "Classic Bluetooth not supported on iOS",
                           details: nil))
        
      case "scanUsb":
        result(FlutterError(code: "NOT_SUPPORTED",
                           message: "USB not supported on iOS",
                           details: nil))
        
      case "scanNetwork":
        let args = call.arguments as? [String: Any]
        let subnet = args?["subnet"] as? String
        let timeoutMs = args?["timeoutMs"] as? Int ?? 5000
        networkManager.scanNetwork(subnet: subnet, timeoutMs: timeoutMs) { devices in
          result(devices)
        }
        
      // Connection
      case "connectBle":
        guard let args = call.arguments as? [String: Any],
              let deviceId = args["deviceId"] as? String else {
          result(FlutterError(code: "INVALID_ARGS",
                             message: "deviceId is required",
                             details: nil))
          return
        }
        let autoReconnect = args["autoReconnect"] as? Bool ?? false
        manager.connect(deviceId: deviceId, autoReconnect: autoReconnect) { success in
          result(success)
        }
        
      case "connectBluetooth":
        result(FlutterError(code: "NOT_SUPPORTED",
                           message: "Classic Bluetooth not supported on iOS",
                           details: nil))
        
      case "connectUsb":
        result(FlutterError(code: "NOT_SUPPORTED",
                           message: "USB not supported on iOS",
                           details: nil))
        
      case "connectNetwork":
        guard let args = call.arguments as? [String: Any],
              let ipAddress = args["ipAddress"] as? String else {
          result(FlutterError(code: "INVALID_ARGS",
                             message: "ipAddress is required",
                             details: nil))
          return
        }
        let port = args["port"] as? Int ?? 9100
        let autoReconnect = args["autoReconnect"] as? Bool ?? false
        networkManager.connect(ipAddress: ipAddress, port: port, autoReconnect: autoReconnect) { success in
          result(success)
        }
        
      case "disconnect":
        manager.disconnect()
        networkManager.disconnect()
        result(true)
        
      case "isConnected":
        let connected = manager.isConnected() || networkManager.isConnected()
        result(connected)
        
      // Printing
      case "printBytes":
        guard let args = call.arguments as? [String: Any],
              let data = args["data"] as? FlutterStandardTypedData else {
          result(FlutterError(code: "INVALID_ARGS",
                             message: "data is required",
                             details: nil))
          return
        }
        let transportType = args["transportType"] as? String ?? "ble"
        if transportType == "ble" {
          let success = manager.sendData(data.data)
          result(success)
        } else {
          let success = networkManager.sendData(data.data)
          result(success)
        }
        
      case "printText":
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String else {
          result(FlutterError(code: "INVALID_ARGS",
                             message: "text is required",
                             details: nil))
          return
        }
        let transportType = args["transportType"] as? String ?? "ble"
        let encoder = EscPosEncoder()
        let bytes = encoder.text(text) + encoder.feed(3)
        if transportType == "ble" {
          let success = manager.sendData(bytes)
          result(success)
        } else {
          let success = networkManager.sendData(bytes)
          result(success)
        }
        
      case "printLines":
        guard let args = call.arguments as? [String: Any],
              let lines = args["lines"] as? [String] else {
          result(FlutterError(code: "INVALID_ARGS",
                             message: "lines is required",
                             details: nil))
          return
        }
        let encoder = EscPosEncoder()
        var data = encoder.initialize()
        for line in lines {
          data.append(contentsOf: encoder.text(line))
          data.append(contentsOf: encoder.feed(1))
        }
        data.append(contentsOf: encoder.feed(3))
        data.append(contentsOf: encoder.cut(true))
        
        let transportType = args["transportType"] as? String ?? "ble"
        if transportType == "ble" {
          let success = manager.sendData(data)
          result(success)
        } else {
          let success = networkManager.sendData(data)
          result(success)
        }
        
      case "printQrCode":
        guard let args = call.arguments as? [String: Any],
              let dataStr = args["data"] as? String else {
          result(FlutterError(code: "INVALID_ARGS",
                             message: "data is required",
                             details: nil))
          return
        }
        let size = args["size"] as? Int ?? 6
        let encoder = EscPosEncoder()
        let bytes = encoder.initialize() + encoder.qrCode(dataStr, size: size) + encoder.feed(3)
        
        let transportType = args["transportType"] as? String ?? "ble"
        if transportType == "ble" {
          let success = manager.sendData(bytes)
          result(success)
        } else {
          let success = networkManager.sendData(bytes)
          result(success)
        }
        
      case "printBarcode":
        guard let args = call.arguments as? [String: Any],
              let dataStr = args["data"] as? String else {
          result(FlutterError(code: "INVALID_ARGS",
                             message: "data is required",
                             details: nil))
          return
        }
        let type = args["type"] as? Int ?? 0
        let encoder = EscPosEncoder()
        let bytes = encoder.initialize() + encoder.barcode(dataStr, type: type) + encoder.feed(3)
        
        let transportType = args["transportType"] as? String ?? "ble"
        if transportType == "ble" {
          let success = manager.sendData(bytes)
          result(success)
        } else {
          let success = networkManager.sendData(bytes)
          result(success)
        }
        
      case "printImage":
        guard let args = call.arguments as? [String: Any],
              let imageData = args["imageBytes"] as? FlutterStandardTypedData else {
          result(FlutterError(code: "INVALID_ARGS",
                             message: "imageBytes is required",
                             details: nil))
          return
        }
        let width = args["width"] as? Int ?? 384
        
        guard let image = UIImage(data: imageData.data) else {
          result(FlutterError(code: "IMAGE_ERROR",
                             message: "Failed to decode image",
                             details: nil))
          return
        }
        
        let encoder = EscPosEncoder()
        let bytes = encoder.initialize() + encoder.image(image, width: width) + encoder.feed(3) + encoder.cut(true)
        
        let transportType = args["transportType"] as? String ?? "ble"
        if transportType == "ble" {
          let success = manager.sendData(bytes)
          result(success)
        } else {
          let success = networkManager.sendData(bytes)
          result(success)
        }
        
      case "printPdf":
        result(FlutterError(code: "NOT_SUPPORTED",
                           message: "PDF printing not supported on iOS",
                           details: nil))
        
      case "printReceipt":
        guard let args = call.arguments as? [String: Any],
              let receiptData = args["receiptBytes"] as? FlutterStandardTypedData else {
          result(FlutterError(code: "INVALID_ARGS",
                             message: "receiptBytes is required",
                             details: nil))
          return
        }
        
        let transportType = args["transportType"] as? String ?? "ble"
        if transportType == "ble" {
          let success = manager.sendData(receiptData.data)
          result(success)
        } else {
          let success = networkManager.sendData(receiptData.data)
          result(success)
        }
        
      case "openCashDrawer":
        let encoder = EscPosEncoder()
        let bytes = byteArrayOf(0x1B, 0x70, 0x00, 0x19)
        let data = encoder.initialize() + bytes
        
        let transportType = args["transportType"] as? String ?? "ble"
        if transportType == "ble" {
          let success = manager.sendData(data)
          result(success)
        } else {
          let success = networkManager.sendData(data)
          result(success)
        }
        
      // Status
      case "getStatus":
        var status: [String: Any] = [
          "isConnected": false,
          "connectionState": "disconnected"
        ]
        
        let transportType = (call.arguments as? [String: Any])?["transportType"] as? String ?? "ble"
        if transportType == "ble" {
          status["isConnected"] = manager.isConnected()
          status["connectionState"] = manager.getConnectionState()
        } else {
          status["isConnected"] = networkManager.isConnected()
          status["connectionState"] = networkManager.getConnectionState()
        }
        
        result(status)
        
      // Permissions
      case "requestPermissions":
        // iOS handles permissions automatically when needed
        result(["bluetooth": true])
        
      case "checkPermissions":
        // Check if Bluetooth is authorized
        let authorized = CBCentralManager.authorization == .allowedAlways ||
                        CBCentralManager.authorization == .authorized
        result(["bluetooth": authorized])
        
      // Platform
      case "getPlatformVersion":
        result("iOS " + UIDevice.current.systemVersion)
        
      case "isFeatureSupported":
        guard let args = call.arguments as? [String: Any],
              let feature = args["feature"] as? String else {
          result(FlutterError(code: "INVALID_ARGS",
                             message: "feature is required",
                             details: nil))
          return
        }
        
        switch feature {
        case "bluetooth":
          result(false) // Classic Bluetooth not supported
        case "ble":
          result(true)
        case "usb":
          result(false) // USB not supported on iOS
        case "network":
          result(true)
        case "qrCode":
          result(true)
        case "barcode":
          result(true)
        case "image":
          result(true)
        case "pdf":
          result(false)
        case "cashDrawer":
          result(true)
        default:
          result(false)
        }
        
      // Background Service
      case "startBackgroundMonitoring":
        result(FlutterError(code: "NOT_SUPPORTED",
                           message: "Background service not supported on iOS",
                           details: nil))
        
      case "stopBackgroundMonitoring":
        result(false)
        
      case "isBackgroundMonitoringActive":
        result(false)
        
      // Printer Profiles
      case "savePrinterProfile":
        // Save to UserDefaults
        guard let args = call.arguments as? [String: Any],
              let device = args["device"] as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS",
                             message: "device is required",
                             details: nil))
          return
        }
        UserDefaults.standard.set(device, forKey: "printer_profile_\(device["id"] as? String ?? "default")")
        result(true)
        
      case "loadPrinterProfile":
        guard let args = call.arguments as? [String: Any],
              let id = args["id"] as? String else {
          result(FlutterError(code: "INVALID_ARGS",
                             message: "id is required",
                             details: nil))
          return
        }
        let profile = UserDefaults.standard.dictionary(forKey: "printer_profile_\(id)")
        result(profile)
        
      case "setDefaultPrinter":
        guard let args = call.arguments as? [String: Any],
              let device = args["device"] as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS",
                             message: "device is required",
                             details: nil))
          return
        }
        UserDefaults.standard.set(device, forKey: "default_printer")
        result(true)
        
      case "getPairedDevices":
        // iOS doesn't support classic Bluetooth pairing
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
    })
    
    // Event channel setup
    let connectionStateStreamHandler = ConnectionStateStreamHandler()
    connectionStateChannel.setStreamHandler(connectionStateStreamHandler)
    
    let deviceEventsStreamHandler = DeviceEventsStreamHandler()
    deviceEventsChannel.setStreamHandler(deviceEventsStreamHandler)
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
