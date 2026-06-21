import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'package:thunder_thermal_print/thunder_thermal_print.dart';
import 'package:thunder_thermal_print/src/services/thermal_print_platform_interface.dart';

// ---------------------------------------------------------------------------
// Web Bluetooth & WebUSB availability helpers
// ---------------------------------------------------------------------------

bool get _isWebBluetoothAvailable {
  try {
    final nav = globalContext.getProperty('navigator'.toJS) as JSObject;
    return (nav.hasProperty('bluetooth'.toJS)).toDart;
  } catch (_) {
    return false;
  }
}

bool get _isWebUSBAvailable {
  try {
    final nav = globalContext.getProperty('navigator'.toJS) as JSObject;
    return (nav.hasProperty('usb'.toJS)).toDart;
  } catch (_) {
    return false;
  }
}

bool get _isWebSocketAvailable {
  try {
    return (globalContext.hasProperty('WebSocket'.toJS)).toDart;
  } catch (_) {
    return false;
  }
}

/// Web implementation of [ThunderThermalPrintPlatform].
class ThunderThermalPrintWeb extends ThunderThermalPrintPlatform {
  // -------------------------------------------------------------------------
  // Registration
  // -------------------------------------------------------------------------
  static void registerWith(Registrar registrar) {
    ThunderThermalPrintPlatform.instance = ThunderThermalPrintWeb();
  }

  // -------------------------------------------------------------------------
  // Internal state
  // -------------------------------------------------------------------------
  JSObject? _bleDevice;
  JSObject? _bleServer;
  JSObject? _bleService;
  JSObject? _bleWriteCharacteristic;
  bool _bleConnected = false;

  JSObject? _usbDevice;
  bool _usbConnected = false;

  web.WebSocket? _webSocket;
  bool _networkConnected = false;

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------
  Never _throwNotSupported(String message, String feature) {
    throw NotSupportedException(
      message,
      feature: feature,
      code: 'NOT_SUPPORTED',
    );
  }

  Never _throwNotConnected() {
    throw const ConnectionException(
      'Not connected to any printer',
      code: 'NOT_CONNECTED',
    );
  }

  JSObject get _navigator {
    final nav = globalContext.getProperty('navigator'.toJS);
    if (nav == null) {
      throw const NotSupportedException(
        'navigator object not available',
        feature: 'web',
        code: 'NO_NAVIGATOR',
      );
    }
    return nav as JSObject;
  }

  JSObject get _bluetooth =>
      _navigator.getProperty('bluetooth'.toJS) as JSObject;
  JSObject get _usb => _navigator.getProperty('usb'.toJS) as JSObject;

  /// Converts a Dart map into a JS object (deep conversion).
  JSObject _jsifyMap(Map<String, dynamic> map) {
    final obj = JSObject();
    map.forEach((key, value) {
      final jsValue = _jsify(value);
      Object.hash(jsValue, obj);
    });
    return obj;
  }

  JSAny? _jsify(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.toJS;
    if (value is int) return value.toJS;
    if (value is double) return value.toJS;
    if (value is bool) return value.toJS;
    if (value is List) {
      return _jsifyList(value);
    }
    if (value is Map<String, dynamic>) {
      return _jsifyMap(value);
    }
    if (value is JSAny) return value;
    return value.toString().toJS;
  }

  JSArray<JSAny?> _jsifyList(List value) {
    final arr = JSArray<JSAny?>();
    for (var i = 0; i < value.length; i++) {
      final jsValue = _jsify(value[i]);
      Object.hash(jsValue, arr);
    }
    return arr;
  }

  String? _jsToString(JSAny? value) {
    if (value == null) return null;
    try {
      return (value as JSString).toDart;
    } catch (_) {
      try {
        // Try .toString() on the JS object
        final str = (value as JSObject).callMethod('toString'.toJS) as JSString;
        return str.toDart;
      } catch (_) {
        return null;
      }
    }
  }

  int? _jsToInt(JSAny? value) {
    if (value == null) return null;
    try {
      return (value as JSNumber).toDartInt;
    } catch (_) {
      try {
        final s = _jsToString(value);
        return s == null ? null : int.tryParse(s);
      } catch (_) {
        return null;
      }
    }
  }

  bool _isUserCancelled(Object error) {
    final str = error.toString().toLowerCase();
    return str.contains('user cancelled') ||
        str.contains('user denied') ||
        str.contains('permission') ||
        (str.contains('navigator.bluetooth.requestdevice') &&
            str.contains('cancelled'));
  }

