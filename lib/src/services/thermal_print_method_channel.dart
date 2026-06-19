import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../exceptions/exceptions.dart';
import '../models/models.dart';
import '../streams/connection_stream.dart';
import '../streams/device_event_stream.dart';
import 'thermal_print_platform_interface.dart';

/// Default [ThunderThermalPrintPlatform] implementation that communicates
/// with the native side via [MethodChannel] and [EventChannel].
///
/// Two event channels are maintained:
/// - **connection_state** – pushes [PrinterConnectionState] transitions.
/// - **device_events** – pushes [PrinterEvent] hardware / lifecycle events.
///
/// All platform exceptions raised by the native layer are caught and
/// re-thrown as one of the typed exception classes defined in
/// `../exceptions/exceptions.dart`.
class MethodChannelThunderThermalPrint extends ThunderThermalPrintPlatform {
  // ---------------------------------------------------------------------------
  // Channel constants
  // ---------------------------------------------------------------------------

  static const MethodChannel _methodChannel =
      MethodChannel('id.thunderlab.thunder_thermal_print');

  static const EventChannel _connectionStateChannel =
      EventChannel('id.thunderlab.thunder_thermal_print/connection_state');

  static const EventChannel _deviceEventsChannel =
      EventChannel('id.thunderlab.thunder_thermal_print/device_events');

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  StreamSubscription<dynamic>? _connectionStateSubscription;
  StreamSubscription<dynamic>? _deviceEventsSubscription;
  bool _eventChannelsInitialized = false;

  // ---------------------------------------------------------------------------
  // Event channel setup
  // ---------------------------------------------------------------------------

