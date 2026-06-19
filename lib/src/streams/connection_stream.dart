import 'dart:async';

import '../models/models.dart';

/// Singleton broadcast stream controller that exposes connection state
/// changes for the thermal printer.
///
/// The native side pushes state transitions through an [EventChannel]. The
/// [MethodChannelThunderThermalPrint] layer listens to that channel and
/// forwards events into this stream so that Dart-only consumers do not
/// need to interact with platform channels directly.
///
/// Usage:
/// ```dart
/// ConnectionStream().stream.listen((state) {
///   print('Connection state: ${state.displayName}');
/// });
/// ```
class ConnectionStream {
  // ---------------------------------------------------------------------------
  // Singleton
  // ---------------------------------------------------------------------------

  static final ConnectionStream _instance = ConnectionStream._internal();

  /// Factory constructor that always returns the same singleton instance.
  factory ConnectionStream() => _instance;

  ConnectionStream._internal();

  // ---------------------------------------------------------------------------
  // Stream controller
  // ---------------------------------------------------------------------------

  final StreamController<PrinterConnectionState> _controller =
      StreamController<PrinterConnectionState>.broadcast();

  /// The most recently emitted state.
  ///
  /// Defaults to [PrinterConnectionState.disconnected].
  PrinterConnectionState _lastState = PrinterConnectionState.disconnected;

  /// A broadcast [Stream] of [PrinterConnectionState] values.
  ///
  /// New subscribers receive **only** events that occur after they
  /// subscribe. Use [currentState] to check the latest value
  /// synchronously.
  Stream<PrinterConnectionState> get stream => _controller.stream;

  /// Returns the most recent connection state without waiting for the
  /// stream.
  PrinterConnectionState get currentState => _lastState;

  // ---------------------------------------------------------------------------
  // Emit / dispose
  // ---------------------------------------------------------------------------

  /// Pushes a new [state] onto the broadcast stream.
  ///
  /// If the controller has been closed this call is a no-op.
  void emit(PrinterConnectionState state) {
    _lastState = state;
    if (!_controller.isClosed) {
      _controller.add(state);
    }
  }

  /// Closes the underlying [StreamController] and releases resources.
  ///
  /// After calling [dispose], [emit] becomes a no-op and the [stream]
  /// will close. The singleton instance remains accessible but
  /// non-functional. Callers who need a fresh controller must create a
  /// new [ConnectionStream] (the singleton will be reused but is
  /// permanently closed).
  Future<void> dispose() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}