  // -------------------------------------------------------------------------
  // Device Discovery
  // -------------------------------------------------------------------------
  @override
  Future<List<PrinterDevice>> scanBluetooth({Duration? timeout}) {
    _throwNotSupported(
      'Bluetooth Classic scanning is not supported on web. '
          'Use scanBle() for Bluetooth Low Energy devices instead.',
      'bluetooth',
    );
  }

  @override
  Future<List<PrinterDevice>> scanBle({Duration? timeout}) async {
    if (!_isWebBluetoothAvailable) {
      _throwNotSupported(
        'Web Bluetooth API is not available in this browser. '
            'Please use Chrome, Edge, or Opera on HTTPS (or localhost). '
            'See: https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API',
        'ble',
      );
    }

    try {
      final optionalServices = _jsifyList(<String>[
        '0000ff00-0000-1000-8000-00805f9b34fb',
        '000018f0-0000-1000-8000-00805f9b34fb',
        'e7810a71-73ae-499d-8c15-faa9aef0c3f2',
      ]);

      final options = JSObject();
      options.setProperty('acceptAllDevices'.toJS, true.toJS);
      options.setProperty('optionalServices'.toJS, optionalServices);

      final devicePromise =
          _bluetooth.callMethod('requestDevice'.toJS, options) as JSPromise;
      final device = (await devicePromise.toDart) as JSObject;

      final deviceName =
          _jsToString(device.getProperty('name'.toJS)) ?? 'Unknown BLE Device';
      final deviceId = _jsToString(device.getProperty('id'.toJS)) ?? '';

      return [
        PrinterDevice(
          address: deviceId,
          name: deviceName,
          connectionType: PrinterConnectionType.ble,
          metadata: {'source': 'web_bluetooth'},
        ),
      ];
    } catch (e) {
      if (_isUserCancelled(e)) {
        return [];
      }
      throw ConnectionException(
        'BLE scan failed: $e',
        code: 'SCAN_FAILED',
      );
    }
  }

  @override
  Future<List<PrinterDevice>> scanUsb() async {
    if (!_isWebUSBAvailable) {
      _throwNotSupported(
        'WebUSB API is not available in this browser. '
            'Please use Chrome, Edge, or Opera on HTTPS (or localhost). '
            'See: https://developer.mozilla.org/en-US/docs/Web/API/Web_USB_API',
        'usb',
      );
    }

    try {
      final filters = _jsifyList(<Map<String, dynamic>>[
        {'vendorId': 0x04b8}, // Epson
        {'vendorId': 0x0483}, // Many Chinese printers
        {'vendorId': 0x1fc9}, // XPrinter
      ]);

      final options = JSObject();
      options.setProperty('filters'.toJS, filters);

      final devicePromise =
          _usb.callMethod('requestDevice'.toJS, options) as JSPromise;
      final device = (await devicePromise.toDart) as JSObject;

      final deviceName = _jsToString(device.getProperty('productName'.toJS)) ??
          'Unknown USB Device';
      final vendorId = _jsToInt(device.getProperty('vendorId'.toJS)) ?? 0;
      final productId = _jsToInt(device.getProperty('productId'.toJS)) ?? 0;

      return [
        PrinterDevice(
          address: 'usb_$vendorId:$productId',
          name: deviceName,
          connectionType: PrinterConnectionType.usb,
          vendorId: vendorId,
          productId: productId,
          metadata: {'source': 'web_usb'},
        ),
      ];
    } catch (e) {
      if (_isUserCancelled(e)) {
        return [];
      }
      throw ConnectionException(
        'USB scan failed: $e',
        code: 'SCAN_FAILED',
      );
    }
  }

  @override
  Future<List<PrinterDevice>> scanNetwork({String? subnet}) {
    _throwNotSupported(
      'Network scanning is not supported on web due to browser security '
          'restrictions (CORS / no raw TCP). Use connectNetwork() with a known '
          'IP address and port instead.',
      'network_scan',
    );
  }

