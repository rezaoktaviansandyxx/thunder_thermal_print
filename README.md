# thunder_thermal_print

[![Pub Version](https://img.shields.io/pub/v/thunder_thermal_print.svg)](https://pub.dev/packages/thunder_thermal_print)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux%20%7C%20Web-blue.svg)](https://github.com)
[![Dart](https://img.shields.io/badge/dart-%3E%3D3.0.0-blue.svg)](https://dart.dev)

A comprehensive, production-ready Flutter plugin for discovering, connecting
to, and printing on **thermal receipt printers** via Bluetooth (Classic & BLE),
USB, and Network (TCP/IP).

Built with a clean layered architecture: **Platform Interface → Method Channel
→ Public API**, with full ESC/POS command support, a fluent receipt builder,
typed exceptions, and real-time connection/hardware event streams.

---

## ✨ Features

- **Multi-transport connectivity** — Bluetooth Classic, BLE, USB, Network (TCP/IP)
- **Device scanning** — Discover nearby printers via Bluetooth, BLE, USB, or network
- **Auto-reconnect** — Configurable exponential-backoff reconnection on connection loss
- **ESC/POS command library** — Complete low-level byte command helpers
- **Fluent receipt builder** — Chainable API for composing styled receipts
- **QR Code & Barcode printing** — CODE128, EAN13, EAN8, UPC-A, CODE39, ITF, and more
- **Image printing** — PNG/JPEG rasterisation with automatic resizing and dithering
- **PDF printing** — Direct PDF-to-thermal conversion
- **Cash drawer control** — Pulse drawer solenoid via ESC `p` command
- **Printer profiles** — Built-in profiles for Epson, XPrinter, Sunmi, Bixolon, Rongta, ZJiang
- **Connection state streams** — Real-time connection lifecycle monitoring
- **Hardware event streams** — Paper out, cover open, battery low, drawer events
- **Printer status queries** — Online, paper, cover, battery, and error status
- **Permission management** — Cross-platform permission request and check
- **Background service (Android)** — Monitor printer connection in the background
- **Typed exceptions** — `ConnectionException`, `PermissionException`,
  `PaperOutException`, `CoverOpenException`, and more
- **Comprehensive testability** — Swappable platform interface for unit/integration tests
- **Wide platform support** — Android, iOS, macOS, Windows, Linux, Web

---

## 📱 Supported Platforms

| Feature                     | Android | iOS | macOS | Windows | Linux | Web |
|-----------------------------|---------|-----|-------|---------|-------|-----|
| Bluetooth Classic           | ✅       | ✅   | ❌     | ❌       | ❌     | ❌   |
| Bluetooth Low Energy (BLE)  | ✅       | ✅   | ✅     | ❌       | ❌     | ❌   |
| USB                         | ✅       | ❌   | ❌     | ✅       | ✅     | ❌   |
| Network (TCP/IP)            | ✅       | ✅   | ✅     | ✅       | ✅     | ❌   |
| ESC/POS Commands            | ✅       | ✅   | ✅     | ✅       | ✅     | ❌   |
| QR Code Printing            | ✅       | ✅   | ✅     | ✅       | ✅     | ❌   |
| Barcode Printing            | ✅       | ✅   | ✅     | ✅       | ✅     | ❌   |
| Image Printing              | ✅       | ✅   | ✅     | ✅       | ✅     | ❌   |
| PDF Printing                | ✅       | ✅   | ❌     | ✅       | ❌     | ❌   |
| Cash Drawer                 | ✅       | ✅   | ✅     | ✅       | ✅     | ❌   |
| Auto-Reconnect              | ✅       | ✅   | ❌     | ❌       | ❌     | ❌   |
| Background Service          | ✅       | ❌   | ❌     | ❌       | ❌     | ❌   |
| Connection State Stream     | ✅       | ✅   | ✅     | ✅       | ✅     | ❌   |
| Device Event Stream         | ✅       | ✅   | ✅     | ✅       | ✅     | ❌   |

> **Note:** Web platform support is limited. Network printing may work via
> WebSocket proxies, but Bluetooth and USB are unavailable in browser environments.

---

## 📦 Installation

Add the plugin to your `pubspec.yaml`:

```yaml
dependencies:
  thunder_thermal_print: 
    git: https://github.com/rezaoktaviansandyxx/thunder_thermal_print.git
```

Then run:

```bash
flutter pub get
```

### Android Permissions

Add the following permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Bluetooth Classic & BLE -->
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<!-- Location (required for Bluetooth scanning on Android < 12) -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- USB Host -->
<uses-feature android:name="android.hardware.usb.host" android:required="false" />

<!-- Network -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />

<!-- Background service (optional) -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />
```

For Android 12+ (API 31+), the `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`
runtime permissions are required. On Android 11 and below, `ACCESS_FINE_LOCATION`
is required for Bluetooth discovery.

### iOS Permissions

Add the following keys to your `ios/Runner/Info.plist`:

```xml
<!-- Bluetooth -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth to connect to thermal printers.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth to connect to thermal printers.</string>

<!-- Local Network (required for network printer discovery on iOS 14+) -->
<key>NSLocalNetworkUsageDescription</key>
<string>This app needs local network access to discover thermal printers.</key>
<key>NSBonjourServices</key>
<array>
  <string>_printer._tcp</string>
  <string>_ipp._tcp</string>
</array>
```

---

## 🚀 Quick Start

### Minimal Working Example

```dart
import 'package:flutter/material.dart';
import 'package:thunder_thermal_print/thunder_thermal_print.dart';

class PrinterScreen extends StatefulWidget {
  @override
  _PrinterScreenState createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  String _status = 'Ready';

  Future<void> _scanAndPrint() async {
    setState(() => _status = 'Requesting permissions...');

    // 1. Request permissions
    final granted = await ThunderThermalPrint.requestPermissions();
    if (!granted) {
      setState(() => _status = 'Permissions denied');
      return;
    }

    // 2. Scan for Bluetooth printers
    setState(() => _status = 'Scanning...');
    final devices = await ThunderThermalPrint.scanBluetooth(
      timeout: const Duration(seconds: 10),
    );

    if (devices.isEmpty) {
      setState(() => _status = 'No printers found');
      return;
    }

    // 3. Connect to the first device
    setState(() => _status = 'Connecting to ${devices.first.name}...');
    await ThunderThermalPrint.connectBluetooth(
      macAddress: devices.first.address,
      profile: PrinterProfile.epson,
    );

    // 4. Print a simple receipt
    final receipt = ReceiptBuilder(maxCharsPerLine: 32)
        .center().bold().text('MY STORE').normal()
        .line()
        .text('Thank you for shopping!')
        .feed(lines: 3)
        .cut();

    await ThunderThermalPrint.printReceipt(receipt);

    // 5. Disconnect
    await ThunderThermalPrint.disconnect();
    setState(() => _status = 'Print complete!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Thermal Print Demo')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_status),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _scanAndPrint,
              child: Text('Scan & Print'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🔍 Device Discovery

### Scanning for Bluetooth Printers

```dart
// Scan with default timeout (10 seconds)
final devices = await ThunderThermalPrint.scanBluetooth();

// Scan with custom timeout
final devices = await ThunderThermalPrint.scanBluetooth(
  timeout: const Duration(seconds: 15),
);

for (final device in devices) {
  print('Name: ${device.name}');
  print('Address: ${device.address}');
  print('Type: ${device.connectionType.displayName}');
  print('Signal: ${device.rssi ?? 'N/A'} dBm');
}
```

### Scanning for BLE Printers

```dart
final devices = await ThunderThermalPrint.scanBle(
  timeout: const Duration(seconds: 10),
);

for (final device in devices) {
  print('BLE Device: ${device.name} (${device.address})');
  // BLE devices may have service UUIDs in metadata
  print('Metadata: ${device.metadata}');
}
```

### Scanning for USB Printers

```dart
final devices = await ThunderThermalPrint.scanUsb();

for (final device in devices) {
  print('USB: ${device.name}');
  print('Vendor ID: ${device.vendorId}');
  print('Product ID: ${device.productId}');
}
```

### Scanning for Network Printers

```dart
// Auto-detect subnet
final devices = await ThunderThermalPrint.scanNetwork();

// Scan a specific subnet
final devices = await ThunderThermalPrint.scanNetwork(
  subnet: '192.168.1.0/24',
);

for (final device in devices) {
  print('Network Printer: ${device.name} at ${device.address}');
}
```

---

## 🔗 Connection

### Bluetooth Classic

```dart
await ThunderThermalPrint.connectBluetooth(
  macAddress: '00:11:22:33:44:55',
  profile: PrinterProfile.epson,
  autoReconnect: true,
  timeout: const Duration(seconds: 10),
);
```

### Bluetooth Low Energy

```dart
final devices = await ThunderThermalPrint.scanBle();
if (devices.isNotEmpty) {
  await ThunderThermalPrint.connectBle(
    deviceId: devices.first.address,
    profile: PrinterProfile.sunmi,
    autoReconnect: true,
  );
}
```

### USB

```dart
await ThunderThermalPrint.connectUsb(
  vendorId: 0x04B8,   // Example: Epson vendor ID
  productId: 0x0E03,  // Example: Epson TM-T88VI product ID
  profile: PrinterProfile.epson,
);
```

### Network (TCP/IP)

```dart
await ThunderThermalPrint.connectNetwork(
  ipAddress: '192.168.1.100',
  port: 9100,  // Standard ESC/POS port
  profile: PrinterProfile.xprinter,
  autoReconnect: true,
  timeout: const Duration(seconds: 5),
);
```

### Disconnecting

```dart
// Explicit disconnect
await ThunderThermalPrint.disconnect();

// Check if connected before acting
if (await ThunderThermalPrint.isConnected()) {
  await ThunderThermalPrint.disconnect();
}
```

---

## 📡 Connection State Monitoring

Subscribe to real-time connection state changes:

```dart
import 'dart:async';

StreamSubscription<PrinterConnectionState>? _connectionSub;

void _startMonitoring() {
  _connectionSub = ThunderThermalPrint.connectionStream.listen(
    (state) {
      switch (state) {
        case PrinterConnectionState.disconnected:
          print('Printer disconnected');
          break;
        case PrinterConnectionState.connecting:
          print('Connecting to printer...');
          break;
        case PrinterConnectionState.connected:
          print('Printer connected and ready!');
          break;
        case PrinterConnectionState.reconnecting:
          print('Attempting to reconnect...');
          break;
        case PrinterConnectionState.connectionLost:
          print('Connection lost unexpectedly');
          break;
        case PrinterConnectionState.reconnectFailed:
          print('Reconnect failed – manual action needed');
          break;
      }
    },
    onError: (error) {
      print('Connection stream error: $error');
    },
  );
}

void _stopMonitoring() {
  _connectionSub?.cancel();
  _connectionSub = null;
}
```

### In a Flutter Widget

```dart
class ConnectionStatusWidget extends StatefulWidget {
  @override
  _ConnectionStatusWidgetState createState() => _ConnectionStatusWidgetState();
}

class _ConnectionStatusWidgetState extends State<ConnectionStatusWidget> {
  PrinterConnectionState _state = PrinterConnectionState.disconnected;

  @override
  void initState() {
    super.initState();
    ThunderThermalPrint.connectionStream.listen((state) {
      setState(() => _state = state);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (_state) {
      PrinterConnectionState.connected => Colors.green,
      PrinterConnectionState.connecting ||
      PrinterConnectionState.reconnecting => Colors.orange,
      PrinterConnectionState.connectionLost ||
      PrinterConnectionState.reconnectFailed => Colors.red,
      _ => Colors.grey,
    };

    return Chip(
      avatar: CircleAvatar(backgroundColor: color),
      label: Text(_state.displayName),
    );
  }
}
```

---

## 📋 Device Event Monitoring

Monitor hardware events from the printer in real-time:

```dart
StreamSubscription<PrinterEvent>? _eventSub;

void _startEventListener() {
  _eventSub = ThunderThermalPrint.deviceEventStream.listen((event) {
    switch (event.type) {
      case PrinterEventType.paperOut:
        _showAlert('Paper Out', 'Please replace the paper roll.');
        break;
      case PrinterEventType.paperNearEnd:
        _showAlert('Paper Low', 'Paper is running low.');
        break;
      case PrinterEventType.coverOpen:
        _showAlert('Cover Open', 'Please close the printer cover.');
        break;
      case PrinterEventType.drawerOpen:
        print('Cash drawer opened');
        break;
      case PrinterEventType.batteryLow:
        _showAlert('Low Battery', 'Printer battery is low.');
        break;
      case PrinterEventType.error:
        _showAlert('Printer Error', event.message ?? 'Unknown error');
        break;
      default:
        print('Event: ${event.type.name} – ${event.message}');
    }
  });
}

void _showAlert(String title, String message) {
  // Show a SnackBar, Dialog, or send a notification
  print('$title: $message');
}
```

---

## 🖨️ Printing

### Text Printing

```dart
// Simple single line
await ThunderThermalPrint.printText('Hello, World!');

// Multiple lines
await ThunderThermalPrint.printLines([
  'Line 1: Item Name     Qty   Price',
  'Line 2: ─────────────────────────',
  'Line 3: Coffee         x2    \$5.00',
  'Line 4: Cake           x1    \$3.50',
]);
```

### QR Code Printing

```dart
// Print a URL QR code
await ThunderThermalPrint.printQrCode(
  'https://example.com/receipt/12345',
  size: 8,
);

// Print a payment QR code
await ThunderThermalPrint.printQrCode(
  'payment:alice@example.com:50.00:USD',
  size: 6,
);
```

### Barcode Printing

```dart
// CODE128 (default)
await ThunderThermalPrint.printBarcode('ORDER-12345', type: 'CODE128');

// EAN-13 retail barcode
await ThunderThermalPrint.printBarcode('5901234123457', type: 'EAN13');

// UPC-A
await ThunderThermalPrint.printBarcode('012345678905', type: 'UPCA');

// CODE39
await ThunderThermalPrint.printBarcode('ABC123', type: 'CODE39');

// ITF (numeric only)
await ThunderThermalPrint.printBarcode('12345678', type: 'ITF');
```

### Image Printing

```dart
import 'package:flutter/services.dart';

// Load an image from assets
final asset = await rootBundle.load('assets/logo.png');
final imageBytes = asset.buffer.asUint8List();

// Print the image – automatically resized and dithered
await ThunderThermalPrint.printImage(imageBytes);
```

### PDF Printing

```dart
final asset = await rootBundle.load('assets/invoice.pdf');
final pdfBytes = asset.buffer.asUint8List();

await ThunderThermalPrint.printPdf(pdfBytes);
```

### Raw Bytes

```dart
// Send custom ESC/POS commands directly
final bytes = [
  ...EscPosCommands.initialize(),
  ...EscPosCommands.alignCenter(),
  ...EscPosCommands.enableBold(),
  ...EscPosCommands.setTextSize(width: 2, height: 2),
  ...EscPosCommands.printText('BIG TEXT'),
  0x0A,
  ...EscPosCommands.feedLines(3),
  ...EscPosCommands.partialCut(),
];
await ThunderThermalPrint.printBytes(bytes);
```

---

## 🧾 Receipt Builder

The `ReceiptBuilder` provides a fluent, chainable API for composing
professional-looking thermal receipts with text styles, alignment, QR codes,
barcodes, images, separators, and paper cuts.

### Complete Example

```dart
final receipt = ReceiptBuilder(maxCharsPerLine: 32)
    // ── Header ──
    .center()
    .bold()
    .text('☕ COFFEE HOUSE')
    .normal()
    .text('123 Main Street')
    .text('Open: Mon-Fri 7AM-9PM')
    .emptyLine()
    .line()

    // ── Order info ──
    .left()
    .text('Order #INV-2024-001')
    .text('Date: Jan 15, 2024 09:42 AM')
    .text('Cashier: Sarah')
    .line()

    // ── Items ──
    .bold()
    .row(left: 'ITEM', right: 'AMOUNT')
    .normal()
    .line(char: '.', width: 32)

    .row(left: 'Espresso', right: '\$3.50')
    .row(left: '  x2', right: '\$7.00')
    .emptyLine()
    .row(left: 'Latte', right: '\$4.50')
    .row(left: '  x1', right: '\$4.50')
    .emptyLine()
    .row(left: 'Croissant', right: '\$2.75')
    .row(left: '  x3', right: '\$8.25')
    .emptyLine()
    .row(left: 'Blueberry Muffin', right: '\$3.00')
    .row(left: '  x1', right: '\$3.00')
    .line(char: '-', width: 32)

    // ── Totals ──
    .bold()
    .row(left: 'Subtotal', right: '\$22.75')
    .normal()
    .row(left: 'Tax (8.5%)', right: '\$1.93')
    .doubleLine()
    .doubleWidth()
    .row(left: 'TOTAL', right: '\$24.68')
    .normal()

    // ── Payment ──
    .line()
    .text('Payment: Visa ****4532')
    .text('Auth Code: 7F3A21')
    .text('Ref: TXN-20240115-094231')
    .line()

    // ── QR Code ──
    .center()
    .text('Scan for digital receipt')
    .qr('https://receipts.coffeehouse.com/inv/2024-001', size: 6)
    .emptyLine()

    // ── Footer ──
    .text('Thank you for visiting!')
    .text('★ ★ ★ ★ ★')
    .text('www.coffeehouse.com')
    .feed(lines: 2)
    .cut();

await ThunderThermalPrint.printReceipt(receipt);
```

### Builder API Reference

| Method | Description | Returns |
|--------|-------------|---------|
| `.text(String)` | Print text with current formatting | `ReceiptBuilder` |
| `.textWrapped(String)` | Print text with auto word-wrap (CJK-aware) | `ReceiptBuilder` |
| `.center()` / `.left()` / `.right()` | Set text alignment | `ReceiptBuilder` |
| `.bold()` | Enable bold/emphasized mode | `ReceiptBuilder` |
| `.normal()` | Reset all formatting to defaults | `ReceiptBuilder` |
| `.underline()` | Enable underline | `ReceiptBuilder` |
| `.doubleWidth()` | Enable double-width | `ReceiptBuilder` |
| `.doubleHeight()` | Enable double-height | `ReceiptBuilder` |
| `.doubleSize()` | Enable both double-width and double-height | `ReceiptBuilder` |
| `.fontA()` / `.fontB()` | Select font A or B | `ReceiptBuilder` |
| `.inverse()` | Enable white-on-black mode | `ReceiptBuilder` |
| `.line({String char, int? width})` | Print a separator line | `ReceiptBuilder` |
| `.doubleLine({int? width})` | Print `=` separator | `ReceiptBuilder` |
| `.row({left, right})` | Print a two-column row | `ReceiptBuilder` |
| `.row3({col1, col2, col3})` | Print a three-column row | `ReceiptBuilder` |
| `.qr(String data, {int size})` | Print a QR code | `ReceiptBuilder` |
| `.barcode(String data, {BarcodeType type})` | Print a barcode | `ReceiptBuilder` |
| `.image(Uint8List, {int? maxWidth})` | Print an image | `ReceiptBuilder` |
| `.feed({int lines})` | Feed paper lines | `ReceiptBuilder` |
| `.cut({bool partial})` | Cut the paper | `ReceiptBuilder` |
| `.beep({int count, int duration})` | Sound the buzzer | `ReceiptBuilder` |
| `.cashDrawer({int pin})` | Open cash drawer | `ReceiptBuilder` |
| `.emptyLine({int count})` | Print blank lines | `ReceiptBuilder` |
| `.lineSpacing(int spacing)` | Set line spacing in dots | `ReceiptBuilder` |
| `.resetLineSpacing()` | Reset to default line spacing | `ReceiptBuilder` |
| `.raw(List<int>)` | Append raw ESC/POS bytes | `ReceiptBuilder` |
| `.build()` | Build byte buffer (returns `List<int>`) | `List<int>` |
| `.buildAsUint8List()` | Build byte buffer as `Uint8List` | `Uint8List` |

---

## ⌨️ ESC/POS Commands

For advanced use cases, you can compose raw ESC/POS commands directly:

```dart
import 'package:thunder_thermal_print/thunder_thermal_print.dart';

void _printCustomReceipt() async {
  final bytes = [
    // Initialize printer
    ...EscPosCommands.initialize(),

    // Center + bold + double-size title
    ...EscPosCommands.alignCenter(),
    ...EscPosCommands.enableBold(),
    ...EscPosCommands.enableDoubleWidthAndHeight(),
    ...EscPosCommands.printText('RECEIPT'),
    0x0A, // Line feed

    // Reset formatting
    ...EscPosCommands.disableBold(),
    ...EscPosCommands.disableDoubleMode(),
    ...EscPosCommands.alignLeft(),

    // Set line spacing
    ...EscPosCommands.setLineSpacing(30),

    // Print separator
    ...EscPosCommands.printText('--------------------------------'),
    0x0A,

    // Print items
    ...EscPosCommands.printText('Coffee .............. \$3.50'),
    0x0A,
    ...EscPosCommands.printText('Cake ................ \$2.75'),
    0x0A,
    ...EscPosCommands.printText('--------------------------------'),
    0x0A,

    // Total in bold
    ...EscPosCommands.enableBold(),
    ...EscPosCommands.printText('TOTAL: \$6.25'),
    0x0A,
    ...EscPosCommands.disableBold(),

    // Feed and cut
    ...EscPosCommands.feedLines(3),
    ...EscPosCommands.partialCut(),
  ];

  await ThunderThermalPrint.printBytes(bytes);
}
```

### Available ESC/POS Commands

| Command | Description |
|---------|-------------|
| `EscPosCommands.initialize()` | Reset all settings to defaults |
| `EscPosCommands.enableBold()` / `disableBold()` | Toggle bold mode |
| `EscPosCommands.enableUnderline({mode})` / `disableUnderline()` | Toggle underline (1 or 2 dot) |
| `EscPosCommands.enableInverse()` / `disableInverse()` | Toggle white-on-black |
| `EscPosCommands.alignLeft()` / `alignCenter()` / `alignRight()` | Set text alignment |
| `EscPosCommands.setFontA()` / `setFontB()` | Select font |
| `EscPosCommands.setTextSize({width, height})` | Set text size (1-8x) |
| `EscPosCommands.enableDoubleWidth()` / `enableDoubleHeight()` | Double size shortcuts |
| `EscPosCommands.feedLines(int)` / `feedDots(int)` | Paper feed |
| `EscPosCommands.partialCut()` / `fullCut()` | Paper cut |
| `EscPosCommands.beep({count, duration})` | Sound buzzer |
| `EscPosCommands.openCashDrawer({pin})` | Cash drawer kick |
| `EscPosCommands.setLineSpacing(int)` / `resetLineSpacing()` | Line spacing |
| `EscPosCommands.setCodePage(int)` | Character code table |
| `EscPosCommands.printText(String)` | Encode text to bytes |
| `EscPosCommands.printQrCode(String, {size, errorCorrection})` | QR code |
| `EscPosCommands.printBarcode(String, {type, width, height})` | Barcode |
| `EscPosCommands.printRasterImage(List<int>, int)` | 1-bit raster image |
| `EscPosCommands.printImageFromBytes(Uint8List, int)` | PNG/JPEG image |

---

## 🖨️ Printer Profiles

Printer profiles configure ESC/POS behaviour for specific printer brands.
Each profile defines paper width, character limits, code page, and feature
support.

### Using Built-in Profiles

```dart
// Epson 58mm paper
await ThunderThermalPrint.connectBluetooth(
  macAddress: '00:11:22:33:44:55',
  profile: PrinterProfile.epson,
);

// Epson 80mm paper (wider, more characters per line)
await ThunderThermalPrint.connectBluetooth(
  macAddress: '00:11:22:33:44:55',
  profile: PrinterProfile.epson80,
);

// XPrinter (common budget brand)
await ThunderThermalPrint.connectNetwork(
  ipAddress: '192.168.1.100',
  profile: PrinterProfile.xprinter,
);

// Sunmi (Android POS devices)
await ThunderThermalPrint.connectBle(
  deviceId: 'device-id',
  profile: PrinterProfile.sunmi,
);
```

### Available Built-in Profiles

| Profile | Paper Width | Max Chars/Line | QR | Barcode | Image |
|---------|-------------|-----------------|----|---------|-------|
| `PrinterProfile.epson` | 48mm | 32 | ✅ | ✅ | ✅ |
| `PrinterProfile.epson80` | 80mm | 48 | ✅ | ✅ | ✅ |
| `PrinterProfile.xprinter` | 58mm | 32 | ✅ | ✅ | ✅ |
| `PrinterProfile.sunmi` | 58mm | 32 | ✅ | ✅ | ✅ |
| `PrinterProfile.bixolon` | 58mm | 32 | ✅ | ✅ | ✅ |
| `PrinterProfile.rongta` | 58mm | 32 | ✅ | ✅ | ✅ |
| `PrinterProfile.zjiang` | 58mm | 32 | ✅ | ✅ | ✅ |

### Custom Profiles

```dart
final customProfile = PrinterProfile.custom(
  name: 'My Custom Printer',
  paperWidth: 80,
  maxCharsPerLine: 48,
  codePage: 0,
  supportsQrCode: true,
  supportsBarcode: true,
  supportsImage: true,
  defaultDotsPerLine: 576,
  feedLines: 4,
  cutPulseDuration: 100,
);

await ThunderThermalPrint.connectNetwork(
  ipAddress: '192.168.1.200',
  profile: customProfile,
);
```

### Profile Lookup

```dart
// Look up a profile by name
final profile = PrinterProfile.lookup('Epson');
if (profile != null) {
  print('Found: ${profile.name} – ${profile.paperWidth}mm');
}

// List all available profiles
final names = PrinterProfile.availableProfiles;
print('Available: $names');
```

---

## 📊 Status Monitoring

```dart
Future<void> _checkPrinterStatus() async {
  if (!await ThunderThermalPrint.isConnected()) {
    print('No printer connected');
    return;
  }

  final status = await ThunderThermalPrint.getStatus();

  print('Online: ${status.online}');
  print('Paper out: ${status.paperOut}');
  print('Paper near end: ${status.paperNearEnd}');
  print('Cover open: ${status.coverOpen}');
  print('Battery: ${status.batteryLevel}%');
  print('Error: ${status.errorMessage}');

  if (status.canPrint) {
    await ThunderThermalPrint.printText('All good!');
  } else {
    // List what's preventing printing
    for (final issue in status.issues) {
      print('Issue: $issue');
    }
  }
}
```

---

## 🔐 Permission Management

### How Permissions Work Per Platform

#### Android

| Android Version | Required Permissions |
|----------------|---------------------|
| Android 12 (API 31) | `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT` |
| Android 11 (API 30) | `BLUETOOTH`, `ACCESS_FINE_LOCATION` |
| Android 10 and below | `BLUETOOTH`, `BLUETOOTH_ADMIN`, `ACCESS_FINE_LOCATION` |

USB host permission is requested at runtime when a USB device is connected.
No manifest permission is needed for USB on most devices.

#### iOS

| Permission | Usage Description Key |
|-----------|----------------------|
| Bluetooth | `NSBluetoothAlwaysUsageDescription` |
| Local Network | `NSLocalNetworkUsageDescription` |

The first time your app accesses Bluetooth or network scanning, iOS shows
the system permission dialog with the description you provided in `Info.plist`.

### Requesting Permissions

```dart
// Check before requesting
if (!await ThunderThermalPrint.checkPermissions()) {
  // Request all required permissions
  final granted = await ThunderThermalPrint.requestPermissions();

  if (!granted) {
    // Some permissions were denied. Show guidance:
    // - Android: direct user to app settings
    // - iOS: direct user to Settings > Privacy
    if (Platform.isAndroid) {
      await openAppSettings(); // from permission_handler package
    } else if (Platform.isIOS) {
      await openAppSettings();
    }
  }
}
```

---

## 🔄 Auto Reconnect

When enabled, the plugin automatically attempts to re-establish the printer
connection if it drops unexpectedly (e.g., the printer goes out of Bluetooth
range and comes back, or a network printer temporarily loses power).

### How It Works

1. When a connection drop is detected, the plugin enters
   [PrinterConnectionState.reconnecting] state.
2. Reconnection attempts use **exponential backoff** (1s, 2s, 4s, 8s, …
   up to 60s).
3. After a configurable number of retries, the plugin transitions to
   [PrinterConnectionState.reconnectFailed].
4. All state transitions are emitted via [connectionStream].

### Enabling Auto-Reconnect

```dart
await ThunderThermalPrint.connectBluetooth(
  macAddress: '00:11:22:33:44:55',
  autoReconnect: true,  // Enable auto-reconnect
);
```

### Monitoring Reconnection State

```dart
ThunderThermalPrint.connectionStream.listen((state) {
  if (state == PrinterConnectionState.reconnecting) {
    // Show a "Reconnecting..." indicator
    showReconnectingIndicator();
  } else if (state == PrinterConnectionState.reconnectFailed) {
    // Show error and prompt manual reconnection
    showManualReconnectPrompt();
  } else if (state == PrinterConnectionState.connected) {
    // Connection restored
    hideReconnectingIndicator();
  }
});
```

### Disabling Auto-Reconnect

Auto-reconnect is disabled by default. To disable it after it has been enabled,
simply disconnect and reconnect without the flag:

```dart
await ThunderThermalPrint.disconnect();
await ThunderThermalPrint.connectBluetooth(
  macAddress: '00:11:22:33:44:55',
  autoReconnect: false,
);
```

---

## ⚠️ Exception Handling

The plugin maps all native platform errors to typed Dart exceptions that
extend [PrinterException]. Always wrap printer operations in try-catch blocks.

### Exception Hierarchy

```
PrinterException (base)
├── ConnectionException
├── PermissionException
├── PaperOutException
├── CoverOpenException
├── DeviceNotFoundException
├── PrintTimeoutException
├── NotSupportedException
├── PrinterBusyException
└── InvalidDataException
```

### Comprehensive Error Handling

```dart
import 'package:thunder_thermal_print/thunder_thermal_print.dart';

Future<void> safePrint() async {
  try {
    // Check permissions first
    if (!await ThunderThermalPrint.checkPermissions()) {
      await ThunderThermalPrint.requestPermissions();
    }

    // Scan
    final devices = await ThunderThermalPrint.scanBluetooth();
    if (devices.isEmpty) {
      print('No printers found');
      return;
    }

    // Connect
    await ThunderThermalPrint.connectBluetooth(
      macAddress: devices.first.address,
      autoReconnect: true,
    );

    // Check status
    final status = await ThunderThermalPrint.getStatus();
    if (!status.canPrint) {
      print('Cannot print: ${status.issues.join(", ")}');
      return;
    }

    // Print
    final receipt = ReceiptBuilder(maxCharsPerLine: 32)
        .text('Hello World')
        .feed(lines: 3)
        .cut();
    await ThunderThermalPrint.printReceipt(receipt);

  } on PermissionException catch (e) {
    // Missing Bluetooth, location, or USB permission
    print('Permission denied: ${e.permissionName}');
    // Guide user to app settings

  } on ConnectionException catch (e) {
    // Bluetooth pairing failed, network unreachable, etc.
    print('Connection failed: ${e.message}');
    // Retry or show manual connect UI

  } on DeviceNotFoundException catch (e) {
    // The specified MAC address or device ID was not found
    print('Device not found: ${e.searchedAddress}');

  } on PaperOutException {
    // Printer reported paper is out
    print('Paper is out – please replace the roll');

  } on CoverOpenException {
    // Printer cover is open
    print('Printer cover is open');

  } on PrintTimeoutException catch (e) {
    // Operation took too long
    print('Print timed out after ${e.timeoutMs}ms');

  } on NotSupportedException catch (e) {
    // Feature not available on this platform/printer
    print('Not supported: ${e.feature}');

  } on PrinterBusyException {
    // Printer is processing a previous job
    print('Printer is busy – try again shortly');

  } on InvalidDataException catch (e) {
    // Malformed barcode data, invalid image format, etc.
    print('Invalid data: ${e.message}');

  } on PrinterException catch (e) {
    // Catch-all for any other printer error
    print('Printer error: ${e.message} (code: ${e.code})');

  } catch (e) {
    // Non-printer errors (e.g., programming errors)
    print('Unexpected error: $e');
  } finally {
    // Always disconnect when done
    await ThunderThermalPrint.disconnect();
  }
}
```

---

## 📱 Background Service (Android)

The plugin includes an optional Android foreground service that monitors
printer connections in the background. This is useful for scenarios where
the app needs to stay connected to a printer even when minimized or the
screen is off (e.g., a restaurant POS system).

### Enabling the Background Service

Add the service declaration to your `AndroidManifest.xml`:

```xml
<application>
  <service
    android:name="id.thunderlab.thunder_thermal_print.service.PrinterMonitorService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="connectedDevice" />
</application>
```

### How It Works

1. When you connect with `autoReconnect: true`, the background service
   may be started (on Android).
2. The service maintains a persistent Bluetooth socket or network connection.
3. Connection state changes are still emitted via [connectionStream], so
   your UI can react even when the app is in the background.
4. The service shows a persistent notification to comply with Android's
   foreground service requirements.

### Stopping the Service

The background service is automatically stopped when you call [disconnect] or
[dispose]. It is also stopped if the app is force-closed by the user.

---

## 🔧 Troubleshooting

### Common Issues & Solutions

#### 1. No printers found during Bluetooth scan

**Symptoms:** `scanBluetooth()` returns an empty list.

**Possible causes:**
- Bluetooth is disabled on the device.
- Location permission is not granted (required for Bluetooth scanning on Android < 12).
- The printer is not in pairing mode or not powered on.
- Bluetooth permissions were permanently denied.

**Solutions:**
```dart
// Check and request permissions
final granted = await ThunderThermalPrint.requestPermissions();
print('Permissions granted: $granted');

// Try with a longer timeout
final devices = await ThunderThermalPrint.scanBluetooth(
  timeout: const Duration(seconds: 30),
);

// Ensure the printer is powered on and in pairing mode
```

#### 2. Connection fails or times out

**Symptoms:** `ConnectionException` thrown when calling `connectBluetooth()`.

**Possible causes:**
- The printer is out of Bluetooth range.
- The printer is already connected to another device.
- The MAC address is incorrect.
- The Bluetooth adapter is busy.

**Solutions:**
```dart
try {
  await ThunderThermalPrint.connectBluetooth(
    macAddress: '00:11:22:33:44:55',
    timeout: const Duration(seconds: 15), // Increase timeout
  );
} on ConnectionException catch (e) {
  print('Connection failed: ${e.message}');
  // Retry once
  await Future.delayed(const Duration(seconds: 2));
  await ThunderThermalPrint.connectBluetooth(macAddress: '00:11:22:33:44:55');
}
```

#### 3. Printed text is garbled or has wrong characters

**Symptoms:** Text contains incorrect characters, boxes, or question marks.

**Possible causes:**
- Character encoding mismatch between the app and the printer.
- The printer uses a non-UTF-8 code page.

**Solutions:**
```dart
// Specify the correct code page for your printer
final bytes = [
  ...EscPosCommands.initialize(),
  ...EscPosCommands.setCodePage(16), // CP1252 (Western European)
  ...EscPosCommands.printText('Café résumé naïve'),
  0x0A,
];
await ThunderThermalPrint.printBytes(bytes);
```

#### 4. QR code not printing

**Symptoms:** Nothing is printed, or `[NotSupportedException]` is thrown.

**Possible causes:**
- The printer does not support QR code commands.
- The printer uses a different QR code command set.

**Solutions:**
```dart
// Check if QR is supported
final supported = await ThunderThermalPrint.isFeatureSupported('qrCode');
if (supported) {
  await ThunderThermalPrint.printQrCode('https://example.com', size: 6);
} else {
  print('QR codes not supported on this printer');
}
```

#### 5. Image too large or corrupted

**Symptoms:** Image is printed with artifacts, is truncated, or not printed at all.

**Solutions:**
```dart
// Use the receipt builder's maxWidth to constrain the image
final receipt = ReceiptBuilder(maxCharsPerLine: 32)
    .center()
    .image(imageBytes, maxWidth: 256)  // Constrain width in dots
    .feed(lines: 3)
    .cut();
await ThunderThermalPrint.printReceipt(receipt);
```

#### 6. Auto-reconnect not working

**Symptoms:** Connection drops and is not restored automatically.

**Solutions:**
- Ensure `autoReconnect: true` is set when connecting.
- Monitor the [connectionStream] for state transitions.
- Check that the background service is running (Android).

```dart
// Enable auto-reconnect
await ThunderThermalPrint.connectBluetooth(
  macAddress: '00:11:22:33:44:55',
  autoReconnect: true,
);

// Monitor state
ThunderThermalPrint.connectionStream.listen((state) {
  print('State: ${state.displayName}');
});
```

#### 7. Network printer not discovered

**Symptoms:** `scanNetwork()` returns empty.

**Solutions:**
- Ensure the printer and phone are on the same Wi-Fi network.
- Try specifying the subnet explicitly:
  ```dart
  final devices = await ThunderThermalPrint.scanNetwork(
    subnet: '192.168.1.0/24',
  );
  ```
- Try connecting directly if you know the IP address:
  ```dart
  await ThunderThermalPrint.connectNetwork(
    ipAddress: '192.168.1.100',
  );
  ```

---

## 📖 API Reference

### ThunderThermalPrint (Static Methods)

#### Device Discovery

| Method | Returns | Description |
|--------|---------|-------------|
| `scanBluetooth({Duration? timeout})` | `Future<List<PrinterDevice>>` | Scan for Bluetooth printers |
| `scanBle({Duration? timeout})` | `Future<List<PrinterDevice>>` | Scan for BLE printers |
| `scanUsb()` | `Future<List<PrinterDevice>>` | Scan for USB printers |
| `scanNetwork({String? subnet})` | `Future<List<PrinterDevice>>` | Scan for network printers |

#### Connection

| Method | Returns | Description |
|--------|---------|-------------|
| `connectBluetooth({required String macAddress, PrinterProfile? profile, bool autoReconnect, Duration? timeout})` | `Future<void>` | Connect via Bluetooth |
| `connectBle({required String deviceId, PrinterProfile? profile, bool autoReconnect, Duration? timeout})` | `Future<void>` | Connect via BLE |
| `connectUsb({required int vendorId, required int productId, PrinterProfile? profile, bool autoReconnect, Duration? timeout})` | `Future<void>` | Connect via USB |
| `connectNetwork({required String ipAddress, int port, PrinterProfile? profile, bool autoReconnect, Duration? timeout})` | `Future<void>` | Connect via TCP/IP |
| `disconnect()` | `Future<void>` | Disconnect current printer |
| `isConnected()` | `Future<bool>` | Check connection state |

#### Status

| Method | Returns | Description |
|--------|---------|-------------|
| `getStatus()` | `Future<PrinterStatus>` | Get printer hardware status |

#### Printing

| Method | Returns | Description |
|--------|---------|-------------|
| `printBytes(List<int> bytes)` | `Future<void>` | Send raw bytes |
| `printText(String text)` | `Future<void>` | Print single line |
| `printLines(List<String> lines)` | `Future<void>` | Print multiple lines |
| `printQrCode(String data, {int size})` | `Future<void>` | Print QR code |
| `printBarcode(String data, {String type})` | `Future<void>` | Print barcode |
| `printImage(Uint8List imageBytes)` | `Future<void>` | Print raster image |
| `printPdf(Uint8List pdfBytes)` | `Future<void>` | Print PDF |
| `printReceipt(ReceiptBuilder receipt)` | `Future<void>` | Print built receipt |
| `printReceiptBytes(List<int> bytes)` | `Future<void>` | Print raw receipt bytes |

#### Hardware Control

| Method | Returns | Description |
|--------|---------|-------------|
| `openCashDrawer({int pin})` | `Future<void>` | Open cash drawer |

#### Permissions

| Method | Returns | Description |
|--------|---------|-------------|
| `requestPermissions()` | `Future<bool>` | Request required permissions |
| `checkPermissions()` | `Future<bool>` | Check permission status |

#### Streams

| Property | Type | Description |
|----------|------|-------------|
| `connectionStream` | `Stream<PrinterConnectionState>` | Connection state events |
| `deviceEventStream` | `Stream<PrinterEvent>` | Hardware events |

#### Platform

| Method | Returns | Description |
|--------|---------|-------------|
| `getPlatformVersion()` | `Future<String>` | Native plugin version |
| `isFeatureSupported(String feature)` | `Future<bool>` | Check feature support |
| `dispose()` | `Future<void>` | Release all resources |

---

## 🧪 Testing

To mock the platform implementation for unit tests:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_thermal_print/thunder_thermal_print.dart';
import 'package:thunder_thermal_print/src/services/services.dart';

class MockPrinterPlatform extends ThunderThermalPrintPlatform {
  @override
  Future<List<PrinterDevice>> scanBluetooth({Duration? timeout}) async {
    return [
      PrinterDevice(
        address: '00:11:22:33:44:55',
        name: 'Mock Printer',
        connectionType: PrinterConnectionType.bluetooth,
        rssi: -50,
      ),
    ];
  }

  @override
  Future<void> connectBluetooth({
    required String macAddress,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) async {
    // Mock connection logic
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<bool> isConnected() async => true;

  @override
  Future<PrinterStatus> getStatus() async => PrinterStatus(online: true);

  @override
  Future<void> printBytes(List<int> bytes) async {}

  @override
  Future<void> printText(String text) async {}

  @override
  Future<void> printLines(List<String> lines) async {}

  @override
  Future<void> printQrCode(String data, {int size = 6}) async {}

  @override
  Future<void> printBarcode(String data, {String type = 'CODE128'}) async {}

  @override
  Future<void> printImage(Uint8List imageBytes) async {}

  @override
  Future<void> printPdf(Uint8List pdfBytes) async {}

  @override
  Future<void> printReceipt(List<int> receiptBytes) async {}

  @override
  Future<void> openCashDrawer({int pin = 0}) async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> checkPermissions() async => true;

  @override
  Future<String> getPlatformVersion() async => 'mock-1.0.0';

  @override
  Future<bool> isFeatureSupported(String feature) async => true;

  @override
  Future<List<PrinterDevice>> scanBle({Duration? timeout}) async => [];

  @override
  Future<List<PrinterDevice>> scanUsb() async => [];

  @override
  Future<List<PrinterDevice>> scanNetwork({String? subnet}) async => [];

  @override
  Future<void> connectBle({
    required String deviceId,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) async {}

  @override
  Future<void> connectUsb({
    required int vendorId,
    required int productId,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) async {}

  @override
  Future<void> connectNetwork({
    required String ipAddress,
    int port = 9100,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) async {}
}

void main() {
  setUp(() {
    ThunderThermalPrintPlatform.instance = MockPrinterPlatform();
  });

  test('scanBluetooth returns mock devices', () async {
    final devices = await ThunderThermalPrint.scanBluetooth();
    expect(devices.length, 1);
    expect(devices.first.name, 'Mock Printer');
  });
}
```

---

## 📄 License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE)
file for details.

---

## 🙏 Credits

- **Thunder Lab** – Development and maintenance
- ESC/POS command reference from the Epson TM Series technical manual
- Built with [Flutter](https://flutter.dev) and [Dart](https://dart.dev)
