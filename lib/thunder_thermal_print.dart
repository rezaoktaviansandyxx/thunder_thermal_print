/// A Flutter plugin for discovering, connecting to, and printing on
/// thermal receipt printers via Bluetooth, BLE, USB, and network (TCP/IP).
///
/// This is the **single public import** consumers should use:
///
/// ```dart
/// import 'package:thunder_thermal_print/thunder_thermal_print.dart';
/// ```
///
/// The plugin exposes all functionality through the static methods on
/// [ThunderThermalPrint]. There is no need to instantiate anything – every
/// method is stateless at the Dart level and delegates to the underlying
/// platform implementation.
///
/// ## Quick start
///
/// ```dart
/// // 1. Scan for nearby Bluetooth printers
/// final devices = await ThunderThermalPrint.scanBluetooth();
///
/// // 2. Connect to the first device found
/// if (devices.isNotEmpty) {
///   await ThunderThermalPrint.connectBluetooth(
///     macAddress: devices.first.address,
///     profile: PrinterProfile.epson,
///   );
/// }
///
/// // 3. Print a receipt
/// final receipt = ReceiptBuilder(maxCharsPerLine: 32)
///     .center().bold().text('MY STORE').normal()
///     .line()
///     .text('Thank you for your purchase!')
///     .feed(lines: 3)
///     .cut();
///
/// await ThunderThermalPrint.printReceipt(receipt);
///
/// // 4. Disconnect when done
/// await ThunderThermalPrint.disconnect();
/// ```
library thunder_thermal_print;

// ---------------------------------------------------------------------------
// Public re-exports – consumers only need this single import.
// ---------------------------------------------------------------------------

/// All model classes: [PrinterDevice], [PrinterStatus],
/// [PrinterConnectionState], [PrinterEvent], [PrinterProfile].
export 'src/models/models.dart';

/// Typed exceptions: [PrinterException], [ConnectionException],
/// [PermissionException], [PaperOutException], [CoverOpenException],
/// [DeviceNotFoundException], [PrintTimeoutException],
/// [NotSupportedException], [PrinterBusyException],
/// [InvalidDataException].
export 'src/exceptions/exceptions.dart';

/// Low-level ESC/POS byte command helpers: [EscPosCommands], [BarcodeType].
export 'src/escpos/escpos_commands.dart';

/// Fluent receipt builder: [ReceiptBuilder].
export 'src/receipt/receipt_builder.dart';

/// Broadcast stream wrappers: [ConnectionStream], [DeviceEventStream].
export 'src/streams/streams.dart';

// ---------------------------------------------------------------------------
// Internal imports – not part of the public API.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:typed_data';

import 'src/models/models.dart';
import 'src/exceptions/exceptions.dart';
import 'src/receipt/receipt_builder.dart';
import 'src/services/services.dart';
import 'src/streams/streams.dart';

// ---------------------------------------------------------------------------
// ThunderThermalPrint – the main public API class.
// ---------------------------------------------------------------------------

/// Top-level entry point for the **thunder_thermal_print** plugin.
///
/// Every public method is `static`, so you never need to instantiate this
/// class. Under the hood, all calls are forwarded to the platform
/// implementation via [ThunderThermalPrintPlatform.instance].
///
/// ### Platform implementation
///
/// The default platform implementation is [MethodChannelThunderThermalPrint],
/// which communicates with native Android/iOS code through a `MethodChannel`.
/// You can swap it out for testing:
///
/// ```dart
/// ThunderThermalPrintPlatform.instance = MyMockPlatform();
/// ```
///
/// ### Connection lifecycle
///
/// 1. **Scan** for devices ([scanBluetooth], [scanBle], [scanUsb],
///    [scanNetwork]).
/// 2. **Connect** to a device (`connect*` methods).
/// 3. **Monitor** connection state via [connectionStream].
/// 4. **Print** using the various `print*` methods.
/// 5. **Disconnect** via [disconnect] or [dispose].
///
/// ### Exception handling
///
/// All platform errors are mapped to typed subclasses of [PrinterException].
/// Use a broad `catch` or catch specific types:
///
/// ```dart
/// try {
///   await ThunderThermalPrint.connectBluetooth(macAddress: '00:11:22:33:44');
/// } on PermissionException catch (e) {
///   // Handle missing Bluetooth / location permission
/// } on ConnectionException catch (e) {
///   // Handle connection failure
/// } on PrinterException catch (e) {
///   // Catch-all for any other printer error
/// }
/// ```
class ThunderThermalPrint {
  // Private constructor – this class is never instantiated.
  ThunderThermalPrint._();

  // ---------------------------------------------------------------------------
  // Device Discovery
  // ---------------------------------------------------------------------------

