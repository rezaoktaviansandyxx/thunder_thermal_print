import Foundation
import CoreBluetooth

// MARK: - BLE Printer Manager

/// Dedicated BLE (Bluetooth Low Energy) printer manager with advanced features.
/// Provides BLE scanning, connection management, service/characteristic discovery,
/// MTU-aware chunked writing, and auto-reconnect with exponential backoff.
public class BlePrinterManager: NSObject {

    // MARK: - Types

    public struct BleDevice {
        public let peripheral: CBPeripheral
        public let rssi: Int
        public let advertisementData: [String: Any]
        public let lastSeen: Date

        public var name: String {
            return peripheral.name ?? "Unknown BLE Device"
        }

        public var address: String {
            return peripheral.identifier.uuidString
        }

        public var toDictionary: [String: Any] {
            return [
                "name": name,
                "address": address,
                "rssi": rssi,
                "type": "ble"
            ]
        }
    }

    public enum BleError: Error, LocalizedError {
        case bluetoothUnavailable
        case bluetoothUnauthorized
        case notConnected
        case writeCharacteristicNotFound
        case mtuTooSmall
        case writeFailed(String)
        case scanInProgress
        case deviceNotFound(String)
        case connectionFailed(String)
        case timeout

        public var errorDescription: String? {
            switch self {
            case .bluetoothUnavailable: return "Bluetooth is not available"
            case .bluetoothUnauthorized: return "Bluetooth access is unauthorized"
            case .notConnected: return "Not connected to a BLE printer"
            case .writeCharacteristicNotFound: return "Write characteristic not found on the printer"
            case .mtuTooSmall: return "MTU size too small for the operation"
            case .writeFailed(let msg): return "Write failed: \(msg)"
            case .scanInProgress: return "A scan is already in progress"
            case .deviceNotFound(let id): return "BLE device not found: \(id)"
            case .connectionFailed(let msg): return "Connection failed: \(msg)"
            case .timeout: return "Operation timed out"
            }
        }
    }

    // MARK: - Properties

    public weak var delegate: PrinterManagerDelegate?

    private(set) var centralManager: CBCentralManager!
    private var discoveredDevices: [String: BleDevice] = [:]
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var readCharacteristic: CBCharacteristic?

    // State
    public private(set) var isConnected: Bool = false
    public private(set) var isScanning: Bool = false
    public private(set) var connectionState: ConnectionState = .disconnected

    // Scan
    private var scanTimeoutTimer: Timer?
    private var scanServices: [CBUUID]?

    // Reconnect
    private var reconnectTimer: Timer?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 5
    private var autoReconnectEnabled: Bool = false
    private var lastConnectedAddress: String?

    // Write queue
    private var writeQueue: [Data] = []
    private var isWriting: Bool = false
    private let writeQueueLock = NSLock()
    private let writeDispatchQueue = DispatchQueue(label: "com.thunderlab.bleprinter.write", qos: .userInitiated)

    // MTU
    private var negotiatedMTU: Int = 20 // Default minimum

    // Service UUIDs for thermal printers
    private static let printerServiceUUIDs: [CBUUID] = [
        CBUUID(string: "000018F0-0000-1000-8000-00805F9B34FB"),
        CBUUID(string: "0000FF00-0000-1000-8000-00805F9B34FB"),
        CBUUID(string: "0000FF01-0000-1000-8000-00805F9B34FB"),
        CBUUID(string: "E7810A71-73AE-499D-8C15-FAA9AEF0C3F2"),
        CBUUID(string: "0000FEFD-0000-1000-8000-00805F9B34FB"),
        CBUUID(string: "49535343-FE7D-4AE5-8FA9-9FAFD205E455"),
        CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")
    ]

    // Completion handlers stored by peripheral identifier
    private var connectionCompletions: [String: (Bool, String?) -> Void] = [:]

    // MARK: - Initialization

