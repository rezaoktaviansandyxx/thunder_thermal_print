import Foundation
import Network

// MARK: - Network Printer Manager

/// Network (TCP/IP) printer manager using the Network framework (NWConnection).
/// Supports TCP socket connections, subnet scanning with parallel probes,
/// and auto-reconnect with exponential backoff.
public class NetworkPrinterManager: NSObject {

    // MARK: - Types

    public struct NetworkDevice {
        public let host: String
        public let port: UInt16
        public let rssi: Int // N/A for network, always 0
        public let name: String

        public var toBluetoothDevice: BluetoothDevice {
            return BluetoothDevice(
                name: name,
                address: "\(host):\(port)",
                rssi: 0,
                type: "network"
            )
        }

        public var toDictionary: [String: Any] {
            return [
                "name": name,
                "address": "\(host):\(port)",
                "rssi": 0,
                "type": "network",
                "host": host,
                "port": port
            ]
        }
    }

    /// Wrapper for queued write operations
    private struct PendingWrite {
        let data: Data
        let completion: ((Bool, String?) -> Void)?
    }

    public enum NetworkError: Error, LocalizedError {
        case invalidAddress(String)
        case connectionFailed(String)
        case connectionTimeout
        case notConnected
        case writeFailed(String)
        case scanFailed(String)
        case invalidPort

        public var errorDescription: String? {
            switch self {
            case .invalidAddress(let addr): return "Invalid network address: \(addr)"
            case .connectionFailed(let msg): return "Connection failed: \(msg)"
            case .connectionTimeout: return "Connection timed out"
            case .notConnected: return "Not connected to a network printer"
            case .writeFailed(let msg): return "Write failed: \(msg)"
            case .scanFailed(let msg): return "Network scan failed: \(msg)"
            case .invalidPort: return "Invalid port number"
            }
        }
    }

    // MARK: - Properties

    public weak var delegate: PrinterManagerDelegate?

    private var tcpConnection: NWConnection?

    // State
    public private(set) var isConnected: Bool = false
    public private(set) var isScanning: Bool = false
    public private(set) var connectionState: ConnectionState = .disconnected

    // Connection info
    private var connectedHost: String?
    private var connectedPort: UInt16?

    // Scanning
    private var discoveredDevices: [String: NetworkDevice] = [:]
    private var scanTimeoutTimer: Timer?
    private let scanQueue = DispatchQueue(label: "com.thunderlab.networkprinter.scan", qos: .userInitiated, attributes: .concurrent)
    private let defaultPort: UInt16 = 9100
    private let probeTimeout: TimeInterval = 1.5 // Per-device probe timeout

    // Reconnect
    private var reconnectTimer: Timer?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 5
    private var autoReconnectEnabled: Bool = false

    // Write queue
    private var pendingWrites: [PendingWrite] = []
    private var isWriting: Bool = false
    private let writeLock = NSLock()
    private let connectionQueue = DispatchQueue(label: "com.thunderlab.networkprinter.connection", qos: .userInitiated)

    // MARK: - Initialization

    public override init() {
        super.init()
    }

    deinit {
        disconnect()
        scanTimeoutTimer?.invalidate()
        reconnectTimer?.invalidate()
    }

    // MARK: - Network Scanning

    /// Scan for network printers on the local subnet.
    /// Attempts TCP connections to common printer ports (9100, 9101, 9102, 8080, 631)
    /// on each IP in the /24 subnet.
    /// - Parameters:
    ///   - duration: Total scan duration in seconds (default 8)
    ///   - port: Specific port to scan (0 = use default ports)
    public func scan(duration: Double = 8.0, port: UInt16 = 0) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard !self.isScanning else {
                self.delegate?.didError("Network scan already in progress")
                return
            }

            self.isScanning = true
            self.connectionState = .scanning
            self.delegate?.didUpdateConnectionState(.scanning)
            self.discoveredDevices.removeAll()

            // Get local IP and subnet
            guard let localIP = self.getLocalWiFiAddress() else {
                self.isScanning = false
                self.connectionState = .disconnected
                self.delegate?.didUpdateConnectionState(.disconnected)
                self.delegate?.didError("Unable to determine local IP address. Ensure WiFi is connected.")
                return
            }

            let subnet = self.getSubnet(from: localIP)
            let portsToScan: [UInt16] = port > 0 ? [port] : [9100, 9101, 9102, 80, 8080, 631]

            // Scan each IP in the subnet on each port using parallel probes
            for i in 1...254 {
                let host = "\(subnet).\(i)"
                for port in portsToScan {
                    self.scanQueue.async { [weak self] in
                        guard let self = self else { return }
                        self.probeHost(host: host, port: port, timeout: self.probeTimeout) { success in
                            guard success else { return }
                            let key = "\(host):\(port)"
                            let device = NetworkDevice(host: host, port: port, name: host)
                            DispatchQueue.main.async {
                                guard !self.discoveredDevices.keys.contains(key) else { return }
                                self.discoveredDevices[key] = device
                                let btDevice = device.toBluetoothDevice
                                self.delegate?.didDiscoverDevice(btDevice)
                            }
                        }
                    }
                }
            }

