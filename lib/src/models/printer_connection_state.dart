/// Represents the current connection state of a thermal printer.
enum PrinterConnectionState {
  /// No active connection
  disconnected,

  /// Currently establishing a connection
  connecting,

  /// Successfully connected and ready
  connected,

  /// Attempting to reconnect after disconnection
  reconnecting,

  /// Connection was lost unexpectedly
  connectionLost,

  /// All reconnection attempts have failed
  reconnectFailed,
}

/// Provides human-readable descriptions for connection states.
extension PrinterConnectionStateExtension on PrinterConnectionState {
  String get displayName {
    switch (this) {
      case PrinterConnectionState.disconnected:
        return 'Disconnected';
      case PrinterConnectionState.connecting:
        return 'Connecting...';
      case PrinterConnectionState.connected:
        return 'Connected';
      case PrinterConnectionState.reconnecting:
        return 'Reconnecting...';
      case PrinterConnectionState.connectionLost:
        return 'Connection Lost';
      case PrinterConnectionState.reconnectFailed:
        return 'Reconnect Failed';
    }
  }

  bool get isConnecting =>
      this == PrinterConnectionState.connecting ||
      this == PrinterConnectionState.reconnecting;

  bool get isConnected => this == PrinterConnectionState.connected;

  bool get isError =>
      this == PrinterConnectionState.connectionLost ||
      this == PrinterConnectionState.reconnectFailed;
}
