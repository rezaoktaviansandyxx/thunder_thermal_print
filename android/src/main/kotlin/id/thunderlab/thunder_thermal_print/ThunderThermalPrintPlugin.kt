package id.thunderlab.thunder_thermal_print

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.usb.UsbManager
import android.net.ConnectivityManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import id.thunderlab.thunder_thermal_print.bluetooth.BluetoothPrinterManager
import id.thunderlab.thunder_thermal_print.ble.BlePrinterManager
import id.thunderlab.thunder_thermal_print.usb.UsbPrinterManager
import id.thunderlab.thunder_thermal_print.network.NetworkPrinterManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener

class ThunderThermalPrintPlugin : FlutterPlugin, ActivityAware, MethodCallHandler,
    RequestPermissionsResultListener {

    companion object {
        private const val TAG = "ThunderThermalPrint"
        private const val CHANNEL_NAME = "id.thunderlab.thunder_thermal_print"
        private const val EVENT_CONNECTION_STATE = "id.thunderlab.thunder_thermal_print/connection_state"
        private const val EVENT_DEVICE_EVENTS = "id.thunderlab.thunder_thermal_print/device_events"

        // Permission request codes
        private const val PERMISSION_REQUEST_CODE = 1001
    }

    private lateinit var channel: MethodChannel
    private lateinit var connectionEventChannel: EventChannel
    private lateinit var deviceEventChannel: EventChannel

    private var context: Context? = null
    private var activity: Activity? = null
    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null

    // Managers
    private var bluetoothManager: BluetoothPrinterManager? = null
    private var bleManager: BlePrinterManager? = null
    private var usbManager: UsbPrinterManager? = null
    private var networkManager: NetworkPrinterManager? = null

    // Event sinks
    private var connectionEventSink: EventChannel.EventSink? = null
    private var deviceEventSink: EventChannel.EventSink? = null

    // Main thread handler for event channel emissions
    private val mainHandler = Handler(Looper.getMainLooper())

    // Pending permission result
    private var pendingPermissionResult: Result? = null
    private var pendingPermissionsResult: List<String>? = null

    // ---- FlutterPlugin ----

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onAttachedToEngine")
        flutterPluginBinding = binding
        context = binding.applicationContext

        setupChannels(binding.binaryMessenger)
        initManagers()
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        Log.d(TAG, "onDetachedFromEngine")
        teardownChannels()
        cleanupManagers()
        context = null
        flutterPluginBinding = null
    }

    // ---- ActivityAware ----

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(TAG, "onAttachedToActivity")
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)

        // Re-init managers with activity context for permission requests etc.
        initManagers()
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "onDetachedFromActivity")
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d(TAG, "onReattachedToActivityForConfigChanges")
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "onDetachedFromActivityForConfigChanges")
        activity = null
    }

    override fun onResumed() {
        Log.d(TAG, "onResumed - lifecycle")
    }

    override fun onPaused() {
        Log.d(TAG, "onPaused - lifecycle")
    }

    // ---- RequestPermissionsResultListener ----

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val resultMap = mutableMapOf<String, Boolean>()
            for (i in permissions.indices) {
                resultMap[permissions[i]] = grantResults[i] == PackageManager.PERMISSION_GRANTED
            }
            pendingPermissionResult?.success(resultMap)
            pendingPermissionResult = null
            pendingPermissionsResult = null
            return true
        }
        return false
    }

    // ---- MethodCallHandler ----

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        Log.d(TAG, "onMethodCall: ${call.method}")

        try {
            when (call.method) {
                // ---- Scanning ----
                "scanBluetooth" -> handleScanBluetooth(call, result)
                "scanBle" -> handleScanBle(call, result)
                "scanUsb" -> handleScanUsb(call, result)
                "scanNetwork" -> handleScanNetwork(call, result)

                // ---- Connection ----
                "connectBluetooth" -> handleConnectBluetooth(call, result)
                "connectBle" -> handleConnectBle(call, result)
                "connectUsb" -> handleConnectUsb(call, result)
                "connectNetwork" -> handleConnectNetwork(call, result)
                "disconnect" -> handleDisconnect(call, result)
                "isConnected" -> handleIsConnected(call, result)

                // ---- Status ----
                "getStatus" -> handleGetStatus(call, result)

                // ---- Printing ----
                "printBytes" -> handlePrintBytes(call, result)
                "printText" -> handlePrintText(call, result)
                "printLines" -> handlePrintLines(call, result)
                "printQrCode" -> handlePrintQrCode(call, result)
                "printBarcode" -> handlePrintBarcode(call, result)
                "printImage" -> handlePrintImage(call, result)
                "printPdf" -> handlePrintPdf(call, result)
                "printReceipt" -> handlePrintReceipt(call, result)

                // ---- Cash Drawer ----
                "openCashDrawer" -> handleOpenCashDrawer(call, result)

                // ---- Permissions ----
                "requestPermissions" -> handleRequestPermissions(call, result)
                "checkPermissions" -> handleCheckPermissions(call, result)
                "requestUsbPermission" -> handleRequestUsbPermission(call, result)

                // ---- Platform ----
                "getPlatformVersion" -> handleGetPlatformVersion(call, result)
                "isFeatureSupported" -> handleIsFeatureSupported(call, result)

                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling method call: ${call.method}", e)
            result.error("NATIVE_ERROR", e.message ?: "Unknown native error", null)
        }
    }

    // ---- Channel Setup / Teardown ----

    private fun setupChannels(messenger: io.flutter.plugin.common.BinaryMessenger) {
        channel = MethodChannel(messenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)

        connectionEventChannel = EventChannel(messenger, EVENT_CONNECTION_STATE)
        connectionEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                connectionEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                connectionEventSink = null
            }
        })

        deviceEventChannel = EventChannel(messenger, EVENT_DEVICE_EVENTS)
        deviceEventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                deviceEventSink = events
            }

            override fun onCancel(arguments: Any?) {
                deviceEventSink = null
            }
        })
    }

    private fun teardownChannels() {
        channel.setMethodCallHandler(null)
        connectionEventChannel.setStreamHandler(null)
        deviceEventChannel.setStreamHandler(null)
        connectionEventSink = null
        deviceEventSink = null
    }

    // ---- Manager Initialization ----

    private fun initManagers() {
        val ctx = context ?: return
        val act = activity

        bluetoothManager?.disconnect()
        bleManager?.disconnect()
        usbManager?.disconnect()
        networkManager?.disconnect()

        bluetoothManager = BluetoothPrinterManager(ctx, act) { state ->
            emitConnectionState("bluetooth", state)
        }
        bluetoothManager?.setDeviceDiscoveryListener { devices ->
            emitDeviceEvent("bluetooth_scan_result", mapOf("devices" to devices))
        }

        bleManager = BlePrinterManager(ctx, act) { state ->
            emitConnectionState("ble", state)
        }
        bleManager?.setDeviceDiscoveryListener { devices ->
            emitDeviceEvent("ble_scan_result", mapOf("devices" to devices))
        }

        usbManager = UsbPrinterManager(ctx, act) { state ->
            emitConnectionState("usb", state)
        }
        usbManager?.setDeviceDiscoveryListener { devices ->
            emitDeviceEvent("usb_scan_result", mapOf("devices" to devices))
        }

        networkManager = NetworkPrinterManager(ctx) { state ->
            emitConnectionState("network", state)
        }
        networkManager?.setDeviceDiscoveryListener { devices ->
            emitDeviceEvent("network_scan_result", mapOf("devices" to devices))
        }
    }

    private fun cleanupManagers() {
        bluetoothManager?.cleanup()
        bleManager?.cleanup()
        usbManager?.cleanup()
        networkManager?.cleanup()
        bluetoothManager = null
        bleManager = null
        usbManager = null
        networkManager = null
    }

    // ---- Event Emission Helpers ----

    private fun emitConnectionState(transportType: String, state: String) {
        mainHandler.post {
            try {
                connectionEventSink?.success(mapOf(
                    "transportType" to transportType,
                    "state" to state,
                    "timestamp" to System.currentTimeMillis()
                ))
            } catch (e: Exception) {
                Log.w(TAG, "Error emitting connection state", e)
            }
        }
    }

    private fun emitDeviceEvent(eventType: String, data: Map<String, Any?>) {
        mainHandler.post {
            try {
                deviceEventSink?.success(mapOf(
                    "eventType" to eventType,
                    "data" to data,
                    "timestamp" to System.currentTimeMillis()
                ))
            } catch (e: Exception) {
                Log.w(TAG, "Error emitting device event", e)
            }
        }
    }

    // ---- Method Handlers: Scanning ----

    @SuppressLint("MissingPermission")
    private fun handleScanBluetooth(call: MethodCall, result: Result) {
        val timeout = call.argument<Number>("timeoutMs")?.toLong() ?: 10000L
        val mgr = bluetoothManager ?: run {
            result.error("NOT_INITIALIZED", "Bluetooth manager not initialized", null)
            return
        }
        Thread {
            try {
                val devices = mgr.startScan(timeout)
                result.success(devices)
            } catch (e: Exception) {
                result.error("SCAN_ERROR", e.message, null)
            }
        }.start()
    }

    @SuppressLint("MissingPermission")
    private fun handleScanBle(call: MethodCall, result: Result) {
        val timeout = call.argument<Number>("timeoutMs")?.toLong() ?: 10000L
        val mgr = bleManager ?: run {
            result.error("NOT_INITIALIZED", "BLE manager not initialized", null)
            return
        }
        Thread {
            try {
                val devices = mgr.startScan(timeout)
                result.success(devices)
            } catch (e: Exception) {
                result.error("SCAN_ERROR", e.message, null)
            }
        }.start()
    }

    private fun handleScanUsb(call: MethodCall, result: Result) {
        val mgr = usbManager ?: run {
            result.error("NOT_INITIALIZED", "USB manager not initialized", null)
            return
        }
        Thread {
            try {
                val devices = mgr.scanDevices()
                result.success(devices)
            } catch (e: Exception) {
                result.error("SCAN_ERROR", e.message, null)
            }
        }.start()
    }

    private fun handleScanNetwork(call: MethodCall, result: Result) {
        val subnet = call.argument<String>("subnet")
        val timeout = call.argument<Number>("timeoutMs")?.toLong() ?: 5000L
        val mgr = networkManager ?: run {
            result.error("NOT_INITIALIZED", "Network manager not initialized", null)
            return
        }
        Thread {
            try {
                val devices = mgr.scanNetwork(subnet, timeout)
                result.success(devices)
            } catch (e: Exception) {
                result.error("SCAN_ERROR", e.message, null)
            }
        }.start()
    }

    // ---- Method Handlers: Connection ----

    private fun handleConnectBluetooth(call: MethodCall, result: Result) {
        val macAddress = call.argument<String>("macAddress")
            ?: run { result.error("INVALID_ARGS", "macAddress is required", null); return }
        val autoReconnect = call.argument<Boolean>("autoReconnect") ?: false
        val mgr = bluetoothManager ?: run {
            result.error("NOT_INITIALIZED", "Bluetooth manager not initialized", null)
            return
        }
        Thread {
            try {
                val success = mgr.connect(macAddress, autoReconnect)
                result.success(success)
            } catch (e: Exception) {
                result.error("CONNECT_ERROR", e.message, null)
            }
        }.start()
    }

    private fun handleConnectBle(call: MethodCall, result: Result) {
        val deviceId = call.argument<String>("deviceId")
            ?: run { result.error("INVALID_ARGS", "deviceId is required", null); return }
        val autoReconnect = call.argument<Boolean>("autoReconnect") ?: false
        val serviceUuid = call.argument<String>("serviceUuid")
        mgr?.setTargetServiceUuid(serviceUuid)
        val mgr = bleManager ?: run {
            result.error("NOT_INITIALIZED", "BLE manager not initialized", null)
            return
        }
        if (serviceUuid != null) {
            mgr.setTargetServiceUuid(serviceUuid)
        }
        Thread {
            try {
                val success = mgr.connect(deviceId, autoReconnect)
                result.success(success)
            } catch (e: Exception) {
                result.error("CONNECT_ERROR", e.message, null)
            }
        }.start()
    }

    private fun handleConnectUsb(call: MethodCall, result: Result) {
        val vendorId = call.argument<Number>("vendorId")?.toInt()
            ?: run { result.error("INVALID_ARGS", "vendorId is required", null); return }
        val productId = call.argument<Number>("productId")?.toInt()
            ?: run { result.error("INVALID_ARGS", "productId is required", null); return }
        val autoReconnect = call.argument<Boolean>("autoReconnect") ?: false
        val mgr = usbManager ?: run {
            result.error("NOT_INITIALIZED", "USB manager not initialized", null)
            return
        }
        Thread {
            try {
                val success = mgr.connect(vendorId, productId, autoReconnect)
                if (success) {
                    result.success(true)
                } else {
                    val state = mgr.getConnectionState()
                    if (state == "no_permission") {
                        result.error("PERMISSION_DENIED", "USB permission not granted. Call requestUsbPermission() first.", null)
                    } else {
                        result.error("CONNECT_FAILED", "Failed to connect to USB printer (state=$state)", null)
                    }
                }
            } catch (e: Exception) {
                result.error("CONNECT_ERROR", e.message, null)
            }
        }.start()
    }

    private fun handleConnectNetwork(call: MethodCall, result: Result) {
        val ipAddress = call.argument<String>("ipAddress")
            ?: run { result.error("INVALID_ARGS", "ipAddress is required", null); return }
        val port = call.argument<Number>("port")?.toInt() ?: 9100
        val autoReconnect = call.argument<Boolean>("autoReconnect") ?: false
        val mgr = networkManager ?: run {
            result.error("NOT_INITIALIZED", "Network manager not initialized", null)
            return
        }
        Thread {
            try {
                val success = mgr.connect(ipAddress, port, autoReconnect)
                result.success(success)
            } catch (e: Exception) {
                result.error("CONNECT_ERROR", e.message, null)
            }
        }.start()
    }

    private fun handleDisconnect(call: MethodCall, result: Result) {
        val transportType = call.argument<String>("transportType")
        when (transportType) {
            "bluetooth" -> bluetoothManager?.disconnect()
            "ble" -> bleManager?.disconnect()
            "usb" -> usbManager?.disconnect()
            "network" -> networkManager?.disconnect()
            null -> {
                bluetoothManager?.disconnect()
                bleManager?.disconnect()
                usbManager?.disconnect()
                networkManager?.disconnect()
            }
            else -> {
                result.error("INVALID_ARGS", "Unknown transportType: $transportType", null)
                return
            }
        }
        result.success(true)
    }

    private fun handleIsConnected(call: MethodCall, result: Result) {
        val transportType = call.argument<String>("transportType")
        val connected = when (transportType) {
            "bluetooth" -> bluetoothManager?.isConnected() ?: false
            "ble" -> bleManager?.isConnected() ?: false
            "usb" -> usbManager?.isConnected() ?: false
            "network" -> networkManager?.isConnected() ?: false
            null -> {
                bluetoothManager?.isConnected() == true ||
                        bleManager?.isConnected() == true ||
                        usbManager?.isConnected() == true ||
                        networkManager?.isConnected() == true
            }
            else -> false
        }
        result.success(connected)
    }

    // ---- Method Handlers: Status ----

    private fun handleGetStatus(call: MethodCall, result: Result) {
        val transportType = call.argument<String>("transportType") ?: "bluetooth"
        val status = mutableMapOf<String, Any?>(
            "isConnected" to false,
            "connectionState" to "disconnected"
        )

        when (transportType) {
            "bluetooth" -> {
                status["isConnected"] = bluetoothManager?.isConnected() ?: false
                status["connectionState"] = bluetoothManager?.getConnectionState() ?: "disconnected"
            }
            "ble" -> {
                status["isConnected"] = bleManager?.isConnected() ?: false
                status["connectionState"] = bleManager?.getConnectionState() ?: "disconnected"
            }
            "usb" -> {
                status["isConnected"] = usbManager?.isConnected() ?: false
                status["connectionState"] = usbManager?.getConnectionState() ?: "disconnected"
            }
            "network" -> {
                status["isConnected"] = networkManager?.isConnected() ?: false
                status["connectionState"] = networkManager?.getConnectionState() ?: "disconnected"
            }
        }

        result.success(status)
    }

    // ---- Method Handlers: Printing ----

    private fun handlePrintBytes(call: MethodCall, result: Result) {
        val data = call.argument<ByteArray>("data")
            ?: run { result.error("INVALID_ARGS", "data is required", null); return }
        val transportType = call.argument<String>("transportType") ?: "bluetooth"
        val mgr = getActiveManager(transportType)
            ?: run { result.error("NOT_CONNECTED", "No printer connected on $transportType", null); return }

        Thread {
            try {
                val success = mgr.sendData(data)
                result.success(success)
            } catch (e: Exception) {
                result.error("PRINT_ERROR", e.message, null)
            }
        }.start()
    }

    private fun handlePrintText(call: MethodCall, result: Result) {
        val text = call.argument<String>("text")
            ?: run { result.error("INVALID_ARGS", "text is required", null); return }
        val transportType = call.argument<String>("transportType") ?: "bluetooth"
        val mgr = getActiveManager(transportType)
            ?: run { result.error("NOT_CONNECTED", "No printer connected on $transportType", null); return }

        val encoder = id.thunderlab.thunder_thermal_print.utils.EscPosEncoder()
        val bytes = encoder.text(text) + encoder.feed(3)

        Thread {
            try {
                val success = mgr.sendData(bytes)
                result.success(success)
            } catch (e: Exception) {
                result.error("PRINT_ERROR", e.message, null)
            }
        }.start()
    }

    private fun handlePrintLines(call: MethodCall, result: Result) {
        @Suppress("UNCHECKED_CAST")
        val lines = call.argument<List<Map<String, Any?>>>("lines")
            ?: run { result.error("INVALID_ARGS", "lines is required", null); return }
        val transportType = call.argument<String>("transportType") ?: "bluetooth"
        val mgr = getActiveManager(transportType)
            ?: run { result.error("NOT_CONNECTED", "No printer connected on $transportType", null); return }

        val encoder = id.thunderlab.thunder_thermal_print.utils.EscPosEncoder()
        val outputStream = ByteArrayOutputStream()

        for (line in lines) {
            val text = line["text"] as? String ?: ""
            val bold = line["bold"] as? Boolean ?: false
            val underline = line["underline"] as? Int ?: 0
            val align = line["align"] as? Int ?: 0 // 0=left, 1=center, 2=right
            val fontSize = line["fontSize"] as? Int ?: 1

            if (bold) outputStream.write(encoder.bold(true))
            if (underline > 0) outputStream.write(encoder.underline(underline))
            outputStream.write(encoder.align(align))
            if (fontSize == 2) {
                outputStream.write(byteArrayOf(0x1D, 0x21, 0x11)) // double width + height
            }
            outputStream.write(encoder.text(text))
            outputStream.write(encoder.feed(1))
            // Reset
            if (bold) outputStream.write(encoder.bold(false))
            if (underline > 0) outputStream.write(encoder.underline(0))
            outputStream.write(encoder.align(0))
            if (fontSize == 2) {
                outputStream.write(byteArrayOf(0x1D, 0x21, 0x00))
            }
        }

        outputStream.write(encoder.feed(3))
        outputStream.write(encoder.cut(true))

        Thread {
            try {
                val success = mgr.sendData(outputStream.toByteArray())
                result.success(success)
            } catch (e: Exception) {
                result.error("PRINT_ERROR", e.message, null)
            }
        }.start()
    }

    private fun handlePrintQrCode(call: MethodCall, result: Result) {
        val data = call.argument<String>("data")
            ?: run { result.error("INVALID_ARGS", "data is required", null); return }
        val size = call.argument<Number>("size")?.toInt() ?: 6
        val transportType = call.argument<String>("transportType") ?: "bluetooth"
        val mgr = getActiveManager(transportType)
            ?: run { result.error("NOT_CONNECTED", "No printer connected on $transportType", null); return }

        val encoder = id.thunderlab.thunder_thermal_print.utils.EscPosEncoder()
        val bytes = encoder.initialize() + encoder.qrCode(data, size) + encoder.feed(3)

        Thread {
            try {
                val success = mgr.sendData(bytes)
                result.success(success)
            } catch (e: Exception) {
                result.error("PRINT_ERROR", e.message, null)
            }
        }.start()
    }

    private fun handlePrintBarcode(call: MethodCall, result: Result) {
        val data = call.argument<String>("data")
            ?: run { result.error("INVALID_ARGS", "data is required", null); return }
        val type = call.argument<Number>("type")?.toInt() ?: 0 // CODE128
        val transportType = call.argument<String>("transportType") ?: "bluetooth"
        val mgr = getActiveManager(transportType)
            ?: run { result.error("NOT_CONNECTED", "No printer connected on $transportType", null); return }

        val encoder = id.thunderlab.thunder_thermal_print.utils.EscPosEncoder()
        val bytes = encoder.initialize() + encoder.barcode(data, type) + encoder.feed(3)

        Thread {
            try {
                val success = mgr.sendData(bytes)
                result.success(success)
            } catch (e: Exception) {
                result.error("PRINT_ERROR", e.message, null)
            }
        }.start()
    }

    private fun handlePrintImage(call: MethodCall, result: Result) {
        val bytes = call.argument<ByteArray>("data")
            ?: run { result.error("INVALID_ARGS", "data (image bytes) is required", null); return }
        val width = call.argument<Number>("width")?.toInt() ?: 384
        val transportType = call.argument<String>("transportType") ?: "bluetooth"
        val mgr = getActiveManager(transportType)
            ?: run { result.error("NOT_CONNECTED", "No printer connected on $transportType", null); return }

        Thread {
            try {
                val bitmap = android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                if (bitmap == null) {
                    mainHandler.post { result.error("IMAGE_ERROR", "Failed to decode image", null) }
                    return@Thread
                }
                val encoder = id.thunderlab.thunder_thermal_print.utils.EscPosEncoder()
                val printBytes = encoder.initialize() + encoder.image(bitmap, width) + encoder.feed(3) + encoder.cut(true)
                val success = mgr.sendData(printBytes)
                bitmap.recycle()
                result.success(success)
            } catch (e: Exception) {
                result.error("PRINT_ERROR", e.message, null)
            }
        }.start()
    }

    private fun handlePrintPdf(call: MethodCall, result: Result) {
        // PDF printing: render PDF pages to bitmaps and send as images
        val bytes = call.argument<ByteArray>("data")
            ?: run { result.error("INVALID_ARGS", "data (PDF bytes) is required", null); return }
        val width = call.argument<Number>("width")?.toInt() ?: 384
        val transportType = call.argument<String>("transportType") ?: "bluetooth"
        val mgr = getActiveManager(transportType)
            ?: run { result.error("NOT_CONNECTED", "No printer connected on $transportType", null); return }

        Thread {
            try {
                // For PDF we use Android's PdfRenderer if available (API 21+)
                val outputFile = java.io.File(context?.cacheDir, "print_temp.pdf")
                outputFile.writeBytes(bytes)

                val fileDescriptor = android.os.ParcelFileDescriptor.open(
                    outputFile,
                    android.os.ParcelFileDescriptor.MODE_READ_ONLY
                )

                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                    val renderer = android.graphics.pdf.PdfRenderer(fileDescriptor)
                    val encoder = id.thunderlab.thunder_thermal_print.utils.EscPosEncoder()
                    var success = true

                    for (i in 0 until renderer.pageCount) {
                        val page = renderer.openPage(i)
                        val bitmap = android.graphics.Bitmap.createBitmap(width, (width * page.height.toFloat() / page.width.toFloat()).toInt(), android.graphics.Bitmap.Config.ARGB_8888)
                        page.render(bitmap, null, null, android.graphics.pdf.PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                        page.close()

                        val printBytes = encoder.initialize() + encoder.image(bitmap, width) + encoder.cut(true)
                        if (!mgr.sendData(printBytes)) {
                            success = false
                        }
                        bitmap.recycle()
                    }
                    renderer.close()
                    result.success(success)
                } else {
                    result.error("UNSUPPORTED", "PDF rendering requires API 21+", null)
                }

                fileDescriptor.close()
                outputFile.delete()
            } catch (e: Exception) {
                result.error("PRINT_ERROR", e.message, null)
            }
        }.start()
    }

    private fun handlePrintReceipt(call: MethodCall, result: Result) {
        @Suppress("UNCHECKED_CAST")
        val receipt = call.argument<Map<String, Any?>>("receipt")
            ?: run { result.error("INVALID_ARGS", "receipt is required", null); return }
        val transportType = call.argument<String>("transportType") ?: "bluetooth"
        val mgr = getActiveManager(transportType)
            ?: run { result.error("NOT_CONNECTED", "No printer connected on $transportType", null); return }

        val encoder = id.thunderlab.thunder_thermal_print.utils.EscPosEncoder()
        val out = ByteArrayOutputStream()

        // Initialize
        out.write(encoder.initialize())

        // Header / store name
        val storeName = receipt["storeName"] as? String
        if (storeName != null) {
            out.write(encoder.align(1)) // center
            out.write(encoder.bold(true))
            out.write(encoder.text(storeName))
            out.write(encoder.bold(false))
            out.write(encoder.feed(1))
        }

        // Store address
        val storeAddress = receipt["storeAddress"] as? String
        if (storeAddress != null) {
            out.write(encoder.align(1))
            out.write(encoder.text(storeAddress))
            out.write(encoder.feed(1))
        }

        // Store phone
        val storePhone = receipt["storePhone"] as? String
        if (storePhone != null) {
            out.write(encoder.align(1))
            out.write(encoder.text(storePhone))
            out.write(encoder.feed(1))
        }

        // Separator
        out.write(encoder.text("--------------------------------"))
        out.write(encoder.feed(1))

        // Date/time
        val dateTime = receipt["dateTime"] as? String
        if (dateTime != null) {
            out.write(encoder.align(0))
            out.write(encoder.text(dateTime))
            out.write(encoder.feed(1))
        }

        // Cashier
        val cashier = receipt["cashier"] as? String
        if (cashier != null) {
            out.write(encoder.text("Cashier: $cashier"))
            out.write(encoder.feed(1))
        }

        // Transaction ID
        val txnId = receipt["transactionId"] as? String
        if (txnId != null) {
            out.write(encoder.text("Txn#: $txnId"))
            out.write(encoder.feed(1))
        }

        out.write(encoder.text("--------------------------------"))
        out.write(encoder.feed(1))

        // Items
        @Suppress("UNCHECKED_CAST")
        val items = receipt["items"] as? List<Map<String, Any?>>
        if (items != null) {
            for (item in items) {
                val name = item["name"] as? String ?: ""
                val qty = item["quantity"] as? Number ?: 1
                val price = item["price"] as? Number ?: 0.0
                val subtotal = qty.toDouble() * price.toDouble()

                out.write(encoder.text(name))
                out.write(encoder.align(2)) // right
                out.write(encoder.text("$qty x ${String.format("%.2f", price.toDouble())}"))
                out.write(encoder.align(2))
                out.write(encoder.text(String.format("%.2f", subtotal)))
                out.write(encoder.align(0))
                out.write(encoder.feed(1))
            }
        }

        out.write(encoder.text("--------------------------------"))
        out.write(encoder.feed(1))

        // Subtotal
        val subtotal = receipt["subtotal"] as? Number
        if (subtotal != null) {
            out.write(encoder.text("Subtotal:"))
            out.write(encoder.align(2))
            out.write(encoder.text(String.format("%.2f", subtotal.toDouble())))
            out.write(encoder.align(0))
            out.write(encoder.feed(1))
        }

        // Tax
        val tax = receipt["tax"] as? Number
        if (tax != null) {
            out.write(encoder.text("Tax:"))
            out.write(encoder.align(2))
            out.write(encoder.text(String.format("%.2f", tax.toDouble())))
            out.write(encoder.align(0))
            out.write(encoder.feed(1))
        }

        // Discount
        val discount = receipt["discount"] as? Number
        if (discount != null && discount.toDouble() != 0.0) {
            out.write(encoder.text("Discount:"))
            out.write(encoder.align(2))
            out.write(encoder.text(String.format("%.2f", discount.toDouble())))
            out.write(encoder.align(0))
            out.write(encoder.feed(1))
        }

        // Total
        val total = receipt["total"] as? Number
        if (total != null) {
            out.write(encoder.text("--------------------------------"))
            out.write(encoder.feed(1))
            out.write(encoder.bold(true))
            out.write(encoder.text("TOTAL:"))
            out.write(encoder.align(2))
            out.write(encoder.text(String.format("%.2f", total.toDouble())))
            out.write(encoder.bold(false))
            out.write(encoder.align(0))
            out.write(encoder.feed(1))
        }

        // Payment method
        val paymentMethod = receipt["paymentMethod"] as? String
        if (paymentMethod != null) {
            out.write(encoder.text("Payment: $paymentMethod"))
            out.write(encoder.feed(1))
        }

        // Footer
        out.write(encoder.feed(1))
        out.write(encoder.text("--------------------------------"))
        out.write(encoder.feed(1))
        out.write(encoder.align(1))
        out.write(encoder.text("Thank you for your purchase!"))
        out.write(encoder.feed(2))

        // Cut
        out.write(encoder.cut(true))

        Thread {
            try {
                val success = mgr.sendData(out.toByteArray())
                result.success(success)
            } catch (e: Exception) {
                result.error("PRINT_ERROR", e.message, null)
            }
        }.start()
    }

    // ---- Method Handlers: Cash Drawer ----

    private fun handleOpenCashDrawer(call: MethodCall, result: Result) {
        val transportType = call.argument<String>("transportType") ?: "bluetooth"
        val mgr = getActiveManager(transportType)
            ?: run { result.error("NOT_CONNECTED", "No printer connected on $transportType", null); return }

        // ESC/POS cash drawer kick command: 0x1B 0x70 0x00 (drawer 2) or 0x1B 0x70 0x01 (drawer 1)
        val drawerPin = call.argument<Number>("pin")?.toInt() ?: 0
        val pulseTime = call.argument<Number>("pulseTimeMs")?.toInt() ?: 200
        val encoder = id.thunderlab.thunder_thermal_print.utils.EscPosEncoder()
        // ESC p <drawer_pin> <pulse_time_x_2ms>
        val cashDrawerCommand = byteArrayOf(0x1B, 0x70, drawerPin.toByte(), (pulseTime / 2).toByte())

        Thread {
            try {
                val success = mgr.sendData(encoder.initialize() + cashDrawerCommand)
                result.success(success)
            } catch (e: Exception) {
                result.error("CASH_DRAWER_ERROR", e.message, null)
            }
        }.start()
    }

    // ---- Method Handlers: Permissions ----

    private fun handleRequestPermissions(call: MethodCall, result: Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "No activity available for permission request", null)
            return
        }

        val permissions = getRequiredPermissions()
        val needRequest = permissions.filter {
            ContextCompat.checkSelfPermission(act, it) != PackageManager.PERMISSION_GRANTED
        }

        if (needRequest.isEmpty()) {
            val resultMap = permissions.associateWith { true }
            result.success(resultMap)
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(act, needRequest.toTypedArray(), PERMISSION_REQUEST_CODE)
    }

    private fun handleCheckPermissions(call: MethodCall, result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "No context available", null)
            return
        }
        val permissions = getRequiredPermissions()
        val resultMap = permissions.associateWith {
            ContextCompat.checkSelfPermission(ctx, it) == PackageManager.PERMISSION_GRANTED
        }
        result.success(resultMap)
    }

    private fun handleRequestUsbPermission(call: MethodCall, result: Result) {
        val act = activity
        if (act == null) {
            result.error("NO_ACTIVITY", "No activity available for USB permission request", null)
            return
        }

        val vendorId = call.argument<Number>("vendorId")?.toInt()
            ?: run { result.error("INVALID_ARGS", "vendorId is required", null); return }
        val productId = call.argument<Number>("productId")?.toInt()
            ?: run { result.error("INVALID_ARGS", "productId is required", null); return }

        val mgr = usbManager ?: run {
            result.error("NOT_INITIALIZED", "USB manager not initialized", null)
            return
        }

        Thread {
            try {
                val granted = mgr.requestPermissionOnly(vendorId, productId)
                if (granted) {
                    result.success(true)
                } else {
                    result.error("PERMISSION_DENIED", "USB permission denied by user", null)
                }
            } catch (e: Exception) {
                result.error("PERMISSION_ERROR", e.message, null)
            }
        }.start()
    }

    private fun getRequiredPermissions(): List<String> {
        val permissions = mutableListOf<String>()
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.R) {
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
            permissions.add(Manifest.permission.ACCESS_COARSE_LOCATION)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            permissions.add(Manifest.permission.BLUETOOTH)
            permissions.add(Manifest.permission.BLUETOOTH_ADMIN)
        }
        return permissions
    }

    // ---- Method Handlers: Platform ----

    private fun handleGetPlatformVersion(call: MethodCall, result: Result) {
        result.success("Android ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})")
    }

    @SuppressLint("HardwareIds")
    private fun handleIsFeatureSupported(call: MethodCall, result: Result) {
        val ctx = context ?: run {
            result.error("NO_CONTEXT", "No context available", null)
            return
        }
        val feature = call.argument<String>("feature")
            ?: run { result.error("INVALID_ARGS", "feature is required", null); return }

        val supported = when (feature) {
            "bluetooth" -> ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH)
            "bluetooth_le" -> ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)
            "usb_host" -> ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_USB_HOST)
            "wifi" -> ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_WIFI)
            "camera" -> ctx.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA)
            else -> false
        }
        result.success(supported)
    }

    // ---- Helper: Get Active Manager ----

    private fun getActiveManager(transportType: String): SendDataCapable? {
        return when (transportType) {
            "bluetooth" -> bluetoothManager
            "ble" -> bleManager
            "usb" -> usbManager
            "network" -> networkManager
            else -> {
                // Try to find whichever is connected
                bluetoothManager?.takeIf { it.isConnected() }
                    ?: bleManager?.takeIf { it.isConnected() }
                        ?: usbManager?.takeIf { it.isConnected() }
                            ?: networkManager?.takeIf { it.isConnected() }
            }
        }
    }

    // ---- Interface for data sending ----

    interface SendDataCapable {
        fun sendData(data: ByteArray): Boolean
        fun isConnected(): Boolean
        fun getConnectionState(): String
    }
}