  /// Scans for nearby classic Bluetooth (RFCOMM) thermal printers.
  ///
  /// Requires `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` permissions on Android
  /// 12+, and `BLUETOOTH` + `ACCESS_FINE_LOCATION` on earlier versions.
  ///
  /// [timeout] – Maximum scan duration. Defaults to the native platform's
  /// default (typically 10 seconds). Set to `null` to use the default.
  ///
  /// Returns a list of [PrinterDevice] objects, each containing the device
  /// name, MAC address, RSSI signal strength, and connection type.
  ///
  /// Throws [PermissionException] if Bluetooth or location permissions are
  /// missing. Throws [NotSupportedException] if Bluetooth is not available on
  /// the current platform.
  ///
  /// Example:
  /// ```dart
  /// final devices = await ThunderThermalPrint.scanBluetooth(
  ///   timeout: const Duration(seconds: 15),
  /// );
  /// for (final device in devices) {
  ///   print('${device.name} (${device.address}) RSSI: ${device.rssi}');
  /// }
  /// ```
  static Future<List<PrinterDevice>> scanBluetooth({Duration? timeout}) {
    return ThunderThermalPrintPlatform.instance.scanBluetooth(timeout: timeout);
  }

  /// Scans for Bluetooth Low Energy (BLE) thermal printers.
  ///
  /// BLE printers advertise their services via GATT and are discovered through
  /// BLE scan. Requires `BLUETOOTH_SCAN` on Android 12+.
  ///
  /// [timeout] – Maximum scan duration. Defaults to the native default.
  ///
  /// Returns a list of discovered [PrinterDevice] objects with BLE-specific
  /// metadata in the [PrinterDevice.metadata] map (e.g., service UUIDs).
  ///
  /// Throws [PermissionException] if required permissions are missing.
  ///
  /// Example:
  /// ```dart
  /// final devices = await ThunderThermalPrint.scanBle(
  ///   timeout: const Duration(seconds: 10),
  /// );
  /// ```
  static Future<List<PrinterDevice>> scanBle({Duration? timeout}) {
    return ThunderThermalPrintPlatform.instance.scanBle(timeout: timeout);
  }

  /// Scans for USB-connected thermal printers.
  ///
  /// On Android, this uses the USB Host API to enumerate connected USB
  /// devices. The returned [PrinterDevice] entries include [PrinterDevice.vendorId]
  /// and [PrinterDevice.productId] which are needed for [connectUsb].
  ///
  /// Returns a list of USB printer devices. May return an empty list if no
  /// USB printers are attached or if USB host mode is not supported.
  ///
  /// Throws [PermissionException] if the USB host permission is missing.
  ///
  /// Example:
  /// ```dart
  /// final devices = await ThunderThermalPrint.scanUsb();
  /// for (final device in devices) {
  ///   print('USB: ${device.name} VID:${device.vendorId} PID:${device.productId}');
  /// }
  /// ```
  static Future<List<PrinterDevice>> scanUsb() {
    return ThunderThermalPrintPlatform.instance.scanUsb();
  }

  /// Scans for network (TCP/IP) thermal printers on the local network.
  ///
  /// Uses a UDP broadcast or subnet scan to discover printers on port 9100
  /// (the standard ESC/POS network port).
  ///
  /// [subnet] – Optionally restrict the scan to a specific subnet
  /// (e.g., `'192.168.1.0/24'`). When `null`, the plugin automatically
  /// determines the current subnet from the device's network configuration.
  ///
  /// Returns a list of discovered [PrinterDevice] objects where
  /// [PrinterDevice.address] is the IP address.
  ///
  /// Throws [NotSupportedException] if network scanning is not available.
  ///
  /// Example:
  /// ```dart
  /// final devices = await ThunderThermalPrint.scanNetwork(
  ///   subnet: '192.168.1.0/24',
  /// );
  /// ```
  static Future<List<PrinterDevice>> scanNetwork({String? subnet}) {
    return ThunderThermalPrintPlatform.instance.scanNetwork(subnet: subnet);
  }

  // ---------------------------------------------------------------------------
  // Connection Management
  // ---------------------------------------------------------------------------

