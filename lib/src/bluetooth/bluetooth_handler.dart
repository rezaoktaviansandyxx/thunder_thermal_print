import 'dart:async';

import '../models/models.dart';
import '../services/thermal_print_platform_interface.dart';

class BluetoothHandler {
  BluetoothHandler._();

  static final _scanController = StreamController<PrinterDevice>.broadcast();

  static Stream<PrinterDevice> get deviceStream => _scanController.stream;

  static Future<List<PrinterDevice>> scan({Duration? timeout}) async {
    final devices = await ThunderThermalPrintPlatform.instance.scanBluetooth(
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
    required String macAddress,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) async {
    await ThunderThermalPrintPlatform.instance.connectBluetooth(
      macAddress: macAddress,
      profile: profile,
      autoReconnect: autoReconnect,
      timeout: timeout,
    );
  }

  static Future<bool> isEnabled() async {
    return ThunderThermalPrintPlatform.instance.isFeatureSupported('bluetooth');
  }

  static Future<List<PrinterDevice>> getPairedDevices() async {
    return ThunderThermalPrintPlatform.instance.getPairedDevices();
  }

  static Future<void> dispose() async {
    await _scanController.close();
  }
}