  // -------------------------------------------------------------------------
  // Connection Management
  // -------------------------------------------------------------------------
  @override
  Future<void> connectBluetooth({
    required String macAddress,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) {
    _throwNotSupported(
      'Bluetooth Classic connections are not supported on web. '
          'Use connectBle() for Bluetooth Low Energy instead.',
      'bluetooth',
    );
  }

  @override
  Future<void> connectBle({
    required String deviceId,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) async {
    if (!_isWebBluetoothAvailable) {
      _throwNotSupported(
        'Web Bluetooth API is not available in this browser. '
            'Please use Chrome, Edge, or Opera on HTTPS (or localhost).',
        'ble',
      );
    }

    try {
      final services = _jsifyList(<String>[
        '0000ff00-0000-1000-8000-00805f9b34fb',
      ]);

      final filterObj = JSObject();
      filterObj.setProperty('services'.toJS, services);

      final filters = JSArray<JSAny?>();
      Object.hash(filterObj, filters);

      final options = JSObject();
      options.setProperty('filters'.toJS, filters);

      final devicePromise =
          _bluetooth.callMethod('requestDevice'.toJS, options) as JSPromise;
      _bleDevice = (await devicePromise.toDart) as JSObject;

      final gatt = _bleDevice!.getProperty('gatt'.toJS) as JSObject;
      _bleServer = (await (gatt.callMethod('connect'.toJS) as JSPromise).toDart)
          as JSObject;
      _bleConnected = true;

      _bleService = (await (_bleServer!.callMethod('getPrimaryService'.toJS,
              '0000ff00-0000-1000-8000-00805f9b34fb'.toJS) as JSPromise)
          .toDart) as JSObject;

      _bleWriteCharacteristic = (await (_bleService!.callMethod(
              'getCharacteristic'.toJS,
              '0000ff02-0000-1000-8000-00805f9b34fb'.toJS) as JSPromise)
          .toDart) as JSObject;
    } catch (e) {
      _bleConnected = false;
      throw ConnectionException(
        'BLE connection failed: $e',
        code: 'CONNECTION_FAILED',
      );
    }
  }

  @override
  Future<void> connectUsb({
    required int vendorId,
    required int productId,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) async {
    if (!_isWebUSBAvailable) {
      _throwNotSupported(
        'WebUSB API is not available in this browser. '
            'Please use Chrome, Edge, or Opera on HTTPS (or localhost).',
        'usb',
      );
    }

    try {
      final filterObj = JSObject();
      filterObj.setProperty('vendorId'.toJS, vendorId.toJS);
      filterObj.setProperty('productId'.toJS, productId.toJS);

      final filters = JSArray<JSAny?>();
      Object.hash(filterObj, filters);

      final options = JSObject();
      options.setProperty('filters'.toJS, filters);

      final devicePromise =
          _usb.callMethod('requestDevice'.toJS, options) as JSPromise;
      _usbDevice = (await devicePromise.toDart) as JSObject;

      await (_usbDevice!.callMethod('open'.toJS) as JSPromise).toDart;

      // Claim interface 0 (most thermal printers use interface 0)
      try {
        await (_usbDevice!.callMethod('claimInterface'.toJS, 0.toJS)
                as JSPromise)
            .toDart;
      } catch (_) {
        // Some printers require configuration selection first
        try {
          await (_usbDevice!.callMethod('selectConfiguration'.toJS, 1.toJS)
                  as JSPromise)
              .toDart;
          await (_usbDevice!.callMethod('claimInterface'.toJS, 0.toJS)
                  as JSPromise)
              .toDart;
        } catch (_) {
          // Ignore — will fail on write if truly not claimable
        }
      }

      _usbConnected = true;
    } catch (e) {
      _usbConnected = false;
      throw ConnectionException(
        'USB connection failed: $e',
        code: 'CONNECTION_FAILED',
      );
    }
  }

  @override
  Future<void> connectNetwork({
    required String ipAddress,
    int port = 9100,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) async {
    if (!_isWebSocketAvailable) {
      _throwNotSupported(
        'WebSocket is not available in this browser environment.',
        'network',
      );
    }

    try {
      // Note: Most thermal printers on port 9100 use raw TCP, not WebSocket.
      // This will only work if the printer supports WebSocket or there is a
      // WebSocket-to-TCP proxy bridge.
      final wsUrl = 'ws://$ipAddress:$port';
      _webSocket = web.WebSocket(wsUrl);

      final connectCompleter = Completer<void>();
      final effectiveTimeout = timeout ?? const Duration(seconds: 10);

      // Use addEventListener instead of onOpen/onError
      _webSocket?.addEventListener(
        'open',
        (web.Event event) {
          if (!connectCompleter.isCompleted) {
            connectCompleter.complete();
          }
        }.toJS,
      );

      _webSocket?.addEventListener(
        'error',
        (web.Event event) {
          if (!connectCompleter.isCompleted) {
            connectCompleter.completeError(
              ConnectionException(
                'WebSocket connection failed to $wsUrl',
                code: 'CONNECTION_FAILED',
              ),
            );
          }
        }.toJS,
      );

      await connectCompleter.future.timeout(
        effectiveTimeout,
        onTimeout: () {
          throw PrintTimeoutException(
            'Network connection timed out after ${effectiveTimeout.inSeconds}s',
            timeoutMs: effectiveTimeout.inMilliseconds,
            code: 'TIMEOUT',
          );
        },
      );

      _networkConnected = true;
    } catch (e) {
      if (e is PrinterException) rethrow;
      throw ConnectionException(
        'Network connection failed: $e',
        code: 'CONNECTION_FAILED',
      );
    }
  }

  @override
  Future<void> disconnect() async {
    // BLE
    if (_bleConnected && _bleDevice != null) {
      try {
        final gatt = _bleDevice!.getProperty('gatt'.toJS) as JSObject;
        await (gatt.callMethod('disconnect'.toJS) as JSPromise).toDart;
      } catch (_) {
        // Ignore disconnect errors
      }
      _bleDevice = null;
      _bleServer = null;
      _bleService = null;
      _bleWriteCharacteristic = null;
      _bleConnected = false;
    }

    // USB
    if (_usbConnected && _usbDevice != null) {
      try {
        await (_usbDevice!.callMethod('close'.toJS) as JSPromise).toDart;
      } catch (_) {
        // Ignore
      }
      _usbDevice = null;
      _usbConnected = false;
    }

    // Network
    if (_networkConnected && _webSocket != null) {
      try {
        _webSocket!.close();
      } catch (_) {
        // Ignore
      }
      _webSocket = null;
      _networkConnected = false;
    }
  }

  @override
  Future<bool> isConnected() async {
    return _bleConnected || _usbConnected || _networkConnected;
  }

  // -------------------------------------------------------------------------
  // Printer Status
  // -------------------------------------------------------------------------
  @override
  Future<Map<String, dynamic>> getStatus() async {
    return {
      'online': await isConnected(),
      'paperOut': false,
      'paperNearEnd': false,
      'coverOpen': false,
      'drawerOpen': false,
      'batteryLow': false,
    };
  }

  @override
  Future<Map<String, dynamic>> getPrinterCapabilities() async {
    return {};
  }

  @override
  Future<int?> getPrintedBytesCount() async {
    return null;
  }

  // -------------------------------------------------------------------------
  // Background Service (not supported on web)
  // -------------------------------------------------------------------------
  @override
  Future<void> startBackgroundMonitoring() async {}

  @override
  Future<void> stopBackgroundMonitoring() async {}

  @override
  Future<bool> isBackgroundMonitoringActive() async {
    return false;
  }

  // -------------------------------------------------------------------------
  // Printer Profiles & Persistence (not supported on web)
  // -------------------------------------------------------------------------
  @override
  Future<void> savePrinterProfile(PrinterDevice device) async {}

  @override
  Future<PrinterDevice?> loadPrinterProfile(String id) async {
    return null;
  }

  @override
  Future<void> setDefaultPrinter(PrinterDevice device) async {}

  @override
  Future<List<PrinterDevice>> getPairedDevices() async {
    return [];
  }

  // -------------------------------------------------------------------------
  // Print Operations
  // -------------------------------------------------------------------------
  @override
  Future<void> printBytes(List<int> bytes) async {
    if (_bleConnected && _bleWriteCharacteristic != null) {
      await _writeBleBytes(Uint8List.fromList(bytes));
    } else if (_usbConnected && _usbDevice != null) {
      await _writeUsbBytes(Uint8List.fromList(bytes));
    } else if (_networkConnected && _webSocket != null) {
      _writeNetworkBytes(Uint8List.fromList(bytes));
    } else {
      _throwNotConnected();
    }
  }

  @override
  Future<void> printText(String text) async {
    final data = Uint8List.fromList([...text.codeUnits, 0x0A]);
    await printBytes(data);
  }

  @override
  Future<void> printLines(List<String> lines) async {
    final buffer = StringBuffer();
    for (final line in lines) {
      buffer.writeln(line);
    }
    buffer.writeln();
    final data = Uint8List.fromList(buffer.toString().codeUnits);
    await printBytes(data);
  }

  @override
  Future<void> printQrCode(String data, {int size = 6}) {
    _throwNotSupported(
      'Direct QR code printing is not supported on web. '
          'Encode the QR code command bytes manually and use printBytes().',
      'qrCode',
    );
  }

  @override
  Future<void> printBarcode(String data, {String type = 'CODE128'}) {
    _throwNotSupported(
      'Direct barcode printing is not supported on web. '
          'Encode the barcode command bytes manually and use printBytes().',
      'barcode',
    );
  }

  @override
  Future<void> printImage(Uint8List imageBytes) {
    _throwNotSupported(
      'Direct image printing is not supported on web. '
          'Convert the image to ESC/POS raster commands and use printBytes().',
      'image',
    );
  }

  @override
  Future<void> printPdf(Uint8List pdfBytes) {
    _throwNotSupported(
      'Direct PDF printing is not supported on web.',
      'pdf',
    );
  }

  @override
  Future<void> printReceipt(List<int> receiptBytes) async {
    await printBytes(receiptBytes);
  }

  @override
  Future<void> openCashDrawer({int pin = 0}) async {
    final pulse = pin == 1
        ? Uint8List.fromList([0x1B, 0x70, 0x01])
        : Uint8List.fromList([0x1B, 0x70, 0x00]);
    await printBytes(pulse);
  }

  // -------------------------------------------------------------------------
  // Permission
  // -------------------------------------------------------------------------
  @override
  Future<bool> requestPermissions() async {
    return true;
  }

  @override
  Future<bool> checkPermissions() async {
    return true;
  }

  // -------------------------------------------------------------------------
  // Platform Info
  // -------------------------------------------------------------------------
  @override
  Future<String> getPlatformVersion() async {
    return 'Web 1.0.0';
  }

  @override
  Future<bool> isFeatureSupported(String feature) async {
    switch (feature) {
      case 'ble':
        return _isWebBluetoothAvailable;
      case 'usb':
        return _isWebUSBAvailable;
      case 'network':
        return _isWebSocketAvailable;
      case 'bluetooth':
        return false;
      case 'qrCode':
      case 'barcode':
      case 'image':
      case 'pdf':
      case 'cashDrawer':
        return true;
      default:
        return false;
    }
  }

  // -------------------------------------------------------------------------
  // BLE Writing
  // -------------------------------------------------------------------------
  Future<void> _writeBleBytes(Uint8List data) async {
    final char = _bleWriteCharacteristic;
    if (char == null) {
      _throwNotConnected();
    }

    const chunkSize = 100; // Conservative chunk size for web BLE
    for (int offset = 0; offset < data.length; offset += chunkSize) {
      final end =
          (offset + chunkSize > data.length) ? data.length : offset + chunkSize;
      final chunk = data.sublist(offset, end);

      // Create DataView from Uint8List for BLE characteristic
      final jsArrayBuffer = chunk.buffer.toJS;
      // Use the DataView constructor to wrap the ArrayBuffer
      final dataViewConstructor =
          globalContext.getProperty('DataView'.toJS) as JSObject;
      final jsDataView =
          dataViewConstructor.callMethod('new'.toJS, jsArrayBuffer);

      await (char.callMethod('writeValueWithoutResponse'.toJS, jsDataView)
              as JSPromise)
          .toDart;
    }
  }

  // -------------------------------------------------------------------------
  // USB Writing
  // -------------------------------------------------------------------------
  Future<void> _writeUsbBytes(Uint8List data) async {
    final dev = _usbDevice;
    if (dev == null) {
      _throwNotConnected();
    }

    try {
      // Convert Uint8List to JSArrayBuffer
      final jsArrayBuffer = data.buffer.toJS;
      await (dev.callMethod('transferOut'.toJS, 1.toJS, jsArrayBuffer)
              as JSPromise)
          .toDart;
    } catch (e) {
      throw ConnectionException(
        'USB write failed: $e',
        code: 'WRITE_FAILED',
      );
    }
  }

  // -------------------------------------------------------------------------
  // Network Writing
  // -------------------------------------------------------------------------
  void _writeNetworkBytes(Uint8List data) {
    final ws = _webSocket;
    if (ws == null) {
      _throwNotConnected();
    }
    try {
      // Send as binary ArrayBuffer over WebSocket
      final buffer = data.buffer.toJS;
      ws.send(buffer);
    } catch (e) {
      throw ConnectionException(
        'Network write failed: $e',
        code: 'WRITE_FAILED',
      );
    }
  }

  @override
  Future<void> dispose() async {
    // Web platform cleanup
  }
}
