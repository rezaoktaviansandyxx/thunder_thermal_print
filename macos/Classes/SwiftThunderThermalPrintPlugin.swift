import Flutter
import Foundation
import CoreBluetooth
import Network

// MARK: - macOS Thermal Printer Plugin

/// macOS implementation of the thermal printer plugin using CoreBluetooth for BLE,
/// NWConnection for TCP networking, and IOKit concepts for USB.
public class SwiftThunderThermalPrintPlugin: NSObject, FlutterPlugin {

    // MARK: - Constants

    private let methodChannelName = "id.thunderlab.thunder_thermal_print"

    // BLE service UUID for thermal printers
    private static let blePrinterServiceUUID = CBUUID(string: "0000FF00-0000-1000-8000-00805F9B34FB")
    private static let bleWriteCharacteristicUUID = CBUUID(string: "0000FF02-0000-1000-8000-00805F9B34FB")
    private static let bleReadCharacteristicUUID = CBUUID(string: "0000FF01-0000-1000-8000-00805F9B34FB")

    // MARK: - Properties

    private var channel: FlutterMethodChannel?

    // BLE
    private var centralManager: CBCentralManager?
    private var discoveredBlePeripherals: [String: CBPeripheral] = [:]  // UUID string -> peripheral
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var readCharacteristic: CBCharacteristic?

    // Network
    private var tcpConnection: NWConnection?
    private var connectedHost: String?
    private var connectedPort: UInt16?

    // Connection state
    private enum ActiveConnection {
        case none
        case ble
        case network
        case usb
    }
    private var activeConnection: ActiveConnection = .none
    private var bleIsConnected: Bool = false
    private var networkIsConnected: Bool = false
    private var usbIsConnected: Bool = false

    // Auto-reconnect
    private var autoReconnectEnabled: Bool = false
    private var reconnectTimer: Timer?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 5

    // Scan results
    private var scanResults: [[String: Any]] = []
    private var scanCompletion: FlutterResult?

    // Write queue
    private var pendingWrites: [Data] = []
    private var isWriting: Bool = false
    private var writeCompletion: FlutterResult?

    // MARK: - Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SwiftThunderThermalPrintPlugin()

        let channel = FlutterMethodChannel(
            name: instance.methodChannelName,
            binaryMessenger: registrar.messenger()
        )
        instance.channel = channel

        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // MARK: - Method Call Handler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        // -------------------------------------------------------------------
        // Discovery
        // -------------------------------------------------------------------
        case "scanBle":
            handleScanBle(call: call, result: result)

        case "scanUsb":
            result(FlutterMethodNotImplemented)

        case "scanNetwork":
            handleScanNetwork(call: call, result: result)

        case "scanBluetooth":
            result(FlutterError(
                code: "NOT_SUPPORTED",
                message: "Bluetooth Classic is not supported on macOS in this version",
                details: "bluetooth"
            ))

        // -------------------------------------------------------------------
        // Connection
        // -------------------------------------------------------------------
        case "connectBle":
            handleConnectBle(call: call, result: result)

        case "connectNetwork":
            handleConnectNetwork(call: call, result: result)

        case "connectUsb":
            result(FlutterError(
                code: "NOT_SUPPORTED",
                message: "USB printer connections are not supported on macOS in this version. Use Network or BLE instead.",
                details: "usb"
            ))

        case "connectBluetooth":
            result(FlutterError(
                code: "NOT_SUPPORTED",
                message: "Bluetooth Classic is not supported on macOS in this version",
                details: "bluetooth"
            ))

        case "disconnect":
            handleDisconnect(result: result)

        case "isConnected":
            let connected = bleIsConnected || networkIsConnected || usbIsConnected
            result(connected)

