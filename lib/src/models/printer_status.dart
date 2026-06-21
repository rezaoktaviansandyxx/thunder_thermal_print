/// Represents the current status of a thermal printer.
class PrinterStatus {
  /// Whether the printer is online and responsive
  final bool online;

  /// Whether the paper roll is out
  final bool paperOut;

  /// Whether the paper is near the end of the roll
  final bool paperNearEnd;

  /// Whether the printer cover is open
  final bool coverOpen;

  /// Whether the cash drawer is open
  final bool drawerOpen;

  /// Whether the battery level is low
  final bool batteryLow;

  /// Current battery level percentage (0-100), null if not available
  final int? batteryLevel;

  /// Error code from the printer, null if no error
  final int? errorCode;

  /// Human-readable error message
  final String? errorMessage;

  /// Timestamp of when this status was retrieved
  final DateTime? timestamp;

  const PrinterStatus({
    this.online = false,
    this.paperOut = false,
    this.paperNearEnd = false,
    this.coverOpen = false,
    this.drawerOpen = false,
    this.batteryLow = false,
    this.batteryLevel,
    this.errorCode,
    this.errorMessage,
    this.timestamp,
  });

  factory PrinterStatus.fromMap(Map<String, dynamic> map) {
    return PrinterStatus(
      online: map['online'] as bool? ?? false,
      paperOut: map['paperOut'] as bool? ?? false,
      paperNearEnd: map['paperNearEnd'] as bool? ?? false,
      coverOpen: map['coverOpen'] as bool? ?? false,
      drawerOpen: map['drawerOpen'] as bool? ?? false,
      batteryLow: map['batteryLow'] as bool? ?? false,
      batteryLevel: map['batteryLevel'] as int?,
      errorCode: map['errorCode'] as int?,
      errorMessage: map['errorMessage'] as String?,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : null,
    );
  }

  /// Creates a copy of this [PrinterStatus] with the given fields replaced.
  PrinterStatus copyWith({
    bool? online,
    bool? paperOut,
    bool? paperNearEnd,
    bool? coverOpen,
    bool? drawerOpen,
    bool? batteryLow,
    int? batteryLevel,
    int? errorCode,
    String? errorMessage,
    DateTime? timestamp,
    bool clearErrorCode = false,
    bool clearErrorMessage = false,
    bool clearBatteryLevel = false,
    bool clearTimestamp = false,
  }) {
    return PrinterStatus(
      online: online ?? this.online,
      paperOut: paperOut ?? this.paperOut,
      paperNearEnd: paperNearEnd ?? this.paperNearEnd,
      coverOpen: coverOpen ?? this.coverOpen,
      drawerOpen: drawerOpen ?? this.drawerOpen,
      batteryLow: batteryLow ?? this.batteryLow,
      batteryLevel: clearBatteryLevel ? null : (batteryLevel ?? this.batteryLevel),
      errorCode: clearErrorCode ? null : (errorCode ?? this.errorCode),
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      timestamp: clearTimestamp ? null : (timestamp ?? this.timestamp),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'online': online,
      'paperOut': paperOut,
      'paperNearEnd': paperNearEnd,
      'coverOpen': coverOpen,
      'drawerOpen': drawerOpen,
      'batteryLow': batteryLow,
      'batteryLevel': batteryLevel,
      'errorCode': errorCode,
      'errorMessage': errorMessage,
      'timestamp': timestamp?.toIso8601String(),
    };
  }

  /// Returns true if the printer is in a state that allows printing.
  bool get canPrint => online && !paperOut && !coverOpen;

  /// Returns a list of active issues preventing printing.
  List<String> get issues {
    final issues = <String>[];
    if (!online) issues.add('Printer is offline');
    if (paperOut) issues.add('Paper is out');
    if (paperNearEnd) issues.add('Paper is near end');
    if (coverOpen) issues.add('Cover is open');
    if (batteryLow) issues.add('Battery is low');
    return issues;
  }

  @override
  String toString() =>
      'PrinterStatus(online: $online, paperOut: $paperOut, '
      'paperNearEnd: $paperNearEnd, coverOpen: $coverOpen, '
      'drawerOpen: $drawerOpen, batteryLow: $batteryLow, '
      'timestamp: $timestamp)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterStatus &&
          runtimeType == other.runtimeType &&
          online == other.online &&
          paperOut == other.paperOut &&
          paperNearEnd == other.paperNearEnd &&
          coverOpen == other.coverOpen &&
          drawerOpen == other.drawerOpen &&
          batteryLow == other.batteryLow &&
          batteryLevel == other.batteryLevel &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
        online,
        paperOut,
        paperNearEnd,
        coverOpen,
        drawerOpen,
        batteryLow,
        batteryLevel,
        timestamp,
      );
}
