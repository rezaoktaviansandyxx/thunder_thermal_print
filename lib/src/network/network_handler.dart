import 'dart:async';

import '../models/models.dart';
import '../services/thermal_print_platform_interface.dart';

class NetworkHandler {
  NetworkHandler._();

  static final _deviceController = StreamController<PrinterDevice>.broadcast();

  static Stream<PrinterDevice> get deviceStream => _deviceController.stream;

  static Future<List<PrinterDevice>> scan({String? subnet}) async {
    final devices = await ThunderThermalPrintPlatform.instance.scanNetwork(
      subnet: subnet,
    );

    for (final device in devices) {
      if (!_deviceController.isClosed) {
        _deviceController.add(device);
      }
    }

    return devices;
  }

  static Future<void> connect({
    required String ipAddress,
    int port = 9100,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) async {
    await ThunderThermalPrintPlatform.instance.connectNetwork(
      ipAddress: ipAddress,
      port: port,
      profile: profile,
      autoReconnect: autoReconnect,
      timeout: timeout,
    );
  }

  static Future<bool> isSupported() async {
    return ThunderThermalPrintPlatform.instance.isFeatureSupported('network');
  }

  static void emitNetworkConnected(PrinterDevice device) {
    if (!_deviceController.isClosed) {
      _deviceController.add(device);
    }
  }

  static void emitNetworkDisconnected(String ipAddress) {
    _deviceController.add(
      PrinterDevice(
        address: ipAddress,
        name: 'Network Printer Disconnected',
        connectionType: PrinterConnectionType.network,
        isConnected: false,
      ),
    );
  }

  static Future<void> dispose() async {
    await _deviceController.close();
  }
}
