import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:thunder_thermal_print/src/services/services.dart';

import '../../thunder_thermal_print.dart';
import '../models/models.dart';

/// Platform-agnostic interface for the thermal printer plugin.
///
/// All platform-specific implementations (Android, iOS, etc.) must extend
/// this class and override every method. The default instance is
/// [MethodChannelThunderThermalPrint], which communicates with the native
/// side via [MethodChannel] and [EventChannel].
///
/// Use [ThunderThermalPrintPlatform.instance] to access the current platform
/// implementation, or replace it for testing:
/// ```dart
/// ThunderThermalPrintPlatform.instance = MyMockPlatform();
/// ```
abstract class ThunderThermalPrintPlatform {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  static ThunderThermalPrintPlatform? _instance;

  /// Returns the current [ThunderThermalPrintPlatform] instance.
  ///
  /// If no instance has been set, a default [MethodChannelThunderThermalPrint]
  /// is created automatically.
  static ThunderThermalPrintPlatform get instance {
    _instance ??= MethodChannelThunderThermalPrint();
    return _instance!;
  }

  /// Replaces the current platform instance.
  ///
  /// Setting this to `null` will cause the next access to [instance] to
  /// create a fresh [MethodChannelThunderThermalPrint].
  static set instance(ThunderThermalPrintPlatform? instance) {
    _instance = instance;
  }

  // ---------------------------------------------------------------------------
  // Device Discovery
  // ---------------------------------------------------------------------------

  /// Scans for classic Bluetooth printers.
  ///
  /// [timeout] overrides the default scan duration. If omitted the native
  /// side chooses a sensible default (typically 10 seconds).
  Future<List<PrinterDevice>> scanBluetooth({Duration? timeout});

  /// Scans for Bluetooth Low Energy (BLE) printers.
  ///
  /// [timeout] overrides the default scan duration.
  Future<List<PrinterDevice>> scanBle({Duration? timeout});

  /// Scans for USB-connected printers.
  Future<List<PrinterDevice>> scanUsb();

  /// Scans for network printers on the local network.
  ///
  /// [subnet] optionally restricts the scan to a specific subnet
  /// (e.g. `'192.168.1.0/24'`). If omitted the plugin discovers the
  /// current subnet automatically.
  Future<List<PrinterDevice>> scanNetwork({String? subnet});

  // ---------------------------------------------------------------------------
  // Connection Management
  // ---------------------------------------------------------------------------

  /// Connects to a classic Bluetooth printer identified by [macAddress].
  ///
  /// [profile] customises ESC/POS behaviour for the target printer.
  /// When [autoReconnect] is `true` the plugin will attempt to re-establish
  /// the connection if it drops unexpectedly.
  /// [timeout] limits the time spent waiting for the connection to succeed.
  Future<void> connectBluetooth({
    required String macAddress,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  });

  /// Connects to a BLE printer identified by platform [deviceId].
  Future<void> connectBle({
    required String deviceId,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  });

  /// Connects to a USB printer identified by [vendorId] and [productId].
  Future<void> connectUsb({
    required int vendorId,
    required int productId,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  });

  /// Connects to a network (TCP/IP) printer at [ipAddress]:[port].
  Future<void> connectNetwork({
    required String ipAddress,
    int port = 9100,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  });

  /// Disconnects the currently connected printer.
  Future<void> disconnect();

  /// Returns `true` when a printer is currently connected.
  Future<bool> isConnected();

  // ---------------------------------------------------------------------------
  // Printer Status
  // ---------------------------------------------------------------------------

  /// Queries the printer for its current hardware status.
  Future<Map<String, dynamic>> getStatus();

  /// Returns printer capabilities.
  Future<Map<String, dynamic>> getPrinterCapabilities();

  /// Returns total printed bytes count.
  Future<int?> getPrintedBytesCount();

  // ---------------------------------------------------------------------------
  // Background Service (Android only)
  // ---------------------------------------------------------------------------

  /// Starts background monitoring service.
  Future<void> startBackgroundMonitoring();

  /// Stops background monitoring service.
  Future<void> stopBackgroundMonitoring();

  /// Checks if background monitoring is active.
  Future<bool> isBackgroundMonitoringActive();

  // ---------------------------------------------------------------------------
  // Printer Profiles & Persistence
  // ---------------------------------------------------------------------------

  /// Saves a printer profile for later use.
  Future<void> savePrinterProfile(PrinterDevice device);

  /// Loads a saved printer profile by id.
  Future<PrinterDevice?> loadPrinterProfile(String id);

  /// Sets the default printer.
  Future<void> setDefaultPrinter(PrinterDevice device);

  /// Gets list of paired Bluetooth devices.
  Future<List<PrinterDevice>> getPairedDevices();

  // ---------------------------------------------------------------------------
  // Print Operations
  // ---------------------------------------------------------------------------

  /// Sends raw bytes directly to the printer.
  Future<void> printBytes(List<int> bytes);

  /// Prints a single-line text string.
  Future<void> printText(String text);

  /// Prints multiple text lines with automatic line-feeding.
  Future<void> printLines(List<String> lines);

  /// Prints a QR code containing [data].
  ///
  /// [size] controls the module size in dots (default 6).
  Future<void> printQrCode(String data, {int size = 6});

  /// Prints a 1-D barcode containing [data].
  ///
  /// [type] specifies the barcode symbology, e.g. `'CODE128'`, `'EAN13'`.
  Future<void> printBarcode(String data, {String type = 'CODE128'});

  /// Prints a raster image from raw image [imageBytes] (e.g. PNG, JPEG).
  Future<void> printImage(Uint8List imageBytes);

  /// Renders and prints a PDF document from [pdfBytes].
  Future<void> printPdf(Uint8List pdfBytes);

  /// Sends pre-formatted receipt bytes (already encoded with ESC/POS
  /// commands) directly to the printer.
  Future<void> printReceipt(List<int> receiptBytes);

  // ---------------------------------------------------------------------------
  // Cash Drawer
  // ---------------------------------------------------------------------------

  /// Sends the pulse signal to open the cash drawer on [pin].
  ///
  /// Most printers support pin `0` (default) and pin `1`.
  Future<void> openCashDrawer({int pin = 0});

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  /// Requests all runtime permissions required for printer operations.
  ///
  /// Returns `true` if all required permissions were granted.
  Future<bool> requestPermissions();

  /// Checks whether all required permissions are currently granted.
  Future<bool> checkPermissions();

  // ---------------------------------------------------------------------------
  // Platform Info
  // ---------------------------------------------------------------------------

  /// Returns a human-readable string identifying the native SDK version.
  Future<String> getPlatformVersion();

  /// Returns `true` when the current platform supports the named [feature].
  ///
  /// Common feature names include `'bluetooth'`, `'ble'`, `'usb'`,
  /// `'network'`, `'qrCode'`, `'barcode'`, `'image'`, `'pdf'`,
  /// `'cashDrawer'`.
  Future<bool> isFeatureSupported(String feature);
}