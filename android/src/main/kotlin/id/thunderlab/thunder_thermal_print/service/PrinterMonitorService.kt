package id.thunderlab.thunder_thermal_print.service

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbManager
import android.net.ConnectivityManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log

/**
 * PrinterMonitorService is a background service that monitors printer connections
 * across all transport types (Bluetooth, BLE, USB, Network) and triggers auto-reconnect
 * when needed.
 *
 * Responsibilities:
 * - Monitor Bluetooth connection state changes
 * - Monitor USB hot-plug events (attach/detach)
 * - Monitor network connectivity changes
 * - Periodically check connection health
 * - Trigger auto-reconnect when a connection is lost
 * - Broadcast connection state changes to the plugin's EventChannel
 * - Run as a foreground service with a persistent notification
 */
class PrinterMonitorService : Service() {

    companion object {
        private const val TAG = "PrinterMonitorService"

        // Notification
        private const val NOTIFICATION_CHANNEL_ID = "thunder_thermal_print_monitor"
        private const val NOTIFICATION_CHANNEL_NAME = "Printer Monitor"
        private const val NOTIFICATION_ID = 1001

        // Status check interval
        private const val STATUS_CHECK_INTERVAL_MS = 30000L // 30 seconds

        // Reconnect delay after detection
        private const val RECONNECT_DELAY_MS = 2000L

        // Intent extras
        const val EXTRA_AUTO_RECONNECT = "auto_reconnect"
        const val EXTRA_TRANSPORT_TYPE = "transport_type"
        const val EXTRA_TARGET_ADDRESS = "target_address"
        const val EXTRA_TARGET_PORT = "target_port"
        const val EXTRA_VENDOR_ID = "vendor_id"
        const val EXTRA_PRODUCT_ID = "product_id"

        // Broadcast actions for plugin communication
        const val ACTION_CONNECTION_STATE_CHANGED = "id.thunderlab.thunder_thermal_print.CONNECTION_STATE"
        const val EXTRA_STATE_TRANSPORT = "transport"
        const val EXTRA_STATE_VALUE = "state"

        // Singleton reference for plugin access
        @Volatile
        var instance: PrinterMonitorService? = null
            private set
    }

    private var notificationManager: NotificationManager? = null
    private var connectivityManager: ConnectivityManager? = null

    // Handler for periodic tasks
    private val handler = Handler(Looper.getMainLooper())
    private var statusCheckRunnable: Runnable? = null

    // Broadcast receivers
    private var bluetoothReceiver: BroadcastReceiver? = null
    private var usbReceiver: BroadcastReceiver? = null
    private var networkReceiver: BroadcastReceiver? = null
    private var isReceiversRegistered = false

    // Connection monitoring state
    @Volatile
    private var isMonitoringBluetooth: Boolean = false
    @Volatile
    private var isMonitoringUsb: Boolean = false
    @Volatile
    private var isMonitoringNetwork: Boolean = false

    // Stored connection targets for auto-reconnect
    private var autoReconnectEnabled: Boolean = false
    private var lastBluetoothAddress: String? = null
    private var lastNetworkIp: String? = null
    private var lastNetworkPort: Int = 9100
    private var lastUsbVendorId: Int = -1
    private var lastUsbProductId: Int = -1

