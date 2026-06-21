import 'dart:async';

import '../models/models.dart';
import '../services/thermal_print_platform_interface.dart';

class UsbHandler {
  UsbHandler._();

  static final _deviceController = StreamController<PrinterDevice>.broadcast();

  static Stream<PrinterDevice> get deviceStream => _deviceController.stream;

  static Future<List<PrinterDevice>> scan() async {
    final devices = await ThunderThermalPrintPlatform.instance.scanUsb();

    for (final device in devices) {
      if (!_deviceController.isClosed) {
        _deviceController.add(device);
      }
    }

    return devices;
  }

  static Future<void> connect({
    required int vendorId,
    required int productId,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) async {
    await ThunderThermalPrintPlatform.instance.connectUsb(
      vendorId: vendorId,
      productId: productId,
      profile: profile,
      autoReconnect: autoReconnect,
      timeout: timeout,
    );
  }

  static Future<bool> requestPermission({
    required int vendorId,
    required int productId,
  }) async {
    return ThunderThermalPrintPlatform.instance.requestUsbPermission(
      vendorId: vendorId,
      productId: productId,
    );
  }

  static Future<bool> isSupported() async {
    return ThunderThermalPrintPlatform.instance.isFeatureSupported('usb');
  }

  static Future<List<PrinterDevice>> getConnectedDevices() async {
    return scan();
  }

  static void emitUsbAttached(PrinterDevice device) {
    if (!_deviceController.isClosed) {
      _deviceController.add(device);
    }
  }

  static void emitUsbDetached(String deviceId) {
    _deviceController.add(
      PrinterDevice(
        address: deviceId,
        name: 'USB Device Detached',
        connectionType: PrinterConnectionType.usb,
        isConnected: false,
      ),
    );
  }

  static Future<void> dispose() async {
    await _deviceController.close();
  }
}
