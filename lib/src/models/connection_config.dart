/// ConnectionConfig model for printer connection configuration.
class ConnectionConfig {
  final String identifier;
  final int? port;
  final Duration timeout;
  final Duration reconnectDelay;
  final int maxReconnectAttempts;
  final bool autoReconnect;
  final String profile;
  final Map<String, dynamic>? metadata;

  const ConnectionConfig({
    required this.identifier,
    this.port,
    this.timeout = const Duration(seconds: 10),
    this.reconnectDelay = const Duration(seconds: 3),
    this.maxReconnectAttempts = 5,
    this.autoReconnect = true,
    this.profile = 'custom',
    this.metadata,
  });

  factory ConnectionConfig.fromMap(Map<String, dynamic> map) {
    return ConnectionConfig(
      identifier: map['identifier'] as String,
      port: map['port'] as int?,
      timeout: Duration(
        seconds: map['timeoutSeconds'] as int? ?? 10,
      ),
      reconnectDelay: Duration(
        seconds: map['reconnectDelaySeconds'] as int? ?? 3,
      ),
      maxReconnectAttempts: map['maxReconnectAttempts'] as int? ?? 5,
      autoReconnect: map['autoReconnect'] as bool? ?? true,
      profile: map['profile'] as String? ?? 'custom',
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'identifier': identifier,
      'port': port,
      'timeoutSeconds': timeout.inSeconds,
      'reconnectDelaySeconds': reconnectDelay.inSeconds,
      'maxReconnectAttempts': maxReconnectAttempts,
      'autoReconnect': autoReconnect,
      'profile': profile,
      'metadata': metadata,
    };
  }

  ConnectionConfig copyWith({
    String? identifier,
    int? port,
    Duration? timeout,
    Duration? reconnectDelay,
    int? maxReconnectAttempts,
    bool? autoReconnect,
    String? profile,
    Map<String, dynamic>? metadata,
  }) {
    return ConnectionConfig(
      identifier: identifier ?? this.identifier,
      port: port ?? this.port,
      timeout: timeout ?? this.timeout,
      reconnectDelay: reconnectDelay ?? this.reconnectDelay,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      profile: profile ?? this.profile,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() =>
      'ConnectionConfig(identifier: $identifier, port: $port, '
      'autoReconnect: $autoReconnect)';
}
