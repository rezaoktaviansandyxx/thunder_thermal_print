package id.thunderlab.thunder_thermal_print.network

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.net.Inet4Address
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.NetworkInterface
import java.net.Socket
import java.net.SocketException
import java.net.SocketTimeoutException
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * NetworkPrinterManager handles network (TCP/IP) thermal printer connections.
 *
 * Features:
 * - TCP socket connection to network printers
 * - Subnet scanning for printer discovery (default port 9100)
 * - Parallel scanning using a thread pool for fast discovery
 * - Auto-reconnect with exponential backoff
 * - Network connectivity monitoring
 * - Connection state tracking
 */
class NetworkPrinterManager(
    private val context: Context,
    private val onConnectionStateChanged: (String) -> Unit
) {

    companion object {
        private const val TAG = "NetworkPrinterManager"

        // Default printer port (JetDirect/RAW)
        private const val DEFAULT_PORT = 9100

        // Connection states
        private const val STATE_DISCONNECTED = "disconnected"
        private const val STATE_CONNECTING = "connecting"
        private const val STATE_CONNECTED = "connected"
        private const val STATE_RECONNECTING = "reconnecting"

        // Auto-reconnect settings
        private const val BASE_RECONNECT_DELAY_MS = 1000L
        private const val MAX_RECONNECT_DELAY_MS = 30000L
        private const val MAX_RECONNECT_ATTEMPTS = 10

        // Socket settings
        private const val SOCKET_CONNECT_TIMEOUT_MS = 5000
        private const val SOCKET_READ_TIMEOUT_MS = 3000
        private const val SOCKET_KEEP_ALIVE = true
        private const val SOCKET_SEND_BUFFER_SIZE = 8192
        private const val SOCKET_RECEIVE_BUFFER_SIZE = 4096

        // Scan settings
        private const val SCAN_THREAD_POOL_SIZE = 50
        private const val SCAN_PORT_TIMEOUT_MS = 300
    }

    // Socket & streams
    private var socket: Socket? = null
    private var outputStream: OutputStream? = null
    private var inputStream: InputStream? = null
    private val isConnectedFlag = AtomicBoolean(false)
    @Volatile
    private var connectionState: String = STATE_DISCONNECTED

    // Connection target
    private var targetIpAddress: String? = null
    private var targetPort: Int = DEFAULT_PORT

    // Auto-reconnect
    private var autoReconnectEnabled: Boolean = false
    private var reconnectAttempts: Int = 0
    private val reconnectHandler = Handler(Looper.getMainLooper())

    // Network monitoring
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var isNetworkRegistered = false
    private var broadcastReceiver: BroadcastReceiver? = null
    private var isReceiverRegistered = false

    // Thread pool for scanning
    private val scanExecutor: ExecutorService = Executors.newFixedThreadPool(SCAN_THREAD_POOL_SIZE)

    // Device discovery listener
    private var deviceDiscoveryListener: ((List<Map<String, Any>>) -> Unit)? = null

    init {
        connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        registerNetworkMonitoring()
    }

    // ---- Network Monitoring ----

    private fun registerNetworkMonitoring() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            registerNetworkCallback()
        } else {
            registerNetworkBroadcastReceiver()
        }
    }

    @android.annotation.SuppressLint("MissingPermission")
    private fun registerNetworkCallback() {
        val cm = connectivityManager ?: return
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                Log.d(TAG, "Network available: $network")
                // If we had a connection and network is back, try reconnect
                if (autoReconnectEnabled && !isConnectedFlag.get() && targetIpAddress != null) {
                    scheduleReconnect()
                }
            }

            override fun onLost(network: Network) {
                Log.d(TAG, "Network lost: $network")
                // If we're connected over network, handle disconnect
                if (isConnectedFlag.get()) {
                    handleUnexpectedDisconnect()
                }
            }

            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                val hasWifi = caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
                val hasCellular = caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
                val hasEthernet = caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
                Log.d(TAG, "Network capabilities: wifi=$hasWifi, cellular=$hasCellular, ethernet=$hasEthernet")
            }
        }

        try {
            cm.registerNetworkCallback(request, networkCallback!!)
            isNetworkRegistered = true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register network callback", e)
        }
    }

    @Suppress("DEPRECATION")
    private fun registerNetworkBroadcastReceiver() {
        if (isReceiverRegistered) return

        broadcastReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent == null) return
                when (intent.action) {
                    ConnectivityManager.CONNECTIVITY_ACTION -> {
                        val networkInfo = intent.getParcelableExtra<android.net.NetworkInfo>(
                            ConnectivityManager.EXTRA_NETWORK_INFO
                        )
                        val isConnected = networkInfo?.isConnected == true
                        Log.d(TAG, "Connectivity changed: connected=$isConnected")
                        if (!isConnected && isConnectedFlag.get()) {
                            handleUnexpectedDisconnect()
                        } else if (isConnected && autoReconnectEnabled && !isConnectedFlag.get()) {
                            scheduleReconnect()
                        }
                    }
                }
            }
        }

        val filter = IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION)
        try {
            context.registerReceiver(broadcastReceiver, filter)
            isReceiverRegistered = true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register network broadcast receiver", e)
        }
    }

    // ---- Scanning ----

    /**
     * Scan a subnet for thermal printers.
     * @param subnet Optional subnet in "192.168.1" format. If null, auto-detects local subnet.
     * @param timeoutMs Timeout per host in milliseconds
     * @return List of discovered device maps: ip, port, hostname, responseTimeMs
     */
    fun scanNetwork(subnet: String? = null, timeoutMs: Long = SCAN_PORT_TIMEOUT_MS.toLong()): List<Map<String, Any>> {
        val scanSubnet = subnet ?: detectLocalSubnet()
        if (scanSubnet == null) {
            Log.e(TAG, "Cannot determine local subnet")
            return emptyList()
        }

        Log.d(TAG, "Scanning subnet $scanSubnet.0/24 on port $DEFAULT_PORT")

        val discoveredDevices = CopyOnWriteArrayList<Map<String, Any>>()
        val latch = CountDownLatch(254) // 1-254

        for (host in 1..254) {
            val ip = "$scanSubnet.$host"
            scanExecutor.submit {
                try {
                    val startTime = System.currentTimeMillis()
                    val addr = InetAddress.getByName(ip)
                    val sock = Socket()
                    sock.connect(InetSocketAddress(addr, DEFAULT_PORT), timeoutMs.toInt())
                    val responseTime = System.currentTimeMillis() - startTime
                    sock.close()

                    val device = mapOf(
                        "ip" to ip,
                        "port" to DEFAULT_PORT,
                        "hostname" to (addr.hostName ?: ip),
                        "responseTimeMs" to responseTime,
                        "type" to "network"
                    )
                    discoveredDevices.add(device)
                    Log.d(TAG, "Found printer at $ip (${responseTime}ms)")
                } catch (e: SocketTimeoutException) {
                    // Host not responding on port, expected
                } catch (e: IOException) {
                    // Host unreachable or port closed, expected
                } catch (e: Exception) {
                    Log.w(TAG, "Error scanning $ip: ${e.message}")
                } finally {
                    latch.countDown()
                }
            }
        }

        // Wait for all scan threads to complete with overall timeout
        try {
            latch.await(30, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {}

        val results = discoveredDevices.toList()
        Log.d(TAG, "Scan complete: found ${results.size} devices on $scanSubnet.0/24")
        return results.sortedBy { it["responseTimeMs"] as? Long }
    }

    /**
     * Detect the local network subnet (e.g., "192.168.1" from local IP "192.168.1.100").
     */
    private fun detectLocalSubnet(): String? {
        return try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            while (interfaces.hasMoreElements()) {
                val iface = interfaces.nextElement()

                // Skip loopback and down interfaces
                if (iface.isLoopback || !iface.isUp) continue

                val addresses = iface.interfaceAddresses
                for (addr in addresses) {
                    val inetAddr = addr.address
                    if (inetAddr is Inet4Address && !inetAddr.isLoopbackAddress) {
                        val ip = inetAddr.hostAddress ?: continue
                        // Extract subnet (first 3 octets)
                        val parts = ip.split(".")
                        if (parts.size == 4) {
                            val subnet = "${parts[0]}.${parts[1]}.${parts[2]}"
                            Log.d(TAG, "Detected local subnet: $subnet (from IP: $ip)")
                            return subnet
                        }
                    }
                }
            }
            null
        } catch (e: SocketException) {
            Log.e(TAG, "Error detecting local subnet", e)
            null
        } catch (e: Exception) {
            Log.e(TAG, "Error detecting local subnet", e)
            null
        }
    }

    // ---- Connection ----

    /**
     * Connect to a network printer.
     * @param ipAddress The IP address of the printer
     * @param port The port number (default 9100)
     * @param autoReconnect Whether to auto-reconnect on disconnect
     * @return true if connection succeeds
     */
    fun connect(ipAddress: String, port: Int = DEFAULT_PORT, autoReconnect: Boolean = false): Boolean {
        // Disconnect existing
        disconnect()

        setConnectionState(STATE_CONNECTING)
        targetIpAddress = ipAddress
        targetPort = port
        autoReconnectEnabled = autoReconnect
        reconnectAttempts = 0

        return try {
            Log.d(TAG, "Connecting to $ipAddress:$port")
            val sock = Socket()
            sock.keepAlive = SOCKET_KEEP_ALIVE
            sock.sendBufferSize = SOCKET_SEND_BUFFER_SIZE
            sock.receiveBufferSize = SOCKET_RECEIVE_BUFFER_SIZE
            sock.connect(InetSocketAddress(ipAddress, port), SOCKET_CONNECT_TIMEOUT_MS)
            sock.soTimeout = SOCKET_READ_TIMEOUT_MS

            outputStream = sock.getOutputStream()
            inputStream = sock.getInputStream()
            socket = sock

            isConnectedFlag.set(true)
            reconnectAttempts = 0
            setConnectionState(STATE_CONNECTED)

            Log.d(TAG, "Connected to $ipAddress:$port")
            true
        } catch (e: SocketTimeoutException) {
            Log.e(TAG, "Connection timeout to $ipAddress:$port", e)
            closeConnection()
            setConnectionState(STATE_DISCONNECTED)
            false
        } catch (e: IOException) {
            Log.e(TAG, "IO error connecting to $ipAddress:$port", e)
            closeConnection()
            setConnectionState(STATE_DISCONNECTED)
            false
        } catch (e: Exception) {
            Log.e(TAG, "Error connecting to $ipAddress:$port", e)
            closeConnection()
            setConnectionState(STATE_DISCONNECTED)
            false
        }
    }

    /**
     * Disconnect from the network printer.
     */
    fun disconnect() {
        autoReconnectEnabled = false
        reconnectAttempts = MAX_RECONNECT_ATTEMPTS
        closeConnection()
        setConnectionState(STATE_DISCONNECTED)
    }

    private fun closeConnection() {
        try {
            outputStream?.flush()
        } catch (_: IOException) {}
        try {
            outputStream?.close()
        } catch (_: IOException) {}
        try {
            inputStream?.close()
        } catch (_: IOException) {}
        try {
            socket?.close()
        } catch (_: IOException) {}

        outputStream = null
        inputStream = null
        socket = null
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
        val ip = targetIpAddress ?: return
        val port = targetPort

        reconnectAttempts++
        val delay = minOf(
            BASE_RECONNECT_DELAY_MS * (1L shl (reconnectAttempts - 1)),
            MAX_RECONNECT_DELAY_MS
        )

        Log.d(TAG, "Scheduling network reconnect attempt $reconnectAttempts in ${delay}ms")
        setConnectionState(STATE_RECONNECTING)

        reconnectHandler.postDelayed({
            if (!autoReconnectEnabled || isConnectedFlag.get()) return@postDelayed
            Log.d(TAG, "Auto-reconnecting to $ip:$port (attempt $reconnectAttempts)")
            if (!connect(ip, port, true)) {
                if (reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
                    Log.e(TAG, "Max network reconnect attempts reached")
                    autoReconnectEnabled = false
                    setConnectionState(STATE_DISCONNECTED)
                }
            }
        }, delay)
    }

    // ---- Data Transfer ----

    /**
     * Send raw bytes to the connected network printer.
     * @param data The bytes to send
     * @return true if data was sent successfully
     */
    fun sendData(data: ByteArray): Boolean {
        val stream = outputStream
        if (stream == null || !isConnectedFlag.get()) {
            Log.e(TAG, "Not connected, cannot send network data")
            return false
        }

        return try {
            stream.write(data)
            stream.flush()
            Log.d(TAG, "Sent ${data.size} bytes via network")
            true
        } catch (e: IOException) {
            Log.e(TAG, "Error sending network data", e)
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

    // ---- Cleanup ----

    fun cleanup() {
        autoReconnectEnabled = false
        reconnectHandler.removeCallbacksAndMessages(null)

        scanExecutor.shutdownNow()
        try {
            scanExecutor.awaitTermination(5, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {}

        // Unregister network monitoring
        if (isNetworkRegistered && networkCallback != null) {
            try {
                connectivityManager?.unregisterNetworkCallback(networkCallback!!)
            } catch (_: Exception) {}
            isNetworkRegistered = false
            networkCallback = null
        }

        if (isReceiverRegistered && broadcastReceiver != null) {
            try {
                context.unregisterReceiver(broadcastReceiver)
            } catch (_: Exception) {}
            isReceiverRegistered = false
            broadcastReceiver = null
        }

        disconnect()
    }
}