    // Connection state callback (set by plugin)
    var onConnectionStateChanged: ((String, String) -> Unit)? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "onCreate")
        instance = this

        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification("Monitoring printer connections"))

        registerReceivers()
        startStatusCheck()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand")

        intent?.let {
            autoReconnectEnabled = it.getBooleanExtra(EXTRA_AUTO_RECONNECT, false)
            lastBluetoothAddress = it.getStringExtra(EXTRA_TARGET_ADDRESS)
            lastNetworkIp = it.getStringExtra(EXTRA_TARGET_ADDRESS)
            lastNetworkPort = it.getIntExtra(EXTRA_TARGET_PORT, 9100)
            lastUsbVendorId = it.getIntExtra(EXTRA_VENDOR_ID, -1)
            lastUsbProductId = it.getIntExtra(EXTRA_PRODUCT_ID, -1)

            val transport = it.getStringExtra(EXTRA_TRANSPORT_TYPE)
            when (transport) {
                "bluetooth", "ble" -> {
                    isMonitoringBluetooth = true
                    updateNotification("Monitoring Bluetooth connection")
                }
                "usb" -> {
                    isMonitoringUsb = true
                    updateNotification("Monitoring USB connection")
                }
                "network" -> {
                    isMonitoringNetwork = true
                    updateNotification("Monitoring network connection")
                }
                "all" -> {
                    isMonitoringBluetooth = true
                    isMonitoringUsb = true
                    isMonitoringNetwork = true
                    updateNotification("Monitoring all connections")
                }
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        // Not a bound service
        return null
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy")
        stopStatusCheck()
        unregisterReceivers()
        instance = null
        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (_: Exception) {}
        try {
            notificationManager?.cancel(NOTIFICATION_ID)
        } catch (_: Exception) {}
        super.onDestroy()
    }

    // ---- Notification ----

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors thermal printer connections in the background"
                setShowBadge(false)
            }
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            flags
        )

        return Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Printer Monitor")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun updateNotification(text: String) {
        try {
            val notification = buildNotification(text)
            notificationManager?.notify(NOTIFICATION_ID, notification)
        } catch (_: Exception) {}
    }

    // ---- Broadcast Receivers ----

    @SuppressLint("MissingPermission")
    private fun registerReceivers() {
        if (isReceiversRegistered) return

        // Bluetooth receiver
        bluetoothReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent == null) return
                when (intent.action) {
                    BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                        val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                        val address = device?.address
                        Log.d(TAG, "Bluetooth ACL disconnected: $address")

                        if (address == lastBluetoothAddress && autoReconnectEnabled) {
                            broadcastState("bluetooth", "disconnected")
                            updateNotification("Bluetooth disconnected, will reconnect")
                            scheduleReconnectBluetooth()
                        }
                    }
                    BluetoothDevice.ACTION_ACL_CONNECTED -> {
                        val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                        val address = device?.address
                        Log.d(TAG, "Bluetooth ACL connected: $address")
                        if (address == lastBluetoothAddress) {
                            broadcastState("bluetooth", "connected")
                            updateNotification("Bluetooth connected")
                        }
                    }
                    BluetoothAdapter.ACTION_STATE_CHANGED -> {
                        val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.STATE_OFF)
                        when (state) {
                            BluetoothAdapter.STATE_ON -> {
                                Log.d(TAG, "Bluetooth turned on")
                                if (autoReconnectEnabled && lastBluetoothAddress != null) {
                                    scheduleReconnectBluetooth()
                                }
                            }
                            BluetoothAdapter.STATE_OFF -> {
                                Log.d(TAG, "Bluetooth turned off")
                                broadcastState("bluetooth", "disconnected")
                                updateNotification("Bluetooth off")
                            }
                        }
                    }
                }
            }
        }

        // USB receiver
        usbReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent == null) return
                when (intent.action) {
                    UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                        val device = intent.getParcelableExtra<android.hardware.usb.UsbDevice>(UsbManager.EXTRA_DEVICE)
                        Log.d(TAG, "USB device detached: ${device?.deviceName}")
                        broadcastState("usb", "disconnected")
                        updateNotification("USB printer disconnected")
                    }
                    UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                        val device = intent.getParcelableExtra<android.hardware.usb.UsbDevice>(UsbManager.EXTRA_DEVICE)
                        Log.d(TAG, "USB device attached: ${device?.deviceName}, vendor=${device?.vendorId}, product=${device?.productId}")
                        if (device?.vendorId == lastUsbVendorId && device.productId == lastUsbProductId && autoReconnectEnabled) {
                            broadcastState("usb", "attached")
                            updateNotification("USB printer re-attached, attempting reconnect")
                        }
                    }
                }
            }
        }

        // Network receiver
        networkReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent == null) return
                if (intent.action == ConnectivityManager.CONNECTIVITY_ACTION) {
                    @Suppress("DEPRECATION")
                    val networkInfo = intent.getParcelableExtra<android.net.NetworkInfo>(
                        ConnectivityManager.EXTRA_NETWORK_INFO
                    )
                    val connected = networkInfo?.isConnected == true
                    Log.d(TAG, "Network connectivity: $connected")

                    if (connected && autoReconnectEnabled && lastNetworkIp != null) {
                        updateNotification("Network available, checking connection")
                        scheduleReconnectNetwork()
                    } else if (!connected) {
                        broadcastState("network", "disconnected")
                        updateNotification("Network disconnected")
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            if (isMonitoringBluetooth) {
                addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
                addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
                addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            }
            if (isMonitoringUsb) {
                addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
                addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
            }
            if (isMonitoringNetwork) {
                addAction(ConnectivityManager.CONNECTIVITY_ACTION)
            }
        }

        try {
            registerReceiver(bluetoothReceiver, IntentFilter().apply {
                addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
                addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
                addAction(BluetoothAdapter.ACTION_STATE_CHANGED)
            })
            registerReceiver(usbReceiver, IntentFilter().apply {
                addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
                addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
            })
            registerReceiver(networkReceiver, IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION))
            isReceiversRegistered = true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register broadcast receivers", e)
        }
    }

    private fun unregisterReceivers() {
        if (!isReceiversRegistered) return
        try { bluetoothReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
        try { usbReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
        try { networkReceiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
        isReceiversRegistered = false
    }

    // ---- Reconnect Scheduling ----

    private fun scheduleReconnectBluetooth() {
        val address = lastBluetoothAddress ?: return
        handler.postDelayed({
            if (!autoReconnectEnabled) return@postDelayed
            broadcastState("bluetooth", "reconnecting")
            // The actual reconnect is handled by the plugin's BluetoothManager
            // This service just broadcasts the need for reconnection
            Log.d(TAG, "Triggering Bluetooth reconnect to $address")
        }, RECONNECT_DELAY_MS)
    }

    private fun scheduleReconnectNetwork() {
        val ip = lastNetworkIp ?: return
        val port = lastNetworkPort
        handler.postDelayed({
            if (!autoReconnectEnabled) return@postDelayed
            broadcastState("network", "reconnecting")
            Log.d(TAG, "Triggering network reconnect to $ip:$port")
        }, RECONNECT_DELAY_MS)
    }

    // ---- Periodic Status Check ----

    private fun startStatusCheck() {
        statusCheckRunnable = object : Runnable {
            override fun run() {
                if (!autoReconnectEnabled) {
                    handler.postDelayed(this, STATUS_CHECK_INTERVAL_MS)
                    return
                }

                Log.d(TAG, "Periodic status check")

                // Check Bluetooth adapter state
                if (isMonitoringBluetooth) {
                    try {
                        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                        val adapter = btManager?.adapter
                        if (adapter != null && adapter.isEnabled) {
                            // Bluetooth is available, could trigger a reconnect if needed
                        } else {
                            broadcastState("bluetooth", "unavailable")
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Error checking Bluetooth status", e)
                    }
                }

                // Check network connectivity
                if (isMonitoringNetwork) {
                    try {
                        val cm = connectivityManager
                        if (cm != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val network = cm.activeNetwork
                            val caps = cm.getNetworkCapabilities(network)
                            val connected = caps != null && caps.hasCapability(
                                android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET
                            )
                            if (!connected) {
                                broadcastState("network", "unavailable")
                            }
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Error checking network status", e)
                    }
                }

                handler.postDelayed(this, STATUS_CHECK_INTERVAL_MS)
            }
        }
        statusCheckRunnable?.let { handler.postDelayed(it, STATUS_CHECK_INTERVAL_MS) }
    }

    private fun stopStatusCheck() {
        statusCheckRunnable?.let { handler.removeCallbacks(it) }
        statusCheckRunnable = null
    }

    // ---- State Broadcasting ----

    /**
     * Broadcast connection state changes that the plugin can receive.
     */
    private fun broadcastState(transport: String, state: String) {
        Log.d(TAG, "Broadcasting state: transport=$transport, state=$state")

        // Send local broadcast for the plugin
        val intent = Intent(ACTION_CONNECTION_STATE_CHANGED).apply {
            putExtra(EXTRA_STATE_TRANSPORT, transport)
            putExtra(EXTRA_STATE_VALUE, state)
            setPackage(packageName)
        }
        try {
            sendBroadcast(intent)
        } catch (e: Exception) {
            Log.w(TAG, "Error sending broadcast", e)
        }

        // Also notify the plugin via callback if set
        try {
            onConnectionStateChanged?.invoke(transport, state)
        } catch (e: Exception) {
            Log.w(TAG, "Error in connection state callback", e)
        }
    }

    // ---- Public API ----

    /**
     * Update the monitoring targets (called from the plugin).
     */
    fun updateTargets(
        transportType: String,
        address: String? = null,
        port: Int = 9100,
        vendorId: Int = -1,
        productId: Int = -1
    ) {
        when (transportType) {
            "bluetooth", "ble" -> {
                isMonitoringBluetooth = true
                lastBluetoothAddress = address
                updateNotification("Monitoring Bluetooth: ${address ?: "scanning"}")
            }
            "usb" -> {
                isMonitoringUsb = true
                lastUsbVendorId = vendorId
                lastUsbProductId = productId
                updateNotification("Monitoring USB: ${String.format("0x%04X:0x%04X", vendorId, productId)}")
            }
            "network" -> {
                isMonitoringNetwork = true
                lastNetworkIp = address
                lastNetworkPort = port
                updateNotification("Monitoring Network: ${address ?: "scanning"}:$port")
            }
        }
    }

    /**
     * Enable or disable auto-reconnect monitoring.
     */
    fun setAutoReconnect(enabled: Boolean) {
        autoReconnectEnabled = enabled
        updateNotification(if (enabled) "Monitoring active (auto-reconnect)" else "Monitoring passive")
    }

    /**
     * Notify the service that a connection was established by the plugin.
     */
    fun notifyConnectionEstablished(transportType: String, address: String?) {
        broadcastState(transportType, "connected")
        updateNotification("Connected: $transportType ${address ?: ""}")
    }

    /**
     * Notify the service that a connection was lost.
     */
    fun notifyConnectionLost(transportType: String) {
        broadcastState(transportType, "disconnected")
        if (autoReconnectEnabled) {
            updateNotification("$transportType disconnected, will reconnect")
        }
    }
}