        // -------------------------------------------------------------------
        // Status
        // -------------------------------------------------------------------
        case "getStatus":
            let status: [String: Any] = [
                "online": bleIsConnected || networkIsConnected,
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

        // -------------------------------------------------------------------
        // Print operations
        // -------------------------------------------------------------------
        case "printBytes":
            handlePrintBytes(call: call, result: result)

        case "printText":
            handlePrintText(call: call, result: result)

        case "printLines":
            handlePrintLines(call: call, result: result)

        case "printQrCode", "printBarcode", "printImage", "printPdf", "printReceipt":
            result(FlutterError(
                code: "NOT_SUPPORTED",
                message: "Method '\(call.method)' must send pre-encoded bytes via printBytes on macOS",
                details: call.method
            ))

        // -------------------------------------------------------------------
        // Cash drawer
        // -------------------------------------------------------------------
        case "openCashDrawer":
            handleOpenCashDrawer(call: call, result: result)

        // -------------------------------------------------------------------
        // Permissions
        // -------------------------------------------------------------------
        case "requestPermissions", "checkPermissions":
            // macOS desktop apps handle permissions differently
            result(true)

        // -------------------------------------------------------------------
        // Platform info
        // -------------------------------------------------------------------
        case "getPlatformVersion":
            result("macOS 1.0.0")

        case "isFeatureSupported":
            handleIsFeatureSupported(call: call, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - BLE Scanning

    private func handleScanBle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        scanResults.removeAll()
        scanCompletion = result

        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }

        guard let manager = centralManager else {
            result(FlutterError(
                code: "BLE_UNAVAILABLE",
                message: "Could not initialize CoreBluetooth",
                details: nil
            ))
            return
        }

        switch manager.state {
        case .poweredOn:
            startBleScan(manager: manager)
        case .unauthorized:
            result(FlutterError(
                code: "PERMISSION_DENIED",
                message: "Bluetooth access is unauthorized on macOS",
                details: "bluetooth"
            ))
            scanCompletion = nil
        case .poweredOff:
            result(FlutterError(
                code: "BLE_UNAVAILABLE",
                message: "Bluetooth is powered off. Please enable Bluetooth.",
                details: nil
            ))
            scanCompletion = nil
        default:
            result(FlutterError(
                code: "BLE_UNAVAILABLE",
                message: "Bluetooth is not available on this Mac",
                details: nil
            ))
            scanCompletion = nil
        }
    }

    private func startBleScan(manager: CBCentralManager) {
        // Stop any existing scan
        manager.stopScan()

        // Scan for thermal printer service or any device
        let services: [CBUUID]? = [SwiftThunderThermalPrintPlugin.blePrinterServiceUUID]
        manager.scanForPeripherals(withServices: services, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ])

