/// Base exception for all thermal printer errors.
///
/// All printer-related exceptions extend this class, allowing callers to
/// catch any printer error with a single [PrinterException] catch block
/// or handle specific error types individually.
class PrinterException implements Exception {
  /// Human-readable description of the error.
  final String message;

  /// Optional machine-readable error code for programmatic handling.
  final String? code;

  /// Optional additional details about the error context.
  final Object? details;

  const PrinterException(
    this.message, {
    this.code,
    this.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('PrinterException: $message');
    if (code != null) {
      buffer.write(' (code: $code)');
    }
    if (details != null) {
      buffer.write(' | details: $details');
    }
    return buffer.toString();
  }
}

/// Thrown when a connection to the printer cannot be established or is lost.
class ConnectionException extends PrinterException {
  const ConnectionException(
    super.message, {
    super.code,
    super.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('ConnectionException: $message');
    if (code != null) buffer.write(' (code: $code)');
    if (details != null) buffer.write(' | details: $details');
    return buffer.toString();
  }
}

/// Thrown when required permissions (Bluetooth, location, USB, etc.) are not granted.
class PermissionException extends PrinterException {
  /// The permission that was denied.
  final String? permissionName;

  const PermissionException(
    super.message, {
    this.permissionName,
    super.code,
    super.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('PermissionException: $message');
    if (permissionName != null) {
      buffer.write(' (permission: $permissionName)');
    }
    if (code != null) buffer.write(' (code: $code)');
    if (details != null) buffer.write(' | details: $details');
    return buffer.toString();
  }
}

/// Thrown when the printer reports that the paper roll is empty.
class PaperOutException extends PrinterException {
  const PaperOutException(
    super.message, {
    super.code,
    super.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('PaperOutException: $message');
    if (code != null) buffer.write(' (code: $code)');
    if (details != null) buffer.write(' | details: $details');
    return buffer.toString();
  }
}

/// Thrown when the printer reports that its cover is open.
class CoverOpenException extends PrinterException {
  const CoverOpenException(
    super.message, {
    super.code,
    super.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('CoverOpenException: $message');
    if (code != null) buffer.write(' (code: $code)');
    if (details != null) buffer.write(' | details: $details');
    return buffer.toString();
  }
}

/// Thrown when a specified printer device cannot be found during scanning.
class DeviceNotFoundException extends PrinterException {
  /// The address or identifier that was searched for.
  final String? searchedAddress;

  const DeviceNotFoundException(
    super.message, {
    this.searchedAddress,
    super.code,
    super.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('DeviceNotFoundException: $message');
    if (searchedAddress != null) {
      buffer.write(' (searchedAddress: $searchedAddress)');
    }
    if (code != null) buffer.write(' (code: $code)');
    if (details != null) buffer.write(' | details: $details');
    return buffer.toString();
  }
}

/// Thrown when a print operation exceeds the configured timeout duration.
class PrintTimeoutException extends PrinterException {
  /// The timeout duration in milliseconds, if known.
  final int? timeoutMs;

  const PrintTimeoutException(
    super.message, {
    this.timeoutMs,
    super.code,
    super.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('PrintTimeoutException: $message');
    if (timeoutMs != null) {
      buffer.write(' (timeoutMs: $timeoutMs)');
    }
    if (code != null) buffer.write(' (code: $code)');
    if (details != null) buffer.write(' | details: $details');
    return buffer.toString();
  }
}

/// Thrown when the printer or connection type does not support the requested operation.
class NotSupportedException extends PrinterException {
  /// The feature or operation that is not supported.
  final String? feature;

  const NotSupportedException(
    super.message, {
    this.feature,
    super.code,
    super.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('NotSupportedException: $message');
    if (feature != null) {
      buffer.write(' (feature: $feature)');
    }
    if (code != null) buffer.write(' (code: $code)');
    if (details != null) buffer.write(' | details: $details');
    return buffer.toString();
  }
}

/// Thrown when the printer is busy processing a previous job and cannot
/// accept new data at this time.
class PrinterBusyException extends PrinterException {
  const PrinterBusyException(
    super.message, {
    super.code,
    super.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('PrinterBusyException: $message');
    if (code != null) buffer.write(' (code: $code)');
    if (details != null) buffer.write(' | details: $details');
    return buffer.toString();
  }
}

/// Thrown when the data provided for printing is invalid, malformed,
/// or exceeds the printer's capabilities.
class InvalidDataException extends PrinterException {
  const InvalidDataException(
    super.message, {
    super.code,
    super.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('InvalidDataException: $message');
    if (code != null) buffer.write(' (code: $code)');
    if (details != null) buffer.write(' | details: $details');
    return buffer.toString();
  }
}
