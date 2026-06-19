import Flutter
import UIKit
import CoreBluetooth
import Network

public class SwiftThunderThermalPrintPlugin: NSObject, FlutterPlugin {

    // MARK: - Constants

    private let methodChannelName = "id.thunderlab.thunder_thermal_print/methods"
    private let connectionEventChannelName = "id.thunderlab.thunder_thermal_print/connection"
    private let deviceEventChannelName = "id.thunderlab.thunder_thermal_print/devices"
    private let dataEventChannelName = "id.thunderlab.thunder_thermal_print/data"

    // MARK: - Properties

    private var channel: FlutterMethodChannel?
    private var connectionEventChannel: FlutterEventChannel?
    private var deviceEventChannel: FlutterEventChannel?
    private var dataEventChannel: FlutterEventChannel?

    // Stream sinks
    private var connectionSink: FlutterEventSink?
    private var deviceSink: FlutterEventSink?
    private var dataSink: FlutterEventSink?

    // Manager instances
    private var bluetoothManager: BluetoothPrinterManager?
    private var bleManager: BlePrinterManager?
    private var networkManager: NetworkPrinterManager?

    // Current active connection type
    private var activeConnectionType: String = "none"

    // MARK: - Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftThunderThermalPrintPlugin()

        // Method channel
        let methodChannel = FlutterMethodChannel(
            name: "id.thunderlab.thunder_thermal_print",
            binaryMessenger: registrar.messenger()
        )

        // Event channels
        let connectionChannel = FlutterEventChannel(
            name: "id.thunderlab.thunder_thermal_print/connection",
            binaryMessenger: registrar.messenger()
        )
        let deviceChannel = FlutterEventChannel(
            name: "id.thunderlab.thunder_thermal_print/devices",
            binaryMessenger: registrar.messenger()
        )
        let dataChannel = FlutterEventChannel(
            name: "id.thunderlab.thunder_thermal_print/data",
            binaryMessenger: registrar.messenger()
        )

        instance.channel = methodChannel
        instance.connectionEventChannel = connectionChannel
        instance.deviceEventChannel = deviceChannel
        instance.dataEventChannel = dataChannel

        // Set up stream handlers
        connectionChannel.setStreamHandler(instance)
        deviceChannel.setStreamHandler(instance)
        dataChannel.setStreamHandler(instance)

