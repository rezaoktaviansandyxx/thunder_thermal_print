import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_thermal_print/src/models/models.dart';

void main() {
  group('PrinterDevice', () {
    test('constructor sets all fields correctly', () {
      final device = PrinterDevice(
        address: '00:11:22:33:44:55',
        name: 'Test Printer',
        connectionType: PrinterConnectionType.bluetooth,
        rssi: -50,
        vendorId: 1234,
        productId: 5678,
        isConnected: true,
        metadata: {'key': 'value'},
      );

      expect(device.address, '00:11:22:33:44:55');
      expect(device.name, 'Test Printer');
      expect(device.connectionType, PrinterConnectionType.bluetooth);
      expect(device.rssi, -50);
      expect(device.vendorId, 1234);
      expect(device.productId, 5678);
      expect(device.isConnected, true);
      expect(device.metadata['key'], 'value');
    });

    test('fromMap creates device correctly', () {
      final map = {
        'address': '192.168.1.100',
        'name': 'Network Printer',
        'connectionType': 'network',
        'rssi': 0,
        'vendorId': null,
        'productId': null,
        'isConnected': false,
        'metadata': {'ip': '192.168.1.100'},
      };

      final device = PrinterDevice.fromMap(map);

      expect(device.address, '192.168.1.100');
      expect(device.name, 'Network Printer');
      expect(device.connectionType, PrinterConnectionType.network);
      expect(device.rssi, 0);
      expect(device.isConnected, false);
    });

    test('toMap converts device correctly', () {
      final device = PrinterDevice(
        address: '00:11:22:33:44:55',
        name: 'BT Printer',
        connectionType: PrinterConnectionType.bluetooth,
        rssi: -60,
      );

      final map = device.toMap();

      expect(map['address'], '00:11:22:33:44:55');
      expect(map['name'], 'BT Printer');
      expect(map['connectionType'], 'bluetooth');
      expect(map['rssi'], -60);
    });

    test('copyWith replaces fields correctly', () {
      final device = PrinterDevice(
        address: '00:11:22:33:44:55',
        name: 'Printer',
        connectionType: PrinterConnectionType.bluetooth,
        rssi: -50,
      );

      final updated = device.copyWith(
        name: 'Updated Printer',
        rssi: -40,
      );

      expect(updated.address, '00:11:22:33:44:55');
      expect(updated.name, 'Updated Printer');
      expect(updated.rssi, -40);
    });

    test('equality works correctly', () {
      final device1 = PrinterDevice(
        address: '00:11:22:33:44:55',
        name: 'Printer',
        connectionType: PrinterConnectionType.bluetooth,
      );

      final device2 = PrinterDevice(
        address: '00:11:22:33:44:55',
        name: 'Printer',
        connectionType: PrinterConnectionType.bluetooth,
      );

      expect(device1 == device2, true);
      expect(device1.hashCode == device2.hashCode, true);
    });

    test('isBluetooth getter works', () {
      final bt = PrinterDevice(
        address: '00:11:22:33:44:55',
        name: 'BT',
        connectionType: PrinterConnectionType.bluetooth,
      );
      expect(bt.isBluetooth, true);
      expect(bt.isBle, false);
      expect(bt.isUsb, false);
      expect(bt.isNetwork, false);
    });

    test('isBle getter works', () {
      final ble = PrinterDevice(
        address: 'device-id',
        name: 'BLE',
        connectionType: PrinterConnectionType.ble,
      );
      expect(ble.isBle, true);
      expect(ble.isBluetooth, false);
    });

    test('isNetwork getter works for network and wifi', () {
      final network = PrinterDevice(
        address: '192.168.1.100',
        name: 'Network',
        connectionType: PrinterConnectionType.network,
      );
      expect(network.isNetwork, true);

      final wifi = PrinterDevice(
        address: '192.168.1.101',
        name: 'WiFi',
        connectionType: PrinterConnectionType.wifi,
      );
      expect(wifi.isNetwork, true);
    });
  });

  group('PrinterConnectionType', () {
    test('fromString parses correctly', () {
      expect(PrinterConnectionType.fromString('bluetooth'), PrinterConnectionType.bluetooth);
      expect(PrinterConnectionType.fromString('BLE'), PrinterConnectionType.ble);
      expect(PrinterConnectionType.fromString('USB'), PrinterConnectionType.usb);
      expect(PrinterConnectionType.fromString('network'), PrinterConnectionType.network);
      expect(PrinterConnectionType.fromString('WIFI'), PrinterConnectionType.network);
      expect(PrinterConnectionType.fromString('ethernet'), PrinterConnectionType.ethernet);
      expect(PrinterConnectionType.fromString('TCP'), PrinterConnectionType.tcp);
      expect(PrinterConnectionType.fromString('unknown'), PrinterConnectionType.unknown);
    });

    test('isWireless returns correct values', () {
      expect(PrinterConnectionType.bluetooth.isWireless, true);
      expect(PrinterConnectionType.ble.isWireless, true);
      expect(PrinterConnectionType.wifi.isWireless, true);
      expect(PrinterConnectionType.network.isWireless, true);
      expect(PrinterConnectionType.usb.isWireless, false);
    });

    test('isWired returns correct values', () {
      expect(PrinterConnectionType.usb.isWired, true);
      expect(PrinterConnectionType.bluetooth.isWired, false);
      expect(PrinterConnectionType.network.isWired, false);
    });

    test('displayName returns correct labels', () {
      expect(PrinterConnectionType.bluetooth.displayName, 'Bluetooth');
      expect(PrinterConnectionType.ble.displayName, 'BLE');
      expect(PrinterConnectionType.usb.displayName, 'USB');
      expect(PrinterConnectionType.network.displayName, 'Network');
      expect(PrinterConnectionType.tcp.displayName, 'TCP/IP');
    });
  });

  group('PrinterStatus', () {
    test('constructor sets defaults correctly', () {
      final status = PrinterStatus();

      expect(status.online, false);
      expect(status.paperOut, false);
      expect(status.paperNearEnd, false);
      expect(status.coverOpen, false);
      expect(status.drawerOpen, false);
      expect(status.batteryLow, false);
    });

    test('fromMap creates status correctly', () {
      final map = {
        'online': true,
        'paperOut': false,
        'paperNearEnd': true,
        'coverOpen': false,
        'drawerOpen': false,
        'batteryLow': true,
        'batteryLevel': 15,
        'errorCode': null,
        'errorMessage': null,
      };

      final status = PrinterStatus.fromMap(map);

      expect(status.online, true);
      expect(status.paperNearEnd, true);
      expect(status.batteryLow, true);
      expect(status.batteryLevel, 15);
    });

    test('canPrint returns correct value', () {
      final printable = PrinterStatus(
        online: true,
        paperOut: false,
        coverOpen: false,
      );
      expect(printable.canPrint, true);

      final notPrintable = PrinterStatus(
        online: true,
        paperOut: true,
        coverOpen: false,
      );
      expect(notPrintable.canPrint, false);
    });

    test('issues returns list of problems', () {
      final status = PrinterStatus(
        online: true,
        paperOut: true,
        paperNearEnd: false,
        coverOpen: true,
        batteryLow: false,
      );

      expect(status.issues.length, 2);
      expect(status.issues.contains('Paper is out'), true);
      expect(status.issues.contains('Cover is open'), true);
    });

    test('copyWith works correctly', () {
      final status = PrinterStatus(online: false);
      final updated = status.copyWith(online: true, paperOut: true);

      expect(updated.online, true);
      expect(updated.paperOut, true);
    });
  });

  group('PrinterEvent', () {
    test('constructor sets fields correctly', () {
      final event = PrinterEvent(
        type: PrinterEventType.printerConnected,
        deviceId: '00:11:22:33:44:55',
        message: 'Printer connected',
      );

      expect(event.type, PrinterEventType.printerConnected);
      expect(event.deviceId, '00:11:22:33:44:55');
      expect(event.message, 'Printer connected');
      expect(event.timestamp, isA<DateTime>());
    });

    test('fromMap creates event correctly', () {
      final map = {
        'type': 'paperOut',
        'deviceId': 'device-123',
        'message': 'Paper is out',
        'data': {'level': 'critical'},
        'timestamp': '2024-01-01T12:00:00.000',
      };

      final event = PrinterEvent.fromMap(map);

      expect(event.type, PrinterEventType.paperOut);
      expect(event.deviceId, 'device-123');
      expect(event.message, 'Paper is out');
      expect(event.data?['level'], 'critical');
    });

    test('isConnectionEvent returns correct value', () {
      final connected = PrinterEvent(type: PrinterEventType.printerConnected);
      expect(connected.isConnectionEvent, true);

      final paperOut = PrinterEvent(type: PrinterEventType.paperOut);
      expect(paperOut.isConnectionEvent, false);
    });

    test('isHardwareEvent returns correct value', () {
      final paperOut = PrinterEvent(type: PrinterEventType.paperOut);
      expect(paperOut.isHardwareEvent, true);

      final connected = PrinterEvent(type: PrinterEventType.printerConnected);
      expect(connected.isHardwareEvent, false);
    });

    test('copyWith works correctly', () {
      final event = PrinterEvent(type: PrinterEventType.printerConnected);
      final updated = event.copyWith(
        type: PrinterEventType.printerDisconnected,
        message: 'Disconnected',
      );

      expect(updated.type, PrinterEventType.printerDisconnected);
      expect(updated.message, 'Disconnected');
    });
  });

  group('PrinterProfile', () {
    test('epson profile has correct settings', () {
      expect(PrinterProfile.epson.name, 'Epson');
      expect(PrinterProfile.epson.maxCharsPerLine, 32);
      expect(PrinterProfile.epson.supportsQrCode, true);
    });

    test('epson80 profile has correct settings', () {
      expect(PrinterProfile.epson80.name, 'Epson 80mm');
      expect(PrinterProfile.epson80.maxCharsPerLine, 48);
    });

    test('xprinter profile exists', () {
      expect(PrinterProfile.xprinter.name, 'XPrinter');
      expect(PrinterProfile.xprinter.supportsQrCode, true);
    });

    test('sunmi profile exists', () {
      expect(PrinterProfile.sunmi.name, 'Sunmi');
      expect(PrinterProfile.sunmi.supportsImage, true);
    });

    test('bixolon profile exists', () {
      expect(PrinterProfile.bixolon.name, 'Bixolon');
    });

    test('rongta profile exists', () {
      expect(PrinterProfile.rongta.name, 'Rongta');
    });

    test('zjiang profile exists', () {
      expect(PrinterProfile.zjiang.name, 'ZJiang');
    });

    test('custom profile can be created', () {
      final custom = PrinterProfile.custom(
        name: 'My Printer',
        paperWidth: 58,
        maxCharsPerLine: 32,
      );

      expect(custom.name, 'My Printer');
      expect(custom.paperWidth, 58);
      expect(custom.maxCharsPerLine, 32);
    });

    test('lookup finds profiles by name', () {
      expect(PrinterProfile.lookup('Epson'), isNotNull);
      expect(PrinterProfile.lookup('epson'), isNotNull);
      expect(PrinterProfile.lookup('EPSON'), isNotNull);
      expect(PrinterProfile.lookup('NonExistent'), isNull);
    });

    test('availableProfiles returns all profile names', () {
      final profiles = PrinterProfile.availableProfiles;
      expect(profiles.contains('Epson'), true);
      expect(profiles.contains('XPrinter'), true);
      expect(profiles.contains('Sunmi'), true);
    });

    test('toMap converts profile correctly', () {
      final map = PrinterProfile.epson.toMap();
      expect(map['name'], 'Epson');
      expect(map['paperWidth'], 48);
      expect(map['maxCharsPerLine'], 32);
    });
  });

  group('ConnectionConfig', () {
    test('constructor sets defaults correctly', () {
      final config = ConnectionConfig(identifier: '00:11:22:33:44:55');

      expect(config.identifier, '00:11:22:33:44:55');
      expect(config.timeout, const Duration(seconds: 10));
      expect(config.reconnectDelay, const Duration(seconds: 3));
      expect(config.maxReconnectAttempts, 5);
      expect(config.autoReconnect, true);
    });

    test('fromMap creates config correctly', () {
      final map = {
        'identifier': '192.168.1.100',
        'port': 9100,
        'timeoutSeconds': 15,
        'reconnectDelaySeconds': 5,
        'maxReconnectAttempts': 10,
        'autoReconnect': true,
        'profile': 'epson',
      };

      final config = ConnectionConfig.fromMap(map);

      expect(config.identifier, '192.168.1.100');
      expect(config.port, 9100);
      expect(config.timeout, const Duration(seconds: 15));
      expect(config.reconnectDelay, const Duration(seconds: 5));
      expect(config.maxReconnectAttempts, 10);
      expect(config.autoReconnect, true);
    });

    test('toMap converts config correctly', () {
      final config = ConnectionConfig(
        identifier: '00:11:22:33:44:55',
        autoReconnect: false,
      );

      final map = config.toMap();

      expect(map['identifier'], '00:11:22:33:44:55');
      expect(map['autoReconnect'], false);
    });

    test('copyWith works correctly', () {
      final config = ConnectionConfig(identifier: 'old');
      final updated = config.copyWith(identifier: 'new', autoReconnect: false);

      expect(updated.identifier, 'new');
      expect(updated.autoReconnect, false);
    });
  });
}
