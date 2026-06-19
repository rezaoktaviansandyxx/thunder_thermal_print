import Foundation
import CoreBluetooth

// MARK: - Bluetooth Device Model

public struct BluetoothDevice: Codable {
    public let name: String
    public let address: String  // UUID string on iOS (no MAC address access)
    public let rssi: Int
    public let type: String    // "bluetooth", "ble", "usb", "network"

    public init(name: String, address: String, rssi: Int, type: String) {
        self.name = name
        self.address = address
        self.rssi = rssi
        self.type = type
    }

    public func toDictionary() -> [String: Any] {
        return [
            "name": name,
            "address": address,
            "rssi": rssi,
            "type": type
        ]
    }
}

// MARK: - Connection State

public enum ConnectionState: String {
    case disconnected = "disconnected"
    case scanning = "scanning"
    case connecting = "connecting"
    case connected = "connected"
    case disconnecting = "disconnecting"
    case error = "error"
}

// MARK: - Printer Manager Delegate Protocol

public protocol PrinterManagerDelegate: AnyObject {
    func didDiscoverDevice(_ device: BluetoothDevice)
    func didUpdateConnectionState(_ state: ConnectionState)
    func didReceiveData(_ data: Data)
    func didError(_ error: String)
}

// MARK: - BluetoothPrinterManager

/// Bluetooth Classic / BLE printer manager for iOS.
/// Note: iOS uses CoreBluetooth for all Bluetooth operations. Classic Bluetooth
/// (SPP/RFCOMM) is not directly accessible on iOS. This manager uses CoreBluetooth
/// which works with BLE devices. For Classic Bluetooth printers, use BLE-to-Serial
/// adapters or network-connected printers.
public class BluetoothPrinterManager: NSObject {

    // MARK: - Properties

    public weak var delegate: PrinterManagerDelegate?

    private(set) var centralManager: CBCentralManager?
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var readCharacteristic: CBCharacteristic?

    private var scanTimeoutTimer: Timer?
    private var reconnectTimer: Timer?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 5

    private var lastWriteData: Data?
    private var writeQueue: [Data] = []
    private var isWriting: Bool = false

    private let writeQueueLock = NSLock()

    // Target service UUIDs for common thermal printers
    private let targetServiceUUIDs: [CBUUID] = [
        CBUUID(string: "000018F0-0000-1000-8000-00805F9B34FB"),
        CBUUID(string: "0000FF00-0000-1000-8000-00805F9B34FB"),
        CBUUID(string: "0000FF01-0000-1000-8000-00805F9B34FB"),
        CBUUID(string: "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2"),
        CBUUID(string: "0000FEFD-0000-1000-8000-00805F9B34FB"),
        CBUUID(string: "49535343-FE7D-4AE5-8FA9-9FAFD205E455") // SPP-like BLE service
    ]

    // Common write characteristic UUIDs
    private let targetWriteUUIDs: [CBUUID] = [
        CBUUID(string: "000018F0-0000-1000-8000-00805F9B34FB"),
        CBUUID(string: "0000FF02-0000-1000-8000-00805F9B34FB"),
        CBUUID(string: "8EC90004-F315-4F60-9FB8-838830DAEA50"),
        CBUUID(string: "49535343-8841-43F5-A1D8-9CD914A27058"),
        CBUUID(string: "49535343-1E4D-4BD9-BA61-23C647A24AC1")
    ]

    // Common read/notify characteristic UUIDs
    private let targetReadUUIDs: [CBUUID] = [
        CBUUID(string: "0000FF01-0000-1000-8000-00805F9B34FB"),
        CBUUID(string: "8EC90003-F315-4F60-9FB8-838830DAEA50"),
        CBUUID(string: "49535343-1E4D-4BD9-BA61-23C647A24AC1")
    ]

    public private(set) var isConnected: Bool = false
    public private(set) var isScanning: Bool = false
    public private(set) var connectionState: ConnectionState = .disconnected

    // MARK: - Initialization

    public override init() {
        super.init()
    }

    deinit {
        stopScan()
        disconnect()
        scanTimeoutTimer?.invalidate()
        reconnectTimer?.invalidate()
    }