        registrar.addMethodCallDelegate(instance, channel: methodChannel)
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        channel = nil
        connectionEventChannel = nil
        deviceEventChannel = nil
        dataEventChannel = nil
        connectionSink = nil
        deviceSink = nil
        dataSink = nil
    }

    // MARK: - Initialization Helpers

    private func ensureBluetoothManager() -> BluetoothPrinterManager {
        if bluetoothManager == nil {
            bluetoothManager = BluetoothPrinterManager()
            bluetoothManager!.delegate = self
        }
        return bluetoothManager!
    }

    private func ensureBleManager() -> BlePrinterManager {
        if bleManager == nil {
            bleManager = BlePrinterManager()
            bleManager!.delegate = self
        }
        return bleManager!
    }

    private func ensureNetworkManager() -> NetworkPrinterManager {
        if networkManager == nil {
            networkManager = NetworkPrinterManager()
            networkManager!.delegate = self
        }
        return networkManager!
    }

    // MARK: - Method Call Handler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        // MARK: Scanning
        case "scanBluetooth":
            handleScanBluetooth(call: call, result: result)

        case "scanBle":
            handleScanBle(call: call, result: result)

        case "scanUsb":
            result(FlutterError(code: "UNSUPPORTED", message: "USB is not directly supported on iOS. Use network or BLE printers instead.", details: nil))

        case "scanNetwork":
            handleScanNetwork(call: call, result: result)

        // MARK: Connection
        case "connectBluetooth":
            handleConnectBluetooth(call: call, result: result)

        case "connectBle":
            handleConnectBle(call: call, result: result)

        case "connectUsb":
            result(FlutterError(code: "UNSUPPORTED", message: "USB is not directly supported on iOS. Use network or BLE printers instead.", details: nil))

        case "connectNetwork":
            handleConnectNetwork(call: call, result: result)

        case "disconnect":
            handleDisconnect(result: result)

        // MARK: Status
        case "isConnected":
            result(isAnyConnected())

        case "getStatus":
            handleGetStatus(result: result)

        // MARK: Printing
        case "printBytes":
            handlePrintBytes(call: call, result: result)

        case "printText":
            handlePrintText(call: call, result: result)

        case "printLines":
            handlePrintLines(call: call, result: result)

        case "printQrCode":
            handlePrintQrCode(call: call, result: result)

        case "printBarcode":
            handlePrintBarcode(call: call, result: result)

        case "printImage":
            handlePrintImage(call: call, result: result)

        case "printPdf":
            result(FlutterError(code: "UNSUPPORTED", message: "Direct PDF printing is not supported on iOS. Convert PDF to image first and use printImage.", details: nil))

        case "printReceipt":
            handlePrintReceipt(call: call, result: result)

        case "openCashDrawer":
            handleOpenCashDrawer(call: call, result: result)

        // MARK: Permissions
        case "requestPermissions":
            handleRequestPermissions(result: result)

        case "checkPermissions":
            handleCheckPermissions(result: result)

        // MARK: Platform
        case "getPlatformVersion":
            let version = "iOS \(UIDevice.current.systemVersion)"
            result(version)

        case "isFeatureSupported":
            handleIsFeatureSupported(call: call, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Scanning Handlers

    private func handleScanBluetooth(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected arguments map", details: nil))
            return
        }

        let duration = args["duration"] as? Double ?? 10.0
        let manager = ensureBluetoothManager()

        manager.scan(duration: duration)

        // Return immediately; devices come via event channel
        result(true)
    }

    private func handleScanBle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected arguments map", details: nil))
            return
        }

        let duration = args["duration"] as? Double ?? 10.0
        let serviceUUIDs = args["serviceUUIDs"] as? [String]
        let scanAll = args["scanAll"] as? Bool ?? false
        let manager = ensureBleManager()

        if scanAll {
            manager.scanAll(duration: duration)
        } else {
            manager.scan(duration: duration, serviceUUIDs: serviceUUIDs)
        }

        result(true)
    }

    private func handleScanNetwork(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected arguments map", details: nil))
            return
        }

        let duration = args["duration"] as? Double ?? 8.0
        let port = args["port"] as? Int ?? 0
        let manager = ensureNetworkManager()

        manager.scan(duration: duration, port: UInt16(port))
        result(true)
    }

    // MARK: - Connection Handlers

    private func handleConnectBluetooth(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let address = args["address"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected 'address' in arguments", details: nil))
            return
        }

        let manager = ensureBluetoothManager()
        manager.connect(to: address) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.activeConnectionType = "bluetooth"
                    result(true)
                } else {
                    result(FlutterError(code: "CONNECTION_FAILED", message: error ?? "Connection failed", details: nil))
                }
            }
        }
    }

    private func handleConnectBle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let address = args["address"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected 'address' in arguments", details: nil))
            return
        }

        let manager = ensureBleManager()
        manager.connect(to: address) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.activeConnectionType = "ble"
                    result(true)
                } else {
                    result(FlutterError(code: "CONNECTION_FAILED", message: error ?? "Connection failed", details: nil))
                }
            }
        }
    }

    private func handleConnectNetwork(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let address = args["address"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected 'address' in arguments", details: nil))
            return
        }

        let manager = ensureNetworkManager()
        manager.connect(to: address) { success, error in
            DispatchQueue.main.async {
                if success {
                    self.activeConnectionType = "network"
                    result(true)
                } else {
                    result(FlutterError(code: "CONNECTION_FAILED", message: error ?? "Connection failed", details: nil))
                }
            }
        }
    }

    private func handleDisconnect(result: @escaping FlutterResult) {
        bluetoothManager?.disconnect()
        bleManager?.disconnect()
        networkManager?.disconnect()
        activeConnectionType = "none"
        result(true)
    }

    // MARK: - Status Handlers

    private func isAnyConnected() -> Bool {
        return bluetoothManager?.isConnected == true ||
               bleManager?.isConnected == true ||
               networkManager?.isConnected == true
    }

    private func handleGetStatus(result: @escaping FlutterResult) {
        var status: [String: Any] = [
            "isConnected": isAnyConnected(),
            "activeConnection": activeConnectionType,
            "platform": "iOS",
            "systemVersion": UIDevice.current.systemVersion
        ]

        if let bm = bluetoothManager {
            status["bluetooth"] = [
                "isConnected": bm.isConnected,
                "connectionState": bm.connectionState.rawValue
            ]
        }

        if let bm = bleManager {
            status["ble"] = [
                "isConnected": bm.isConnected,
                "connectionState": bm.connectionState.rawValue,
                "deviceName": bm.connectedDeviceName ?? "",
                "mtu": bm.currentMTU
            ]
        }

        if let nm = networkManager {
            status["network"] = [
                "isConnected": nm.isConnected,
                "connectionState": nm.connectionState.rawValue,
                "address": nm.connectedDeviceAddress ?? ""
            ]
        }

        result(status)
    }

    // MARK: - Printing Handlers

    private func handlePrintBytes(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected arguments map", details: nil))
            return
        }

        guard let bytes = args["bytes"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected 'bytes' as TypedData", details: nil))
            return
        }

        let data = bytes.data
        writeToActiveManager(data: data, result: result)
    }

    private func handlePrintText(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected arguments map", details: nil))
            return
        }

        guard let text = args["text"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected 'text' in arguments", details: nil))
            return
        }

        let encoder = EscPosEncoder(width: 48)

        // Apply optional formatting
        if let bold = args["bold"] as? Bool, bold {
            encoder.bold(true)
        }
        if let underline = args["underline"] as? Bool, underline {
            encoder.underline(.on1Dot)
        }
        if let align = args["align"] as? Int {
            switch align {
            case 1: encoder.setAlignment(.center)
            case 2: encoder.setAlignment(.right)
            default: encoder.setAlignment(.left)
            }
        }
        if let size = args["size"] as? Int {
            switch size {
            case 1: encoder.setCharacterSize(heightMultiplier: 1, widthMultiplier: 1)
            case 2: encoder.setCharacterSize(heightMultiplier: 2, widthMultiplier: 2)
            case 3: encoder.setCharacterSize(heightMultiplier: 2, widthMultiplier: 1)
            case 4: encoder.setCharacterSize(heightMultiplier: 1, widthMultiplier: 2)
            default: break
            }
        }

        encoder.textLine(text)
        let data = encoder.build()

        writeToActiveManager(data: data, result: result)
    }

    private func handlePrintLines(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected arguments map", details: nil))
            return
        }

        guard let lines = args["lines"] as? [String] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected 'lines' as list of strings", details: nil))
            return
        }

        let encoder = EscPosEncoder(width: 48)

        if let bold = args["bold"] as? Bool, bold {
            encoder.bold(true)
        }
        if let align = args["align"] as? Int {
            switch align {
            case 1: encoder.setAlignment(.center)
            case 2: encoder.setAlignment(.right)
            default: encoder.setAlignment(.left)
            }
        }

        encoder.textLines(lines)
        let data = encoder.build()

        writeToActiveManager(data: data, result: result)
    }

    private func handlePrintQrCode(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected arguments map", details: nil))
            return
        }

        guard let content = args["content"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected 'content' in arguments", details: nil))
            return
        }

        let size = args["size"] as? Int ?? 6
        let errorCorrection = args["errorCorrection"] as? String ?? "M"

        let encoder = EscPosEncoder(width: 48)
        encoder.printQrCode(content: content, size: size, errorCorrection: errorCorrection)
        let data = encoder.build()

        writeToActiveManager(data: data, result: result)
    }

    private func handlePrintBarcode(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected arguments map", details: nil))
            return
        }

        guard let content = args["content"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected 'content' in arguments", details: nil))
            return
        }

        let type = args["type"] as? String ?? "CODE128"
        let width = args["width"] as? Int ?? 2
        let height = args["height"] as? Int ?? 162
        let textPosition = args["textPosition"] as? Int ?? 2
        let font = args["font"] as? Int ?? 0

        let encoder = EscPosEncoder(width: 48)
        encoder.printBarcode(
            type: type,
            content: content,
            width: width,
            height: height,
            textPosition: textPosition,
            font: font
        )
        let data = encoder.build()

        writeToActiveManager(data: data, result: result)
    }

    private func handlePrintImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected arguments map", details: nil))
            return
        }

        guard let imageData = args["imageData"] as? FlutterStandardTypedData else {
            // Try 'bytes' as fallback key
            guard let bytes = args["bytes"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "INVALID_ARGS", message: "Expected 'imageData' or 'bytes' as TypedData", details: nil))
                return
            }
            let data = bytes.data
            let maxWidth = args["maxWidth"] as? Int ?? 384

            let encoder = EscPosEncoder(width: 48)
            encoder.imageData(data, maxWidth: maxWidth)
            let escposData = encoder.build()
            writeToActiveManager(data: escposData, result: result)
            return
        }

        let data = imageData.data
        let maxWidth = args["maxWidth"] as? Int ?? 384

        let encoder = EscPosEncoder(width: 48)
        encoder.imageData(data, maxWidth: maxWidth)
        let escposData = encoder.build()

        writeToActiveManager(data: escposData, result: result)
    }

    private func handlePrintReceipt(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected arguments map", details: nil))
            return
        }

        // Receipt can contain a mix of text lines, QR codes, barcodes, images
        let encoder = EscPosEncoder(width: 48)
        encoder.initialize()

        // Header
        if let title = args["title"] as? String {
            let subtitle = args["subtitle"] as? String ?? ""
            encoder.receiptHeader(title, subtitle: subtitle)
        }

        // Content lines
        if let content = args["content"] as? [String] {
            for line in content {
                encoder.textLine(line)
            }
        }

        // Columns / table
        if let columns = args["columns"] as? [[String: Any]] {
            for col in columns {
                let text = col["text"] as? String ?? ""
                let width = col["width"] as? Int ?? 16
                let alignStr = col["align"] as? String ?? "left"
                let align: EscPosEncoder.Align
                switch alignStr {
                case "center": align = .center
                case "right": align = .right
                default: align = .left
                }
                encoder.tableRow(columns: [(text: text, width: width, align: align)])
            }
        }

        // QR Code
        if let qrContent = args["qrContent"] as? String {
            let qrSize = args["qrSize"] as? Int ?? 6
            encoder.setAlignment(.center)
            encoder.printQrCode(content: qrContent, size: qrSize)
            encoder.setAlignment(.left)
        }

        // Barcode
        if let barcodeContent = args["barcodeContent"] as? String {
            let barcodeType = args["barcodeType"] as? String ?? "CODE128"
            encoder.setAlignment(.center)
            encoder.printBarcode(type: barcodeType, content: barcodeContent)
            encoder.setAlignment(.left)
        }

        // Footer
        if let footer = args["footer"] as? [String] {
            encoder.receiptFooter(footer)
        }

        // Cash drawer
        if let openDrawer = args["openCashDrawer"] as? Bool, openDrawer {
            encoder.openCashDrawer()
        }

        // Cut paper
        if let cut = args["cut"] as? Bool, cut {
            encoder.cut()
        }

        let data = encoder.build()
        writeToActiveManager(data: data, result: result)
    }

    private func handleOpenCashDrawer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            // Use defaults
            let encoder = EscPosEncoder(width: 48)
            encoder.openCashDrawer(pin: 0, duration: 100)
            let data = encoder.build()
            writeToActiveManager(data: data, result: result)
            return
        }

        let pin = args["pin"] as? Int ?? 0
        let duration = args["duration"] as? Int ?? 100

        let encoder = EscPosEncoder(width: 48)
        encoder.openCashDrawer(pin: UInt8(pin), duration: UInt8(duration))
        let data = encoder.build()

        writeToActiveManager(data: data, result: result)
    }

    // MARK: - Permission Handlers

    private func handleRequestPermissions(result: @escaping FlutterResult) {
        // On iOS 13+, Bluetooth requires explicit permission request
        let bleManager = ensureBleManager()

        // CBCentralManager automatically triggers the permission dialog
        // when we try to scan. Just return current status.
        if bleManager.isBluetoothPoweredOn {
            result(true)
        } else {
            // Bluetooth might need permission - the dialog will show on next scan
            result(true) // The system will prompt when needed
        }
    }

    private func handleCheckPermissions(result: @escaping FlutterResult) {
        var permissions: [String: Any] = [:]

        let btState: String
        if let bm = bleManager {
            switch bm.centralManager.state {
            case .poweredOn:
                btState = "granted"
            case .poweredOff:
                btState = "denied"
            case .unauthorized:
                btState = "denied"
            default:
                btState = "unknown"
            }
        } else if let bm = bluetoothManager {
            switch bm.centralManager?.state ?? .unknown {
            case .poweredOn:
                btState = "granted"
            case .poweredOff:
                btState = "denied"
            case .unauthorized:
                btState = "denied"
            default:
                btState = "unknown"
            }
        } else {
            btState = "notDetermined"
        }

        permissions["bluetooth"] = btState
        permissions["location"] = "granted" // Network scanning needs location
        permissions["network"] = "granted"   // Always available

        result(permissions)
    }

    // MARK: - Feature Support

    private func handleIsFeatureSupported(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let feature = args["feature"] as? String else {
            result(false)
            return
        }

        let supported: Bool
        switch feature {
        case "bluetooth":
            supported = true  // BLE via CoreBluetooth
        case "ble":
            supported = true
        case "usb":
            supported = false // Not directly supported on iOS
        case "network":
            supported = true
        case "wifi":
            supported = true
        case "lan":
            supported = true
        case "escpos":
            supported = true
        case "qrCode":
            supported = true
        case "barcode":
            supported = true
        case "image":
            supported = true
        case "pdf":
            supported = false // Not directly supported
        case "cashDrawer":
            supported = true
        case "paperCut":
            supported = true
        case "autoReconnect":
            supported = true
        default:
            supported = false
        }

        result(supported)
    }

    // MARK: - Write to Active Manager

    private func writeToActiveManager(data: Data, result: @escaping FlutterResult) {
        switch activeConnectionType {
        case "bluetooth":
            guard let manager = bluetoothManager else {
                result(FlutterError(code: "NOT_CONNECTED", message: "Bluetooth manager not initialized", details: nil))
                return
            }
            if !manager.isConnected {
                result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to Bluetooth printer", details: nil))
                return
            }
            manager.writeData(data) { success, error in
                DispatchQueue.main.async {
                    if success {
                        result(true)
                    } else {
                        result(FlutterError(code: "WRITE_FAILED", message: error ?? "Write failed", details: nil))
                    }
                }
            }

        case "ble":
            guard let manager = bleManager else {
                result(FlutterError(code: "NOT_CONNECTED", message: "BLE manager not initialized", details: nil))
                return
            }
            if !manager.isConnected {
                result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to BLE printer", details: nil))
                return
            }
            manager.writeData(data) { success, error in
                DispatchQueue.main.async {
                    if success {
                        result(true)
                    } else {
                        result(FlutterError(code: "WRITE_FAILED", message: error ?? "Write failed", details: nil))
                    }
                }
            }

        case "network":
            guard let manager = networkManager else {
                result(FlutterError(code: "NOT_CONNECTED", message: "Network manager not initialized", details: nil))
                return
            }
            if !manager.isConnected {
                result(FlutterError(code: "NOT_CONNECTED", message: "Not connected to network printer", details: nil))
                return
            }
            manager.writeData(data) { success, error in
                DispatchQueue.main.async {
                    if success {
                        result(true)
                    } else {
                        result(FlutterError(code: "WRITE_FAILED", message: error ?? "Write failed", details: nil))
                    }
                }
            }

        default:
            result(FlutterError(code: "NOT_CONNECTED", message: "No active connection. Connect to a printer first.", details: nil))
        }
    }
}