    public override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue(label: "com.thunderlab.bleprinter.central", qos: .userInitiated))
    }

    deinit {
        stopScan()
        disconnect()
        scanTimeoutTimer?.invalidate()
        reconnectTimer?.invalidate()
    }

    // MARK: - Bluetooth State

    public var isBluetoothPoweredOn: Bool {
        return centralManager.state == .poweredOn
    }

    public var isBluetoothAvailable: Bool {
        return centralManager.state == .poweredOn || centralManager.state == .poweredOff
    }

    // MARK: - Scanning

    /// Start scanning for BLE printer devices.
    /// - Parameters:
    ///   - duration: Scan duration in seconds (default 10)
    ///   - serviceUUIDs: Optional list of service UUIDs to filter. If nil, scans for all.
    public func scan(duration: Double = 10.0, serviceUUIDs: [String]? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            guard !self.isScanning else {
                self.delegate?.didError("Scan already in progress")
                return
            }

            self.stopScan()
            self.discoveredDevices.removeAll()

            guard self.centralManager.state == .poweredOn else {
                self.delegate?.didError("Bluetooth is not powered on")
                return
            }

            // Parse service UUIDs if provided
            if let uuidStrings = serviceUUIDs {
                self.scanServices = uuidStrings.compactMap { CBUUID(string: $0) }
            } else {
                // Default: scan for common printer services
                self.scanServices = BlePrinterManager.printerServiceUUIDs
            }

            self.connectionState = .scanning
            self.delegate?.didUpdateConnectionState(.scanning)
            self.isScanning = true

            // Start scan
            self.centralManager.scanForPeripherals(
                withServices: self.scanServices,
                options: [
                    CBCentralManagerScanOptionAllowDuplicatesKey: true,
                    CBCentralManagerScanOptionSolicitedServiceUUIDsKey: self.scanServices as Any
                ]
            )

            // Set timeout
            self.scanTimeoutTimer?.invalidate()
            self.scanTimeoutTimer = Timer.scheduledTimer(
                withTimeInterval: duration,
                repeats: false
            ) { [weak self] _ in
                self?.stopScan()
            }
        }
    }

    /// Scan for all BLE devices regardless of service
    public func scanAll(duration: Double = 10.0) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard !self.isScanning else { return }
            guard self.centralManager.state == .poweredOn else {
                self.delegate?.didError("Bluetooth is not powered on")
                return
            }

            self.stopScan()
            self.discoveredDevices.removeAll()
            self.scanServices = nil
            self.isScanning = true
            self.connectionState = .scanning
            self.delegate?.didUpdateConnectionState(.scanning)

            self.centralManager.scanForPeripherals(withServices: nil, options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: true
            ])

            self.scanTimeoutTimer?.invalidate()
            self.scanTimeoutTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.stopScan()
            }
        }
    }

    /// Stop scanning
    public func stopScan() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isScanning else { return }
            self.centralManager.stopScan()
            self.scanTimeoutTimer?.invalidate()
            self.scanTimeoutTimer = nil
            self.isScanning = false

            if self.connectionState == .scanning {
                self.connectionState = .disconnected
                self.delegate?.didUpdateConnectionState(.disconnected)
            }
        }
    }

    /// Get list of discovered BLE devices
    public func getDiscoveredDevices() -> [BluetoothDevice] {
        return discoveredDevices.values.map { bleDevice in
            BluetoothDevice(
                name: bleDevice.name,
                address: bleDevice.address,
                rssi: bleDevice.rssi,
                type: "ble"
            )
        }
    }

    // MARK: - Connection

    /// Connect to a BLE device by its address (UUID string)
    public func connect(to address: String, completion: ((Bool, String?) -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                completion?(false, "Manager not available")
                return
            }

            guard self.centralManager.state == .poweredOn else {
                completion?(false, "Bluetooth is not powered on")
                return
            }

            // Find the peripheral
            let uuid = UUID(uuidString: address)
            if uuid != nil {
                let retrieved = self.centralManager.retrievePeripherals(withIdentifiers: [uuid!])
                if let peripheral = retrieved.first {
                    self._connect(peripheral, completion: completion)
                    return
                }
            }

            // Check discovered devices
            if let bleDevice = self.discoveredDevices[address] {
                self._connect(bleDevice.peripheral, completion: completion)
                return
            }

            completion?(false, "Device not found. Please scan for devices first.")
        }
    }

    private func _connect(_ peripheral: CBPeripheral, completion: ((Bool, String?) -> Void)?) {
        connectionState = .connecting
        delegate?.didUpdateConnectionState(.connecting)

        connectedPeripheral = peripheral
        writeCharacteristic = nil
        readCharacteristic = nil
        writeQueue.removeAll()
        isWriting = false

        // Store completion
        let address = peripheral.identifier.uuidString
        if let comp = completion {
            connectionCompletions[address] = comp
        }

        centralManager.connect(peripheral, options: [
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true
        ])
    }

    /// Disconnect from the connected device
    public func disconnect() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let peripheral = self.connectedPeripheral {
                self.connectionState = .disconnecting
                self.delegate?.didUpdateConnectionState(.disconnecting)
                self.centralManager.cancelPeripheralConnection(peripheral)
                self.connectionCompletions.removeValue(forKey: peripheral.identifier.uuidString)
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

    public func enableAutoReconnect(_ enabled: Bool) {
        autoReconnectEnabled = enabled
        if !enabled {
            reconnectTimer?.invalidate()
            reconnectTimer = nil
            reconnectAttempts = 0
        }
    }

    private func scheduleReconnect() {
        guard autoReconnectEnabled else { return }
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionState = .error
            delegate?.didUpdateConnectionState(.error)
            delegate?.didError("Max BLE reconnect attempts reached (\(maxReconnectAttempts))")
            return
        }

        // Exponential backoff: 1s, 2s, 4s, 8s, 16s
        let delay: TimeInterval = pow(2.0, Double(reconnectAttempts))
        reconnectAttempts += 1

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self, let address = self.lastConnectedAddress else { return }

            self.connectionState = .connecting
            self.delegate?.didUpdateConnectionState(.connecting)

            self.connect(to: address) { [weak self] success, error in
                if !success {
                    self?.scheduleReconnect()
                }
            }
        }
    }

    // MARK: - Data Writing

    /// Write raw data to the BLE printer.
    /// Automatically handles chunking based on negotiated MTU.
    public func writeData(_ data: Data, completion: ((Bool, String?) -> Void)? = nil) {
        writeDispatchQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion?(false, "Manager deallocated") }
                return
            }

            guard let peripheral = self.connectedPeripheral else {
                DispatchQueue.main.async { completion?(false, "Not connected") }
                return
            }

            guard let characteristic = self.writeCharacteristic else {
                DispatchQueue.main.async { completion?(false, "Write characteristic not discovered") }
                return
            }

            self.writeQueueLock.lock()
            if self.isWriting {
                self.writeQueue.append(data)
                self.writeQueueLock.unlock()
                return
            }
            self.isWriting = true
            self.writeQueueLock.unlock()

            let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
            let effectiveMTU = max(mtu, 20)

            if data.count <= effectiveMTU {
                // Single write
                DispatchQueue.main.async {
                    peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.processWriteQueue(
                        peripheral: peripheral,
                        characteristic: characteristic,
                        completion: completion
                    )
                }
            } else {
                // Chunked write
                let chunks = self.chunkData(data, chunkSize: effectiveMTU)
                self.writeChunksSequentially(
                    chunks: chunks,
                    index: 0,
                    peripheral: peripheral,
                    characteristic: characteristic,
                    completion: completion
                )
            }
        }
    }

    /// Write data with response (more reliable but slower)
    public func writeDataWithResponse(_ data: Data, completion: ((Bool, String?) -> Void)? = nil) {
        writeDispatchQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion?(false, "Manager deallocated") }
                return
            }

            guard let peripheral = self.connectedPeripheral else {
                DispatchQueue.main.async { completion?(false, "Not connected") }
                return
            }

            guard let characteristic = self.writeCharacteristic else {
                DispatchQueue.main.async { completion?(false, "Write characteristic not discovered") }
                return
            }

            let mtu = peripheral.maximumWriteValueLength(for: .withResponse)
            let effectiveMTU = max(mtu, 20)

            if data.count <= effectiveMTU {
                DispatchQueue.main.async {
                    peripheral.writeValue(data, for: characteristic, type: .withResponse)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    completion?(true, nil)
                }
            } else {
                let chunks = self.chunkData(data, chunkSize: effectiveMTU)
                self.writeChunksWithResponse(
                    chunks: chunks,
                    index: 0,
                    peripheral: peripheral,
                    characteristic: characteristic,
                    completion: completion
                )
            }
        }
    }

    private func processWriteQueue(
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        completion: ((Bool, String?) -> Void)?
    ) {
        writeQueueLock.lock()
        isWriting = false

        if let nextData = writeQueue.first {
            writeQueue.removeFirst()
            isWriting = true
            writeQueueLock.unlock()

            let mtu = peripheral.maximumWriteValueLength(for: .withoutResponse)
            let effectiveMTU = max(mtu, 20)

            if nextData.count <= effectiveMTU {
                DispatchQueue.main.async {
                    peripheral.writeValue(nextData, for: characteristic, type: .withoutResponse)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.processWriteQueue(peripheral: peripheral, characteristic: characteristic, completion: nil)
                }
            } else {
                let chunks = chunkData(nextData, chunkSize: effectiveMTU)
                writeChunksSequentially(
                    chunks: chunks,
                    index: 0,
                    peripheral: peripheral,
                    characteristic: characteristic,
                    completion: nil
                )
            }
        } else {
            writeQueueLock.unlock()
            completion?(true, nil)
        }
    }

    private func writeChunksSequentially(
        chunks: [Data],
        index: Int,
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        completion: ((Bool, String?) -> Void)?
    ) {
        guard index < chunks.count else {
            processWriteQueue(peripheral: peripheral, characteristic: characteristic, completion: completion)
            return
        }

        DispatchQueue.main.async {
            peripheral.writeValue(chunks[index], for: characteristic, type: .withoutResponse)
        }

        // Brief delay between chunks
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.writeChunksSequentially(
                chunks: chunks,
                index: index + 1,
                peripheral: peripheral,
                characteristic: characteristic,
                completion: completion
            )
        }
    }

    private func writeChunksWithResponse(
        chunks: [Data],
        index: Int,
        peripheral: CBPeripheral,
        characteristic: CBCharacteristic,
        completion: ((Bool, String?) -> Void)?
    ) {
        guard index < chunks.count else {
            DispatchQueue.main.async { completion?(true, nil) }
            return
        }

        DispatchQueue.main.async {
            peripheral.writeValue(chunks[index], for: characteristic, type: .withResponse)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.writeChunksWithResponse(
                chunks: chunks,
                index: index + 1,
                peripheral: peripheral,
                characteristic: characteristic,
                completion: completion
            )
        }
    }

    private func chunkData(_ data: Data, chunkSize: Int) -> [Data] {
        var chunks: [Data] = []
        var offset = 0
        while offset < data.count {
            let length = min(data.count - offset, chunkSize)
            chunks.append(data.subdata(in: offset..<(offset + length)))
            offset += length
        }
        return chunks
    }

    /// Write string to the BLE printer
    public func writeString(_ string: String, completion: ((Bool, String?) -> Void)? = nil) {
        if let data = string.data(using: .utf8) {
            writeData(data, completion: completion)
        } else {
            DispatchQueue.main.async { completion?(false, "Failed to encode string") }
        }
    }

    // MARK: - MTU

    /// Get the current effective MTU for writing
    public var currentMTU: Int {
        guard let peripheral = connectedPeripheral else { return 20 }
        return max(peripheral.maximumWriteValueLength(for: .withoutResponse), 20)
    }

    // MARK: - Device Info

    /// Get the name of the connected device
    public var connectedDeviceName: String? {
        return connectedPeripheral?.name
    }

    /// Get the address of the connected device
    public var connectedDeviceAddress: String? {
        return connectedPeripheral?.identifier.uuidString
    }
}

