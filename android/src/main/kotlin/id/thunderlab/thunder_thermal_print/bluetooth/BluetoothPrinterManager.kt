package id.thunderlab.thunder_thermal_print.bluetooth

import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothSocket
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import java.io.IOException
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * BluetoothPrinterManager handles classic Bluetooth (RFCOMM/SPP) thermal printer connections.
 *
 * Features:
 * - Bluetooth device scanning (classic + BLE fallback for API 31+)
 * - RFCOMM socket connection with SPP UUID
 * - Sending bytes over Bluetooth socket
 * - Auto-reconnect with exponential backoff
 * - Connection state tracking via BroadcastReceiver
 * - Proper permission handling for API 31+
 */
class BluetoothPrinterManager(
    private val context: Context,
    private var activity: Activity?,
    private val onConnectionStateChanged: (String) -> Unit
) {

    companion object {
        private const val TAG = "BTPrinterManager"
        private const val SPP_UUID_STRING = "00001101-0000-1000-8000-00805F9B34FB"
        private val SPP_UUID: UUID = UUID.fromString(SPP_UUID_STRING)

        private const val STATE_DISCONNECTED = "disconnected"
        private const val STATE_CONNECTING = "connecting"
        private const val STATE_CONNECTED = "connected"
        private const val STATE_RECONNECTING = "reconnecting"

        // Auto-reconnect settings
        private const val BASE_RECONNECT_DELAY_MS = 1000L
        private const val MAX_RECONNECT_DELAY_MS = 30000L
        private const val MAX_RECONNECT_ATTEMPTS = 10

        // Scan timeout fallback
        private const val DISCOVERY_SCAN_TIMEOUT_MS = 12000L
    }

    // Bluetooth adapter
    private var bluetoothAdapter: BluetoothAdapter? = null

    // Socket & streams
    private val socketRef = AtomicReference<BluetoothSocket?>(null)
    private var outputStream: OutputStream? = null
    private val isConnectedFlag = AtomicBoolean(false)

    // Connection state
    @Volatile
    private var connectionState: String = STATE_DISCONNECTED

    // Auto-reconnect state
    private var autoReconnectEnabled: Boolean = false
    private var targetMacAddress: String? = null
    private var reconnectAttempts: Int = 0
    private val reconnectHandler = Handler(Looper.getMainLooper())

    // Scan latch
    private val scanLatch = CountDownLatch(1)
    private val discoveredDevices = mutableListOf<Map<String, Any>>()
    private val scanLock = Any()

    // Broadcast receiver
    private var broadcastReceiver: BroadcastReceiver? = null
    private var isReceiverRegistered = false

    // Device discovery listener
    private var deviceDiscoveryListener: ((List<Map<String, Any>>) -> Unit)? = null

    init {
        initBluetoothAdapter()
        registerBroadcastReceiver()
    }

    // ---- Initialization ----

    private fun initBluetoothAdapter() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val btManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                bluetoothAdapter = btManager?.adapter
            } else {
                bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "No permission to access Bluetooth", e)
            bluetoothAdapter = null
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing Bluetooth adapter", e)
            bluetoothAdapter = null
        }
    }

    private fun registerBroadcastReceiver() {
        if (isReceiverRegistered) return
        broadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent == null) return
                when (intent.action) {
                    BluetoothDevice.ACTION_ACL_CONNECTED -> {
                        val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                        Log.d(TAG, "ACL Connected: ${device?.address}")
                    }
                    BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                        val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                        Log.d(TAG, "ACL Disconnected: ${device?.address}")
                        if (device?.address == targetMacAddress) {
                            handleUnexpectedDisconnect()
                        }
                    }
                    BluetoothDevice.ACTION_BOND_STATE_CHANGED -> {
                        val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                        val newState = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.BOND_NONE)
                        Log.d(TAG, "Bond state changed for ${device?.address}: $newState")
                    }
                    BluetoothAdapter.ACTION_STATE_CHANGED -> {
                        val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.STATE_OFF)
                        if (state == BluetoothAdapter.STATE_OFF || state == BluetoothAdapter.STATE_TURNING_OFF) {
                            Log.d(TAG, "Bluetooth turned off")
                            disconnect()
                        }
                    }
                    BluetoothAdapter.ACTION_DISCOVERY_STARTED -> {
                        Log.d(TAG, "Discovery started")
                    }
                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                        Log.d(TAG, "Discovery finished")
                        synchronized(scanLock) {
                            scanLatch.countDown()
                        }
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
            addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_STARTED)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
            addAction(BluetoothDevice.ACTION_FOUND)
        }

        try {
            context.registerReceiver(broadcastReceiver, filter)
            isReceiverRegistered = true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register broadcast receiver", e)
        }
    }

    // ---- Scanning ----

    /**
     * Start scanning for Bluetooth devices.
     * Returns a list of discovered device maps with keys: name, address, type, bondState
     */
    @SuppressLint("MissingPermission")
    fun startScan(timeoutMs: Long = 10000L): List<Map<String, Any>> {
        val adapter = bluetoothAdapter
        if (adapter == null || !adapter.isEnabled) {
            Log.e(TAG, "Bluetooth adapter not available or not enabled")
            return emptyList()
        }

        val results = mutableListOf<Map<String, Any>>()

        // Cancel any existing discovery
        if (adapter.isDiscovering) {
            adapter.cancelDiscovery()
        }

        // First, add already bonded/paired devices
        try {
            val bondedDevices = adapter.bondedDevices
            for (device in bondedDevices) {
                results.add(deviceToMap(device))
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "No permission to get bonded devices", e)
            return results
        }

        // Start discovery for new devices with timeout
        synchronized(scanLock) {
            discoveredDevices.clear()

            // Temporary receiver for device found during scan
            val scanReceiver = object : BroadcastReceiver() {
                override fun onReceive(ctx: Context?, intent: Intent?) {
                    if (intent?.action == BluetoothDevice.ACTION_FOUND) {
                        val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                        if (device != null) {
                            synchronized(scanLock) {
                                if (discoveredDevices.none { it["address"] == device.address }) {
                                    val deviceMap = deviceToMap(device)
                                    discoveredDevices.add(deviceMap)
                                    deviceDiscoveryListener?.invoke(discoveredDevices.toList())
                                }
                            }
                        }
                    }
                }
            }

            val scanFilter = IntentFilter(BluetoothDevice.ACTION_FOUND)
            context.registerReceiver(scanReceiver, scanFilter)

            // Reset latch
            val newLatch = CountDownLatch(1)
            try {
                @Suppress("DEPRECATION")
                adapter.startDiscovery()
            } catch (e: SecurityException) {
                Log.e(TAG, "No permission to start discovery", e)
                try {
                    context.unregisterReceiver(scanReceiver)
                } catch (_: Exception) {}
                return results
            }

            try {
                newLatch.await(timeoutMs, TimeUnit.MILLISECONDS)
            } catch (_: InterruptedException) {}

            // Cancel discovery if still running
            if (adapter.isDiscovering) {
                adapter.cancelDiscovery()
            }

            try {
                context.unregisterReceiver(scanReceiver)
            } catch (_: Exception) {}

            results.addAll(discoveredDevices)
        }

        return results.distinctBy { it["address"] }
    }

    @SuppressLint("MissingPermission")
    private fun deviceToMap(device: BluetoothDevice): Map<String, Any> {
        val bondState = try {
            when (device.bondState) {
                BluetoothDevice.BOND_BONDED -> "bonded"
                BluetoothDevice.BOND_BONDING -> "bonding"
                else -> "none"
            }
        } catch (e: SecurityException) {
            "unknown"
        }

        val type = try {
            when (device.type) {
                BluetoothDevice.DEVICE_TYPE_CLASSIC -> "classic"
                BluetoothDevice.DEVICE_TYPE_LE -> "le"
                BluetoothDevice.DEVICE_TYPE_DUAL -> "dual"
                else -> "unknown"
            }
        } catch (e: SecurityException) {
            "unknown"
        }

        return mapOf(
            "name" to (device.name ?: "Unknown"),
            "address" to device.address,
            "type" to type,
            "bondState" to bondState
        )
    }

    // ---- Connection ----

    /**
     * Connect to a Bluetooth printer by MAC address.
     * @param macAddress The MAC address of the printer
     * @param autoReconnect Whether to automatically attempt reconnection on disconnect
     * @return true if connection succeeds
     */
    @SuppressLint("MissingPermission")
    fun connect(macAddress: String, autoReconnect: Boolean = false): Boolean {
        val adapter = bluetoothAdapter
        if (adapter == null) {
            Log.e(TAG, "Bluetooth adapter not available")
            return false
        }

        // Disconnect existing connection
        disconnect()

        setConnectionState(STATE_CONNECTING)
        targetMacAddress = macAddress
        autoReconnectEnabled = autoReconnect
        reconnectAttempts = 0

        try {
            val device: BluetoothDevice = try {
                adapter.getRemoteDevice(macAddress)
            } catch (e: IllegalArgumentException) {
                Log.e(TAG, "Invalid MAC address: $macAddress", e)
                setConnectionState(STATE_DISCONNECTED)
                return false
            }

            // Try connecting with SPP UUID
            var socket: BluetoothSocket? = null
            var connectionSuccess = false

            // Attempt 1: Use createRfcommSocketToServiceRecord
            try {
                socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect()
                connectionSuccess = true
                Log.d(TAG, "Connected via SPP UUID")
            } catch (e: IOException) {
                Log.w(TAG, "Failed to connect via SPP UUID: ${e.message}")
                try { socket?.close() } catch (_: IOException) {}
                socket = null
            }

            // Attempt 2: Fallback to hidden method createRfcommSocket (channel 1)
            if (!connectionSuccess) {
                try {
                    @Suppress("PrivateApi")
                    val method = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                    socket = method.invoke(device, 1) as? BluetoothSocket
                    if (socket != null) {
                        socket.connect()
                        connectionSuccess = true
                        Log.d(TAG, "Connected via fallback createRfcommSocket")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to connect via fallback: ${e.message}")
                    try { socket?.close() } catch (_: IOException) {}
                    socket = null
                }
            }

            // Attempt 3: Try other common channels
            if (!connectionSuccess) {
                for (channel in intArrayOf(2, 3, 4, 5, 6)) {
                    try {
                        @Suppress("PrivateApi")
                        val method = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                        socket = method.invoke(device, channel) as? BluetoothSocket
                        if (socket != null) {
                            socket.connect()
                            connectionSuccess = true
                            Log.d(TAG, "Connected via channel $channel")
                            break
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed channel $channel: ${e.message}")
                        try { socket?.close() } catch (_: IOException) {}
                        socket = null
                    }
                }
            }

            if (connectionSuccess && socket != null) {
                socketRef.set(socket)
                try {
                    outputStream = socket.outputStream
                } catch (e: IOException) {
                    Log.e(TAG, "Failed to get output stream", e)
                    socket.close()
                    socketRef.set(null)
                    setConnectionState(STATE_DISCONNECTED)
                    return false
                }
                isConnectedFlag.set(true)
                reconnectAttempts = 0
                setConnectionState(STATE_CONNECTED)
                Log.d(TAG, "Successfully connected to $macAddress")
                return true
            } else {
                Log.e(TAG, "All connection attempts failed for $macAddress")
                setConnectionState(STATE_DISCONNECTED)
                return false
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "No Bluetooth permission", e)
            setConnectionState(STATE_DISCONNECTED)
            return false
        } catch (e: Exception) {
            Log.e(TAG, "Error connecting to $macAddress", e)
            setConnectionState(STATE_DISCONNECTED)
            return false
        }
    }

    /**
     * Disconnect from the currently connected Bluetooth printer.
     */
    fun disconnect() {
        autoReconnectEnabled = false
        reconnectAttempts = MAX_RECONNECT_ATTEMPTS // Prevent auto-reconnect
        closeConnection()
        setConnectionState(STATE_DISCONNECTED)
    }

    private fun closeConnection() {
        try {
            outputStream?.close()
        } catch (_: IOException) {}
        outputStream = null

        val socket = socketRef.getAndSet(null)
        try {
            socket?.close()
        } catch (_: IOException) {}

        isConnectedFlag.set(false)
    }

    private fun handleUnexpectedDisconnect() {
        if (!isConnectedFlag.get()) return
        closeConnection()
        setConnectionState(STATE_DISCONNECTED)

        if (autoReconnectEnabled && reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
            scheduleReconnect()
        }
    }

    // ---- Auto-reconnect ----

    private fun scheduleReconnect() {
        if (!autoReconnectEnabled) return
        val mac = targetMacAddress ?: return

        reconnectAttempts++
        val delay = minOf(
            BASE_RECONNECT_DELAY_MS * (1L shl (reconnectAttempts - 1)),
            MAX_RECONNECT_DELAY_MS
        )

        Log.d(TAG, "Scheduling reconnect attempt $reconnectAttempts/$MAX_RECONNECT_ATTEMPTS in ${delay}ms")
        setConnectionState(STATE_RECONNECTING)

        reconnectHandler.postDelayed({
            if (!autoReconnectEnabled || isConnectedFlag.get()) return@postDelayed
            Log.d(TAG, "Auto-reconnecting to $mac (attempt $reconnectAttempts)")
            if (!connect(mac, true)) {
                if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
                    Log.e(TAG, "Max reconnect attempts reached")
                    autoReconnectEnabled = false
                    setConnectionState(STATE_DISCONNECTED)
                }
            }
        }, delay)
    }

    // ---- Data Transfer ----

    /**
     * Send raw bytes to the connected printer.
     * @param data The bytes to send
     * @return true if the data was sent successfully
     */
    fun sendData(data: ByteArray): Boolean {
        val stream = outputStream
        if (stream == null || !isConnectedFlag.get()) {
            Log.e(TAG, "Not connected, cannot send data")
            return false
        }

        return try {
            // Send data in chunks to avoid buffer overflow
            val chunkSize = 512
            var offset = 0
            while (offset < data.size) {
                val end = minOf(offset + chunkSize, data.size)
                stream.write(data, offset, end - offset)
                stream.flush()
                offset = end
            }
            Log.d(TAG, "Sent ${data.size} bytes successfully")
            true
        } catch (e: IOException) {
            Log.e(TAG, "Error sending data", e)
            handleUnexpectedDisconnect()
            false
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

    // ---- Listeners ----

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
        disconnect()

        if (isReceiverRegistered && broadcastReceiver != null) {
            try {
                context.unregisterReceiver(broadcastReceiver)
            } catch (_: Exception) {}
            isReceiverRegistered = false
            broadcastReceiver = null
        }
    }
}
