# Thunder Thermal Print

[![pub package](https://img.shields.io/pub/v/thunder_thermal_print.svg)](https://pub.dev/packages/thunder_thermal_print)
[![likes](https://img.shields.io/pub/likes/thunder_thermal_print)](https://pub.dev/packages/thunder_thermal_print)
[![popularity](https://img.shields.io/pub/popularity/thunder_thermal_print)](https://pub.dev/packages/thunder_thermal_print)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Universal Flutter Thermal Printer Plugin with Bluetooth, BLE, USB, LAN, WiFi, TCP/IP, and ESC/POS support for Android, iOS, Windows, Linux, macOS, and Web.

## Features

| Feature | Android | iOS | Windows | Linux | macOS | Web |
|---------|---------|-----|---------|-------|-------|-----|
| Bluetooth Classic | ✅ | ❌ | ❌ | ❌ | ⚠️ | ❌ |
| BLE | ✅ | ✅ | ⚠️ | ❌ | ❌ | ✅ |
| USB | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Network (TCP/IP) | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| ESC/POS Commands | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ |
| Receipt Builder | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| QR Code Printing | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Barcode Printing | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Image Printing | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Auto Reconnect | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Background Service | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| USB Hot-Plug Detection | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ |
| Real-time Status | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Connection Monitoring | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  thunder_thermal_print: ^1.0.0
```

## Quick Start

```dart
import 'package:thunder_thermal_print/thunder_thermal_print.dart';

// 1. Scan for printers
final devices = await ThunderThermalPrint.scanBluetooth();
final bleDevices = await ThunderThermalPrint.scanBle();
final usbDevices = await ThunderThermalPrint.scanUsb();
final networkDevices = await ThunderThermalPrint.scanNetwork();

// 2. Connect to a printer
await ThunderThermalPrint.connectBluetooth(
  macAddress: '00:11:22:33:44:55',
  profile: PrinterProfile.epson,
  autoReconnect: true,
);

// Or connect via network
await ThunderThermalPrint.connectNetwork(
  ipAddress: '192.168.1.100',
  port: 9100,
);

// 3. Print a receipt
final receipt = ReceiptBuilder(maxCharsPerLine: 32)
    .center()
    .bold()
    .text('MY STORE')
    .normal()
    .line()
    .row(left: 'Item A', right: '\$10.00')
    .row(left: 'Item B', right: '\$20.00')
    .line()
    .row(left: 'TOTAL', right: '\$30.00')
    .feed(lines: 3)
    .cut();

await ThunderThermalPrint.printReceipt(receipt);

// 4. Disconnect
await ThunderThermalPrint.disconnect();
```

## Platform Setup

### Android

Add permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest>
    <!-- Bluetooth Classic -->
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    
    <!-- Bluetooth for Android 12+ -->
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
    
    <!-- Location for Bluetooth scanning -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    
    <!-- Network -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <!-- USB -->
    <uses-feature android:name="android.hardware.usb.host" android:required="false" />
    
    <!-- Foreground service for background monitoring -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    
    <application>
        <service
            android:name="id.thunderlab.thunder_thermal_print.service.PrinterMonitorService"
            android:foregroundServiceType="connectedDevice" />
    </application>
</manifest>
```

Minimum SDK: 21 (Android 5.1)

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs access to Bluetooth to connect to thermal printers</string>
<key>NSBluetoothCentralUsageDescription</key>
<string>This app needs access to Bluetooth to scan and connect to printers</string>
<key>NSLocalNetworkUsageDescription</key>
<string>This app needs access to local network to connect to network printers</string>
<key>NSBonjourServices</key>
<array>
    <string>_printer._tcp</string>
</array>
```

Minimum deployment target: 12.0

### Windows

No additional setup required. Requires Windows 10 or later.

### Linux

Install required system libraries:

```bash
sudo apt-get install -y libusb-1.0-0-dev libcups2-dev libbluetooth-dev
```

Add user to dialout group for USB access:

```bash
sudo usermod -a -G dialout $USER
```

### macOS

Add to `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.device.usb</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

### Web

Web support requires:
- Chrome, Edge, or Opera browser
- HTTPS connection (or localhost for development)
- User gesture required for device connection (browser security)

## API Reference

### Device Discovery

```dart
// Scan for Bluetooth Classic devices
final bluetoothDevices = await ThunderThermalPrint.scanBluetooth(
  timeout: const Duration(seconds: 10),
);

// Scan for BLE devices
final bleDevices = await ThunderThermalPrint.scanBle();

// Scan for USB devices
final usbDevices = await ThunderThermalPrint.scanUsb();

// Scan for network printers
final networkDevices = await ThunderThermalPrint.scanNetwork(
  subnet: '192.168.1.0/24',
);

// Scan all types at once
final allDevices = await ThunderThermalPrint.scanAll();

// Get paired Bluetooth devices
final pairedDevices = await ThunderThermalPrint.getPairedDevices();
```

### Connection

```dart
// Bluetooth Classic
await ThunderThermalPrint.connectBluetooth(
  macAddress: '00:11:22:33:44:55',
  profile: PrinterProfile.epson,
  autoReconnect: true,
  timeout: const Duration(seconds: 15),
);

// BLE
await ThunderThermalPrint.connectBle(
  deviceId: 'device-uuid',
  profile: PrinterProfile.sunmi,
);

// USB
await ThunderThermalPrint.connectUsb(
  vendorId: 0x04B8,
  productId: 0x0E03,
  profile: PrinterProfile.epson,
);

// Network
await ThunderThermalPrint.connectNetwork(
  ipAddress: '192.168.1.100',
  port: 9100,
  autoReconnect: true,
);

// Check connection
final isConnected = await ThunderThermalPrint.isConnected();

// Disconnect
await ThunderThermalPrint.disconnect();
```

### Printing

```dart
// Raw bytes
await ThunderThermalPrint.printBytes([0x1B, 0x40]);

// Text
await ThunderThermalPrint.printText('Hello World');

// Multiple lines
await ThunderThermalPrint.printLines(['Line 1', 'Line 2', 'Line 3']);

// QR Code
await ThunderThermalPrint.printQrCode('https://example.com', size: 6);

// Barcode
await ThunderThermalPrint.printBarcode('1234567890128', type: 'EAN13');

// Image
final imageBytes = await rootBundle.load('assets/logo.png');
await ThunderThermalPrint.printImage(imageBytes.buffer.asUint8List());

// PDF
final pdfBytes = await rootBundle.load('assets/receipt.pdf');
await ThunderThermalPrint.printPdf(pdfBytes.buffer.asUint8List());

// Receipt (recommended)
final receipt = ReceiptBuilder(maxCharsPerLine: 32)
    .center()
    .bold()
    .text('STORE NAME')
    .normal()
    .line()
    .row(left: 'Item', right: '\$10.00')
    .feed(lines: 3)
    .cut();

await ThunderThermalPrint.printReceipt(receipt);

// Cash drawer
await ThunderThermalPrint.openCashDrawer(pin: 0);
```

### Printer Status & Monitoring

```dart
// Get printer status
final status = await ThunderThermalPrint.getStatus();
print('Online: ${status.online}');
print('Paper out: ${status.paperOut}');
print('Cover open: ${status.coverOpen}');
print('Can print: ${status.canPrint}');
print('Issues: ${status.issues}');

// Monitor connection state
ThunderThermalPrint.connectionStream.listen((state) {
  print('Connection: ${state.displayName}');
});

// Monitor printer events
ThunderThermalPrint.deviceEventStream.listen((event) {
  print('Event: ${event.type.name}');
  if (event.type == PrinterEventType.paperOut) {
    print('Paper is out!');
  }
});
```

### Printer Profiles

```dart
// Built-in profiles
PrinterProfile.epson      // Epson 58mm
PrinterProfile.epson80    // Epson 80mm
PrinterProfile.xprinter   // XPrinter
PrinterProfile.sunmi      // Sunmi
PrinterProfile.bixolon    // Bixolon
PrinterProfile.rongta     // Rongta
PrinterProfile.zjiang     // ZJiang

// Custom profile
final customProfile = PrinterProfile.custom(
  name: 'My Printer',
  paperWidth: 58,
  maxCharsPerLine: 32,
  supportsQrCode: true,
  supportsBarcode: true,
  supportsImage: true,
);
```

### Permissions

```dart
// Request all required permissions
final granted = await ThunderThermalPrint.requestPermissions();

// Check current permissions
final hasPermission = await ThunderThermalPrint.checkPermissions();
```

### ESC/POS Commands

```dart
import 'package:thunder_thermal_print/thunder_thermal_print.dart';

// Build custom ESC/POS commands
final bytes = [
  ...EscPosCommands.initialize(),
  ...EscPosCommands.alignCenter(),
  ...EscPosCommands.enableBold(),
  ...EscPosCommands.printText('Hello World'),
  ...EscPosCommands.feedLines(3),
  ...EscPosCommands.partialCut(),
];

await ThunderThermalPrint.printBytes(bytes);
```

### Receipt Builder (Fluent API)

```dart
final receipt = ReceiptBuilder(maxCharsPerLine: 32)
    .center()
    .bold()
    .text('STORE NAME')
    .normal()
    .line()
    .row(left: 'Subtotal', right: '\$100.00')
    .row(left: 'Tax', right: '\$10.00')
    .doubleLine()
    .bold()
    .row(left: 'TOTAL', right: '\$110.00')
    .normal()
    .feed(lines: 2)
    .center()
    .text('Thank you!')
    .feed(lines: 3)
    .cut();

await ThunderThermalPrint.printReceipt(receipt);
```

## Supported ESC/POS Commands

- ✅ Initialize Printer (`ESC @`)
- ✅ Bold (`ESC E`)
- ✅ Underline (`ESC -`)
- ✅ Inverse (`GS B`)
- ✅ Align Left/Center/Right (`ESC a`)
- ✅ Font A / Font B (`ESC M`)
- ✅ Double Width (`GS !`)
- ✅ Double Height (`GS !`)
- ✅ Feed Paper (`ESC d`)
- ✅ Partial Cut (`GS V B`)
- ✅ Full Cut (`GS V`)
- ✅ Beep (`ESC B`)
- ✅ Cash Drawer (`ESC p`)
- ✅ QR Code (`GS ( k`)
- ✅ Barcode (`GS k`)
- ✅ Raster Image (`GS v 0`)

## Error Handling

```dart
try {
  await ThunderThermalPrint.connectBluetooth(macAddress: '00:11:22:33:44:55');
} on PermissionException catch (e) {
  print('Permission denied: ${e.message}');
} on ConnectionException catch (e) {
  print('Connection failed: ${e.message}');
} on DeviceNotFoundException catch (e) {
  print('Device not found: ${e.searchedAddress}');
} on PrintTimeoutException catch (e) {
  print('Timeout: ${e.timeoutMs}ms');
} on PaperOutException catch (e) {
  print('Paper out!');
} on CoverOpenException catch (e) {
  print('Cover is open!');
} on PrinterException catch (e) {
  print('Printer error: ${e.message}');
}
```

## Troubleshooting

### Bluetooth not scanning on Android
- Ensure location permissions are granted
- Check if Bluetooth is enabled
- For Android 12+, ensure `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` permissions are granted

### BLE connection fails on iOS
- Ensure `NSBluetoothPeripheralUsageDescription` is in Info.plist
- Check if the printer supports BLE
- Restart the printer and try again

### USB not detected on Linux
- Add user to `dialout` group: `sudo usermod -a -G dialout $USER`
- Log out and log back in for changes to take effect
- Check if `libusb` is installed

### Network printer not found
- Verify the printer IP address is correct
- Ensure the printer is on the same network
- Check firewall settings
- Try port 9100, 9101, or 9102

### Web Bluetooth not working
- Must use Chrome, Edge, or Opera
- Requires HTTPS (or localhost)
- User gesture required to trigger device selection

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- [GitHub Issues](https://github.com/thunderlabs/thunder_thermal_print/issues)
- [Pub.dev](https://pub.dev/packages/thunder_thermal_print)
- [Example App](example/)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes.
