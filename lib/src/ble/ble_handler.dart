import 'dart:async';

import '../models/models.dart';
import '../exceptions/exceptions.dart';
import '../services/thermal_print_platform_interface.dart';

class BleHandler {
  BleHandler._();

  static final _scanController = StreamController<PrinterDevice>.broadcast();

  static Stream<PrinterDevice> get deviceStream => _scanController.stream;

  static Future<List<PrinterDevice>> scan({Duration? timeout}) async {
    final devices = await ThunderThermalPrintPlatform.instance.scanBle(
      timeout: timeout,
    );

    for (final device in devices) {
      if (!_scanController.isClosed) {
        _scanController.add(device);
      }
    }

    return devices;
  }

  static Future<void> connect({
    required String deviceId,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) async {
    await ThunderThermalPrintPlatform.instance.connectBle(
      deviceId: deviceId,
      profile: profile,
      autoReconnect: autoReconnect,
      timeout: timeout,
    );
  }

  static Future<bool> isSupported() async {
    return ThunderThermalPrintPlatform.instance.isFeatureSupported('ble');
  }

  static Future<void> dispose() async {
    await _scanController.close();
  }
}
