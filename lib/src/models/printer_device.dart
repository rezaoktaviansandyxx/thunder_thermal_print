/// Represents a discovered thermal printer device.
class PrinterDevice {
  /// Unique identifier (MAC address for Bluetooth, IP for network, etc.)
  final String address;

  /// Human-readable device name
  final String name;

  /// Connection type of this device
  final PrinterConnectionType connectionType;

  /// Port for network devices (e.g. 9100 for ESC/POS)
  final int? port;

  /// Signal strength (RSSI) for wireless devices, null for USB
  final int? rssi;

  /// Vendor ID for USB devices
  final int? vendorId;

  /// Product ID for USB devices
  final int? productId;

  /// Whether the device is currently connected
  final bool isConnected;

  /// Whether USB host permission has been granted for this device.
  /// Only meaningful for USB devices on Android. `null` for other types.
  final bool? usbPermissionGranted;

  /// Additional device metadata
  final Map<String, dynamic> metadata;

  const PrinterDevice({
    required this.address,
    required this.name,
    required this.connectionType,
    this.port,
    this.rssi,
    this.vendorId,
    this.productId,
    this.isConnected = false,
    this.usbPermissionGranted,
    this.metadata = const {},
  });

  factory PrinterDevice.fromMap(Map<String, dynamic> map) {
    return PrinterDevice(
      address: map['address'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown Printer',
      connectionType: PrinterConnectionType.fromString(
        map['connectionType'] as String? ?? 'unknown',
      ),
      port: map['port'] as int?,
      rssi: map['rssi'] as int?,
      vendorId: map['vendorId'] as int?,
      productId: map['productId'] as int?,
      isConnected: map['isConnected'] as bool? ?? false,
      usbPermissionGranted: map['hasPermission'] as bool?,
      metadata: Map<String, dynamic>.from(map['metadata'] as Map? ?? {}),
    );
  }

  /// Creates a copy of this [PrinterDevice] with the given fields replaced.
  PrinterDevice copyWith({
    String? address,
    String? name,
    PrinterConnectionType? connectionType,
    int? port,
    int? rssi,
    int? vendorId,
    int? productId,
    bool? isConnected,
    bool? usbPermissionGranted,
    Map<String, dynamic>? metadata,
    bool clearPort = false,
    bool clearRssi = false,
    bool clearVendorId = false,
    bool clearProductId = false,
    bool clearUsbPermissionGranted = false,
  }) {
    return PrinterDevice(
      address: address ?? this.address,
      name: name ?? this.name,
      connectionType: connectionType ?? this.connectionType,
      port: clearPort ? null : (port ?? this.port),
      rssi: clearRssi ? null : (rssi ?? this.rssi),
      vendorId: clearVendorId ? null : (vendorId ?? this.vendorId),
      productId: clearProductId ? null : (productId ?? this.productId),
      isConnected: isConnected ?? this.isConnected,
      usbPermissionGranted: clearUsbPermissionGranted
          ? null
          : (usbPermissionGranted ?? this.usbPermissionGranted),
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'name': name,
      'connectionType': connectionType.name,
      'port': port,
      'rssi': rssi,
      'vendorId': vendorId,
      'productId': productId,
      'isConnected': isConnected,
      'hasPermission': usbPermissionGranted,
      'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterDevice &&
          runtimeType == other.runtimeType &&
          address == other.address &&
          name == other.name &&
          connectionType == other.connectionType &&
          port == other.port &&
          rssi == other.rssi &&
          vendorId == other.vendorId &&
          productId == other.productId &&
          isConnected == other.isConnected &&
          usbPermissionGranted == other.usbPermissionGranted;

  @override
  int get hashCode => Object.hash(
        address,
        name,
        connectionType,
        port,
        rssi,
        vendorId,
        productId,
        isConnected,
        usbPermissionGranted,
      );

  @override
  String toString() =>
      'PrinterDevice(address: $address, name: $name, type: $connectionType)';
}

/// Enum representing the type of printer connection.
enum PrinterConnectionType {
  bluetooth,
  ble,
  usb,
  network,
  wifi,
  ethernet,
  tcp,
  unknown;

  static PrinterConnectionType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'bluetooth':
        return PrinterConnectionType.bluetooth;
      case 'ble':
        return PrinterConnectionType.ble;
      case 'usb':
        return PrinterConnectionType.usb;
      case 'network':
      case 'wifi':
        return PrinterConnectionType.network;
      case 'ethernet':
        return PrinterConnectionType.ethernet;
      case 'tcp':
        return PrinterConnectionType.tcp;
      default:
        return PrinterConnectionType.unknown;
    }
  }

  /// Whether this connection type uses wireless communication.
  bool get isWireless =>
      this == PrinterConnectionType.bluetooth ||
      this == PrinterConnectionType.ble ||
      this == PrinterConnectionType.wifi ||
      this == PrinterConnectionType.network ||
      this == PrinterConnectionType.ethernet ||
      this == PrinterConnectionType.tcp;

  /// Whether this connection type is wired.
  bool get isWired => this == PrinterConnectionType.usb;

  /// Human-readable label for this connection type.
  String get displayName {
    switch (this) {
      case PrinterConnectionType.bluetooth:
        return 'Bluetooth';
      case PrinterConnectionType.ble:
        return 'BLE';
      case PrinterConnectionType.usb:
        return 'USB';
      case PrinterConnectionType.network:
        return 'Network';
      case PrinterConnectionType.wifi:
        return 'WiFi';
      case PrinterConnectionType.ethernet:
        return 'Ethernet';
      case PrinterConnectionType.tcp:
        return 'TCP/IP';
      case PrinterConnectionType.unknown:
        return 'Unknown';
    }
  }
}