// MARK: - CBCentralManagerDelegate

extension BlePrinterManager: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch central.state {
            case .poweredOn:
                if self.connectionState == .scanning && !self.isScanning {
                    self.startActualScan()
                }
            case .poweredOff:
                self.stopScan()
                self.disconnect()
                self.delegate?.didError("Bluetooth is powered off. Please enable Bluetooth in Settings.")
            case .unauthorized:
                self.delegate?.didError("Bluetooth access is unauthorized. Please grant Bluetooth permission in Settings.")
            case .unknown:
                break
            case .resetting:
                self.disconnect()
                self.delegate?.didError("Bluetooth system is resetting")
            @unknown default:
                break
            }
        }
    }

    private func startActualScan() {
        isScanning = true
        centralManager.scanForPeripherals(
            withServices: scanServices,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let identifier = peripheral.identifier.uuidString
        let existing = discoveredDevices[identifier]

        // Update or create device entry
        let device = BleDevice(
            peripheral: peripheral,
            rssi: RSSI.intValue,
            advertisementData: advertisementData,
            lastSeen: Date()
        )
        discoveredDevices[identifier] = device

        // Only notify delegate for new devices
        if existing == nil {
            let btDevice = BluetoothDevice(
                name: device.name,
                address: device.address,
                rssi: device.rssi,
                type: "ble"
            )
            delegate?.didDiscoverDevice(btDevice)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.isConnected = true
            self.connectionState = .connected
            self.reconnectAttempts = 0
            self.lastConnectedAddress = peripheral.identifier.uuidString
            self.delegate?.didUpdateConnectionState(.connected)

            // Set up the peripheral
            peripheral.delegate = self
            self.negotiatedMTU = 20 // Will be updated after service discovery

            // Discover services
            peripheral.discoverServices(BlePrinterManager.printerServiceUUIDs)
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.isConnected = false
            self.writeCharacteristic = nil
            self.readCharacteristic = nil
            self.writeQueue.removeAll()
            self.isWriting = false

            let address = peripheral.identifier.uuidString
            let completion = self.connectionCompletions.removeValue(forKey: address)

            if self.connectionState == .disconnecting {
                self.connectionState = .disconnected
                self.delegate?.didUpdateConnectionState(.disconnected)
                self.connectedPeripheral = nil
            } else {
                self.connectionState = .disconnected
                self.delegate?.didUpdateConnectionState(.disconnected)
                if let err = error {
                    self.delegate?.didError("Unexpected disconnect: \(err.localizedDescription)")
                }
                self.scheduleReconnect()
            }
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let address = peripheral.identifier.uuidString
            let errorMsg = error?.localizedDescription ?? "Unknown connection error"

            self.connectionState = .error
            self.delegate?.didUpdateConnectionState(.error)
            self.delegate?.didError("Connection failed: \(errorMsg)")

            if let completion = self.connectionCompletions.removeValue(forKey: address) {
                completion(false, errorMsg)
            }

            self.scheduleReconnect()
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BlePrinterManager: CBPeripheralDelegate {

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            delegate?.didError("Service discovery error: \(error.localizedDescription)")
            return
        }

        guard let services = peripheral.services else { return }

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error = error {
            delegate?.didError("Characteristic discovery error: \(error.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            let props = characteristic.properties
            let uuidString = characteristic.uuid.uuidString

            // Identify write characteristic
            if props.contains(.writeWithoutResponse) || props.contains(.write) {
                if writeCharacteristic == nil {
                    writeCharacteristic = characteristic
                }
            }

            // Identify read/notify characteristic
            if props.contains(.notify) || props.contains(.read) {
                if readCharacteristic == nil {
                    readCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }

        // After discovering all characteristics, fire connection completion
        if writeCharacteristic != nil {
            let address = peripheral.identifier.uuidString
            if let completion = connectionCompletions.removeValue(forKey: address) {
                completion(true, nil)
            }
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            delegate?.didError("Notification state error: \(error.localizedDescription)")
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            delegate?.didError("Value update error: \(error.localizedDescription)")
            return
        }
        if let value = characteristic.value {
            delegate?.didReceiveData(value)
        }
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            delegate?.didError("Write error: \(error.localizedDescription)")
        }
    }
}