  /// Lazily initialises the event channel listeners and wires them into
  /// the broadcast [ConnectionStream] and [DeviceEventStream] singletons.
  ///
  /// Called automatically before the first operation that may trigger
  /// native events. Safe to call multiple times.
  void _ensureEventChannelsInitialized() {
    if (_eventChannelsInitialized) return;
    _eventChannelsInitialized = true;

    // -- Connection state ---------------------------------------------------
    _connectionStateSubscription =
        _connectionStateChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        final state = PrinterConnectionState.values.firstWhere(
          (e) => e.name == event,
          orElse: () => PrinterConnectionState.disconnected,
        );
        ConnectionStream().emit(state);
      },
      onError: (Object error) {
        // Silently close the connection stream on channel error – the
        // native side likely tore down the event sink.
        if (error is PlatformException) {
          debugPrint(
            '[ThermalPrint] connection_state EventChannel error: '
            '${error.code} – ${error.message}',
          );
        }
      },
    );

    // -- Device events -------------------------------------------------------
    _deviceEventsSubscription =
        _deviceEventsChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          final data = Map<String, dynamic>.from(event);
          final printerEvent = PrinterEvent.fromMap(data);
          DeviceEventStream().emit(printerEvent);
        }
      },
      onError: (Object error) {
        if (error is PlatformException) {
          debugPrint(
            '[ThermalPrint] device_events EventChannel error: '
            '${error.code} – ${error.message}',
          );
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Exception mapping
  // ---------------------------------------------------------------------------

  /// Converts a [PlatformException] into the most specific [PrinterException]
  /// subclass based on the platform error code.
  ///
  /// Recognised codes (case-insensitive):
  ///
  /// | Code | Exception |
  /// |---|---|
  /// | `PERMISSION_DENIED` | [PermissionException] |
  /// | `CONNECTION_FAILED`, `CONNECTION_LOST`, `NOT_CONNECTED`, `ALREADY_CONNECTED` | [ConnectionException] |
  /// | `DEVICE_NOT_FOUND` | [DeviceNotFoundException] |
  /// | `TIMEOUT` | [PrintTimeoutException] |
  /// | `NOT_SUPPORTED`, `UNSUPPORTED_FEATURE` | [NotSupportedException] |
  /// | `PRINTER_BUSY` | [PrinterBusyException] |
  /// | `PAPER_OUT` | [PaperOutException] |
  /// | `COVER_OPEN` | [CoverOpenException] |
  /// | `INVALID_DATA` | [InvalidDataException] |
  ///
  /// Any unrecognised code falls back to a generic [PrinterException].
  PrinterException _mapException(PlatformException e) {
    final code = e.code.toUpperCase();

    // --- Permission ---------------------------------------------------------
    if (code.contains('PERMISSION') || code.contains('DENIED')) {
      return PermissionException(
        e.message ?? 'Permission denied',
        permissionName: e.details is String ? e.details as String : null,
        code: e.code,
        details: e.details,
      );
    }

    // --- Connection ---------------------------------------------------------
    if (code.contains('CONNECTION') ||
        code.contains('CONNECT_FAILED') ||
        code.contains('CONNECT_LOST') ||
        code.contains('NOT_CONNECTED') ||
        code.contains('ALREADY_CONNECTED') ||
        code.contains('SOCKET') ||
        code.contains('BLUETOOTH_DISCONNECTED')) {
      return ConnectionException(
        e.message ?? 'Connection error',
        code: e.code,
        details: e.details,
      );
    }

    // --- Device not found ---------------------------------------------------
    if (code.contains('DEVICE_NOT_FOUND') || code.contains('NOT_FOUND')) {
      return DeviceNotFoundException(
        e.message ?? 'Device not found',
        code: e.code,
        details: e.details,
      );
    }

    // --- Timeout ------------------------------------------------------------
    if (code.contains('TIMEOUT') || code.contains('TIMED_OUT')) {
      int? timeoutMs;
      if (e.details is int) {
        timeoutMs = e.details as int;
      } else if (e.details is Map) {
        timeoutMs = (e.details as Map)['timeoutMs'] as int?;
      }
      return PrintTimeoutException(
        e.message ?? 'Operation timed out',
        timeoutMs: timeoutMs,
        code: e.code,
        details: e.details,
      );
    }

    // --- Not supported ------------------------------------------------------
    if (code.contains('NOT_SUPPORTED') ||
        code.contains('UNSUPPORTED') ||
        code.contains('UNIMPLEMENTED')) {
      return NotSupportedException(
        e.message ?? 'Operation not supported',
        feature: e.details is String ? e.details as String : null,
        code: e.code,
        details: e.details,
      );
    }

    // --- Printer busy -------------------------------------------------------
    if (code.contains('BUSY')) {
      return PrinterBusyException(
        e.message ?? 'Printer is busy',
        code: e.code,
        details: e.details,
      );
    }

    // --- Paper out ----------------------------------------------------------
    if (code.contains('PAPER_OUT') || code.contains('NO_PAPER')) {
      return PaperOutException(
        e.message ?? 'Paper out',
        code: e.code,
        details: e.details,
      );
    }

    // --- Cover open ---------------------------------------------------------
    if (code.contains('COVER_OPEN') || code.contains('LID_OPEN')) {
      return CoverOpenException(
        e.message ?? 'Printer cover is open',
        code: e.code,
        details: e.details,
      );
    }

    // --- Invalid data -------------------------------------------------------
    if (code.contains('INVALID_DATA') ||
        code.contains('INVALID_ARGUMENT') ||
        code.contains('DECODE_ERROR')) {
      return InvalidDataException(
        e.message ?? 'Invalid data provided',
        code: e.code,
        details: e.details,
      );
    }

    // --- Fallback -----------------------------------------------------------
    return PrinterException(
      e.message ?? 'An unknown printer error occurred',
      code: e.code,
      details: e.details,
    );
  }

  /// Wraps a [Future] that may throw a [PlatformException] and converts it
  /// to the appropriate [PrinterException].
  Future<T> _guard<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on PlatformException catch (e) {
      throw _mapException(e);
    } on MissingPluginException catch (e) {
      throw NotSupportedException(
        'The thermal print plugin is not implemented on this platform',
        feature: 'platform_implementation',
        details: e.message,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Device Discovery
  // ---------------------------------------------------------------------------

  @override
  Future<List<PrinterDevice>> scanBluetooth({Duration? timeout}) {
    _ensureEventChannelsInitialized();
    return _guard(() async {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'scanBluetooth',
        {
          if (timeout != null) 'timeout': timeout.inMilliseconds,
        },
      );
      return _parseDeviceList(result);
    });
  }

  @override
  Future<List<PrinterDevice>> scanBle({Duration? timeout}) {
    _ensureEventChannelsInitialized();
    return _guard(() async {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'scanBle',
        {
          if (timeout != null) 'timeout': timeout.inMilliseconds,
        },
      );
      return _parseDeviceList(result);
    });
  }

  @override
  Future<List<PrinterDevice>> scanUsb() {
    _ensureEventChannelsInitialized();
    return _guard(() async {
      final result = await _methodChannel
          .invokeMethod<List<dynamic>>('scanUsb');
      return _parseDeviceList(result);
    });
  }

  @override
  Future<List<PrinterDevice>> scanNetwork({String? subnet}) {
    _ensureEventChannelsInitialized();
    return _guard(() async {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'scanNetwork',
        {
          if (subnet != null) 'subnet': subnet,
        },
      );
      return _parseDeviceList(result);
    });
  }

  // ---------------------------------------------------------------------------
  // Connection Management
  // ---------------------------------------------------------------------------

  @override
  Future<void> connectBluetooth({
    required String macAddress,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) {
    _ensureEventChannelsInitialized();
    return _guard(() => _methodChannel.invokeMethod<void>(
      'connectBluetooth',
      {
        'macAddress': macAddress,
        if (profile != null) 'profile': profile.toMap(),
        'autoReconnect': autoReconnect,
        if (timeout != null) 'timeout': timeout.inMilliseconds,
      },
    ));
  }

  @override
  Future<void> connectBle({
    required String deviceId,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) {
    _ensureEventChannelsInitialized();
    return _guard(() => _methodChannel.invokeMethod<void>(
      'connectBle',
      {
        'deviceId': deviceId,
        if (profile != null) 'profile': profile.toMap(),
        'autoReconnect': autoReconnect,
        if (timeout != null) 'timeout': timeout.inMilliseconds,
      },
    ));
  }

  @override
  Future<void> connectUsb({
    required int vendorId,
    required int productId,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) {
    _ensureEventChannelsInitialized();
    return _guard(() => _methodChannel.invokeMethod<void>(
      'connectUsb',
      {
        'vendorId': vendorId,
        'productId': productId,
        if (profile != null) 'profile': profile.toMap(),
        'autoReconnect': autoReconnect,
        if (timeout != null) 'timeout': timeout.inMilliseconds,
      },
    ));
  }

  @override
  Future<void> connectNetwork({
    required String ipAddress,
    int port = 9100,
    PrinterProfile? profile,
    bool autoReconnect = false,
    Duration? timeout,
  }) {
    _ensureEventChannelsInitialized();
    return _guard(() => _methodChannel.invokeMethod<void>(
      'connectNetwork',
      {
        'ipAddress': ipAddress,
        'port': port,
        if (profile != null) 'profile': profile.toMap(),
        'autoReconnect': autoReconnect,
        if (timeout != null) 'timeout': timeout.inMilliseconds,
      },
    ));
  }

  @override
  Future<void> disconnect() {
    return _guard(
      () => _methodChannel.invokeMethod<void>('disconnect'),
    );
  }

  @override
  Future<bool> isConnected() {
    return _guard(
      () => _methodChannel.invokeMethod<bool>('isConnected').then(
            (v) => v ?? false,
          ),
    );
  }

  // ---------------------------------------------------------------------------
  // Printer Status
  // ---------------------------------------------------------------------------

  @override
  Future<PrinterStatus> getStatus() {
    return _guard(() async {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'getStatus',
      );
      return PrinterStatus.fromMap(Map<String, dynamic>.from(result ?? {}));
    });
  }

  // ---------------------------------------------------------------------------
  // Print Operations
  // ---------------------------------------------------------------------------

  @override
  Future<void> printBytes(List<int> bytes) {
    return _guard(() => _methodChannel.invokeMethod<void>(
      'printBytes',
      {'bytes': bytes},
    ));
  }

  @override
  Future<void> printText(String text) {
    return _guard(() => _methodChannel.invokeMethod<void>(
      'printText',
      {'text': text},
    ));
  }

  @override
  Future<void> printLines(List<String> lines) {
    return _guard(() => _methodChannel.invokeMethod<void>(
      'printLines',
      {'lines': lines},
    ));
  }

  @override
  Future<void> printQrCode(String data, {int size = 6}) {
    return _guard(() => _methodChannel.invokeMethod<void>(
      'printQrCode',
      {'data': data, 'size': size},
    ));
  }

  @override
  Future<void> printBarcode(String data, {String type = 'CODE128'}) {
    return _guard(() => _methodChannel.invokeMethod<void>(
      'printBarcode',
      {'data': data, 'type': type},
    ));
  }

  @override
  Future<void> printImage(Uint8List imageBytes) {
    return _guard(() => _methodChannel.invokeMethod<void>(
      'printImage',
      {'imageBytes': imageBytes},
    ));
  }

  @override
  Future<void> printPdf(Uint8List pdfBytes) {
    return _guard(() => _methodChannel.invokeMethod<void>(
      'printPdf',
      {'pdfBytes': pdfBytes},
    ));
  }

  @override
  Future<void> printReceipt(List<int> receiptBytes) {
    return _guard(() => _methodChannel.invokeMethod<void>(
      'printReceipt',
      {'receiptBytes': receiptBytes},
    ));
  }

  // ---------------------------------------------------------------------------
  // Cash Drawer
  // ---------------------------------------------------------------------------

  @override
  Future<void> openCashDrawer({int pin = 0}) {
    return _guard(() => _methodChannel.invokeMethod<void>(
      'openCashDrawer',
      {'pin': pin},
    ));
  }

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  @override
  Future<bool> requestPermissions() {
    return _guard(
      () => _methodChannel.invokeMethod<bool>('requestPermissions').then(
            (v) => v ?? false,
          ),
    );
  }

  @override
  Future<bool> checkPermissions() {
    return _guard(
      () => _methodChannel.invokeMethod<bool>('checkPermissions').then(
            (v) => v ?? false,
          ),
    );
  }

  // ---------------------------------------------------------------------------
  // Platform Info
  // ---------------------------------------------------------------------------

  @override
  Future<String> getPlatformVersion() {
    return _guard(
      () => _methodChannel
          .invokeMethod<String>('getPlatformVersion')
          .then((v) => v ?? 'unknown'),
    );
  }

  @override
  Future<bool> isFeatureSupported(String feature) {
    return _guard(
      () => _methodChannel.invokeMethod<bool>(
        'isFeatureSupported',
        {'feature': feature},
      ).then((v) => v ?? false),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Converts a raw list-of-maps response from the native side into a
  /// typed [List<PrinterDevice>].
  List<PrinterDevice> _parseDeviceList(List<dynamic>? raw) {
    if (raw == null) return const [];
    return raw
        .map((item) {
          if (item is Map) {
            return PrinterDevice.fromMap(Map<String, dynamic>.from(item));
          }
          return null;
        })
        .whereType<PrinterDevice>()
        .toList();
  }

  /// Cancels all event channel subscriptions and marks the instance as
  /// disposed.
  ///
  /// After disposal the instance is non-functional. A new
  /// [MethodChannelThunderThermalPrint] should be assigned to
  /// [ThunderThermalPrintPlatform.instance] if further communication is
  /// required.
  Future<void> dispose() async {
    await _connectionStateSubscription?.cancel();
    await _deviceEventsSubscription?.cancel();
    _connectionStateSubscription = null;
    _deviceEventsSubscription = null;
    _eventChannelsInitialized = false;
  }
}