// MARK: - FlutterStreamHandler

extension SwiftThunderThermalPrintPlugin: FlutterStreamHandler {

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // Determine which stream based on channel name from arguments or just set all
        // Flutter calls each stream handler independently, so we need to detect which one
        if let args = arguments as? [String: Any] {
            let channelName = args["channel"] as? String ?? ""
            switch channelName {
            case "connection":
                connectionSink = events
            case "devices":
                deviceSink = events
            case "data":
                dataSink = events
            default:
                // Fallback: try to detect based on calling context
                // In practice, we assign sinks on first onListen call
                connectionSink = events
            }
            return nil
        }

        // If no arguments, assign based on order or use a default
        if connectionSink == nil {
            connectionSink = events
        } else if deviceSink == nil {
            deviceSink = events
        } else if dataSink == nil {
            dataSink = events
        } else {
            dataSink = events // Fallback
        }

        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if let args = arguments as? [String: Any] {
            let channelName = args["channel"] as? String ?? ""
            switch channelName {
            case "connection":
                connectionSink = nil
            case "devices":
                deviceSink = nil
            case "data":
                dataSink = nil
            default:
                connectionSink = nil
                deviceSink = nil
                dataSink = nil
            }
            return nil
        }

        // Clear all on cancel without args
        connectionSink = nil
        deviceSink = nil
        dataSink = nil
        return nil
    }
}

// MARK: - PrinterManagerDelegate

extension SwiftThunderThermalPrintPlugin: PrinterManagerDelegate {

    public func didDiscoverDevice(_ device: BluetoothDevice) {
        DispatchQueue.main.async { [weak self] in
            self?.deviceSink?(device.toDictionary())
        }
    }

    public func didUpdateConnectionState(_ state: ConnectionState) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionSink?([
                "state": state.rawValue,
                "timestamp": Date().timeIntervalSince1970 * 1000,
                "type": self?.activeConnectionType ?? "unknown"
            ])
        }
    }

    public func didReceiveData(_ data: Data) {
        DispatchQueue.main.async { [weak self] in
            self?.dataSink?(FlutterStandardTypedData(data: data))
        }
    }

    public func didError(_ error: String) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionSink?([
                "state": "error",
                "error": error,
                "timestamp": Date().timeIntervalSince1970 * 1000,
                "type": self?.activeConnectionType ?? "unknown"
            ])
        }
    }
}