        // Auto-stop scan after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self else { return }
            self.centralManager?.stopScan()
            if let completion = self.scanCompletion {
                completion(self.scanResults)
                self.scanCompletion = nil
            }
        }
    }

    // MARK: - BLE Connection

    private func handleConnectBle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let deviceId = args["deviceId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "deviceId is required",
                details: nil
            ))
            return
        }

        // Check auto-reconnect preference
        if let autoReconnect = args["autoReconnect"] as? Bool {
            self.autoReconnectEnabled = autoReconnect
        }

        // Find the peripheral by UUID
        guard let uuid = UUID(uuidString: deviceId) else {
            result(FlutterError(
                code: "DEVICE_NOT_FOUND",
                message: "Invalid device ID format: \(deviceId)",
                details: deviceId
            ))
            return
        }

        // Look in discovered peripherals first, then retrieve from manager
        let peripheral: CBPeripheral
        if let discovered = discoveredBlePeripherals[deviceId] {
            peripheral = discovered
        } else if let retrieved = centralManager?.retrievePeripherals(withIdentifiers: [uuid]).first {
            peripheral = retrieved
        } else {
            // Try connecting to unknown peripheral
            let periphs = centralManager?.retrievePeripherals(withIdentifiers: [uuid])
            if let p = periphs?.first {
                peripheral = p
            } else {
                result(FlutterError(
                    code: "DEVICE_NOT_FOUND",
                    message: "BLE device \(deviceId) not found. Run scanBle first.",
                    details: deviceId
                ))
                return
            }
        }

        // Disconnect existing connection
        if connectedPeripheral != nil {
            centralManager?.cancelPeripheralConnection(connectedPeripheral!)
        }

        writeCompletion = result
        connectedPeripheral = peripheral
        peripheral.delegate = self

        centralManager?.connect(peripheral, options: [
            CBConnectOptionTimeout: 10.0
        ])
    }

    // MARK: - Network Scanning

    private func handleScanNetwork(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result([])
            return
        }

        let subnet = args["subnet"] as? String
        var devices: [[String: Any]] = []

        let baseSubnet = subnet ?? getLocalSubnet()
        let ports: [UInt16] = [9100, 9101, 9102, 8080, 631]
        let scanQueue = DispatchQueue(label: "com.thunderlab.thermalprint.networkscan",
                                       qos: .userInitiated,
                                       attributes: .concurrent)
        let group = DispatchGroup()

        for i in 1...254 {
            let host = "\(baseSubnet).\(i)"
            for port in ports {
                group.enter()
                scanQueue.async {
                    self.probeNetworkHost(host: host, port: port) { found in
                        if found {
                            let device: [String: Any] = [
                                "name": host,
                                "address": "\(host):\(port)",
                                "rssi": 0,
                                "connectionType": "network",
                                "vendorId": NSNull(),
                                "productId": NSNull(),
                                "isConnected": false,
                                "metadata": [:]
                            ]
                            DispatchQueue.main.async {
                                devices.append(device)
                            }
                        }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) {
            result(devices)
        }
    }

    private func probeNetworkHost(host: String, port: UInt16, completion: @escaping (Bool) -> Void) {
        guard let endpointHost = NWEndpoint.Host(host),
              let endpointPort = NWEndpoint.Port(rawValue: port) else {
            completion(false)
            return
        }

        let probe = NWConnection(host: endpointHost, port: endpointPort, using: .tcp)
        let probeQueue = DispatchQueue(label: "com.thunderlab.thermalprint.probe.\(host).\(port)")
        var completed = false

        probe.stateUpdateHandler = { [weak probe] state in
            guard !completed else { return }
            switch state {
            case .ready:
                completed = true
                probe?.cancel()
                completion(true)
            case .failed, .cancelled:
                completed = true
                completion(false)
            case .setup, .preparing, .waiting:
                break
            @unknown default:
                break
            }
        }

        probe.start(queue: probeQueue)

        probeQueue.asyncAfter(deadline: .now() + 1.5) {
            if !completed {
                completed = true
                probe.cancel()
                completion(false)
            }
        }
    }

    // MARK: - Network Connection

    private func handleConnectNetwork(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let ipAddress = args["ipAddress"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "ipAddress is required",
                details: nil
            ))
            return
        }

        let port: UInt16
        if let p = args["port"] as? Int, p > 0, p <= 65535 {
            port = UInt16(p)
        } else {
            port = 9100
        }

        if let autoReconnect = args["autoReconnect"] as? Bool {
            self.autoReconnectEnabled = autoReconnect
        }

        // Disconnect existing TCP connection
        if let existing = tcpConnection {
            existing.cancel()
            tcpConnection = nil
        }

        guard let endpointHost = NWEndpoint.Host(ipAddress),
              let endpointPort = NWEndpoint.Port(rawValue: port) else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "Invalid host or port: \(ipAddress):\(port)",
                details: nil
            ))
            return
        }

        let connection = NWConnection(host: endpointHost, port: endpointPort, using: .tcp)
        let connectionQueue = DispatchQueue(label: "com.thunderlab.thermalprint.tcp")

        var completed = false

        connection.stateUpdateHandler = { [weak self] state in
            guard !completed else { return }
            switch state {
            case .ready:
                completed = true
                DispatchQueue.main.async {
                    self?.tcpConnection = connection
                    self?.connectedHost = ipAddress
                    self?.connectedPort = port
                    self?.networkIsConnected = true
                    self?.reconnectAttempts = 0
                    self?.activeConnection = .network
                    result(true)
                }

            case .failed(let error):
                completed = true
                DispatchQueue.main.async {
                    self?.networkIsConnected = false
                    self?.activeConnection = .none
                    result(FlutterError(
                        code: "CONNECTION_FAILED",
                        message: "Network connection failed: \(error.localizedDescription)",
                        details: nil
                    ))
                }

            case .cancelled:
                if !completed {
                    completed = true
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "CONNECTION_FAILED",
                            message: "Connection cancelled",
                            details: nil
                        ))
                    }
                }

            case .setup, .preparing, .waiting:
                break

            @unknown default:
                break
            }
        }

        connection.start(queue: connectionQueue)

        // Hard timeout
        connectionQueue.asyncAfter(deadline: .now() + 10.0) {
            if !completed {
                completed = true
                connection.cancel()
                DispatchQueue.main.async {
                    self.networkIsConnected = false
                    self.activeConnection = .none
                    result(FlutterError(
                        code: "TIMEOUT",
                        message: "Network connection timed out after 10 seconds",
                        details: "10000"
                    ))
                }
            }
        }
    }

    // MARK: - Print Operations

    private func handlePrintBytes(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let bytes = args["bytes"] as? [Int] else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "bytes is required and must be a List<int>",
                details: nil
            ))
            return
        }

        let data = Data(bytes: bytes, count: bytes.count)

        switch activeConnection {
        case .ble:
            writeBleData(data, completion: result)
        case .network:
            writeNetworkData(data, completion: result)
        case .usb:
            result(FlutterError(
                code: "NOT_CONNECTED",
                message: "USB connection is not supported on macOS",
                details: nil
            ))
        case .none:
            result(FlutterError(
                code: "NOT_CONNECTED",
                message: "Not connected to any printer",
                details: nil
            ))
        }
    }

    private func handlePrintText(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "text is required",
                details: nil
            ))
            return
        }

        var payload = text
        payload += "\n"
        guard let data = payload.data(using: .utf8) else {
            result(FlutterError(
                code: "INVALID_DATA",
                message: "Failed to encode text to UTF-8",
                details: nil
            ))
            return
        }

        switch activeConnection {
        case .ble:
            writeBleData(data, completion: result)
        case .network:
            writeNetworkData(data, completion: result)
        default:
            result(FlutterError(
                code: "NOT_CONNECTED",
                message: "Not connected to any printer",
                details: nil
            ))
        }
    }

    private func handlePrintLines(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let lines = args["lines"] as? [String] else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "lines is required and must be a List<String>",
                details: nil
            ))
            return
        }

        var payload = lines.joined(separator: "\n")
        payload += "\n\n"
        guard let data = payload.data(using: .utf8) else {
            result(FlutterError(
                code: "INVALID_DATA",
                message: "Failed to encode lines to UTF-8",
                details: nil
            ))
            return
        }

        switch activeConnection {
        case .ble:
            writeBleData(data, completion: result)
        case .network:
            writeNetworkData(data, completion: result)
        default:
            result(FlutterError(
                code: "NOT_CONNECTED",
                message: "Not connected to any printer",
                details: nil
            ))
        }
    }

    private func handleOpenCashDrawer(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let pin = args?["pin"] as? Int ?? 0

        // ESC/POS cash drawer pulse
        let data: Data
        if pin == 1 {
            data = Data([0x1B, 0x70, 0x01])
        } else {
            data = Data([0x1B, 0x70, 0x00])
        }

        switch activeConnection {
        case .ble:
            writeBleData(data, completion: result)
        case .network:
            writeNetworkData(data, completion: result)
        default:
            result(FlutterError(
                code: "NOT_CONNECTED",
                message: "Not connected to any printer",
                details: nil
            ))
        }
    }

    // MARK: - BLE Data Writing

    private func writeBleData(_ data: Data, completion: @escaping FlutterResult) {
        guard let peripheral = connectedPeripheral,
              let characteristic = writeCharacteristic else {
            completion(FlutterError(
                code: "NOT_CONNECTED",
                message: "BLE not connected or write characteristic not found",
                details: nil
            ))
            return
        }

        // BLE has MTU limitations, chunk the data
        let mtu = min(peripheral.maximumWriteValueLength(for: .withoutResponse), 512)
        var offset = 0

        func writeChunk() {
            guard offset < data.count else {
                completion(true)
                return
            }

            let end = min(offset + mtu, data.count)
            let chunk = data[offset..<end]
            offset = end

            if characteristic.properties.contains(.writeWithoutResponse) {
                peripheral.writeValue(chunk, for: characteristic, type: .withoutResponse)
                writeChunk()
            } else if characteristic.properties.contains(.write) {
                peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
                // Response comes through peripheral(_:didWriteValueFor:error:)
                writeCompletion = completion
            } else {
                completion(FlutterError(
                    code: "WRITE_FAILED",
                    message: "Write characteristic does not support writing",
                    details: nil
                ))
            }
        }

        writeChunk()
    }

    // MARK: - Network Data Writing

    private func writeNetworkData(_ data: Data, completion: @escaping FlutterResult) {
        guard let connection = tcpConnection else {
            completion(FlutterError(
                code: "NOT_CONNECTED",
                message: "Not connected to a network printer",
                details: nil
            ))
            return
        }

        switch connection.state {
        case .ready:
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    completion(FlutterError(
                        code: "WRITE_FAILED",
                        message: "Network write failed: \(error.localizedDescription)",
                        details: nil
                    ))
                } else {
                    completion(true)
                }
            })

        case .setup, .preparing, .waiting:
            // Retry after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.writeNetworkData(data, completion: completion)
            }

        default:
            completion(FlutterError(
                code: "NOT_CONNECTED",
                message: "Connection is not in a valid state",
                details: nil
            ))
        }
    }

    // MARK: - Disconnect

    private func handleDisconnect(result: FlutterResult) {
        // BLE
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
            connectedPeripheral = nil
            writeCharacteristic = nil
            readCharacteristic = nil
            bleIsConnected = false
        }

        // Network
        if let connection = tcpConnection {
            connection.cancel()
            tcpConnection = nil
            connectedHost = nil
            connectedPort = nil
            networkIsConnected = false
        }

        activeConnection = .none
        autoReconnectEnabled = false
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectAttempts = 0

        result(true)
    }

    // MARK: - Auto-Reconnect

    private func scheduleBleReconnect() {
        guard autoReconnectEnabled else { return }
        guard reconnectAttempts < maxReconnectAttempts else {
            return
        }

        let delay: TimeInterval = pow(2.0, Double(reconnectAttempts))
        reconnectAttempts += 1

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self,
                  let peripheral = self.connectedPeripheral,
                  let manager = self.centralManager else { return }
            manager.connect(peripheral, options: nil)
        }
    }

    private func scheduleNetworkReconnect() {
        guard autoReconnectEnabled else { return }
        guard let host = connectedHost, let port = connectedPort else { return }
        guard reconnectAttempts < maxReconnectAttempts else { return }

        let delay: TimeInterval = pow(2.0, Double(reconnectAttempts))
        reconnectAttempts += 1

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            // Reconnect using a synthetic method call
            self.tcpConnection = nil
            self.networkIsConnected = false
            self.activeConnection = .none

            guard let endpointHost = NWEndpoint.Host(host),
                  let endpointPort = NWEndpoint.Port(rawValue: port) else { return }

            let connection = NWConnection(host: endpointHost, port: endpointPort, using: .tcp)
            let connectionQueue = DispatchQueue(label: "com.thunderlab.thermalprint.reconnect")

            connection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    DispatchQueue.main.async {
                        self?.tcpConnection = connection
                        self?.networkIsConnected = true
                        self?.activeConnection = .network
                        self?.reconnectAttempts = 0
                    }
                case .failed, .cancelled:
                    DispatchQueue.main.async {
                        self?.scheduleNetworkReconnect()
                    }
                default:
                    break
                }
            }

            connection.start(queue: connectionQueue)
        }
    }

    // MARK: - Feature Support

    private func handleIsFeatureSupported(call: FlutterMethodCall, result: FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let feature = args["feature"] as? String else {
            result(false)
            return
        }

        let supported: Bool
        switch feature {
        case "ble": supported = true
        case "network": supported = true
        case "usb": supported = false
        case "bluetooth": supported = false
        case "qrCode", "barcode", "image", "pdf", "cashDrawer": supported = true  // via raw bytes
        default: supported = false
        }
        result(supported)
    }

    // MARK: - Network Utilities

    private func getLocalSubnet() -> String {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return "192.168.1"
        }

        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                    break
                }
            }
        }

        if let ip = address {
            let parts = ip.split(separator: ".")
            if parts.count >= 3 {
                return "\(parts[0]).\(parts[1]).\(parts[2])"
            }
        }

        return "192.168.1"
    }

    deinit {
        reconnectTimer?.invalidate()
        tcpConnection?.cancel()
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension SwiftThunderThermalPrintPlugin: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // State changes are handled in scan/connect methods
    }

    public func centralManager(_ central: CBCentralManager,
                                didDiscover peripheral: CBPeripheral,
                                advertisementData: [String: Any],
                                rssi RSSI: NSNumber) {
        let uuidString = peripheral.identifier.uuidString

        // Avoid duplicates
        if discoveredBlePeripherals[uuidString] != nil {
            return
        }

        discoveredBlePeripherals[uuidString] = peripheral

        let device: [String: Any] = [
            "name": peripheral.name ?? "Unknown BLE Printer",
            "address": uuidString,
            "rssi": RSSI.intValue,
            "connectionType": "ble",
            "vendorId": NSNull(),
            "productId": NSNull(),
            "isConnected": false,
            "metadata": advertisementData as? [String: Any] ?? [:]
        ]
        scanResults.append(device)
    }

    public func centralManager(_ central: CBCentralManager,
                                didConnect peripheral: CBPeripheral) {
        bleIsConnected = true
        activeConnection = .ble
        reconnectAttempts = 0

        // Discover services
        peripheral.discoverServices([SwiftThunderThermalPrintPlugin.blePrinterServiceUUID])
    }

    public func centralManager(_ central: CBCentralManager,
                                didDisconnectPeripheral peripheral: CBPeripheral,
                                error: Error?) {
        bleIsConnected = false
        writeCharacteristic = nil
        readCharacteristic = nil

        if activeConnection == .ble {
            activeConnection = .none
        }

        if let completion = writeCompletion {
            writeCompletion = nil
        }

        // Handle disconnect completion if pending
        // Schedule reconnect if enabled
        if autoReconnectEnabled && error != nil {
            scheduleBleReconnect()
        }
    }

    public func centralManager(_ central: CBCentralManager,
                                didFailToConnect peripheral: CBPeripheral,
                                error: Error?) {
        bleIsConnected = false
        activeConnection = .none

        if let completion = writeCompletion {
            writeCompletion = nil
            completion(FlutterError(
                code: "CONNECTION_FAILED",
                message: "BLE connection failed: \(error?.localizedDescription ?? "unknown error")",
                details: nil
            ))
        }

        if autoReconnectEnabled {
            scheduleBleReconnect()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension SwiftThunderThermalPrintPlugin: CBPeripheralDelegate {

    public func peripheral(_ peripheral: CBPeripheral,
                            didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == SwiftThunderThermalPrintPlugin.blePrinterServiceUUID {
                peripheral.discoverCharacteristics(
                    [SwiftThunderThermalPrintPlugin.bleWriteCharacteristicUUID,
                     SwiftThunderThermalPrintPlugin.bleReadCharacteristicUUID],
                    for: service
                )
            }
        }
    }

    public func peripheral(_ peripheral: CBPeripheral,
                            didDiscoverCharacteristicsFor service: CBService,
                            error: Error?) {
        guard let characteristics = service.characteristics else {
            if let completion = writeCompletion {
                writeCompletion = nil
                completion(FlutterError(
                    code: "CONNECTION_FAILED",
                    message: "Failed to discover BLE characteristics",
                    details: nil
                ))
            }
            return
        }

        for characteristic in characteristics {
            if characteristic.uuid == SwiftThunderThermalPrintPlugin.bleWriteCharacteristicUUID {
                writeCharacteristic = characteristic
            }
            if characteristic.uuid == SwiftThunderThermalPrintPlugin.bleReadCharacteristicUUID {
                readCharacteristic = characteristic
                // Enable notifications for read characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }

        // Connection fully established
        if writeCompletion != nil {
            let completion = writeCompletion
            writeCompletion = nil
            completion?(true)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral,
                            didWriteValueFor characteristic: CBCharacteristic,
                            error: Error?) {
        // Write with response completed
        // Further writes can be queued here if needed
    }

    public func peripheral(_ peripheral: CBPeripheral,
                            didUpdateNotificationStateFor characteristic: CBCharacteristic,
                            error: Error?) {
        // Notification state updated
    }

    public func peripheral(_ peripheral: CBPeripheral,
                            didUpdateValueFor characteristic: CBCharacteristic,
                            error: Error?) {
        // Data received from printer
    }
}