    // MARK: - Scanning

    /// Start scanning for Bluetooth/BLE printer devices
    public func scan(duration: Double = 10.0) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.stopScan()
            self.discoveredPeripherals.removeAll()

            if self.centralManager == nil || self.centralManager?.state == .poweredOff {
                self.centralManager = CBCentralManager(delegate: self, queue: nil)
            }

            self.connectionState = .scanning
            self.delegate?.didUpdateConnectionState(.scanning)

            self.scanTimeoutTimer?.invalidate()
            self.scanTimeoutTimer = Timer.scheduledTimer(
                withTimeInterval: duration,
                repeats: false
            ) { [weak self] _ in
                self?.stopScan()
            }
        }
    }

    /// Stop scanning for devices
    public func stopScan() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let manager = self.centralManager else { return }

            if manager.isScanning {
                manager.stopScan()
            }

            self.scanTimeoutTimer?.invalidate()
            self.scanTimeoutTimer = nil
            self.isScanning = false

            if self.connectionState == .scanning {
                self.connectionState = .disconnected
                self.delegate?.didUpdateConnectionState(.disconnected)
            }
        }
    }

    /// Get all discovered devices
    public func getDiscoveredDevices() -> [BluetoothDevice] {
        return discoveredPeripherals.map { (key, peripheral) in
            let name = peripheral.name ?? "Unknown Device"
            return BluetoothDevice(
                name: name,
                address: peripheral.identifier.uuidString,
                rssi: 0,
                type: "bluetooth"
            )
        }
    }

    // MARK: - Connection

    /// Connect to a device by address (UUID string)
    public func connect(to address: String, completion: ((Bool, String?) -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                completion?(false, "Manager not available")
                return
            }

            // Ensure central manager is ready
            if let manager = self.centralManager, manager.state == .poweredOn {
                self._connectToAddress(address, completion: completion)
            } else {
                if self.centralManager == nil {
                    self.centralManager = CBCentralManager(delegate: self, queue: nil)
                }
                // Wait for powered on, then connect
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?._connectToAddress(address, completion: completion)
                }
            }
        }
    }

    private func _connectToAddress(_ address: String, completion: ((Bool, String?) -> Void)?) {
        guard let manager = centralManager else {
            completion?(false, "Central manager not initialized")
            return
        }

        guard manager.state == .poweredOn else {
            completion?(false, "Bluetooth is not powered on. Please enable Bluetooth.")
            return
        }

        // Find the peripheral
        let uuid = UUID(uuidString: address)
        let peripherals = manager.retrievePeripherals(withIdentifiers: uuid != nil ? [uuid!] : [])
        let knownPeripheral = peripherals.first

        if let peripheral = knownPeripheral ?? discoveredPeripherals[address] {
            connectPeripheral(peripheral, completion: completion)
        } else {
            // Try to connect by scanning for the device
            completion?(false, "Device not found. Please scan first.")
        }
    }

    private func connectPeripheral(_ peripheral: CBPeripheral, completion: ((Bool, String?) -> Void)?) {
        self.connectionState = .connecting
        self.delegate?.didUpdateConnectionState(.connecting)

        // Store completion handler
        objc_setAssociatedObject(
            peripheral,
            Unmanaged.passUnretained(peripheral).toOpaque(),
            completion as AnyObject,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )

        self.connectedPeripheral = peripheral
        self.writeCharacteristic = nil
        self.readCharacteristic = nil
        self.writeQueue.removeAll()
        self.isWriting = false

        centralManager?.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
    }

    /// Disconnect from the connected device
    public func disconnect() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let peripheral = self.connectedPeripheral {
                self.connectionState = .disconnecting
                self.delegate?.didUpdateConnectionState(.disconnecting)
                self.centralManager?.cancelPeripheralConnection(peripheral)
            }

            self.connectedPeripheral = nil
            self.writeCharacteristic = nil
            self.readCharacteristic = nil
            self.writeQueue.removeAll()
            self.isWriting = false
            self.isConnected = false
            self.reconnectAttempts = 0
            self.reconnectTimer?.invalidate()
            self.reconnectTimer = nil

            if self.connectionState != .disconnected {
                self.connectionState = .disconnected
                self.delegate?.didUpdateConnectionState(.disconnected)
            }
        }
    }

    // MARK: - Auto-Reconnect

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()

        guard reconnectAttempts < maxReconnectAttempts else {
            connectionState = .error
            delegate?.didUpdateConnectionState(.error)
            delegate?.didError("Max reconnect attempts reached")
            return
        }

        // Exponential backoff: 2s, 4s, 8s, 16s, 32s
        let delay = Double(2) * pow(2.0, Double(reconnectAttempts))
        reconnectAttempts += 1

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self, let peripheral = self.connectedPeripheral else { return }
            self.delegate?.didUpdateConnectionState(.connecting)
            self.connectionState = .connecting
            self.centralManager?.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey: true])
        }
    }

    public func enableAutoReconnect(_ enabled: Bool) {
        if !enabled {
            reconnectTimer?.invalidate()
            reconnectTimer = nil
            reconnectAttempts = 0
        }
    }

    // MARK: - Data Writing

    /// Write raw data to the printer
    public func writeData(_ data: Data, completion: ((Bool, String?) -> Void)? = nil) {
        guard let peripheral = connectedPeripheral else {
            completion?(false, "Not connected to a printer")
            return
        }

        guard let characteristic = writeCharacteristic else {
            completion?(false, "Write characteristic not discovered")
            return
        }

        writeQueueLock.lock()
        if isWriting {
            writeQueue.append(data)
            writeQueueLock.unlock()
            return
        }
        isWriting = true
        writeQueueLock.unlock()

        _writeData(data, to: peripheral, characteristic: characteristic, completion: completion)
    }

    private func _writeData(
        _ data: Data,
        to peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        completion: ((Bool, String?) -> Void)?
    ) {
        // BLE has MTU limitations; chunk data if necessary
        let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)

        if data.count <= mtu {
            lastWriteData = data
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)

            // Give a brief moment then report success
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }

                self.writeQueueLock.lock()
                self.isWriting = false

                if let nextData = self.writeQueue.first {
                    self.writeQueue.removeFirst()
                    self.isWriting = true
                    self.writeQueueLock.unlock()
                    self._writeData(nextData, to: peripheral, characteristic: characteristic, completion: nil)
                } else {
                    self.writeQueueLock.unlock()
                }

                completion?(true, nil)
            }
        } else {
            // Chunk the data
            let chunks = chunkData(data, chunkSize: mtu)
            _writeChunks(chunks, index: 0, peripheral: peripheral, characteristic: characteristic, completion: completion)
        }
    }

    private func _writeChunks(
        _ chunks: [Data],
        index: Int,
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        completion: ((Bool, String?) -> Void)?
    ) {
        guard index < chunks.count else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.writeQueueLock.lock()
                self?.isWriting = false

                if let self = self, let nextData = self.writeQueue.first {
                    self.writeQueue.removeFirst()
                    self.isWriting = true
                    self.writeQueueLock.unlock()
                    self._writeData(nextData, to: peripheral, characteristic: characteristic, completion: nil)
                } else {
                    self?.writeQueueLock.unlock()
                }

                completion?(true, nil)
            }
            return
        }

        let chunk = chunks[index]
        peripheral.writeValue(chunk, for: characteristic, type: .withoutResponse)

        // Delay between chunks to prevent overwhelming the peripheral
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?._writeChunks(chunks, index: index + 1, peripheral: peripheral, characteristic: characteristic, completion: completion)
        }
    }

    private func chunkData(_ data: Data, chunkSize: Int) -> [Data] {
        var chunks: [Data] = []
        var offset = 0

        while offset < data.count {
            let remaining = data.count - offset
            let chunkLength = min(remaining, chunkSize)
            let chunk = data.subdata(in: offset..<(offset + chunkLength))
            chunks.append(chunk)
            offset += chunkLength
        }

        return chunks
    }

    /// Write string data to the printer
    public func writeString(_ string: String, completion: ((Bool, String?) -> Void)? = nil) {
        if let data = string.data(using: .utf8) {
            writeData(data, completion: completion)
        } else {
            completion?(false, "Failed to encode string")
        }
    }

    // MARK: - MTU Negotiation

    public func requestMTU(_ mtu: Int) {
        guard let peripheral = connectedPeripheral else { return }
        peripheral.performSelector(inBackground: nil)
        // Note: MTU negotiation requires iOS 10+ and can only be done via
        // the peripheral(delegate:didDiscoverServices:) callback
        // CBCentralManager doesn't directly support MTU negotiation on the central side.
        // The peripheral.maximumWriteValueLength already accounts for negotiated MTU.
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothPrinterManager: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Start scanning if we were asked to
            if connectionState == .scanning {
                startActualScan()
            }
        case .poweredOff:
            stopScan()
            disconnect()
            delegate?.didError("Bluetooth is powered off")
        case .unauthorized:
            delegate?.didError("Bluetooth access is unauthorized")
        case .unknown:
            break
        case .resetting:
            disconnect()
        @unknown default:
            break
        }
    }

    private func startActualScan() {
        guard let manager = centralManager else { return }
        // Scan for all devices to find thermal printers
        // We don't filter by service UUID because some printers may use custom UUIDs
        manager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ])
        isScanning = true
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let identifier = peripheral.identifier.uuidString

        // Only add new devices or update RSSI
        if discoveredPeripherals[identifier] == nil {
            discoveredPeripherals[identifier] = peripheral

            let deviceName = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "Unknown Device"
            let device = BluetoothDevice(
                name: deviceName,
                address: identifier,
                rssi: RSSI.intValue,
                type: "bluetooth"
            )
            delegate?.didDiscoverDevice(device)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        connectionState = .connected
        reconnectAttempts = 0
        delegate?.didUpdateConnectionState(.connected)

        // Discover services
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        writeCharacteristic = nil
        readCharacteristic = nil
        writeQueue.removeAll()
        isWriting = false

        if connectionState == .disconnecting {
            connectionState = .disconnected
            delegate?.didUpdateConnectionState(.disconnected)
            connectedPeripheral = nil
        } else {
            // Unexpected disconnect - try auto-reconnect
            connectionState = .disconnected
            delegate?.didUpdateConnectionState(.disconnected)
            delegate?.didError("Printer disconnected unexpectedly")

            // Schedule reconnect if peripheral is still known
            if connectedPeripheral != nil {
                scheduleReconnect()
            }
        }
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let errorMsg = error?.localizedDescription ?? "Failed to connect"
        connectionState = .error
        delegate?.didUpdateConnectionState(.error)
        delegate?.didError(errorMsg)

        // Try reconnect
        scheduleReconnect()
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothPrinterManager: CBPeripheralDelegate {

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }

        for service in services {
            // Discover characteristics for all services
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            let uuidString = characteristic.uuid.uuidString

            // Check if this is a write characteristic
            if isWriteCharacteristic(characteristic) {
                writeCharacteristic = characteristic
                // Complete pending connection
                let completion = objc_getAssociatedObject(
                    peripheral,
                    Unmanaged.passUnretained(peripheral).toOpaque()
                ) as? ((Bool, String?) -> Void)
                completion?(true, nil)
                objc_setAssociatedObject(
                    peripheral,
                    Unmanaged.passUnretained(peripheral).toOpaque(),
                    nil,
                    .OBJC_ASSOCIATION_RETAIN_NONATOMIC
                )
            }

            // Check if this is a read/notify characteristic
            if isReadCharacteristic(characteristic) {
                readCharacteristic = characteristic
                // Enable notifications
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            delegate?.didError("Failed to enable notifications: \(error.localizedDescription)")
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let value = characteristic.value else { return }
        delegate?.didReceiveData(value)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            delegate?.didError("Write failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Characteristic Detection Helpers

    private func isWriteCharacteristic(_ characteristic: CBCharacteristic) -> Bool {
        let properties = characteristic.properties
        return properties.contains(.write) || properties.contains(.writeWithoutResponse)
    }

    private func isReadCharacteristic(_ characteristic: CBCharacteristic) -> Bool {
        let properties = characteristic.properties
        return properties.contains(.read) || properties.contains(.notify)
    }
}
