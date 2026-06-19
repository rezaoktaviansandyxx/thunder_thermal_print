package id.thunderlab.thuder_thermal_print.ble

import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * BlePrinterManager handles BLE (Bluetooth Low Energy) thermal printer connections.
 *
 * Features:
 * - BLE scanning using BluetoothLeScanner with configurable filters
 * - GATT connection with service/characteristic discovery
 * - Automatic detection of common printer service UUIDs
 *   (000018F0, 0000FF00, or user-specified)
 * - Writing to the print characteristic
 * - Auto-reconnect with exponential backoff
 * - MTU negotiation for larger data transfer
 */
class BlePrinterManager(
    private val context: Context,
    private var activity: Activity?,
    private val onConnectionStateChanged: (String) -> Unit
) {

    companion object {
        private const val TAG = "BLEPrinterManager"

        // Common BLE printer service UUIDs
        val SERVICE_UUID_PRINTER: UUID = UUID.fromString("000018F0-0000-1000-8000-00805F9B34FB")
        val SERVICE_UUID_VENDOR: UUID = UUID.fromString("0000FF00-0000-1000-8000-00805F9B34FB")
        val SERVICE_UUID_SPP_LE: UUID = UUID.fromString("0000FFE0-0000-1000-8000-00805F9B34FB")

        // Common characteristic UUIDs
        val CHAR_WRITE: UUID = UUID.fromString("000018F1-0000-1000-8000-00805F9B34FB")
        val CHAR_WRITE_VENDOR: UUID = UUID.fromString("0000FF02-0000-1000-8000-00805F9B34FB")
        val CHAR_WRITE_SPP: UUID = UUID.fromString("0000FFE1-0000-1000-8000-00805F9B34FB")

        // CCC descriptor for enabling notifications
        val CCC_DESCRIPTOR_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805F9B34FB")

        // Connection states
        private const val STATE_DISCONNECTED = "disconnected"
        private const val STATE_CONNECTING = "connecting"
        private const val STATE_CONNECTED = "connected"
        private const val STATE_DISCOVERING_SERVICES = "discovering_services"
        private const val STATE_READY = "ready"
        private const val STATE_RECONNECTING = "reconnecting"

        // Auto-reconnect settings
        private const val BASE_RECONNECT_DELAY_MS = 1000L
        private const val MAX_RECONNECT_DELAY_MS = 30000L
        private const val MAX_RECONNECT_ATTEMPTS = 8

        // GATT timeout
        private const val GATT_TIMEOUT_MS = 15000L
        private const val DEFAULT_MTU = 512
    }

    // Bluetooth adapter & scanner
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bleScanner: BluetoothLeScanner? = null

    // GATT
    private var bluetoothGatt: BluetoothGatt? = null
    private var writeCharacteristic: BluetoothGattCharacteristic? = null
    private var notifyCharacteristic: BluetoothGattCharacteristic? = null

    // Connection state
    private val isConnectedFlag = AtomicBoolean(false)
    @Volatile
    private var connectionState: String = STATE_DISCONNECTED

    // Auto-reconnect state
    private var autoReconnectEnabled: Boolean = false
    private var targetDeviceId: String? = null
    private var targetServiceUuid: UUID? = null
    private var reconnectAttempts: Int = 0
    private val reconnectHandler = Handler(Looper.getMainLooper())

    // Scan state
    private val scanResults = mutableListOf<ScanResult>()
    private val scanLatch = CountDownLatch(1)
    private var isScanning = AtomicBoolean(false)

    // GATT operation queue (to avoid concurrent GATT operations)
    private val gattOperationQueue = ArrayDeque<() -> Boolean>()
    private var isGattOperationInProgress = false

    // Device discovery listener
    private var deviceDiscoveryListener: ((List<Map<String, Any>>) -> Unit)? = null

    // Latch for connection
    private var connectLatch: CountDownLatch? = null
    private var connectSuccess = AtomicBoolean(false)

    init {
        initBleAdapter()
    }

    // ---- Initialization ----

    private fun initBleAdapter() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                bluetoothAdapter = btManager?.adapter
            } else {
                bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
            }
            bleScanner = bluetoothAdapter?.bluetoothLeScanner
        } catch (e: SecurityException) {
            Log.e(TAG, "No permission to access Bluetooth LE", e)
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing BLE adapter", e)
        }
    }

    // ---- Scanning ----

    /**
     * Start BLE scanning for devices.
     * @param timeoutMs Scan duration in milliseconds
     * @return List of discovered device maps: name, address, rssi, type
     */
    @SuppressLint("MissingPermission")
    fun startScan(timeoutMs: Long = 10000L): List<Map<String, Any>> {
        val scanner = bleScanner
        if (scanner == null) {
            Log.e(TAG, "BLE scanner not available")
            return emptyList()
        }

        if (isScanning.getAndSet(true)) {
            Log.w(TAG, "Scan already in progress")
            return emptyList()
        }

        scanResults.clear()
        val newLatch = CountDownLatch(1)

        val scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                synchronized(scanResults) {
                    if (scanResults.none { it.device.address == result.device.address }) {
                        scanResults.add(result)
                        val devices = scanResults.map { scanResultToMap(it) }
                        deviceDiscoveryListener?.invoke(devices)
                    }
                }
            }

            override fun onBatchScanResults(results: MutableList<ScanResult>?) {
                results?.let { batch ->
                    synchronized(scanResults) {
                        for (result in batch) {
                            if (scanResults.none { it.device.address == result.device.address }) {
                                scanResults.add(result)
                            }
                        }
                        val devices = scanResults.map { scanResultToMap(it) }
                        deviceDiscoveryListener?.invoke(devices)
                    }
                }
            }

            override fun onScanFailed(errorCode: Int) {
                Log.e(TAG, "BLE scan failed with error: $errorCode")
                newLatch.countDown()
                isScanning.set(false)
            }
        }

        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .setReportDelay(0)
            .build()

        // Optionally filter by known printer service UUIDs
        val filters = mutableListOf<ScanFilter>()
        // We do NOT set service UUID filters to maximize discovery
        // If you want to filter: filters.add(ScanFilter.Builder().setServiceUuid(ParcelUuid(SERVICE_UUID_PRINTER)).build())

        try {
            scanner.startScan(filters, scanSettings, scanCallback)
        } catch (e: SecurityException) {
            Log.e(TAG, "No permission to start BLE scan", e)
            isScanning.set(false)
            return emptyList()
        } catch (e: IllegalStateException) {
            Log.e(TAG, "BLE scan already running", e)
            isScanning.set(false)
            return emptyList()
        }

        try {
            newLatch.await(timeoutMs, TimeUnit.MILLISECONDS)
        } catch (_: InterruptedException) {}

        // Stop scan
        try {
            scanner.stopScan(scanCallback)
        } catch (e: SecurityException) {
            Log.w(TAG, "No permission to stop BLE scan", e)
        } catch (_: Exception) {}

        isScanning.set(false)

        return synchronized(scanResults) {
            scanResults.map { scanResultToMap(it) }
        }
    }

    @SuppressLint("MissingPermission")
    private fun scanResultToMap(result: ScanResult): Map<String, Any> {
        val device = result.device
        return mapOf(
            "name" to (device.name ?: "Unknown BLE"),
            "address" to device.address,
            "rssi" to result.rssi,
            "type" to "ble"
        )
    }

    // ---- Connection ----

    /**
     * Connect to a BLE device.
     * @param deviceId The MAC address of the BLE device
     * @param autoReconnect Whether to auto-reconnect on disconnect
     * @return true if connection and service discovery succeed
     */
    @SuppressLint("MissingPermission")
    fun connect(deviceId: String, autoReconnect: Boolean = false): Boolean {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            Log.e(TAG, "BLE adapter not available")
            return false
        }

        // Disconnect existing
        disconnect()

        setConnectionState(STATE_CONNECTING)
        targetDeviceId = deviceId
        autoReconnectEnabled = autoReconnect
        reconnectAttempts = 0
        connectSuccess = AtomicBoolean(false)
        connectLatch = CountDownLatch(1)

        try {
            val device = adapter.getRemoteDevice(deviceId)

            // Connect with autoConnect=false for direct connection, true for background
            // Use false for immediate connection
            val gatt: BluetoothGatt? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
            } else {
                @Suppress("DEPRECATION")
                device.connectGatt(context, false, gattCallback)
            }

            bluetoothGatt = gatt

            if (gatt == null) {
                Log.e(TAG, "Failed to create GATT connection to $deviceId")
                setConnectionState(STATE_DISCONNECTED)
                return false
            }

            // Request MTU
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                gatt.requestMtu(DEFAULT_MTU)
            }

            // Wait for connection with timeout
            val connected = connectLatch?.await(GATT_TIMEOUT_MS, TimeUnit.MILLISECONDS) ?: false
            if (!connected || !connectSuccess.get()) {
                Log.e(TAG, "GATT connection timed out for $deviceId")
                gatt.close()
                bluetoothGatt = null
                setConnectionState(STATE_DISCONNECTED)
                return false
            }

            // Wait a bit for service discovery
            Thread.sleep(500)

            return isConnectedFlag.get()
        } catch (e: SecurityException) {
            Log.e(TAG, "No Bluetooth permission", e)
            setConnectionState(STATE_DISCONNECTED)
            return false
        } catch (e: Exception) {
            Log.e(TAG, "Error connecting to $deviceId", e)
            setConnectionState(STATE_DISCONNECTED)
            return false
        }
    }

    /**
     * Disconnect from the currently connected BLE device.
     */
    fun disconnect() {
        autoReconnectEnabled = false
        reconnectAttempts = MAX_RECONNECT_ATTEMPTS
        closeGatt()
        setConnectionState(STATE_DISCONNECTED)
    }

    private fun closeGatt() {
        writeCharacteristic = null
        notifyCharacteristic = null
        val gatt = bluetoothGatt
        bluetoothGatt = null
        isConnectedFlag.set(false)

        try {
            gatt?.disconnect()
        } catch (e: SecurityException) {
            Log.w(TAG, "Permission error disconnecting GATT", e)
        } catch (_: Exception) {}

        try {
            gatt?.close()
        } catch (e: SecurityException) {
            Log.w(TAG, "Permission error closing GATT", e)
        } catch (_: Exception) {}
    }

    private fun handleUnexpectedDisconnect() {
        if (!isConnectedFlag.get()) return
        closeGatt()
        setConnectionState(STATE_DISCONNECTED)

        if (autoReconnectEnabled && reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
            scheduleReconnect()
        }
    }

    // ---- Auto-reconnect ----

    private fun scheduleReconnect() {
        if (!autoReconnectEnabled) return
        val deviceId = targetDeviceId ?: return

        reconnectAttempts++
        val delay = minOf(
            BASE_RECONNECT_DELAY_MS * (1L shl (reconnectAttempts - 1)),
            MAX_RECONNECT_DELAY_MS
        )

        Log.d(TAG, "Scheduling BLE reconnect attempt $reconnectAttempts in ${delay}ms")
        setConnectionState(STATE_RECONNECTING)

        reconnectHandler.postDelayed({
            if (!autoReconnectEnabled || isConnectedFlag.get()) return@postDelayed
            Log.d(TAG, "Auto-reconnecting to $deviceId (attempt $reconnectAttempts)")
            if (!connect(deviceId, true)) {
                if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
                    Log.e(TAG, "Max BLE reconnect attempts reached")
                    autoReconnectEnabled = false
                    setConnectionState(STATE_DISCONNECTED)
                }
            }
        }, delay)
    }

    // ---- GATT Callback ----

    private val gattCallback = object : BluetoothGattCallback() {

        override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
            Log.d(TAG, "onConnectionStateChange: status=$status, newState=$newState")

            if (status != BluetoothGatt.GATT_SUCCESS) {
                Log.e(TAG, "GATT connection failed: status=$status")
                connectLatch?.countDown()
                handleUnexpectedDisconnect()
                return
            }

            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    Log.d(TAG, "GATT connected to ${gatt?.device?.address}")
                    setConnectionState(STATE_DISCOVERING_SERVICES)
                    // Discover services
                    try {
                        gatt?.discoverServices()
                    } catch (e: SecurityException) {
                        Log.e(TAG, "Permission error discovering services", e)
                        connectLatch?.countDown()
                        handleUnexpectedDisconnect()
                    }
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    Log.d(TAG, "GATT disconnected from ${gatt?.device?.address}")
                    connectLatch?.countDown()
                    handleUnexpectedDisconnect()
                }
                BluetoothProfile.STATE_CONNECTING -> {
                    Log.d(TAG, "GATT connecting...")
                }
                BluetoothProfile.STATE_DISCONNECTING -> {
                    Log.d(TAG, "GATT disconnecting...")
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
            Log.d(TAG, "onServicesDiscovered: status=$status")

            if (status != BluetoothGatt.GATT_SUCCESS) {
                Log.e(TAG, "Service discovery failed: status=$status")
                connectLatch?.countDown()
                handleUnexpectedDisconnect()
                return
            }

            val targetUuid = targetServiceUuid
            val service = findPrinterService(gatt, targetUuid)

            if (service != null) {
                Log.d(TAG, "Found printer service: ${service.uuid}")
                val writeChar = findWriteCharacteristic(service)
                if (writeChar != null) {
                    writeCharacteristic = writeChar
                    Log.d(TAG, "Found write characteristic: ${writeChar.uuid}")

                    // Enable notifications on the notify characteristic if available
                    enableNotifications(gatt, service)

                    isConnectedFlag.set(true)
                    reconnectAttempts = 0
                    connectSuccess.set(true)
                    setConnectionState(STATE_READY)
                    connectLatch?.countDown()
                    return
                } else {
                    Log.e(TAG, "No write characteristic found in service ${service.uuid}")
                }
            } else {
                Log.e(TAG, "No printer service found")
                // Log all discovered services for debugging
                gatt?.services?.forEach { s ->
                    Log.d(TAG, "  Service: ${s.uuid}")
                    s.characteristics.forEach { c ->
                        val props = characteristicPropertiesToString(c.properties)
                        Log.d(TAG, "    Char: ${c.uuid} [$props]")
                    }
                }
            }

            connectLatch?.countDown()
            handleUnexpectedDisconnect()
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt?, characteristic: BluetoothGattCharacteristic?) {
            characteristic?.value?.let { data ->
                Log.d(TAG, "Notification received: ${data.size} bytes")
                // Process printer status response
                val status = decodePrinterStatus(data)
                Log.d(TAG, "Printer status: $status")
            }
        }

        override fun onCharacteristicChanged(
            gatt: BluetoothGatt?,
            characteristic: BluetoothGattCharacteristic?,
            value: ByteArray?
        ) {
            value?.let { data ->
                Log.d(TAG, "Notification received (API 33+): ${data.size} bytes")
            }
        }

        override fun onCharacteristicWrite(
            gatt: BluetoothGatt?,
            characteristic: BluetoothGattCharacteristic?,
            status: Int
        ) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                Log.d(TAG, "Characteristic write success")
                processNextGattOperation()
            } else {
                Log.e(TAG, "Characteristic write failed: status=$status")
                processNextGattOperation()
            }
        }

        override fun onMtuChanged(gatt: BluetoothGatt?, mtu: Int, status: Int) {
            Log.d(TAG, "MTU changed: $mtu, status=$status")
        }

        override fun onReliableWriteCompleted(gatt: BluetoothGatt?, status: Int) {
            Log.d(TAG, "Reliable write completed: status=$status")
        }
    }

    // ---- Service & Characteristic Discovery ----

    private fun findPrinterService(gatt: BluetoothGatt?, targetUuid: UUID?): BluetoothGattService? {
        if (gatt == null) return null

        // If user specified a target service UUID, try that first
        if (targetUuid != null) {
            val service = gatt.getService(targetUuid)
            if (service != null) return service
        }

        // Try known printer service UUIDs
        val knownUuids = listOf(SERVICE_UUID_PRINTER, SERVICE_UUID_VENDOR, SERVICE_UUID_SPP_LE)
        for (uuid in knownUuids) {
            val service = gatt.getService(uuid)
            if (service != null) {
                return service
            }
        }

        // Heuristic: find first service with a writable characteristic
        for (service in gatt.services) {
            val writeChar = findWriteCharacteristic(service)
            if (writeChar != null) {
                return service
            }
        }

        return null
    }

    private fun findWriteCharacteristic(service: BluetoothGattService): BluetoothGattCharacteristic? {
        val knownWriteUuids = listOf(CHAR_WRITE, CHAR_WRITE_VENDOR, CHAR_WRITE_SPP)

        // Try known UUIDs first
        for (uuid in knownWriteUuids) {
            val char = service.getCharacteristic(uuid)
            if (char != null && char.isWritable()) {
                return char
            }
        }

        // Heuristic: find any writable characteristic
        for (char in service.characteristics) {
            if (char.isWritable()) {
                return char
            }
        }

        return null
    }

    private fun BluetoothGattCharacteristic.isWritable(): Boolean {
        return (properties and BluetoothGattCharacteristic.PROPERTY_WRITE) != 0 ||
                (properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0
    }

    @SuppressLint("MissingPermission")
    private fun enableNotifications(gatt: BluetoothGatt?, service: BluetoothGattService) {
        // Find a notify characteristic
        for (char in service.characteristics) {
            if (char.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) {
                notifyCharacteristic = char
                try {
                    gatt?.setCharacteristicNotification(char, true)
                    // Write CCC descriptor
                    val descriptor = char.getDescriptor(CCC_DESCRIPTOR_UUID)
                    if (descriptor != null) {
                        descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        gatt.writeDescriptor(descriptor)
                    }
                } catch (e: SecurityException) {
                    Log.w(TAG, "Permission error enabling notifications", e)
                }
                return
            }
        }
    }

    private fun characteristicPropertiesToString(properties: Int): String {
        val props = mutableListOf<String>()
        if (properties and BluetoothGattCharacteristic.PROPERTY_READ != 0) props.add("READ")
        if (properties and BluetoothGattCharacteristic.PROPERTY_WRITE != 0) props.add("WRITE")
        if (properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0) props.add("WRITE_NO_RESP")
        if (properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) props.add("NOTIFY")
        if (properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0) props.add("INDICATE")
        if (properties and BluetoothGattCharacteristic.PROPERTY_BROADCAST != 0) props.add("BROADCAST")
        return props.joinToString("|")
    }

    private fun decodePrinterStatus(data: ByteArray): String {
        return if (data.isNotEmpty()) {
            "0x${data.joinToString(" ") { "%02X".format(it) }}"
        } else {
            "empty"
        }
    }

    // ---- Data Transfer ----

    /**
     * Send raw bytes to the connected BLE printer.
     * @param data The bytes to send
     * @return true if enqueued successfully
     */
    fun sendData(data: ByteArray): Boolean {
        val char = writeCharacteristic
        val gatt = bluetoothGatt
        if (char == null || gatt == null || !isConnectedFlag.get()) {
            Log.e(TAG, "Not connected, cannot send data")
            return false
        }

        return try {
            // BLE has MTU limitations, chunk the data
            val mtu = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                gatt.mtu - 3 // 3 bytes for ATT header
            } else {
                20 // default MTU
            }

            val chunkSize = maxOf(mtu, 20)
            var offset = 0
            var allSuccess = true

            while (offset < data.size) {
                val end = minOf(offset + chunkSize, data.size)
                val chunk = data.copyOfRange(offset, end)

                char.value = chunk
                val writeType = if (char.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0) {
                    BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                } else {
                    BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                }
                char.writeType = writeType

                val success = try {
                    @SuppressLint("MissingPermission")
                    gatt.writeCharacteristic(char)
                } catch (e: SecurityException) {
                    Log.e(TAG, "Permission error writing characteristic", e)
                    false
                }

                if (!success) {
                    Log.e(TAG, "Failed to write chunk at offset $offset")
                    allSuccess = false
                    break
                }

                offset = end

                // Small delay between writes to avoid overwhelming the GATT stack
                if (offset < data.size) {
                    Thread.sleep(20)
                }
            }

            Log.d(TAG, "Sent ${data.size} bytes via BLE in $offset/chunkSize chunks, success=$allSuccess")
            allSuccess
        } catch (e: Exception) {
            Log.e(TAG, "Error sending data via BLE", e)
            handleUnexpectedDisconnect()
            false
        }
    }

    // ---- GATT Operation Queue ----

    private fun processNextGattOperation() {
        if (gattOperationQueue.isEmpty()) {
            isGattOperationInProgress = false
            return
        }
        val operation = gattOperationQueue.removeFirstOrNull() ?: return
        try {
            operation()
        } catch (e: Exception) {
            Log.e(TAG, "GATT operation error", e)
            processNextGattOperation()
        }
    }

    private fun queueGattOperation(operation: () -> Boolean) {
        gattOperationQueue.add(operation)
        if (!isGattOperationInProgress) {
            isGattOperationInProgress = true
            processNextGattOperation()
        }
    }

    // ---- State Queries ----

    fun isConnected(): Boolean = isConnectedFlag.get()

    fun getConnectionState(): String = connectionState

    // ---- State Management ----

    @Synchronized
    private fun setConnectionState(state: String) {
        val oldState = connectionState
        connectionState = state
        if (oldState != state) {
            Log.d(TAG, "Connection state: $oldState -> $state")
            try {
                onConnectionStateChanged(state)
            } catch (e: Exception) {
                Log.w(TAG, "Error in connection state callback", e)
            }
        }
    }

    // ---- Configuration ----

    /**
     * Set a target service UUID for the printer service.
     */
    fun setTargetServiceUuid(uuidString: String?) {
        targetServiceUuid = try {
            uuidString?.let { UUID.fromString(it) }
        } catch (e: IllegalArgumentException) {
            Log.e(TAG, "Invalid service UUID: $uuidString", e)
            null
        }
    }

    fun setDeviceDiscoveryListener(listener: ((List<Map<String, Any>>) -> Unit)?) {
        deviceDiscoveryListener = listener
    }

    fun setActivity(activity: Activity?) {
        this.activity = activity
    }

    // ---- Cleanup ----

    fun cleanup() {
        autoReconnectEnabled = false
        reconnectHandler.removeCallbacksAndMessages(null)
        gattOperationQueue.clear()
        disconnect()
    }
}
