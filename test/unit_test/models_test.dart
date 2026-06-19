import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_thermal_print/src/models/models.dart';

void main() {
  // ---------------------------------------------------------------------------
  // PrinterDevice
  // ---------------------------------------------------------------------------
  group('PrinterDevice', () {
    test('creates with required fields', () {
      final device = PrinterDevice(
        address: '00:11:22:33:44:55',
        name: 'My Printer',
        connectionType: PrinterConnectionType.bluetooth,
      );
      expect(device.address, '00:11:22:33:44:55');
      expect(device.name, 'My Printer');
      expect(device.connectionType, PrinterConnectionType.bluetooth);
      expect(device.rssi, isNull);
      expect(device.vendorId, isNull);
      expect(device.productId, isNull);
      expect(device.isConnected, isFalse);
      expect(device.metadata, isEmpty);
    });

    test('creates with optional fields', () {
      final device = PrinterDevice(
        address: '192.168.1.100',
        name: 'Network Printer',
        connectionType: PrinterConnectionType.network,
        rssi: -60,
        vendorId: 0x04B8,
        productId: 0x0202,
        isConnected: true,
        metadata: {'firmware': '1.0.0'},
      );
      expect(device.rssi, -60);
      expect(device.vendorId, 0x04B8);
      expect(device.productId, 0x0202);
      expect(device.isConnected, isTrue);
      expect(device.metadata, {'firmware': '1.0.0'});
    });

    test('fromMap parses all fields correctly', () {
      final map = {
        'address': 'AA:BB:CC:DD:EE:FF',
        'name': 'Test Printer',
        'connectionType': 'bluetooth',
        'rssi': -45,
        'vendorId': 1234,
        'productId': 5678,
        'isConnected': true,
        'metadata': {'key': 'value'},
      };
      final device = PrinterDevice.fromMap(map);
      expect(device.address, 'AA:BB:CC:DD:EE:FF');
      expect(device.name, 'Test Printer');
      expect(device.connectionType, PrinterConnectionType.bluetooth);
      expect(device.rssi, -45);
      expect(device.vendorId, 1234);
      expect(device.productId, 5678);
      expect(device.isConnected, isTrue);
      expect(device.metadata, {'key': 'value'});
    });

    test('fromMap uses defaults for missing fields', () {
      final device = PrinterDevice.fromMap({});
      expect(device.address, '');
      expect(device.name, 'Unknown Printer');
      expect(device.connectionType, PrinterConnectionType.unknown);
      expect(device.rssi, isNull);
      expect(device.isConnected, isFalse);
      expect(device.metadata, isEmpty);
    });

    test('toMap serialises all fields', () {
      final device = PrinterDevice(
        address: '00:11:22:33',
        name: 'Printer',
        connectionType: PrinterConnectionType.usb,
        rssi: -70,
        vendorId: 1,
        productId: 2,
        isConnected: true,
        metadata: {'x': 'y'},
      );
      final map = device.toMap();
      expect(map['address'], '00:11:22:33');
      expect(map['name'], 'Printer');
      expect(map['connectionType'], 'usb');
      expect(map['rssi'], -70);
      expect(map['vendorId'], 1);
      expect(map['productId'], 2);
      expect(map['isConnected'], isTrue);
      expect(map['metadata'], {'x': 'y'});
    });

    test('fromMap -> toMap round-trip preserves data', () {
      final original = PrinterDevice(
        address: '00:11:22:33:44:55',
        name: 'Round-Trip',
        connectionType: PrinterConnectionType.bluetooth,
        rssi: -50,
        metadata: {'foo': 'bar'},
      );
      final restored = PrinterDevice.fromMap(original.toMap());
      expect(restored.address, original.address);
      expect(restored.name, original.name);
      expect(restored.connectionType, original.connectionType);
      expect(restored.rssi, original.rssi);
      expect(restored.metadata, original.metadata);
    });

    test('equality compares all fields except metadata', () {
      final a = PrinterDevice(
        address: 'addr',
        name: 'name',
        connectionType: PrinterConnectionType.bluetooth,
        rssi: -60,
      );
      final b = PrinterDevice(
        address: 'addr',
        name: 'name',
        connectionType: PrinterConnectionType.bluetooth,
        rssi: -60,
      );
      expect(a, equals(b));
    });

    test('equality returns false for different fields', () {
      final a = PrinterDevice(
        address: 'a',
        name: 'n',
        connectionType: PrinterConnectionType.bluetooth,
      );
      final b = PrinterDevice(
        address: 'b',
        name: 'n',
        connectionType: PrinterConnectionType.bluetooth,
      );
      expect(a, isNot(equals(b)));
    });

    test('copyWith replaces specified fields', () {
      final device = PrinterDevice(
        address: 'addr',
        name: 'Old Name',
        connectionType: PrinterConnectionType.bluetooth,
        rssi: -60,
      );
      final updated = device.copyWith(name: 'New Name', rssi: -80);
      expect(updated.address, 'addr');
      expect(updated.name, 'New Name');
      expect(updated.rssi, -80);
    });

    test('copyWith clearRssi sets rssi to null', () {
      final device = PrinterDevice(
        address: 'a',
        name: 'n',
        connectionType: PrinterConnectionType.bluetooth,
        rssi: -50,
      );
      final updated = device.copyWith(clearRssi: true);
      expect(updated.rssi, isNull);
    });

    test('toString contains address, name and type', () {
      final device = PrinterDevice(
        address: '00:11',
        name: 'Test',
        connectionType: PrinterConnectionType.bluetooth,
      );
      final str = device.toString();
      expect(str, contains('00:11'));
      expect(str, contains('Test'));
      expect(str, contains('bluetooth'));
    });

    test('hashCode is consistent with equality', () {
      final a = PrinterDevice(
        address: 'a',
        name: 'n',
        connectionType: PrinterConnectionType.bluetooth,
      );
      final b = PrinterDevice(
        address: 'a',
        name: 'n',
        connectionType: PrinterConnectionType.bluetooth,
      );
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  // ---------------------------------------------------------------------------
  // PrinterConnectionType
  // ---------------------------------------------------------------------------
  group('PrinterConnectionType', () {
    test('fromString parses known types', () {
      expect(PrinterConnectionType.fromString('bluetooth'),
          PrinterConnectionType.bluetooth);
      expect(PrinterConnectionType.fromString('ble'), PrinterConnectionType.ble);
      expect(PrinterConnectionType.fromString('usb'), PrinterConnectionType.usb);
      expect(PrinterConnectionType.fromString('network'),
          PrinterConnectionType.network);
      expect(PrinterConnectionType.fromString('wifi'),
          PrinterConnectionType.network);
      expect(PrinterConnectionType.fromString('ethernet'),
          PrinterConnectionType.ethernet);
      expect(PrinterConnectionType.fromString('tcp'), PrinterConnectionType.tcp);
    });

    test('fromString is case-insensitive', () {
      expect(PrinterConnectionType.fromString('Bluetooth'),
          PrinterConnectionType.bluetooth);
      expect(PrinterConnectionType.fromString('WIFI'),
          PrinterConnectionType.network);
      expect(PrinterConnectionType.fromString('USB'), PrinterConnectionType.usb);
    });

    test('fromString returns unknown for unrecognised values', () {
      expect(PrinterConnectionType.fromString('foobar'),
          PrinterConnectionType.unknown);
      expect(PrinterConnectionType.fromString(''), PrinterConnectionType.unknown);
    });

    test('isWireless returns true for wireless types', () {
      expect(PrinterConnectionType.bluetooth.isWireless, isTrue);
      expect(PrinterConnectionType.ble.isWireless, isTrue);
      expect(PrinterConnectionType.network.isWireless, isTrue);
      expect(PrinterConnectionType.wifi.isWireless, isTrue);
      expect(PrinterConnectionType.ethernet.isWireless, isTrue);
      expect(PrinterConnectionType.tcp.isWireless, isTrue);
    });

    test('isWireless returns false for USB and unknown', () {
      expect(PrinterConnectionType.usb.isWireless, isFalse);
      expect(PrinterConnectionType.unknown.isWireless, isFalse);
    });

    test('isWired returns true only for USB', () {
      expect(PrinterConnectionType.usb.isWired, isTrue);
      expect(PrinterConnectionType.bluetooth.isWired, isFalse);
      expect(PrinterConnectionType.network.isWired, isFalse);
    });

    test('displayName returns human-readable labels', () {
      expect(PrinterConnectionType.bluetooth.displayName, 'Bluetooth');
      expect(PrinterConnectionType.ble.displayName, 'BLE');
      expect(PrinterConnectionType.usb.displayName, 'USB');
      expect(PrinterConnectionType.network.displayName, 'Network');
      expect(PrinterConnectionType.wifi.displayName, 'WiFi');
      expect(PrinterConnectionType.ethernet.displayName, 'Ethernet');
      expect(PrinterConnectionType.tcp.displayName, 'TCP/IP');
      expect(PrinterConnectionType.unknown.displayName, 'Unknown');
    });
  });

  // ---------------------------------------------------------------------------
  // PrinterStatus
  // ---------------------------------------------------------------------------
  group('PrinterStatus', () {
    test('default constructor has all falses', () {
      final status = const PrinterStatus();
      expect(status.online, isFalse);
      expect(status.paperOut, isFalse);
      expect(status.paperNearEnd, isFalse);
      expect(status.coverOpen, isFalse);
      expect(status.drawerOpen, isFalse);
      expect(status.batteryLow, isFalse);
      expect(status.batteryLevel, isNull);
      expect(status.errorCode, isNull);
      expect(status.errorMessage, isNull);
    });

    test('canPrint is true when online, not paperOut, not coverOpen', () {
      final status = PrinterStatus(online: true);
      expect(status.canPrint, isTrue);
    });

    test('canPrint is false when offline', () {
      final status = PrinterStatus(online: false);
      expect(status.canPrint, isFalse);
    });

    test('canPrint is false when paper is out', () {
      final status = PrinterStatus(online: true, paperOut: true);
      expect(status.canPrint, isFalse);
    });

    test('canPrint is false when cover is open', () {
      final status = PrinterStatus(online: true, coverOpen: true);
      expect(status.canPrint, isFalse);
    });

    test('canPrint is true even with paperNearEnd', () {
      final status = PrinterStatus(online: true, paperNearEnd: true);
      expect(status.canPrint, isTrue);
    });

    test('issues returns empty list when no problems', () {
      final status = PrinterStatus(online: true);
      expect(status.issues, isEmpty);
    });

    test('issues lists all active problems', () {
      final status = PrinterStatus(
        online: false,
        paperOut: true,
        paperNearEnd: true,
        coverOpen: true,
        batteryLow: true,
      );
      expect(status.issues.length, 5);
      expect(status.issues, contains('Printer is offline'));
      expect(status.issues, contains('Paper is out'));
      expect(status.issues, contains('Paper is near end'));
      expect(status.issues, contains('Cover is open'));
      expect(status.issues, contains('Battery is low'));
    });

    test('fromMap parses all fields', () {
      final map = {
        'online': true,
        'paperOut': false,
        'paperNearEnd': true,
        'coverOpen': false,
        'drawerOpen': true,
        'batteryLow': false,
        'batteryLevel': 85,
        'errorCode': 42,
        'errorMessage': 'No error really',
      };
      final status = PrinterStatus.fromMap(map);
      expect(status.online, isTrue);
      expect(status.paperNearEnd, isTrue);
      expect(status.drawerOpen, isTrue);
      expect(status.batteryLevel, 85);
      expect(status.errorCode, 42);
      expect(status.errorMessage, 'No error really');
    });

    test('fromMap uses defaults for missing fields', () {
      final status = PrinterStatus.fromMap({});
      expect(status.online, isFalse);
      expect(status.batteryLevel, isNull);
      expect(status.errorCode, isNull);
    });

    test('toMap serialises all fields', () {
      final status = PrinterStatus(
        online: true,
        batteryLevel: 50,
        errorCode: 1,
        errorMessage: 'err',
      );
      final map = status.toMap();
      expect(map['online'], isTrue);
      expect(map['batteryLevel'], 50);
      expect(map['errorCode'], 1);
      expect(map['errorMessage'], 'err');
    });

    test('equality compares key fields', () {
      final a = PrinterStatus(online: true, batteryLevel: 50);
      final b = PrinterStatus(online: true, batteryLevel: 50);
      expect(a, equals(b));
    });

    test('equality is false for different fields', () {
      final a = PrinterStatus(online: true);
      final b = PrinterStatus(online: false);
      expect(a, isNot(equals(b)));
    });

    test('copyWith replaces specified fields', () {
      final status = PrinterStatus(online: false, batteryLevel: 20);
      final updated = status.copyWith(online: true, batteryLevel: 80);
      expect(updated.online, isTrue);
      expect(updated.batteryLevel, 80);
    });

    test('copyWith clearErrorCode sets errorCode to null', () {
      final status = PrinterStatus(errorCode: 5);
      final updated = status.copyWith(clearErrorCode: true);
      expect(updated.errorCode, isNull);
    });

    test('toString contains relevant fields', () {
      final status = PrinterStatus(online: true, paperOut: true);
      final str = status.toString();
      expect(str, contains('online: true'));
      expect(str, contains('paperOut: true'));
    });
  });

  // ---------------------------------------------------------------------------
  // PrinterConnectionState extension
  // ---------------------------------------------------------------------------
  group('PrinterConnectionState', () {
    test('displayName returns correct labels', () {
      expect(PrinterConnectionState.disconnected.displayName, 'Disconnected');
      expect(PrinterConnectionState.connecting.displayName, 'Connecting...');
      expect(PrinterConnectionState.connected.displayName, 'Connected');
      expect(PrinterConnectionState.reconnecting.displayName, 'Reconnecting...');
      expect(
          PrinterConnectionState.connectionLost.displayName, 'Connection Lost');
      expect(
          PrinterConnectionState.reconnectFailed.displayName, 'Reconnect Failed');
    });

    test('isConnecting is true for connecting and reconnecting', () {
      expect(PrinterConnectionState.connecting.isConnecting, isTrue);
      expect(PrinterConnectionState.reconnecting.isConnecting, isTrue);
      expect(PrinterConnectionState.connected.isConnecting, isFalse);
      expect(PrinterConnectionState.disconnected.isConnecting, isFalse);
    });

    test('isConnected is true only for connected', () {
      expect(PrinterConnectionState.connected.isConnected, isTrue);
      expect(PrinterConnectionState.connecting.isConnected, isFalse);
      expect(PrinterConnectionState.disconnected.isConnected, isFalse);
    });

    test('isError is true for connectionLost and reconnectFailed', () {
      expect(PrinterConnectionState.connectionLost.isError, isTrue);
      expect(PrinterConnectionState.reconnectFailed.isError, isTrue);
      expect(PrinterConnectionState.disconnected.isError, isFalse);
      expect(PrinterConnectionState.connected.isError, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // PrinterEvent
  // ---------------------------------------------------------------------------
  group('PrinterEvent', () {
    test('creates with required type', () {
      final event = PrinterEvent(type: PrinterEventType.printerConnected);
      expect(event.type, PrinterEventType.printerConnected);
      expect(event.message, isNull);
      expect(event.data, isNull);
    });

    test('creates with message and data', () {
      final event = PrinterEvent(
        type: PrinterEventType.error,
        message: 'Something broke',
        data: {'code': 500},
      );
      expect(event.message, 'Something broke');
      expect(event.data, {'code': 500});
    });

    test('timestamp defaults to DateTime.now() if not provided', () {
      final before = DateTime.now();
      final event = PrinterEvent(type: PrinterEventType.unknown);
      final after = DateTime.now();
      expect(event.timestamp.isAfter(before.subtract(
          const Duration(milliseconds: 10))), isTrue);
      expect(event.timestamp.isBefore(after.add(
          const Duration(milliseconds: 10))), isTrue);
    });

    test('fromMap parses known type', () {
      final event = PrinterEvent.fromMap({
        'type': 'printerConnected',
        'message': 'Device connected',
        'data': {'address': '00:11:22'},
        'timestamp': '2025-01-15T12:00:00.000Z',
      });
      expect(event.type, PrinterEventType.printerConnected);
      expect(event.message, 'Device connected');
      expect(event.data, {'address': '00:11:22'});
      expect(event.timestamp.toIso8601String(), '2025-01-15T12:00:00.000Z');
    });

    test('fromMap defaults to unknown for unrecognised type', () {
      final event = PrinterEvent.fromMap({'type': 'nonexistent_type'});
      expect(event.type, PrinterEventType.unknown);
    });

    test('toMap serialises all fields', () {
      final event = PrinterEvent(
        type: PrinterEventType.paperOut,
        message: 'No paper',
        data: {'tray': 1},
        timestamp: DateTime(2025, 1, 1, 0, 0, 0),
      );
      final map = event.toMap();
      expect(map['type'], 'paperOut');
      expect(map['message'], 'No paper');
      expect(map['data'], {'tray': 1});
      expect(map['timestamp'], isNotNull);
    });

    test('isConnectionEvent is true for connection types', () {
      expect(PrinterEvent(type: PrinterEventType.printerConnected)
          .isConnectionEvent, isTrue);
      expect(PrinterEvent(type: PrinterEventType.printerDisconnected)
          .isConnectionEvent, isTrue);
      expect(PrinterEvent(type: PrinterEventType.bluetoothEnabled)
          .isConnectionEvent, isTrue);
      expect(PrinterEvent(type: PrinterEventType.usbDetached)
          .isConnectionEvent, isTrue);
      expect(PrinterEvent(type: PrinterEventType.networkConnected)
          .isConnectionEvent, isTrue);
    });

    test('isConnectionEvent is false for non-connection types', () {
      expect(PrinterEvent(type: PrinterEventType.paperOut).isConnectionEvent,
          isFalse);
      expect(PrinterEvent(type: PrinterEventType.error).isConnectionEvent,
          isFalse);
    });

    test('isHardwareEvent is true for hardware types', () {
      expect(PrinterEvent(type: PrinterEventType.paperOut).isHardwareEvent,
          isTrue);
      expect(PrinterEvent(type: PrinterEventType.coverOpen).isHardwareEvent,
          isTrue);
      expect(PrinterEvent(type: PrinterEventType.drawerOpen).isHardwareEvent,
          isTrue);
      expect(
          PrinterEvent(type: PrinterEventType.batteryLow).isHardwareEvent,
          isTrue);
    });

    test('isHardwareEvent is false for non-hardware types', () {
      expect(PrinterEvent(type: PrinterEventType.printerConnected)
          .isHardwareEvent, isFalse);
      expect(
          PrinterEvent(type: PrinterEventType.error).isHardwareEvent, isFalse);
    });

    test('copyWith replaces fields', () {
      final event = PrinterEvent(
        type: PrinterEventType.error,
        message: 'old',
        data: {'a': 1},
      );
      final updated = event.copyWith(message: 'new', type: PrinterEventType.batteryLow);
      expect(updated.type, PrinterEventType.batteryLow);
      expect(updated.message, 'new');
      expect(updated.data, {'a': 1});
    });

    test('copyWith clearMessage sets message to null', () {
      final event = PrinterEvent(type: PrinterEventType.error, message: 'msg');
      final updated = event.copyWith(clearMessage: true);
      expect(updated.message, isNull);
    });

    test('toString contains type and message', () {
      final event = PrinterEvent(
        type: PrinterEventType.paperOut,
        message: 'Out of paper!',
      );
      expect(event.toString(), contains('paperOut'));
      expect(event.toString(), contains('Out of paper!'));
    });
  });

  // ---------------------------------------------------------------------------
  // PrinterProfile
  // ---------------------------------------------------------------------------
  group('PrinterProfile', () {
    test('epson profile has correct 58mm values', () {
      expect(PrinterProfile.epson.name, 'Epson');
      expect(PrinterProfile.epson.paperWidth, 48);
      expect(PrinterProfile.epson.maxCharsPerLine, 32);
      expect(PrinterProfile.epson.codePage, 0);
      expect(PrinterProfile.epson.supportsQrCode, isTrue);
      expect(PrinterProfile.epson.supportsBarcode, isTrue);
      expect(PrinterProfile.epson.supportsImage, isTrue);
      expect(PrinterProfile.epson.defaultDotsPerLine, 384);
      expect(PrinterProfile.epson.feedLines, 3);
      expect(PrinterProfile.epson.cutPulseDuration, 100);
    });

    test('epson80 profile has correct 80mm values', () {
      expect(PrinterProfile.epson80.paperWidth, 80);
      expect(PrinterProfile.epson80.maxCharsPerLine, 48);
      expect(PrinterProfile.epson80.defaultDotsPerLine, 576);
    });

    test('xprinter profile has correct values', () {
      expect(PrinterProfile.xprinter.name, 'XPrinter');
      expect(PrinterProfile.xprinter.paperWidth, 58);
      expect(PrinterProfile.xprinter.maxCharsPerLine, 32);
      expect(PrinterProfile.xprinter.cutPulseDuration, 80);
    });

    test('sunmi profile has correct values', () {
      expect(PrinterProfile.sunmi.name, 'Sunmi');
      expect(PrinterProfile.sunmi.paperWidth, 58);
      expect(PrinterProfile.sunmi.supportsQrCode, isTrue);
    });

    test('bixolon profile has correct values', () {
      expect(PrinterProfile.bixolon.name, 'Bixolon');
      expect(PrinterProfile.bixolon.defaultDotsPerLine, 384);
    });

    test('rongta profile has correct values', () {
      expect(PrinterProfile.rongta.name, 'Rongta');
      expect(PrinterProfile.rongta.maxCharsPerLine, 32);
    });

    test('zjiang profile has correct values', () {
      expect(PrinterProfile.zjiang.name, 'ZJiang');
      expect(PrinterProfile.zjiang.paperWidth, 58);
    });

    test('lookup finds built-in profiles case-insensitively', () {
      expect(PrinterProfile.lookup('epson'), PrinterProfile.epson);
      expect(PrinterProfile.lookup('EPSON'), PrinterProfile.epson);
      expect(PrinterProfile.lookup('xprinter'), PrinterProfile.xprinter);
      expect(PrinterProfile.lookup('XPrinter'), PrinterProfile.xprinter);
    });

    test('lookup returns null for unknown name', () {
      expect(PrinterProfile.lookup('Nonexistent'), isNull);
    });

    test('availableProfiles lists all built-in names', () {
      final names = PrinterProfile.availableProfiles;
      expect(names, containsAll([
        'Epson',
        'Epson 80mm',
        'XPrinter',
        'Sunmi',
        'Bixolon',
        'Rongta',
        'ZJiang',
      ]));
      expect(names.length, 7);
    });

    test('custom profile factory works with defaults', () {
      final custom = PrinterProfile.custom(name: 'MyPrinter');
      expect(custom.name, 'MyPrinter');
      expect(custom.paperWidth, 58);
      expect(custom.maxCharsPerLine, 32);
      expect(custom.codePage, 0);
      expect(custom.supportsQrCode, isTrue);
      expect(custom.supportsBarcode, isTrue);
      expect(custom.supportsImage, isTrue);
      expect(custom.defaultDotsPerLine, 384);
      expect(custom.feedLines, 3);
      expect(custom.cutPulseDuration, 100);
      expect(custom.customCommands, isEmpty);
    });

    test('custom profile factory accepts custom values', () {
      final custom = PrinterProfile.custom(
        name: 'Custom',
        paperWidth: 80,
        maxCharsPerLine: 48,
        supportsQrCode: false,
        supportsImage: false,
        customCommands: {'INIT': [0x1B, 0x40]},
      );
      expect(custom.paperWidth, 80);
      expect(custom.maxCharsPerLine, 48);
      expect(custom.supportsQrCode, isFalse);
      expect(custom.supportsImage, isFalse);
      expect(custom.customCommands, {'INIT': [0x1B, 0x40]});
    });

    test('toMap serialises all fields', () {
      final map = PrinterProfile.epson.toMap();
      expect(map['name'], 'Epson');
      expect(map['paperWidth'], 48);
      expect(map['maxCharsPerLine'], 32);
      expect(map['codePage'], 0);
      expect(map['supportsQrCode'], isTrue);
      expect(map['supportsBarcode'], isTrue);
      expect(map['supportsImage'], isTrue);
      expect(map['defaultDotsPerLine'], 384);
      expect(map['feedLines'], 3);
      expect(map['cutPulseDuration'], 100);
    });

    test('equality compares name, paperWidth, maxCharsPerLine, codePage', () {
      final a = PrinterProfile.custom(name: 'P', paperWidth: 58,
          maxCharsPerLine: 32, codePage: 0);
      final b = PrinterProfile.custom(name: 'P', paperWidth: 58,
          maxCharsPerLine: 32, codePage: 0);
      expect(a, equals(b));
    });

    test('equality is false for different fields', () {
      final a = PrinterProfile.custom(name: 'A');
      final b = PrinterProfile.custom(name: 'B');
      expect(a, isNot(equals(b)));
    });

    test('toString contains name and paperWidth', () {
      final str = PrinterProfile.epson.toString();
      expect(str, contains('Epson'));
      expect(str, contains('48'));
      expect(str, contains('32'));
    });
  });
}
