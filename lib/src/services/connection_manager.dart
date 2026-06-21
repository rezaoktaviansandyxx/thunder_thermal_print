import 'dart:async';

import 'package:thunder_thermal_print/src/ble/ble.dart';
import 'package:thunder_thermal_print/src/bluetooth/bluetooth.dart';
import 'package:thunder_thermal_print/src/network/network.dart';
import 'package:thunder_thermal_print/src/usb/usb.dart';
import 'package:thunder_thermal_print/thunder_thermal_print.dart';
import '../services/thermal_print_platform_interface.dart';

class ConnectionManager {
  ConnectionManager._();

  static PrinterConnectionState _currentState =
      PrinterConnectionState.disconnected;
  static PrinterDevice? _currentDevice;
  static bool _isReconnecting = false;
  static Timer? _reconnectTimer;
  static int _reconnectAttempts = 0;
  static ConnectionConfig? _activeConfig;

  static PrinterConnectionState get currentState => _currentState;
  static PrinterDevice? get currentDevice => _currentDevice;
  static bool get isConnected =>
      _currentState == PrinterConnectionState.connected;
  static bool get isReconnecting => _isReconnecting;

  static Future<void> connectBluetooth({
    required String macAddress,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) async {
    try {
      _setState(PrinterConnectionState.connecting);
      _currentDevice = PrinterDevice(
        address: macAddress,
        name: 'Bluetooth Printer',
        connectionType: PrinterConnectionType.bluetooth,
      );

      await BluetoothHandler.connect(
        macAddress: macAddress,
        profile: profile,
        autoReconnect: autoReconnect,
        timeout: timeout,
      );

      _setState(PrinterConnectionState.connected);
      _emitEvent(PrinterEventType.printerConnected);

      if (autoReconnect) {
        _activeConfig = ConnectionConfig(
          identifier: macAddress,
          autoReconnect: true,
          profile: profile?.name ?? 'custom',
        );
      }
    } catch (e) {
      _setState(PrinterConnectionState.disconnected);
      _currentDevice = null;
      rethrow;
    }
  }

  static Future<void> connectBle({
    required String deviceId,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) async {
    try {
      _setState(PrinterConnectionState.connecting);
      _currentDevice = PrinterDevice(
        address: deviceId,
        name: 'BLE Printer',
        connectionType: PrinterConnectionType.ble,
      );

      await BleHandler.connect(
        deviceId: deviceId,
        profile: profile,
        autoReconnect: autoReconnect,
        timeout: timeout,
      );

      _setState(PrinterConnectionState.connected);
      _emitEvent(PrinterEventType.printerConnected);

      if (autoReconnect) {
        _activeConfig = ConnectionConfig(
          identifier: deviceId,
          autoReconnect: true,
          profile: profile?.name ?? 'custom',
        );
      }
    } catch (e) {
      _setState(PrinterConnectionState.disconnected);
      _currentDevice = null;
      rethrow;
    }
  }

  static Future<void> connectUsb({
    required int vendorId,
    required int productId,
    PrinterProfile? profile,
    bool autoReconnect = true,
    Duration? timeout,
  }) async {
    try {
      _setState(PrinterConnectionState.connecting);
      _currentDevice = PrinterDevice(
        address: 'usb:$vendorId:$productId',
        name: 'USB Printer',
        connectionType: PrinterConnectionType.usb,
        vendorId: vendorId,
        productId: productId,
      );

      await UsbHandler.connect(
        vendorId: vendorId,
        productId: productId,
        profile: profile,
        autoReconnect: autoReconnect,
        timeout: timeout,
      );

      _setState(PrinterConnectionState.connected);
      _emitEvent(PrinterEventType.printerConnected);

      if (autoReconnect) {
        _activeConfig = ConnectionConfig(
          identifier: 'usb:$vendorId:$productId',
          autoReconnect: true,
          profile: profile?.name ?? 'custom',
        );
      }
    } catch (e) {
      _setState(PrinterConnectionState.disconnected);
      _currentDevice = null;
      rethrow;
    }
  }

  /// Ensures a USB printer is connected before printing.
  ///
  /// If the printer is already connected, this is a no-op.
  /// If not connected but [vendorId] and [productId] are provided, it
  /// attempts to connect first. Returns `true` if connected after the call.
  static Future<bool> ensureUsbConnected({
    required int vendorId,
    required int productId,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) async {
    if (isConnected && _currentDevice?.vendorId == vendorId &&
        _currentDevice?.productId == productId) {
      return true;
    }

    try {
      await connectUsb(
        vendorId: vendorId,
        productId: productId,
        profile: profile,
        autoReconnect: autoReconnect,
        timeout: timeout,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> connectNetwork({
    required String ipAddress,
    int port = 9100,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) async {
    try {
      _setState(PrinterConnectionState.connecting);
      _currentDevice = PrinterDevice(
        address: ipAddress,
        name: 'Network Printer',
        connectionType: PrinterConnectionType.network,
        port: port,
      );

      await NetworkHandler.connect(
        ipAddress: ipAddress,
        port: port,
        profile: profile,
        autoReconnect: autoReconnect,
        timeout: timeout,
      );

      _setState(PrinterConnectionState.connected);
      _emitEvent(PrinterEventType.printerConnected);

      if (autoReconnect) {
        _activeConfig = ConnectionConfig(
          identifier: ipAddress,
          port: port,
          autoReconnect: true,
          profile: profile?.name ?? 'custom',
        );
      }
    } catch (e) {
      _setState(PrinterConnectionState.disconnected);
      _currentDevice = null;
      rethrow;
    }
  }

  static Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isReconnecting = false;
    _reconnectAttempts = 0;
    _activeConfig = null;

    await ThunderThermalPrintPlatform.instance.disconnect();

    _setState(PrinterConnectionState.disconnected);
    _emitEvent(PrinterEventType.printerDisconnected);
    _currentDevice = null;
  }

  static void _handleConnectionLost() {
    if (_activeConfig?.autoReconnect != true) {
      _setState(PrinterConnectionState.disconnected);
      _emitEvent(PrinterEventType.printerDisconnected);
      return;
    }

    _setState(PrinterConnectionState.connectionLost);
    _startReconnect();
  }

  static void _startReconnect() {
    if (_isReconnecting || _reconnectTimer?.isActive == true) return;

    _isReconnecting = true;
    _reconnectAttempts = 0;

    _attemptReconnect();
  }

  static void _attemptReconnect() {
    final config = _activeConfig;
    if (config == null) return;

    if (_reconnectAttempts >= config.maxReconnectAttempts) {
      _isReconnecting = false;
      _setState(PrinterConnectionState.reconnectFailed);
      _emitEvent(PrinterEventType.printerDisconnected);
      return;
    }

    _setState(PrinterConnectionState.reconnecting);
    _reconnectAttempts++;

    _reconnectTimer = Timer(config.reconnectDelay, () async {
      try {
        if (config.port != null) {
          await connectNetwork(
            ipAddress: config.identifier,
            port: config.port!,
            autoReconnect: config.autoReconnect,
            timeout: config.timeout,
          );
        } else if (config.identifier.startsWith('usb:')) {
          final parts = config.identifier.replaceFirst('usb:', '').split(':');
          if (parts.length == 2) {
            await connectUsb(
              vendorId: int.tryParse(parts[0]) ?? 0,
              productId: int.tryParse(parts[1]) ?? 0,
              autoReconnect: config.autoReconnect,
              timeout: config.timeout,
            );
          }
        } else {
          await connectBluetooth(
            macAddress: config.identifier,
            autoReconnect: config.autoReconnect,
            timeout: config.timeout,
          );
        }

        _isReconnecting = false;
        _reconnectAttempts = 0;
      } catch (e) {
        _attemptReconnect();
      }
    });
  }

  static void _setState(PrinterConnectionState state) {
    _currentState = state;
    ConnectionStream().emit(state);
  }

  static void _emitEvent(PrinterEventType type, {String? deviceId}) {
    DeviceEventStream().emit(
      PrinterEvent(
        type: type,
        deviceId: deviceId ?? _currentDevice?.address,
      ),
    );
  }

  static void handleDeviceAttached(PrinterDevice device) {
    if (_activeConfig?.identifier == device.address) {
      _attemptReconnect();
    }
  }

  static void handleDeviceDetached(String deviceId) {
    if (_currentDevice?.address == deviceId) {
      _handleConnectionLost();
    }
  }

  static Future<void> dispose() async {
    await disconnect();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
}
