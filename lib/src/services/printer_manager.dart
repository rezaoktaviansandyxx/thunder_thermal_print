import 'dart:async';
import 'dart:typed_data';

import '../models/models.dart';
import '../receipt/receipt_builder.dart';
import '../services/thermal_print_platform_interface.dart';
import '../streams/connection_stream.dart';
import '../streams/device_event_stream.dart';
import 'connection_manager.dart';
import 'device_scanner.dart';
import 'printer_status_service.dart';

class PrinterManager {
  PrinterManager._();

  // Device Discovery
  static Future<List<PrinterDevice>> scanBluetooth({Duration? timeout}) {
    return DeviceScanner.scanBluetooth(timeout: timeout);
  }

  static Future<List<PrinterDevice>> scanBle({Duration? timeout}) {
    return DeviceScanner.scanBle(timeout: timeout);
  }

  static Future<List<PrinterDevice>> scanUsb() {
    return DeviceScanner.scanUsb();
  }

  static Future<List<PrinterDevice>> scanNetwork({String? subnet}) {
    return DeviceScanner.scanNetwork(subnet: subnet);
  }

  static Future<List<PrinterDevice>> scanAll({
    Duration? timeout,
    bool includeBluetooth = true,
    bool includeBle = true,
    bool includeUsb = true,
    bool includeNetwork = true,
  }) {
    return DeviceScanner.scanAll(
      timeout: timeout,
      includeBluetooth: includeBluetooth,
      includeBle: includeBle,
      includeUsb: includeUsb,
      includeNetwork: includeNetwork,
    );
  }

  static Future<List<PrinterDevice>> getPairedDevices() {
    return DeviceScanner.getPairedDevices();
  }

  // Connection Management
  static Future<void> connectBluetooth({
    required String macAddress,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) {
    return ConnectionManager.connectBluetooth(
      macAddress: macAddress,
      profile: profile,
      autoReconnect: autoReconnect,
      timeout: timeout,
    );
  }

  static Future<void> connectBle({
    required String deviceId,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) {
    return ConnectionManager.connectBle(
      deviceId: deviceId,
      profile: profile,
      autoReconnect: autoReconnect,
      timeout: timeout,
    );
  }

  static Future<void> connectUsb({
    required int vendorId,
    required int productId,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) {
    return ConnectionManager.connectUsb(
      vendorId: vendorId,
      productId: productId,
      profile: profile,
      autoReconnect: autoReconnect,
      timeout: timeout,
    );
  }

  static Future<void> connectNetwork({
    required String ipAddress,
    int port = 9100,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) {
    return ConnectionManager.connectNetwork(
      ipAddress: ipAddress,
      port: port,
      profile: profile,
      autoReconnect: autoReconnect,
      timeout: timeout,
    );
  }

  static Future<void> disconnect() {
    return ConnectionManager.disconnect();
  }

  static Future<bool> isConnected() async {
    return ThunderThermalPrintPlatform.instance.isConnected();
  }

  static PrinterConnectionState get connectionState =>
      ConnectionManager.currentState;

  static PrinterDevice? get currentDevice => ConnectionManager.currentDevice;

  // Print Operations
  static Future<void> printBytes(List<int> bytes) {
    return ThunderThermalPrintPlatform.instance.printBytes(bytes);
  }

  static Future<void> printText(String text) {
    return ThunderThermalPrintPlatform.instance.printText(text);
  }

  static Future<void> printLines(List<String> lines) {
    return ThunderThermalPrintPlatform.instance.printLines(lines);
  }

  static Future<void> printQrCode(String data, {int size = 6}) {
    return ThunderThermalPrintPlatform.instance.printQrCode(data, size: size);
  }

  static Future<void> printBarcode(String data, {String type = 'CODE128'}) {
    return ThunderThermalPrintPlatform.instance.printBarcode(data, type: type);
  }

  static Future<void> printImage(Uint8List imageBytes) {
    return ThunderThermalPrintPlatform.instance.printImage(imageBytes);
  }

  static Future<void> printPdf(Uint8List pdfBytes) {
    return ThunderThermalPrintPlatform.instance.printPdf(pdfBytes);
  }

  static Future<void> printReceipt(ReceiptBuilder receipt) {
    final bytes = receipt.build();
    return ThunderThermalPrintPlatform.instance.printReceipt(bytes);
  }

  static Future<void> printReceiptBytes(List<int> bytes) {
    return ThunderThermalPrintPlatform.instance.printReceipt(bytes);
  }

  static Future<void> openCashDrawer({int pin = 0}) {
    return ThunderThermalPrintPlatform.instance.openCashDrawer(pin: pin);
  }

  // Printer Status
  static Future<PrinterStatus> getStatus() {
    return PrinterStatusService.getStatus();
  }

  static Future<Map<String, dynamic>> getPrinterCapabilities() {
    return PrinterStatusService.getPrinterCapabilities();
  }

  static Future<Map<String, dynamic>> checkPaperStatus() {
    return PrinterStatusService.checkPaperStatus();
  }

  static Future<double?> getPrinterTemperature() {
    return PrinterStatusService.getPrinterTemperature();
  }

  static Future<int?> getPrintedBytesCount() {
    return PrinterStatusService.getPrintedBytesCount();
  }

  // Permissions
  static Future<bool> requestPermissions() {
    return ThunderThermalPrintPlatform.instance.requestPermissions();
  }

  static Future<bool> checkPermissions() {
    return ThunderThermalPrintPlatform.instance.checkPermissions();
  }

  // Feature Support
  static Future<bool> isFeatureSupported(String feature) {
    return ThunderThermalPrintPlatform.instance.isFeatureSupported(feature);
  }

  // Platform Info
  static Future<String> getPlatformVersion() {
    return ThunderThermalPrintPlatform.instance.getPlatformVersion();
  }

  // Streams
  static Stream<PrinterConnectionState> get connectionStream =>
      ConnectionStream().stream;

  static Stream<PrinterEvent> get deviceEventStream =>
      DeviceEventStream().stream;

  // Background Service (Android only)
  static Future<void> startBackgroundMonitoring() async {
    await ThunderThermalPrintPlatform.instance.startBackgroundMonitoring();
  }

  static Future<void> stopBackgroundMonitoring() async {
    await ThunderThermalPrintPlatform.instance.stopBackgroundMonitoring();
  }

  static Future<bool> isBackgroundMonitoringActive() async {
    return ThunderThermalPrintPlatform.instance.isBackgroundMonitoringActive();
  }

  // Printer Profiles
  static Future<void> savePrinterProfile(PrinterDevice device) async {
    await ThunderThermalPrintPlatform.instance.savePrinterProfile(device);
  }

  static Future<PrinterDevice?> loadPrinterProfile(String id) async {
    return ThunderThermalPrintPlatform.instance.loadPrinterProfile(id);
  }

  static Future<void> setDefaultPrinter(PrinterDevice device) async {
    await ThunderThermalPrintPlatform.instance.setDefaultPrinter(device);
  }

  // Cleanup
  static Future<void> dispose() async {
    await ConnectionManager.dispose();
    await ThunderThermalPrintPlatform.instance.dispose();
    await ConnectionStream().dispose();
    await DeviceEventStream().dispose();
  }
}
