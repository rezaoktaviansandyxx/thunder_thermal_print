package id.thunderlab.thunder_thermal_print.usb

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

/**
 * UsbPrinterManager handles USB thermal printer connections.
 *
 * Features:
 * - USB device enumeration via UsbManager
 * - USB connection with permission handling
 * - Bulk transfer for sending print data
 * - USB hot-plug detection via BroadcastReceiver
 * - Auto-reconnect when a previously connected USB device is re-attached
 * - Interface and endpoint detection (bulk OUT endpoint)
 */
class UsbPrinterManager(
    private val context: Context,
    private var activity: Activity?,
    private val onConnectionStateChanged: (String) -> Unit
) {

    companion object {
        private const val TAG = "USBPrinterManager"
        private const val ACTION_USB_PERMISSION = "id.thunderlab.thunder_thermal_print.USB_PERMISSION"

        // Connection states
        private const val STATE_DISCONNECTED = "disconnected"
        private const val STATE_CONNECTING = "connecting"
        private const val STATE_CONNECTED = "connected"
        private const val STATE_NO_PERMISSION = "no_permission"
        private const val STATE_RECONNECTING = "reconnecting"

        // Auto-reconnect settings
        private const val BASE_RECONNECT_DELAY_MS = 1000L
        private const val MAX_RECONNECT_DELAY_MS = 10000L
        private const val MAX_RECONNECT_ATTEMPTS = 5

        // USB transfer timeout
        private const val USB_TIMEOUT_MS = 5000

        // Known thermal printer vendor/product IDs (common brands)
        private val KNOWN_PRINTER_VENDORS = setOf(
            0x04b8, // EPSON
            0x0483, // STMicroelectronics (many Chinese printers)
            0x1a86, // QinHeng
            0x0525, // Netchip
            0x1532, // Razer (some repurposed)
            0x0fe6, // POS58/80 series
            0x04e8, // Samsung
            0x145f  // ?
        )
    }

    private var usbManager: UsbManager? = null

    // Connection state
    private var usbConnection: UsbDeviceConnection? = null
    private var usbDevice: UsbDevice? = null
    private var usbInterface: UsbInterface? = null
    private var bulkOutEndpoint: UsbEndpoint? = null
    private var bulkInEndpoint: UsbEndpoint? = null
    private val isConnectedFlag = AtomicBoolean(false)
    @Volatile
    private var connectionState: String = STATE_DISCONNECTED

    // Auto-reconnect state
    private var autoReconnectEnabled: Boolean = false
    private var targetVendorId: Int = -1
    private var targetProductId: Int = -1
    private var reconnectAttempts: Int = 0
    private val reconnectHandler = Handler(Looper.getMainLooper())

    // Permission handling
    private var permissionRequestCode = 0
    private val pendingPermissionResults = mutableMapOf<Int, ((Boolean) -> Unit)>()

    // Broadcast receiver
    private var broadcastReceiver: BroadcastReceiver? = null
    private var isReceiverRegistered = false

    // Device discovery listener
    private var deviceDiscoveryListener: ((List<Map<String, Any>>) -> Unit)? = null

    init {
        usbManager = context.getSystemService(Context.USB_SERVICE) as? UsbManager
        registerBroadcastReceiver()
    }

    // ---- Broadcast Receiver ----

    private fun registerBroadcastReceiver() {
        if (isReceiverRegistered) return

        broadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent == null) return
                when (intent.action) {
                    UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                        val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                        Log.d(TAG, "USB device attached: ${device?.deviceName}")
                        if (device != null && device.vendorId == targetVendorId && device.productId == targetProductId) {
                            if (autoReconnectEnabled && !isConnectedFlag.get()) {
                                Log.d(TAG, "Target USB printer re-attached, attempting reconnect")
                                reconnectHandler.post {
                                    connect(targetVendorId, targetProductId, true)
                                }
                            }
                        }
                        deviceDiscoveryListener?.invoke(scanDevices())
                    }
                    UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                        val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                        Log.d(TAG, "USB device detached: ${device?.deviceName}")
                        if (device == usbDevice) {
                            handleUnexpectedDisconnect()
                        }
                    }
                    ACTION_USB_PERMISSION -> {
                        val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                        val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                        Log.d(TAG, "USB permission for ${device?.deviceName}: granted=$granted")
                        val requestCode = intent.getIntExtra("requestCode", 0)
                        pendingPermissionResults[requestCode]?.invoke(granted)
                        pendingPermissionResults.remove(requestCode)
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
            addAction(ACTION_USB_PERMISSION)
        }

        try {
            context.registerReceiver(broadcastReceiver, filter)
            isReceiverRegistered = true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register USB broadcast receiver", e)
        }
    }

    // ---- Scanning ----

    /**
     * Enumerate connected USB devices.
     * @return List of device maps: name, vendorId, productId, deviceId, interfaceCount
     */
    fun scanDevices(): List<Map<String, Any>> {
        val manager = usbManager ?: return emptyList()

        try {
            val deviceList = manager.deviceList
        return deviceList.values.map { device ->
            mapOf(
                "name" to (device.deviceName ?: "Unknown USB"),
                "vendorId" to device.vendorId,
                "productId" to device.productId,
                "deviceId" to device.deviceId,
                "interfaceCount" to device.interfaceCount,
                "isPrinter" to isLikelyPrinter(device),
                "vendorIdHex" to String.format("0x%04X", device.vendorId),
                "productIdHex" to String.format("0x%04X", device.productId),
                "hasPermission" to (manager?.hasPermission(device) ?: false)
            )
        }.sortedByDescending { it["isPrinter"] as? Boolean }
        } catch (e: Exception) {
            Log.e(TAG, "Error scanning USB devices", e)
            return emptyList()
        }
    }

    /**
     * Heuristic check if a USB device is likely a thermal printer.
     */
    private fun isLikelyPrinter(device: UsbDevice): Boolean {
        // Check known vendor IDs
        if (KNOWN_PRINTER_VENDORS.contains(device.vendorId)) return true

        // Check for a bulk OUT interface (common in printers)
        for (i in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(i)
            if (usbInterface.interfaceClass == UsbConstants.USB_CLASS_PRINTER ||
                usbInterface.interfaceClass == UsbConstants.USB_CLASS_VENDOR_SPEC) {
                // Check for bulk OUT endpoint
                for (j in 0 until usbInterface.endpointCount) {
                    val endpoint = usbInterface.getEndpoint(j)
                    if (endpoint.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                        endpoint.direction == UsbConstants.USB_DIR_OUT) {
                        return true
                    }
                }
            }
        }
        return false
    }

    // ---- Connection ----

    /**
     * Connect to a USB device by vendor and product ID.
     * @param vendorId The USB vendor ID
     * @param productId The USB product ID
     * @param autoReconnect Whether to auto-reconnect on detach/reattach
     * @return true if connection succeeds
     */
    fun connect(vendorId: Int, productId: Int, autoReconnect: Boolean = false): Boolean {
        val manager = usbManager
        if (manager == null) {
            Log.e(TAG, "USB manager not available")
            return false
        }

        // Disconnect existing
        disconnect()

        setConnectionState(STATE_CONNECTING)
        targetVendorId = vendorId
        targetProductId = productId
        autoReconnectEnabled = autoReconnect
        reconnectAttempts = 0

        try {
            // Find the device
            val device = manager.deviceList.values.find {
                it.vendorId == vendorId && it.productId == productId
            }

            if (device == null) {
                Log.e(TAG, "USB device not found: vendor=0x${vendorId.toString(16)}, product=0x${productId.toString(16)}")
                setConnectionState(STATE_DISCONNECTED)
                return false
            }

            // Check permission
            if (!manager.hasPermission(device)) {
                Log.d(TAG, "Requesting USB permission for ${device.deviceName}")
                return requestUsbPermission(device, manager)
            }

            // Establish connection
            return establishConnection(device, manager)
        } catch (e: Exception) {
            Log.e(TAG, "Error connecting to USB device", e)
            setConnectionState(STATE_DISCONNECTED)
            return false
        }
    }

    /**
     * Request USB permission and attempt connection on grant.
     */
    private fun requestUsbPermission(device: UsbDevice, manager: UsbManager): Boolean {
        val act = activity
        if (act == null) {
            Log.e(TAG, "No activity for USB permission request")
            setConnectionState(STATE_NO_PERMISSION)
            return false
        }

        setConnectionState(STATE_NO_PERMISSION)

        val granted = requestPermissionInternal(device, manager)

        if (granted) {
            Log.d(TAG, "USB permission granted, establishing connection")
            return establishConnection(device, manager)
        } else {
            Log.e(TAG, "USB permission denied")
            setConnectionState(STATE_NO_PERMISSION)
            return false
        }
    }

    /**
     * Request USB permission only (without connecting).
     * @param vendorId Target USB vendor ID
     * @param productId Target USB product ID
     * @return true if permission was granted
     */
    fun requestPermissionOnly(vendorId: Int, productId: Int): Boolean {
        val manager = usbManager
        if (manager == null) {
            Log.e(TAG, "USB manager not available")
            return false
        }

        val device = manager.deviceList.values.find {
            it.vendorId == vendorId && it.productId == productId
        }

        if (device == null) {
            Log.e(TAG, "USB device not found: vendor=0x${vendorId.toString(16)}, product=0x${productId.toString(16)}")
            return false
        }

        if (manager.hasPermission(device)) {
            Log.d(TAG, "USB permission already granted for ${device.deviceName}")
            return true
        }

        return requestPermissionInternal(device, manager)
    }

    /**
     * Internal permission request without connection logic.
     */
    private fun requestPermissionInternal(device: UsbDevice, manager: UsbManager): Boolean {
        val act = activity
        if (act == null) {
            Log.e(TAG, "No activity for USB permission request")
            return false
        }

        permissionRequestCode++
        val requestCode = permissionRequestCode

        val pendingResult = java.util.concurrent.CountDownLatch(1)
        var granted = false

        pendingPermissionResults[requestCode] = { g ->
            granted = g
            pendingResult.countDown()
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE
        } else {
            0
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            Intent(ACTION_USB_PERMISSION).apply { putExtra("requestCode", requestCode) },
            flags
        )

        manager.requestPermission(device, pendingIntent)

        // Wait for permission result (with timeout)
        try {
            pendingResult.await(30, java.util.concurrent.TimeUnit.SECONDS)
        } catch (_: InterruptedException) {}

        return granted
    }

    /**
     * Establish the actual USB connection, claim interface, and find endpoints.
     */
    private fun establishConnection(device: UsbDevice, manager: UsbManager): Boolean {
        try {
            val connection = manager.openDevice(device)
            if (connection == null) {
                Log.e(TAG, "Failed to open USB device ${device.deviceName}")
                setConnectionState(STATE_DISCONNECTED)
                return false
            }

            // Find a suitable interface with a bulk OUT endpoint
            val interfaceInfo = findSuitableInterface(device)
            if (interfaceInfo == null) {
                Log.e(TAG, "No suitable interface found on device ${device.deviceName}")
                connection.close()
                setConnectionState(STATE_DISCONNECTED)
                return false
            }

            val (usbInterface, bulkOut, bulkIn) = interfaceInfo

            // Claim the interface
            val claimed = connection.claimInterface(usbInterface, true)
            if (!claimed) {
                Log.e(TAG, "Failed to claim USB interface ${usbInterface.interfaceClass}")
                connection.close()
                setConnectionState(STATE_DISCONNECTED)
                return false
            }

            usbConnection = connection
            usbDevice = device
            this.usbInterface = usbInterface
            bulkOutEndpoint = bulkOut
            bulkInEndpoint = bulkIn
            isConnectedFlag.set(true)
            reconnectAttempts = 0
            setConnectionState(STATE_CONNECTED)

            Log.d(TAG, "USB connected to ${device.deviceName}, interface=${usbInterface.interfaceClass}, " +
                    "endpoint count=${usbInterface.endpointCount}")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error establishing USB connection", e)
            setConnectionState(STATE_DISCONNECTED)
            return false
        }
    }

    /**
     * Find a suitable USB interface with bulk OUT endpoint for printing.
     * Preference order:
     * 1. USB_CLASS_PRINTER with bulk OUT
     * 2. USB_CLASS_VENDOR_SPEC with bulk OUT
     * 3. Any interface with bulk OUT
     */
    private fun findSuitableInterface(device: UsbDevice): Triple<UsbInterface, UsbEndpoint, UsbEndpoint?>? {
        // First pass: look for printer class
        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            if (iface.interfaceClass == UsbConstants.USB_CLASS_PRINTER) {
                val endpoints = findEndpoints(iface)
                if (endpoints != null) return endpoints
            }
        }

        // Second pass: look for vendor specific
        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            if (iface.interfaceClass == UsbConstants.USB_CLASS_VENDOR_SPEC) {
                val endpoints = findEndpoints(iface)
                if (endpoints != null) return endpoints
            }
        }

        // Third pass: any interface with bulk OUT
        for (i in 0 until device.interfaceCount) {
            val iface = device.getInterface(i)
            val endpoints = findEndpoints(iface)
            if (endpoints != null) return endpoints
        }

        return null
    }

    /**
     * Find bulk OUT (and optionally bulk IN) endpoints on a given interface.
     */
    private fun findEndpoints(iface: UsbInterface): Triple<UsbInterface, UsbEndpoint, UsbEndpoint?>? {
        var bulkOut: UsbEndpoint? = null
        var bulkIn: UsbEndpoint? = null

        for (j in 0 until iface.endpointCount) {
            val endpoint = iface.getEndpoint(j)
            when {
                endpoint.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                        endpoint.direction == UsbConstants.USB_DIR_OUT -> {
                    bulkOut = endpoint
                }
                endpoint.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                        endpoint.direction == UsbConstants.USB_DIR_IN -> {
                    bulkIn = endpoint
                }
            }
        }

        return if (bulkOut != null) {
            Triple(iface, bulkOut, bulkIn)
        } else {
            null
        }
    }

    /**
     * Disconnect from the USB printer.
     */
    fun disconnect() {
        autoReconnectEnabled = false
        reconnectAttempts = MAX_RECONNECT_ATTEMPTS
        closeConnection()
        setConnectionState(STATE_DISCONNECTED)
    }

    private fun closeConnection() {
        try {
            usbConnection?.releaseInterface(usbInterface)
        } catch (_: Exception) {}

        try {
            usbConnection?.close()
        } catch (_: Exception) {}

        usbConnection = null
        usbDevice = null
        usbInterface = null
        bulkOutEndpoint = null
        bulkInEndpoint = null
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

        reconnectAttempts++
        val delay = minOf(
            BASE_RECONNECT_DELAY_MS * (1L shl (reconnectAttempts - 1)),
            MAX_RECONNECT_DELAY_MS
        )

        Log.d(TAG, "Scheduling USB reconnect attempt $reconnectAttempts in ${delay}ms")
        setConnectionState(STATE_RECONNECTING)

        reconnectHandler.postDelayed({
            if (!autoReconnectEnabled || isConnectedFlag.get()) return@postDelayed
            Log.d(TAG, "Attempting USB reconnect $reconnectAttempts")
            if (!connect(targetVendorId, targetProductId, true)) {
                if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
                    Log.e(TAG, "Max USB reconnect attempts reached")
                    autoReconnectEnabled = false
                    setConnectionState(STATE_DISCONNECTED)
                }
            }
        }, delay)
    }

    // ---- Data Transfer ----

    /**
     * Send raw bytes to the connected USB printer.
     * @param data The bytes to send
     * @return true if all data was sent successfully
     */
    fun sendData(data: ByteArray): Boolean {
        // If not connected but auto-reconnect is enabled, attempt a quick reconnect
        if (!isConnectedFlag.get()) {
            if (autoReconnectEnabled && targetVendorId != -1 && targetProductId != -1) {
                Log.d(TAG, "Connection lost, attempting reconnect before sendData")
                val reconnected = connect(targetVendorId, targetProductId, true)
                if (!reconnected) {
                    Log.e(TAG, "Reconnect failed, cannot send USB data")
                    return false
                }
            } else {
                Log.e(TAG, "Not connected, cannot send USB data")
                return false
            }
        }

        val connection = usbConnection
        val endpoint = bulkOutEndpoint
        if (connection == null || endpoint == null || !isConnectedFlag.get()) {
            Log.e(TAG, "Not connected, cannot send USB data")
            return false
        }

        return try {
            val maxPacketSize = endpoint.maxPacketSize
            var offset = 0
            var allSuccess = true

            while (offset < data.size) {
                val length = minOf(maxPacketSize, data.size - offset)
                val transferred = connection.bulkTransfer(
                    endpoint,
                    data,
                    offset,
                    length,
                    USB_TIMEOUT_MS
                )

                if (transferred < 0) {
                    Log.e(TAG, "USB bulk transfer failed at offset $offset")
                    allSuccess = false
                    break
                }

                offset += transferred
            }

            Log.d(TAG, "Sent $offset/${data.size} bytes via USB")
            allSuccess
        } catch (e: Exception) {
            Log.e(TAG, "Error sending USB data", e)
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