  /// Connects to a classic Bluetooth (RFCOMM) thermal printer.
  ///
  /// [macAddress] – The Bluetooth MAC address of the target printer
  /// (e.g., `'00:11:22:33:44:55'`).
  ///
  /// [profile] – An optional [PrinterProfile] that configures ESC/POS
  /// behaviour for the target printer brand. If omitted, the plugin uses
  /// a generic profile.
  ///
  /// [autoReconnect] – When `true`, the plugin will automatically attempt
  /// to re-establish the connection if it drops unexpectedly (e.g., the printer
  /// goes out of range and comes back). The reconnection attempts are
  /// exponential-backoff with a maximum retry count. Connection state
  /// transitions are emitted via [connectionStream].
  ///
  /// [timeout] – Maximum time to wait for the connection to be established.
  /// Throws [PrintTimeoutException] if the timeout expires.
  ///
  /// Throws [PermissionException] if Bluetooth permissions are missing.
  /// Throws [ConnectionException] if the connection fails.
  /// Throws [DeviceNotFoundException] if no device with the given MAC is
  /// found.
  ///
  /// Example:
  /// ```dart
  /// await ThunderThermalPrint.connectBluetooth(
  ///   macAddress: '00:11:22:33:44:55',
  ///   profile: PrinterProfile.epson,
  ///   autoReconnect: true,
  ///   timeout: const Duration(seconds: 10),
  /// );
  /// ```
  static Future<void> connectBluetooth({
    required String macAddress,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) {
    return ThunderThermalPrintPlatform.instance.connectBluetooth(
      macAddress: macAddress,
      profile: profile,
      autoReconnect: autoReconnect,
      timeout: timeout,
    );
  }

  /// Connects to a Bluetooth Low Energy (BLE) thermal printer.
  ///
  /// [deviceId] – The platform-specific BLE device identifier (not a MAC
  /// address). On Android this is typically the GATT device address; on
  /// iOS it is a UUID string.
  ///
  /// [profile] – Optional [PrinterProfile] for ESC/POS configuration.
  ///
  /// [autoReconnect] – Automatically reconnect on disconnection.
  ///
  /// [timeout] – Connection timeout.
  ///
  /// Throws the same exceptions as [connectBluetooth].
  ///
  /// Example:
  /// ```dart
  /// final devices = await ThunderThermalPrint.scanBle();
  /// if (devices.isNotEmpty) {
  ///   await ThunderThermalPrint.connectBle(
  ///     deviceId: devices.first.address,
  ///     profile: PrinterProfile.sunmi,
  ///   );
  /// }
  /// ```
  static Future<void> connectBle({
    required String deviceId,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) {
    return ThunderThermalPrintPlatform.instance.connectBle(
      deviceId: deviceId,
      profile: profile,
      autoReconnect: autoReconnect,
      timeout: timeout,
    );
  }

  /// Connects to a USB thermal printer.
  ///
  /// [vendorId] – The USB vendor ID of the printer.
  /// [productId] – The USB product ID of the printer.
  ///
  /// Both IDs can be obtained from [scanUsb] or from the printer's
  /// documentation.
  ///
  /// [profile] – Optional [PrinterProfile].
  /// [autoReconnect] – Reconnect when the USB device is detached
  /// and reattached. Defaults to `true`.
  /// [timeout] – Connection timeout.
  ///
  /// Throws [PermissionException] if USB host permission is missing.
  /// Throws [DeviceNotFoundException] if no USB device matching the given
  /// VID/PID is connected.
  ///
  /// Example:
  /// ```dart
  /// await ThunderThermalPrint.connectUsb(
  ///   vendorId: 0x04B8,  // Epson
  ///   productId: 0x0E03,
  ///   profile: PrinterProfile.epson,
  /// );
  /// ```
  static Future<void> connectUsb({
    required int vendorId,
    required int productId,
    PrinterProfile? profile,
    bool autoReconnect = true,
    Duration? timeout,
  }) {
    return ThunderThermalPrintPlatform.instance.connectUsb(
      vendorId: vendorId,
      productId: productId,
      profile: profile,
      autoReconnect: autoReconnect,
      timeout: timeout,
    );
  }

  /// Connects to a network (TCP/IP) thermal printer.
  ///
  /// [ipAddress] – The IP address of the printer (e.g., `'192.168.1.100'`).
  ///
  /// [port] – The TCP port number. Defaults to `9100`, which is the
  /// industry-standard port for ESC/POS network printers.
  ///
  /// [profile] – Optional [PrinterProfile].
  /// [autoReconnect] – Reconnect on connection loss.
  /// [timeout] – Connection timeout.
  ///
  /// Throws [ConnectionException] if the printer cannot be reached.
  /// Throws [PrintTimeoutException] if the connection times out.
  ///
  /// Example:
  /// ```dart
  /// await ThunderThermalPrint.connectNetwork(
  ///   ipAddress: '192.168.1.100',
  ///   port: 9100,
  ///   profile: PrinterProfile.xprinter,
  ///   autoReconnect: true,
  /// );
  /// ```
  static Future<void> connectNetwork({
    required String ipAddress,
    int port = 9100,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) {
    return ThunderThermalPrintPlatform.instance.connectNetwork(
      ipAddress: ipAddress,
      port: port,
      profile: profile,
      autoReconnect: autoReconnect,
      timeout: timeout,
    );
  }

  /// Disconnects the currently connected printer.
  ///
  /// This closes the active Bluetooth socket, BLE GATT connection, USB
  /// endpoint, or TCP socket. Any pending print jobs are cancelled.
  ///
  /// Auto-reconnect, if enabled, is disabled for this connection.
  ///
  /// It is safe to call [disconnect] when no printer is connected; the call
  /// completes silently.
  ///
  /// Example:
  /// ```dart
  /// await ThunderThermalPrint.disconnect();
  /// ```
  static Future<void> disconnect() {
    return ThunderThermalPrintPlatform.instance.disconnect();
  }

  /// Ensures a USB printer is connected before printing.
  ///
  /// If the USB printer is already connected, this is a no-op.
  /// If not connected but [vendorId] and [productId] are provided, it
  /// attempts to connect first (which may trigger the USB permission dialog
  /// if permission hasn't been granted yet).
  ///
  /// Returns `true` if connected after the call completes.
  ///
  /// Example:
  /// ```dart
  /// if (await ThunderThermalPrint.ensureUsbConnected(
  ///   vendorId: 0x04B8,
  ///   productId: 0x0E03,
  /// )) {
  ///   await ThunderThermalPrint.printText('Ready to print!');
  /// }
  /// ```
  static Future<bool> ensureUsbConnected({
    required int vendorId,
    required int productId,
    PrinterProfile? profile,
    bool autoReconnect = true,
    Duration? timeout,
  }) {
    return ConnectionManager.ensureUsbConnected(
      vendorId: vendorId,
      productId: productId,
      profile: profile,
      autoReconnect: autoReconnect,
      timeout: timeout,
    );
  }

  /// Returns `true` if a printer is currently connected and ready to accept
  /// data.
  ///
  /// This performs a lightweight check on the native side (e.g., checks
  /// whether the socket is still open or the Bluetooth connection is still
  /// active). It does **not** query the printer hardware itself – use
  /// [getStatus] for a full hardware status check.
  ///
  /// Example:
  /// ```dart
  /// if (await ThunderThermalPrint.isConnected()) {
  ///   await ThunderThermalPrint.printText('Hello, printer!');
  /// } else {
  ///   print('No printer connected.');
  /// }
  /// ```
  static Future<bool> isConnected() {
    return ThunderThermalPrintPlatform.instance.isConnected();
  }

  // ---------------------------------------------------------------------------
  // Printer Status
  // ---------------------------------------------------------------------------

  /// Queries the printer for its current hardware status.
  ///
  /// Returns a [PrinterStatus] object containing:
  /// - [PrinterStatus.online] – Whether the printer is responsive.
  /// - [PrinterStatus.paperOut] – Paper roll is empty.
  /// - [PrinterStatus.paperNearEnd] – Paper is almost empty.
  /// - [PrinterStatus.coverOpen] – The printer cover/lid is open.
  /// - [PrinterStatus.drawerOpen] – The cash drawer is open.
  /// - [PrinterStatus.batteryLow] – Battery is low (for portable printers).
  /// - [PrinterStatus.batteryLevel] – Battery percentage (0-100).
  /// - [PrinterStatus.errorCode] / [PrinterStatus.errorMessage] – Hardware
  ///   error details.
  ///
  /// The [PrinterStatus.canPrint] property is a convenience shortcut that
  /// returns `true` only when the printer is online, has paper, and the cover
  /// is closed.
  ///
  /// Throws [ConnectionException] if no printer is connected.
  ///
  /// Example:
  /// ```dart
  /// final status = await ThunderThermalPrint.getStatus();
  /// if (status.canPrint) {
  ///   await ThunderThermalPrint.printText('Printing...');
  /// } else {
  ///   print('Cannot print: ${status.issues.join(", ")}');
  /// }
  /// ```
  static Future<PrinterStatus> getStatus() async {
    final map = await ThunderThermalPrintPlatform.instance.getStatus();
    return PrinterStatus(
      online: map['online'] as bool? ?? false,
      paperOut: map['paperOut'] as bool? ?? false,
      paperNearEnd: map['paperNearEnd'] as bool? ?? false,
      coverOpen: map['coverOpen'] as bool? ?? false,
      drawerOpen: map['drawerOpen'] as bool? ?? false,
      batteryLow: map['batteryLow'] as bool? ?? false,
      batteryLevel: map['batteryLevel'] as int?,
      errorCode: map['errorCode'] as int?,
      errorMessage: map['errorMessage'] as String?,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Print Operations
  // ---------------------------------------------------------------------------

  /// Sends raw bytes directly to the connected printer.
  ///
  /// This is the lowest-level print method. The [bytes] are sent verbatim
  /// to the printer without any encoding or formatting. Use this when you
  /// have pre-assembled ESC/POS commands or need to send custom sequences.
  ///
  /// For typical printing tasks, prefer higher-level methods like
  /// [printText], [printLines], [printQrCode], or [printReceipt].
  ///
  /// Throws [ConnectionException] if no printer is connected.
  /// Throws [PrinterBusyException] if the printer is still processing a
  /// previous job.
  /// Throws [PrintTimeoutException] if the write times out.
  ///
  /// Example:
  /// ```dart
  /// import 'package:thunder_thermal_print/thunder_thermal_print.dart';
  ///
  /// final bytes = [
  ///   ...EscPosCommands.initialize(),
  ///   ...EscPosCommands.alignCenter(),
  ///   ...EscPosCommands.enableBold(),
  ///   ...EscPosCommands.printText('Hello World'),
  ///   0x0A, // LF
  ///   ...EscPosCommands.feedLines(3),
  ///   ...EscPosCommands.partialCut(),
  /// ];
  /// await ThunderThermalPrint.printBytes(bytes);
  /// ```
  static Future<void> printBytes(List<int> bytes) {
    return ThunderThermalPrintPlatform.instance.printBytes(bytes);
  }

  /// Prints a single line of text.
  ///
  /// The [text] string is encoded as UTF-8 and sent to the printer with
  /// a trailing line feed (`LF`). No ESC/POS formatting commands are
  /// applied – the text is printed with the printer's current settings.
  ///
  /// For styled text (bold, centered, etc.), use [ReceiptBuilder] or
  /// compose raw bytes with [EscPosCommands].
  ///
  /// Throws [ConnectionException] if no printer is connected.
  ///
  /// Example:
  /// ```dart
  /// await ThunderThermalPrint.printText('Hello, World!');
  /// ```
  static Future<void> printText(String text) {
    return ThunderThermalPrintPlatform.instance.printText(text);
  }

  /// Prints multiple lines of text with automatic line feeding.
  ///
  /// Each string in [lines] is printed followed by a line feed. This is
  /// equivalent to calling [printText] for each line, but may be more
  /// efficient as a single batch operation on some platforms.
  ///
  /// Example:
  /// ```dart
  /// await ThunderThermalPrint.printLines([
  ///   'Line 1',
  ///   'Line 2',
  ///   'Line 3',
  /// ]);
  /// ```
  static Future<void> printLines(List<String> lines) {
    return ThunderThermalPrintPlatform.instance.printLines(lines);
  }

  /// Prints a QR code containing the specified [data].
  ///
  /// The QR code is rendered using the ESC/POS `GS ( k` command set and
  /// printed at the center of the paper width.
  ///
  /// [data] – The text or URL to encode in the QR code.
  ///
  /// [size] – The module size in dots (default `6`). Larger values produce
  /// bigger QR codes. Valid range is 1–16.
  ///
  /// Throws [NotSupportedException] if the connected printer does not
  /// support QR code printing (check with `isFeatureSupported('qrCode')`).
  ///
  /// Example:
  /// ```dart
  /// await ThunderThermalPrint.printQrCode(
  ///   'https://example.com/receipt/12345',
  ///   size: 8,
  /// );
  /// ```
  static Future<void> printQrCode(String data, {int size = 6}) {
    return ThunderThermalPrintPlatform.instance.printQrCode(data, size: size);
  }

  /// Prints a 1-D barcode containing the specified [data].
  ///
  /// [data] – The string to encode in the barcode. The format must be
  /// valid for the chosen barcode type.
  ///
  /// [type] – The barcode symbology. Common values:
  /// - `'CODE128'` (default) – General-purpose alphanumeric.
  /// - `'EAN13'` – 13-digit retail barcode.
  /// - `'EAN8'` – 8-digit short retail barcode.
  /// - `'UPCA'` – 12-digit North American retail barcode.
  /// - `'CODE39'` – Industrial alphanumeric.
  /// - `'ITF'` – Interleaved 2-of-5 (numeric only).
  /// - `'CODABAR'` – Numeric with special characters.
  /// - `'PHARMACODE'` – Pharmaceutical packaging code.
  ///
  /// Throws [NotSupportedException] if the printer does not support barcode
  /// printing. Throws [InvalidDataException] if [data] is not valid for the
  /// chosen barcode type.
  ///
  /// Example:
  /// ```dart
  /// await ThunderThermalPrint.printBarcode('1234567890128', type: 'EAN13');
  /// ```
  static Future<void> printBarcode(String data, {String type = 'CODE128'}) {
    return ThunderThermalPrintPlatform.instance.printBarcode(data, type: type);
  }

  /// Prints a raster image (PNG or JPEG) on the thermal printer.
  ///
  /// [imageBytes] – The raw image file bytes (PNG or JPEG encoded).
  ///
  /// The image is automatically:
  /// 1. Decoded from PNG/JPEG.
  /// 2. Resized to fit the printer's paper width.
  /// 3. Converted to grayscale.
  /// 4. Dithered to 1-bit black-and-white.
  /// 5. Encoded as ESC/POS raster bit-image commands.
  ///
  /// For best results, use high-contrast images with clean edges.
  /// Thermal printers have low resolution (typically 203 or 300 DPI).
  ///
  /// Throws [NotSupportedException] if the printer does not support image
  /// printing. Throws [InvalidDataException] if the image bytes cannot be
  /// decoded.
  ///
  /// Example:
  /// ```dart
  /// final imageBytes = await rootBundle.load('assets/logo.png');
  /// await ThunderThermalPrint.printImage(imageBytes.buffer.asUint8List());
  /// ```
  static Future<void> printImage(Uint8List imageBytes) {
    return ThunderThermalPrintPlatform.instance.printImage(imageBytes);
  }

  /// Renders and prints a PDF document on the thermal printer.
  ///
  /// [pdfBytes] – The raw bytes of a PDF file.
  ///
  /// The PDF is rendered page by page. Each page is converted to a raster
  /// image and sent to the printer. For multi-page PDFs, only the first page
  /// is printed (thermal printers are single-sheet devices).
  ///
  /// Throws [NotSupportedException] if the printer or platform does not
  /// support PDF printing.
  ///
  /// Example:
  /// ```dart
  /// final pdfBytes = await rootBundle.load('assets/receipt.pdf');
  /// await ThunderThermalPrint.printPdf(pdfBytes.buffer.asUint8List());
  /// ```
  static Future<void> printPdf(Uint8List pdfBytes) {
    return ThunderThermalPrintPlatform.instance.printPdf(pdfBytes);
  }

  /// Builds a [ReceiptBuilder] into ESC/POS bytes and sends them to the
  /// printer.
  ///
  /// This is the recommended way to print formatted receipts. The
  /// [ReceiptBuilder] fluent API lets you compose text styles, alignment,
  /// QR codes, barcodes, images, separators, and paper cuts in a readable,
  /// chainable manner.
  ///
  /// Internally, this calls `receipt.build()` to generate the byte buffer,
  /// then passes the result to [printReceiptBytes].
  ///
  /// Example:
  /// ```dart
  /// final receipt = ReceiptBuilder(maxCharsPerLine: 32)
  ///     .center().bold().text('COFFEE SHOP').normal()
  ///     .line()
  ///     .row(left: 'Latte', right: '\$4.50')
  ///     .row(left: 'Croissant', right: '\$2.75')
  ///     .line()
  ///     .row(left: 'TOTAL', right: '\$7.25')
  ///     .doubleLine()
  ///     .text('Payment: Visa ****1234')
  ///     .feed(lines: 2)
  ///     .center().text('Thank you!').feed(lines: 3)
  ///     .cut();
  ///
  /// await ThunderThermalPrint.printReceipt(receipt);
  /// ```
  static Future<void> printReceipt(ReceiptBuilder receipt) {
    final bytes = receipt.build();
    return printReceiptBytes(bytes);
  }

  /// Sends pre-built receipt bytes (raw ESC/POS commands) to the printer.
  ///
  /// Use this when you have already assembled the byte buffer yourself
  /// (e.g., via [ReceiptBuilder.build], manual [EscPosCommands] composition,
  /// or loading from a template).
  ///
  /// Example:
  /// ```dart
  /// final builder = ReceiptBuilder(maxCharsPerLine: 48);
  /// builder.text('Custom receipt...').feed(lines: 3).cut();
  ///
  /// final bytes = builder.build();
  /// await ThunderThermalPrint.printReceiptBytes(bytes);
  /// ```
  static Future<void> printReceiptBytes(List<int> bytes) {
    return ThunderThermalPrintPlatform.instance.printReceipt(bytes);
  }

  // ---------------------------------------------------------------------------
  // Cash Drawer
  // ---------------------------------------------------------------------------

  /// Opens the cash drawer connected to the printer.
  ///
  /// Many thermal printers have one or two cash drawer kick-out solenoids.
  /// This method sends the ESC `p` command to pulse the solenoid on the
  /// specified [pin].
  ///
  /// [pin] – The drawer connector pin: `0` (default, primary drawer) or `1`
  /// (secondary drawer). Most printers only support pin 0.
  ///
  /// Throws [NotSupportedException] if the printer does not have a cash
  /// drawer connector.
  ///
  /// Example:
  /// ```dart
  /// await ThunderThermalPrint.openCashDrawer(pin: 0);
  /// ```
  static Future<void> openCashDrawer({int pin = 0}) {
    return ThunderThermalPrintPlatform.instance.openCashDrawer(pin: pin);
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Requests all runtime permissions required for printer operations.
  ///
  /// On Android, this may request:
  /// - `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` (Android 12+)
  /// - `BLUETOOTH` / `ACCESS_FINE_LOCATION` (Android 11 and below)
  /// - `ACCESS_COARSE_LOCATION`
  ///
  /// On iOS, this triggers the Bluetooth and/or local network permission
  /// dialogs if they haven't been shown yet.
  ///
  /// Returns `true` if **all** required permissions were granted, `false`
  /// otherwise.
  ///
  /// Example:
  /// ```dart
  /// final granted = await ThunderThermalPrint.requestPermissions();
  /// if (!granted) {
  ///   // Explain to the user why permissions are needed
  ///   print('Printer permissions not granted.');
  /// }
  /// ```
  static Future<bool> requestPermissions() {
    return ThunderThermalPrintPlatform.instance.requestPermissions();
  }

  /// Requests USB device permission for a specific USB printer.
  ///
  /// On Android, USB host permission must be granted by the user before
  /// the app can communicate with a USB device. Unlike [connectUsb], this
  /// method only shows the permission dialog **without** opening the USB
  /// connection – call it early (e.g., right after scanning) so the user
  /// can grant permission before any print operation.
  ///
  /// Once granted, Android remembers the permission, so subsequent calls
  /// to [connectUsb] with the same VID/PID will skip the dialog.
  ///
  /// [vendorId] – The USB vendor ID of the target printer.
  /// [productId] – The USB product ID of the target printer.
  ///
  /// Returns `true` if permission was granted, `false` if denied.
  ///
  /// Throws [PermissionException] if the permission dialog fails to show
  /// (e.g., no Activity context available).
  ///
  /// Example:
  /// ```dart
  /// // Scan USB printers first
  /// final devices = await ThunderThermalPrint.scanUsb();
  /// if (devices.isNotEmpty) {
  ///   final device = devices.first;
  ///   // Pre-request permission before connecting
  ///   final granted = await ThunderThermalPrint.requestUsbPermission(
  ///     vendorId: device.vendorId!,
  ///     productId: device.productId!,
  ///   );
  ///   if (granted) {
  ///     await ThunderThermalPrint.connectUsb(
  ///       vendorId: device.vendorId!,
  ///       productId: device.productId!,
  ///     );
  ///   }
  /// }
  /// ```
  static Future<bool> requestUsbPermission({
    required int vendorId,
    required int productId,
  }) {
    return ThunderThermalPrintPlatform.instance.requestUsbPermission(
      vendorId: vendorId,
      productId: productId,
    );
  }

  /// Checks whether all required printer permissions are currently granted.
  ///
  /// Unlike [requestPermissions], this does **not** show any permission
  /// dialogs – it simply returns the current permission state.
  ///
  /// Returns `true` if all required permissions are granted, `false` if
  /// any are missing.
  ///
  /// Example:
  /// ```dart
  /// if (await ThunderThermalPrint.checkPermissions()) {
  ///   final devices = await ThunderThermalPrint.scanBluetooth();
  /// } else {
  ///   await ThunderThermalPrint.requestPermissions();
  /// }
  /// ```
  static Future<bool> checkPermissions() {
    return ThunderThermalPrintPlatform.instance.checkPermissions();
  }

  // ---------------------------------------------------------------------------
  // Streams
  // ---------------------------------------------------------------------------

  /// A broadcast [Stream] of [PrinterConnectionState] transitions.
  ///
  /// Subscribe to this stream to monitor connection lifecycle events:
  /// - [PrinterConnectionState.disconnected] – No active connection.
  /// - [PrinterConnectionState.connecting] – Connection in progress.
  /// - [PrinterConnectionState.connected] – Successfully connected.
  /// - [PrinterConnectionState.reconnecting] – Auto-reconnect in progress.
  /// - [PrinterConnectionState.connectionLost] – Connection dropped.
  /// - [PrinterConnectionState.reconnectFailed] – All reconnect attempts
  ///   exhausted.
  ///
  /// The stream is backed by a broadcast [StreamController], so multiple
  /// subscribers are supported. Each subscriber only receives events that
  /// occur after subscription.
  ///
  /// Example:
  /// ```dart
  /// ThunderThermalPrint.connectionStream.listen((state) {
  ///   print('Connection: ${state.displayName}');
  ///   if (state.isConnected) {
  ///     print('Printer is ready!');
  ///   }
  /// });
  /// ```
  static Stream<PrinterConnectionState> get connectionStream =>
      ConnectionStream().stream;

  /// A broadcast [Stream] of hardware and lifecycle [PrinterEvent] values.
  ///
  /// Subscribe to this stream to receive real-time events from the printer:
  /// - [PrinterEventType.printerConnected] / [PrinterEventType.printerDisconnected]
  /// - [PrinterEventType.bluetoothEnabled] / [PrinterEventType.bluetoothDisabled]
  /// - [PrinterEventType.usbAttached] / [PrinterEventType.usbDetached]
  /// - [PrinterEventType.paperOut] / [PrinterEventType.paperNearEnd]
  /// - [PrinterEventType.coverOpen] / [PrinterEventType.coverClosed]
  /// - [PrinterEventType.drawerOpen] / [PrinterEventType.drawerClosed]
  /// - [PrinterEventType.batteryLow] / [PrinterEventType.batteryNormal]
  /// - [PrinterEventType.error]
  ///
  /// Example:
  /// ```dart
  /// ThunderThermalPrint.deviceEventStream.listen((event) {
  ///   if (event.type == PrinterEventType.paperOut) {
  ///     showDialog(
  ///       context: context,
  ///       builder: (_) => AlertDialog(
  ///         title: Text('Paper Out'),
  ///         content: Text('Please replace the paper roll.'),
  ///       ),
  ///     );
  ///   }
  /// });
  /// ```
  static Stream<PrinterEvent> get deviceEventStream =>
      DeviceEventStream().stream;

  // ---------------------------------------------------------------------------
  // Platform Info
  // ---------------------------------------------------------------------------

  /// Returns a human-readable string identifying the native plugin version.
  ///
  /// The format is platform-dependent (e.g., `'1.0.0+3'` on Android,
  /// `'1.0.0'` on iOS). This is useful for debugging and version checks.
  ///
  /// Example:
  /// ```dart
  /// print('Plugin version: ${await ThunderThermalPrint.getPlatformVersion()}');
  /// ```
  static Future<String> getPlatformVersion() {
    return ThunderThermalPrintPlatform.instance.getPlatformVersion();
  }

  /// Checks whether the current platform and connected printer support
  /// a specific feature.
  ///
  /// [feature] – The feature name to check. Common values:
  /// - `'bluetooth'` – Classic Bluetooth (RFCOMM) support.
  /// - `'ble'` – Bluetooth Low Energy support.
  /// - `'usb'` – USB host support.
  /// - `'network'` – TCP/IP network support.
  /// - `'qrCode'` – QR code printing support.
  /// - `'barcode'` – Barcode printing support.
  /// - `'image'` – Raster image printing support.
  /// - `'pdf'` – PDF printing support.
  /// - `'cashDrawer'` – Cash drawer kick-out support.
  /// - `'autoReconnect'` – Auto-reconnect on connection loss.
  /// - `'backgroundService'` – Android background monitoring service.
  ///
  /// Returns `true` if the feature is supported on the current platform,
  /// `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// if (await ThunderThermalPrint.isFeatureSupported('qrCode')) {
  ///   await ThunderThermalPrint.printQrCode('https://example.com');
  /// } else {
  ///   print('QR code printing not supported.');
  /// }
  /// ```
  static Future<bool> isFeatureSupported(String feature) {
    return ThunderThermalPrintPlatform.instance.isFeatureSupported(feature);
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Releases all resources held by the plugin.
  ///
  /// Call this when your app is shutting down or when you are permanently
  /// done with printer operations. This:
  /// 1. Cancels all event channel subscriptions.
  /// 2. Closes the broadcast stream controllers.
  /// 3. Disconnects any active printer connection.
  ///
  /// After calling [dispose], the plugin is in a non-functional state.
  /// If you need to use the plugin again, the internal state will be
  /// lazily re-initialized on the next operation.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   ThunderThermalPrint.dispose();
  ///   super.dispose();
  /// }
  /// ```
  static Future<void> dispose() async {
    final platform = ThunderThermalPrintPlatform.instance;
    if (platform is MethodChannelThunderThermalPrint) {
      await platform.dispose();
    }
    await ConnectionStream().dispose();
    await DeviceEventStream().dispose();
  }
}
