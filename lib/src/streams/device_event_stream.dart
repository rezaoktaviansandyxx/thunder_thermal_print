import 'dart:async';

import '../models/models.dart';

/// Singleton broadcast stream controller that exposes hardware and
/// lifecycle events from the thermal printer.
///
/// Events originate from the native side via an [EventChannel]. The
/// [MethodChannelThunderThermalPrint] implementation listens to that channel
/// and re-emits the events through this stream so that pure-Dart consumers
/// can subscribe without touching platform channels.
///
/// Usage:
/// ```dart
/// DeviceEventStream().stream.listen((event) {
///   print('Printer event: ${event.type.name}');
/// });
/// ```
class DeviceEventStream {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  static final DeviceEventStream _instance = DeviceEventStream._internal();

  /// Factory constructor that always returns the same singleton instance.
  factory DeviceEventStream() => _instance;

  DeviceEventStream._internal();

  // ---------------------------------------------------------------------------
  // Stream controller
  // ---------------------------------------------------------------------------

  final StreamController<PrinterEvent> _controller =
      StreamController<PrinterEvent>.broadcast();

  /// The most recently emitted event, or `null` if no event has been
  /// emitted yet.
  PrinterEvent? _lastEvent;

  /// A broadcast [Stream] of [PrinterEvent] values.
  ///
  /// New subscribers receive **only** events that occur after they
  /// subscribe. Use [lastEvent] to inspect the most recent event
  /// synchronously.
  Stream<PrinterEvent> get stream => _controller.stream;

  /// Returns the most recent event that was emitted, or `null` if the
  /// stream has not yet received any events.
  PrinterEvent? get lastEvent => _lastEvent;

  // ---------------------------------------------------------------------------
  // Emit / dispose
  // ---------------------------------------------------------------------------

  /// Pushes a new [event] onto the broadcast stream.
  ///
  /// If the controller has been closed this call is a no-op.
  void emit(PrinterEvent event) {
    _lastEvent = event;
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// Closes the underlying [StreamController] and releases resources.
  ///
  /// After calling [dispose], [emit] becomes a no-op and the [stream]
  /// will close. The singleton instance remains accessible but
  /// non-functional.
  Future<void> dispose() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}