            // Set scan timeout
            self.scanTimeoutTimer?.invalidate()
            self.scanTimeoutTimer = Timer.scheduledTimer(
                withTimeInterval: duration,
                repeats: false
            ) { [weak self] _ in
                self?.stopScan()
            }
        }
    }

    /// Scan a specific IP address/port for a printer
    public func scanAddress(_ host: String, port: UInt16, completion: ((Bool, String?) -> Void)? = nil) {
        scanQueue.async { [weak self] in
            guard let self = self else { return }
            self.probeHost(host: host, port: port, timeout: self.probeTimeout) { success in
                if success {
                    let device = NetworkDevice(host: host, port: port, name: host)
                    DispatchQueue.main.async {
                        self.discoveredDevices["\(host):\(port)"] = device
                        let btDevice = device.toBluetoothDevice
                        self.delegate?.didDiscoverDevice(btDevice)
                        completion?(true, nil)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion?(false, "No printer found at \(host):\(port)")
                    }
                }
            }
        }
    }

    /// Probe a host:port with a timeout to check if a printer is listening
    private func probeHost(host: String, port: UInt16, timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
        let endpointHost = NWEndpoint.Host(host)
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            completion(false)
            return
        }

        let probe = NWConnection(host: endpointHost, port: endpointPort, using: .tcp)
        let probeQueue = DispatchQueue(label: "com.thunderlab.networkprinter.probe.\(host).\(port)", qos: .utility)

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

        // Hard timeout for the probe
        probeQueue.asyncAfter(deadline: .now() + timeout) {
            if !completed {
                completed = true
                probe.cancel()
                completion(false)
            }
        }
    }

    /// Stop scanning
    public func stopScan() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isScanning else { return }
            self.isScanning = false
            self.scanTimeoutTimer?.invalidate()
            self.scanTimeoutTimer = nil

            if self.connectionState == .scanning {
                self.connectionState = .disconnected
                self.delegate?.didUpdateConnectionState(.disconnected)
            }
        }
    }

    /// Get all discovered network devices
    public func getDiscoveredDevices() -> [BluetoothDevice] {
        return Array(discoveredDevices.values).map { $0.toBluetoothDevice }
    }

    // MARK: - Connection

    /// Connect to a network printer by address string ("host:port")
    public func connect(to address: String, completion: ((Bool, String?) -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                completion?(false, "Manager not available")
                return
            }

            // Parse host and port
            let parts = address.split(separator: ":", maxSplits: 1).map(String.init)
            guard !parts.isEmpty else {
                completion?(false, "Invalid address format. Expected 'host:port'")
                return
            }

            let host = parts[0]
            let port: UInt16
            if parts.count > 1, let p = UInt16(parts[1]) {
                port = p
            } else {
                port = self.defaultPort
            }

            self._connect(host: host, port: port, completion: completion)
        }
    }

    /// Connect to a network printer by explicit host and port
    public func connect(host: String, port: UInt16, completion: ((Bool, String?) -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            self?._connect(host: host, port: port, completion: completion)
        }
    }

    private func _connect(host: String, port: UInt16, completion: ((Bool, String?) -> Void)?) {
        // Disconnect existing connection first
        tcpConnection?.cancel()
        tcpConnection = nil

        connectionState = .connecting
        delegate?.didUpdateConnectionState(.connecting)

        let endpointHost = NWEndpoint.Host(host)
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            connectionState = .error
            delegate?.didUpdateConnectionState(.error)
            completion?(false, "Invalid port: \(port)")
            return
        }

        let newConnection = NWConnection(host: endpointHost, port: endpointPort, using: .tcp)

        let connectTimeout: DispatchTime = .now() + 10.0
        var connectionCompleted = false

        newConnection.stateUpdateHandler = { [weak self] state in
            guard !connectionCompleted else { return }

            switch state {
            case .setup:
                break

            case .waiting:
                // Transient networking issue - keep waiting
                break

            case .preparing:
                break

            case .ready:
                connectionCompleted = true
                self?.tcpConnection = newConnection
                self?.connectedHost = host
                self?.connectedPort = port
                self?.isConnected = true
                self?.reconnectAttempts = 0
                self?.connectionState = .connected

                DispatchQueue.main.async {
                    self?.delegate?.didUpdateConnectionState(.connected)
                    completion?(true, nil)
                }

                // Start receiving data from printer
                self?.receiveData()

            case .failed(let error):
                connectionCompleted = true
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.connectionState = .error
                    self?.delegate?.didUpdateConnectionState(.error)
                    completion?(false, "Connection failed: \(error.localizedDescription)")
                }

            case .cancelled:
                if !connectionCompleted {
                    connectionCompleted = true
                    DispatchQueue.main.async {
                        completion?(false, "Connection cancelled")
                    }
                }

            @unknown default:
                break
            }
        }

        newConnection.start(queue: connectionQueue)

        // Hard timeout fallback
        connectionQueue.asyncAfter(deadline: connectTimeout) { [weak self] in
            if !connectionCompleted {
                connectionCompleted = true
                newConnection.cancel()
                DispatchQueue.main.async {
                    self?.isConnected = false
                    self?.connectionState = .error
                    self?.delegate?.didUpdateConnectionState(.error)
                    completion?(false, "Connection timed out after 10 seconds")
                }
            }
        }
    }

    /// Disconnect from the network printer
    public func disconnect() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if let conn = self.tcpConnection {
                self.connectionState = .disconnecting
                self.delegate?.didUpdateConnectionState(.disconnecting)
                conn.cancel()
            }

            self.tcpConnection = nil
            self.connectedHost = nil
            self.connectedPort = nil
            self.isConnected = false

            self.writeLock.lock()
            self.pendingWrites.removeAll()
            self.isWriting = false
            self.writeLock.unlock()

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
        guard let host = connectedHost, let port = connectedPort else { return }
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionState = .error
            delegate?.didUpdateConnectionState(.error)
            delegate?.didError("Max network reconnect attempts reached (\(maxReconnectAttempts))")
            return
        }

        // Exponential backoff: 1s, 2s, 4s, 8s, 16s
        let delay: TimeInterval = pow(2.0, Double(reconnectAttempts))
        reconnectAttempts += 1

        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.connect(host: host, port: port) { success, _ in
                if !success {
                    self.scheduleReconnect()
                }
            }
        }
    }

    // MARK: - Data Writing

    /// Write raw data to the network printer
    public func writeData(_ data: Data, completion: ((Bool, String?) -> Void)? = nil) {
        guard let conn = tcpConnection else {
            completion?(false, "Not connected to a network printer")
            return
        }

        switch conn.state {
        case .ready:
            conn.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    completion?(false, error.localizedDescription)
                } else {
                    completion?(true, nil)
                }
            })

        case .setup, .preparing, .waiting:
            // Connection is still being established, retry after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.writeData(data, completion: completion)
            }

        default:
            completion?(false, "Connection is not in a valid state (state: \(String(describing: conn.state)))")
        }
    }

    /// Write data with queued support for sequential large payloads
    public func writeDataQueued(_ data: Data, completion: ((Bool, String?) -> Void)? = nil) {
        let pending = PendingWrite(data: data, completion: completion)

        writeLock.lock()
        if isWriting {
            pendingWrites.append(pending)
            writeLock.unlock()
            return
        }
        isWriting = true
        writeLock.unlock()

        writeData(data) { [weak self] success, error in
            self?.processNextWrite(originalCompletion: completion, success: success, error: error)
        }
    }

    private func processNextWrite(originalCompletion: ((Bool, String?) -> Void)?, success: Bool, error: String?) {
        writeLock.lock()
        isWriting = false

        if let next = pendingWrites.first {
            pendingWrites.removeFirst()
            isWriting = true
            writeLock.unlock()

            writeData(next.data) { [weak self] nextSuccess, nextError in
                self?.processNextWrite(originalCompletion: next.completion, success: nextSuccess, error: nextError)
            }
        } else {
            writeLock.unlock()
        }

        originalCompletion?(success, error)
    }

    /// Write string to the network printer
    public func writeString(_ string: String, completion: ((Bool, String?) -> Void)? = nil) {
        if let data = string.data(using: .utf8) {
            writeData(data, completion: completion)
        } else {
            completion?(false, "Failed to encode string to UTF-8")
        }
    }

    // MARK: - Data Receiving

    private func receiveData() {
        guard let conn = tcpConnection else { return }

        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.delegate?.didReceiveData(data)
            }

            if isComplete || error != nil {
                if let _ = error {
                    DispatchQueue.main.async {
                        self?.isConnected = false
                        self?.connectionState = .disconnected
                        self?.delegate?.didUpdateConnectionState(.disconnected)
                        self?.delegate?.didError("Network connection lost")
                        self?.scheduleReconnect()
                    }
                }
                return
            }

            // Continue receiving
            self?.receiveData()
        }
    }

    // MARK: - Network Utility Methods

    /// Get the local WiFi IP address using getifaddrs
    private func getLocalWiFiAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }

        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {  // IPv4 only
                let name = String(cString: interface.ifa_name)
                if name == "en0" {  // WiFi interface on iOS
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

        return address
    }

    /// Extract subnet prefix from IP (e.g., "192.168.1.100" -> "192.168.1")
    private func getSubnet(from ip: String) -> String {
        let parts = ip.split(separator: ".")
        if parts.count >= 3 {
            return "\(parts[0]).\(parts[1]).\(parts[2])"
        }
        return "192.168.1"
    }

    // MARK: - Device Info

    public var connectedDeviceAddress: String? {
        guard let host = connectedHost, let port = connectedPort else { return nil }
        return "\(host):\(port)"
    }

    public var connectedDeviceHost: String? {
        return connectedHost
    }

    public var connectedDevicePort: UInt16? {
        return connectedPort
    }
}
