# Changelog

## 1.1.0

### USB Improvements
- ✅ **New `requestUsbPermission()` method** – Request USB permission without connecting (early permission prompt)
- ✅ **Auto-reconnect enabled by default** for USB connections (`autoReconnect` now defaults to `true`)
- ✅ **Auto-reconnect on sendData** – If the USB printer is turned off and on, `sendData()` will attempt a reconnect before failing
- ✅ **Improved error reporting** – `connectUsb()` now throws `PermissionException` or `ConnectionException` instead of silent failure
- ✅ **Fixed connection state EventChannel** – Native connection state events (Map format) are now properly parsed on the Dart side
- ✅ **USB permission status in scan results** – `PrinterDevice.usbPermissionGranted` shows whether permission is already granted

### Connection Manager
- ✅ **New `ensureUsbConnected()` method** – Check USB connection and auto-connect if needed
- ✅ **USB reconnect support in ConnectionManager** – USB devices are now tracked in `_activeConfig` for proper reconnection
- ✅ **Updated example app defaults** – `autoReconnect: true` now the default for USB

## 1.0.0 - Initial Release

### Core Features
- ✅ Bluetooth Classic printer support (Android, macOS)
- ✅ Bluetooth Low Energy (BLE) printer support (Android, iOS, Web)
- ✅ USB printer support (Android, Windows, Linux, macOS, Web)
- ✅ Network/TCP/IP printer support (All platforms)
- ✅ ESC/POS command library
- ✅ Receipt Builder with fluent API
- ✅ QR Code printing
- ✅ Barcode printing (CODE128, EAN13, EAN8, UPCA, CODE39, ITF, CODABAR)
- ✅ Image printing (PNG, JPEG)
- ✅ PDF printing (Android only)
- ✅ Cash drawer control

### Printer Profiles
- ✅ Epson (58mm, 80mm)
- ✅ XPrinter
- ✅ Sunmi
- ✅ Bixolon
- ✅ Rongta
- ✅ ZJiang
- ✅ Custom profile support

### Connection Management
- ✅ Auto-reconnect with exponential backoff
- ✅ Connection state monitoring (real-time stream)
- ✅ Device event monitoring (real-time stream)
- ✅ Connection lifecycle management

### Device Discovery
- ✅ Bluetooth Classic scanning
- ✅ BLE scanning
- ✅ USB device enumeration
- ✅ Network subnet scanning
- ✅ Paired device listing
- ✅ Scan all device types

### Printer Status & Monitoring
- ✅ Printer status query (online, paper, cover, drawer, battery)
- ✅ Real-time connection state stream
- ✅ Real-time printer event stream
- ✅ Paper status checking
- ✅ Printer capabilities query

### Platform Support
- ✅ Android (Kotlin) - Full implementation
  - Bluetooth Classic & BLE
  - USB Host mode
  - Network TCP/IP
  - Background service for monitoring
  - USB hot-plug detection
  - Auto-reconnect
- ✅ iOS (Swift) - BLE & Network
  - BLE support via CoreBluetooth
  - Network support
- ✅ Windows (C++) - USB & Network
  - USB via SetupAPI/WinUSB
  - Network via WinSock2
- ✅ Linux (C) - USB & Network
  - USB via libusb
  - Network via POSIX sockets
- ✅ macOS (Swift) - USB & Network
  - USB via IOKit
  - Network via Network framework
- ✅ Web (Dart) - Experimental
  - BLE via Web Bluetooth API
  - USB via WebUSB API
  - Network via WebSocket

### Error Handling
- ✅ Typed exceptions (PrinterException, ConnectionException, PermissionException, etc.)
- ✅ Graceful error recovery
- ✅ Retry with exponential backoff
- ✅ Timeout handling

### Architecture
- ✅ Factory Pattern for printer handlers
- ✅ Facade Pattern (ThunderThermalPrint)
- ✅ Observer Pattern (streams)
- ✅ Builder Pattern (ReceiptBuilder)
- ✅ Strategy Pattern (platform implementations)
- ✅ Singleton Pattern (ThunderThermalPrint)
- ✅ Stream-based event system

### Testing
- ✅ Unit tests for ESC/POS commands
- ✅ Unit tests for models
- ✅ Unit tests for receipt builder
- ✅ Unit tests for exceptions
- ✅ Unit tests for streams
- ✅ Integration tests

### Documentation
- ✅ Comprehensive README
- ✅ API documentation (dartdoc)
- ✅ Example applications for all connection types
- ✅ Troubleshooting guide
