import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_thermal_print/thunder_thermal_print.dart';

/// Integration tests for the thunder_thermal_print plugin.
/// 
/// These tests verify the full integration of all components.
/// Note: These tests do not require a physical printer - they test the Dart layer.
void main() {
  group('ThunderThermalPrint Integration', () {
    test('connectionStream returns broadcast stream', () {
      final stream = ThunderThermalPrint.connectionStream;
      expect(stream.isBroadcast, true);
    });

    test('deviceEventStream returns broadcast stream', () {
      final stream = ThunderThermalPrint.deviceEventStream;
      expect(stream.isBroadcast, true);
    });

    test('isFeatureSupported returns bool for known features', () async {
      final features = ['bluetooth', 'ble', 'usb', 'network', 'qrCode', 'barcode', 'image'];
      for (final feature in features) {
        final result = await ThunderThermalPrint.isFeatureSupported(feature);
        expect(result, isA<bool>());
      }
    });

    test('getPlatformVersion returns non-empty string', () async {
      final version = await ThunderThermalPrint.getPlatformVersion();
      expect(version, isA<String>());
      expect(version.isNotEmpty, true);
    });

    test('isConnected returns bool when not connected', () async {
      final result = await ThunderThermalPrint.isConnected();
      expect(result, isA<bool>());
    });

    test('disconnect works when not connected', () async {
      // Should not throw when not connected
      await ThunderThermalPrint.disconnect();
    });

    test('checkPermissions returns bool', () async {
      final result = await ThunderThermalPrint.checkPermissions();
      expect(result, isA<bool>());
    });
  });

  group('PrinterDevice Model Integration', () {
    test('PrinterDevice serialization round-trip', () {
      final original = PrinterDevice(
        address: '00:11:22:33:44:55',
        name: 'Test Printer',
        connectionType: PrinterConnectionType.bluetooth,
        rssi: -50,
        vendorId: 1234,
        productId: 5678,
        isConnected: true,
        metadata: {'key': 'value'},
      );

      final map = original.toMap();
      final restored = PrinterDevice.fromMap(map);

      expect(restored.address, original.address);
      expect(restored.name, original.name);
      expect(restored.connectionType, original.connectionType);
      expect(restored.rssi, original.rssi);
      expect(restored.isConnected, original.isConnected);
    });
  });

  group('PrinterStatus Model Integration', () {
    test('PrinterStatus serialization round-trip', () {
      final original = PrinterStatus(
        online: true,
        paperOut: false,
        paperNearEnd: true,
        coverOpen: false,
        drawerOpen: false,
        batteryLow: true,
        batteryLevel: 25,
      );

      final map = original.toMap();
      final restored = PrinterStatus.fromMap(map);

      expect(restored.online, original.online);
      expect(restored.paperOut, original.paperOut);
      expect(restored.paperNearEnd, original.paperNearEnd);
      expect(restored.batteryLow, original.batteryLow);
      expect(restored.batteryLevel, original.batteryLevel);
    });
  });

  group('PrinterEvent Model Integration', () {
    test('PrinterEvent serialization round-trip', () {
      final original = PrinterEvent(
        type: PrinterEventType.printerConnected,
        deviceId: 'device-123',
        message: 'Connected successfully',
        data: {'timestamp': '2024-01-01'},
      );

      final map = original.toMap();
      final restored = PrinterEvent.fromMap(map);

      expect(restored.type, original.type);
      expect(restored.deviceId, original.deviceId);
      expect(restored.message, original.message);
    });
  });

  group('PrinterProfile Integration', () {
    test('all built-in profiles can be looked up', () {
      final profiles = PrinterProfile.availableProfiles;
      for (final name in profiles) {
        final profile = PrinterProfile.lookup(name);
        expect(profile, isNotNull, reason: 'Profile "$name" should be lookup-able');
      }
    });

    test('custom profile has correct settings', () {
      final custom = PrinterProfile.custom(
        name: 'Custom',
        paperWidth: 80,
        maxCharsPerLine: 48,
        supportsQrCode: false,
      );

      expect(custom.name, 'Custom');
      expect(custom.paperWidth, 80);
      expect(custom.maxCharsPerLine, 48);
      expect(custom.supportsQrCode, false);
    });
  });

  group('ReceiptBuilder + EscPosCommands Integration', () {
    test('ReceiptBuilder generates valid ESC/POS bytes', () {
      final receipt = ReceiptBuilder(maxCharsPerLine: 32)
          .center()
          .bold()
          .text('Test')
          .normal()
          .line()
          .feed(lines: 3)
          .cut();

      final bytes = receipt.build();

      // Should start with initialize command
      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x40);

      // Should contain alignment command
      expect(bytes.contains(0x61), true);

      // Should contain bold command
      expect(bytes.contains(0x45), true);

      // Should contain cut command
      expect(bytes.contains(0x56), true);
    });

    test('QR code generates valid ESC/POS bytes', () {
      final bytes = EscPosCommands.printQrCode('https://example.com');
      expect(bytes.isNotEmpty, true);
      expect(bytes.first, 0x1D); // GS
    });

    test('Barcode generates valid ESC/POS bytes', () {
      final bytes = EscPosCommands.printBarcode('123456789', type: BarcodeType.code128);
      expect(bytes.isNotEmpty, true);
      expect(bytes.contains(0x6B), true); // GS k
    });
  });

  group('ConnectionConfig Integration', () {
    test('ConnectionConfig serialization round-trip', () {
      final original = ConnectionConfig(
        identifier: '192.168.1.100',
        port: 9100,
        timeout: const Duration(seconds: 15),
        reconnectDelay: const Duration(seconds: 5),
        maxReconnectAttempts: 10,
        autoReconnect: true,
        profile: 'epson',
      );

      final map = original.toMap();
      final restored = ConnectionConfig.fromMap(map);

      expect(restored.identifier, original.identifier);
      expect(restored.port, original.port);
      expect(restored.timeout, original.timeout);
      expect(restored.reconnectDelay, original.reconnectDelay);
      expect(restored.maxReconnectAttempts, original.maxReconnectAttempts);
      expect(restored.autoReconnect, original.autoReconnect);
    });
  });

  group('Stream Integration', () {
    test('ConnectionStream emits and receives states', () async {
      final stream = ConnectionStream();
      final states = <PrinterConnectionState>[];
      final subscription = stream.stream.listen(states.add);

      stream.emit(PrinterConnectionState.connecting);
      stream.emit(PrinterConnectionState.connected);
      stream.emit(PrinterConnectionState.disconnected);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(states, contains(PrinterConnectionState.connecting));
      expect(states, contains(PrinterConnectionState.connected));
      expect(states, contains(PrinterConnectionState.disconnected));

      await subscription.cancel();
    });

    test('DeviceEventStream emits and receives events', () async {
      final stream = DeviceEventStream();
      final events = <PrinterEvent>[];
      final subscription = stream.stream.listen(events.add);

      final event1 = PrinterEvent(type: PrinterEventType.printerConnected);
      final event2 = PrinterEvent(type: PrinterEventType.paperOut);

      stream.emit(event1);
      stream.emit(event2);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(events, contains(event1));
      expect(events, contains(event2));

      await subscription.cancel();
    });
  });
}
