/// Events emitted by the thermal printer plugin.
enum PrinterEventType {
  printerConnected,
  printerDisconnected,
  bluetoothEnabled,
  bluetoothDisabled,
  usbAttached,
  usbDetached,
  networkConnected,
  networkDisconnected,
  paperOut,
  paperNearEnd,
  coverOpen,
  coverClosed,
  drawerOpen,
  drawerClosed,
  batteryLow,
  batteryNormal,
  error,
  unknown,
}

/// Represents a printer-related event.
class PrinterEvent {
  final PrinterEventType type;
  final String? deviceId;
  final String? message;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  PrinterEvent({
    required this.type,
    this.deviceId,
    this.message,
    this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory PrinterEvent.fromMap(Map<String, dynamic> map) {
    return PrinterEvent(
      type: PrinterEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => PrinterEventType.unknown,
      ),
      deviceId: map['deviceId'] as String?,
      message: map['message'] as String?,
      data: map['data'] != null
          ? Map<String, dynamic>.from(map['data'] as Map)
          : null,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'deviceId': deviceId,
      'message': message,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Creates a copy of this [PrinterEvent] with the given fields replaced.
  PrinterEvent copyWith({
    PrinterEventType? type,
    String? deviceId,
    String? message,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool clearDeviceId = false,
    bool clearMessage = false,
    bool clearData = false,
  }) {
    return PrinterEvent(
      type: type ?? this.type,
      deviceId: clearDeviceId ? null : (deviceId ?? this.deviceId),
      message: clearMessage ? null : (message ?? this.message),
      data: clearData ? null : (data ?? this.data),
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Whether this event represents a connection-related event.
  bool get isConnectionEvent =>
      type == PrinterEventType.printerConnected ||
      type == PrinterEventType.printerDisconnected ||
      type == PrinterEventType.bluetoothEnabled ||
      type == PrinterEventType.bluetoothDisabled ||
      type == PrinterEventType.usbAttached ||
      type == PrinterEventType.usbDetached ||
      type == PrinterEventType.networkConnected ||
      type == PrinterEventType.networkDisconnected;

  /// Whether this event represents a hardware error condition.
  bool get isHardwareEvent =>
      type == PrinterEventType.paperOut ||
      type == PrinterEventType.paperNearEnd ||
      type == PrinterEventType.coverOpen ||
      type == PrinterEventType.coverClosed ||
      type == PrinterEventType.drawerOpen ||
      type == PrinterEventType.drawerClosed ||
      type == PrinterEventType.batteryLow ||
      type == PrinterEventType.batteryNormal;

  @override
  String toString() => 'PrinterEvent(type: ${type.name}, message: $message)';
}
