import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_thermal_print/src/exceptions/exceptions.dart';
import 'package:thunder_thermal_print/src/models/models.dart';
import 'package:thunder_thermal_print/src/services/thermal_print_method_channel.dart';

void main() {
  const channel = MethodChannel('id.thunderlab.thunder_thermal_print');

  late MethodChannelThunderThermalPrint platform;

  setUp(() {
    platform = MethodChannelThunderThermalPrint();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // ---------------------------------------------------------------------------
  // scanBluetooth
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint scanBluetooth', () {
    test('returns list of PrinterDevice on success', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'scanBluetooth') {
          return [
            {
              'address': '00:11:22:33:44:55',
              'name': 'Printer 1',
              'connectionType': 'bluetooth',
              'rssi': -60,
            },
            {
              'address': 'AA:BB:CC:DD:EE:FF',
              'name': 'Printer 2',
              'connectionType': 'bluetooth',
              'rssi': -80,
            },
          ];
        }
        return null;
      });

      final devices = await platform.scanBluetooth();
      expect(devices.length, 2);
      expect(devices[0].address, '00:11:22:33:44:55');
      expect(devices[0].name, 'Printer 1');
      expect(devices[0].connectionType, PrinterConnectionType.bluetooth);
      expect(devices[0].rssi, -60);
      expect(devices[1].address, 'AA:BB:CC:DD:EE:FF');
    });

    test('returns empty list when no devices found', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'scanBluetooth') {
          return <dynamic>[];
        }
        return null;
      });

      final devices = await platform.scanBluetooth();
      expect(devices, isEmpty);
    });

    test('returns empty list when null response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'scanBluetooth') {
          return null;
        }
        return null;
      });

      final devices = await platform.scanBluetooth();
      expect(devices, isEmpty);
    });

    test('passes timeout argument', () async {
      Duration? capturedTimeout;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'scanBluetooth') {
          capturedTimeout = methodCall.arguments['timeout'] != null
              ? Duration(milliseconds: methodCall.arguments['timeout'] as int)
              : null;
          return <dynamic>[];
        }
        return null;
      });

      await platform.scanBluetooth(timeout: const Duration(seconds: 15));
      expect(capturedTimeout, const Duration(seconds: 15));
    });
  });

  // ---------------------------------------------------------------------------
  // scanBle
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint scanBle', () {
    test('returns list of PrinterDevice', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'scanBle') {
          return [
            {
              'address': 'device-id-1',
              'name': 'BLE Printer',
              'connectionType': 'ble',
            },
          ];
        }
        return null;
      });

      final devices = await platform.scanBle();
      expect(devices.length, 1);
      expect(devices[0].connectionType, PrinterConnectionType.ble);
    });
  });

  // ---------------------------------------------------------------------------
  // scanNetwork
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint scanNetwork', () {
    test('returns list of PrinterDevice', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'scanNetwork') {
          return [
            {
              'address': '192.168.1.100',
              'name': 'Network Printer',
              'connectionType': 'network',
            },
          ];
        }
        return null;
      });

      final devices = await platform.scanNetwork();
      expect(devices.length, 1);
      expect(devices[0].address, '192.168.1.100');
      expect(devices[0].connectionType, PrinterConnectionType.network);
    });

    test('passes subnet argument', () async {
      String? capturedSubnet;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'scanNetwork') {
          capturedSubnet = methodCall.arguments['subnet'] as String?;
          return <dynamic>[];
        }
        return null;
      });

      await platform.scanNetwork(subnet: '192.168.1.0/24');
      expect(capturedSubnet, '192.168.1.0/24');
    });
  });

  // ---------------------------------------------------------------------------
  // connectNetwork
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint connectNetwork', () {
    test('succeeds without error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'connectNetwork') {
          return null;
        }
        return null;
      });

      // Should not throw
      await platform.connectNetwork(ipAddress: '192.168.1.100');
    });

    test('passes ipAddress and port', () async {
      Map<String, dynamic>? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'connectNetwork') {
          capturedArgs =
              Map<String, dynamic>.from(methodCall.arguments as Map);
          return null;
        }
        return null;
      });

      await platform.connectNetwork(ipAddress: '192.168.1.50', port: 9100);
      expect(capturedArgs!['ipAddress'], '192.168.1.50');
      expect(capturedArgs!['port'], 9100);
    });

    test('passes profile when provided', () async {
      Map<String, dynamic>? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'connectNetwork') {
          capturedArgs =
              Map<String, dynamic>.from(methodCall.arguments as Map);
          return null;
        }
        return null;
      });

      final profile = PrinterProfile.epson;
      await platform.connectNetwork(
        ipAddress: '192.168.1.50',
        profile: profile,
      );
      expect(capturedArgs!['profile'], isNotNull);
      expect(capturedArgs!['profile']['name'], 'Epson');
    });
  });

  // ---------------------------------------------------------------------------
  // connectBluetooth
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint connectBluetooth', () {
    test('passes macAddress', () async {
      String? capturedMac;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'connectBluetooth') {
          capturedMac = methodCall.arguments['macAddress'] as String;
          return null;
        }
        return null;
      });

      await platform.connectBluetooth(macAddress: '00:11:22:33:44:55');
      expect(capturedMac, '00:11:22:33:44:55');
    });
  });

  // ---------------------------------------------------------------------------
  // printText
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint printText', () {
    test('sends correct text data', () async {
      String? capturedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'printText') {
          capturedText = methodCall.arguments['text'] as String;
          return null;
        }
        return null;
      });

      await platform.printText('Hello Printer');
      expect(capturedText, 'Hello Printer');
    });

    test('succeeds without error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'printText') return null;
        return null;
      });

      await platform.printText('Test');
    });
  });

  // ---------------------------------------------------------------------------
  // printBytes
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint printBytes', () {
    test('sends byte data', () async {
      List<dynamic>? capturedBytes;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'printBytes') {
          capturedBytes = methodCall.arguments['bytes'] as List<dynamic>;
          return null;
        }
        return null;
      });

      final data = [0x1B, 0x40, 0x1B, 0x45, 0x01];
      await platform.printBytes(data);
      expect(capturedBytes, [0x1B, 0x40, 0x1B, 0x45, 0x01]);
    });
  });

  // ---------------------------------------------------------------------------
  // printReceipt
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint printReceipt', () {
    test('sends receipt bytes', () async {
      List<dynamic>? capturedBytes;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'printReceipt') {
          capturedBytes =
              methodCall.arguments['receiptBytes'] as List<dynamic>;
          return null;
        }
        return null;
      });

      final data = [0x1B, 0x40, 0x48, 0x65, 0x6C, 0x6C, 0x6F];
      await platform.printReceipt(data);
      expect(capturedBytes, data);
    });
  });

  // ---------------------------------------------------------------------------
  // getStatus
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint getStatus', () {
    test('returns PrinterStatus on success', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getStatus') {
          return {
            'online': true,
            'paperOut': false,
            'paperNearEnd': false,
            'coverOpen': false,
            'drawerOpen': false,
            'batteryLow': false,
            'batteryLevel': 85,
          };
        }
        return null;
      });

      final status = await platform.getStatus();
      expect(status.online, isTrue);
      expect(status.paperOut, isFalse);
      expect(status.batteryLevel, 85);
      expect(status.canPrint, isTrue);
    });

    test('returns default PrinterStatus for null response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getStatus') return null;
        return null;
      });

      final status = await platform.getStatus();
      expect(status.online, isFalse);
      expect(status.canPrint, isFalse);
    });

    test('returns status with error conditions', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getStatus') {
          return {
            'online': false,
            'paperOut': true,
            'coverOpen': true,
            'errorCode': 100,
            'errorMessage': 'Hardware failure',
          };
        }
        return null;
      });

      final status = await platform.getStatus();
      expect(status.online, isFalse);
      expect(status.paperOut, isTrue);
      expect(status.coverOpen, isTrue);
      expect(status.errorCode, 100);
      expect(status.errorMessage, 'Hardware failure');
    });
  });

  // ---------------------------------------------------------------------------
  // isConnected
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint isConnected', () {
    test('returns true when connected', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'isConnected') return true;
        return null;
      });

      final result = await platform.isConnected();
      expect(result, isTrue);
    });

    test('returns false when not connected', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'isConnected') return false;
        return null;
      });

      final result = await platform.isConnected();
      expect(result, isFalse);
    });

    test('returns false for null response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'isConnected') return null;
        return null;
      });

      final result = await platform.isConnected();
      expect(result, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // disconnect
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint disconnect', () {
    test('completes without error', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'disconnect') return null;
        return null;
      });

      await platform.disconnect();
    });
  });

  // ---------------------------------------------------------------------------
  // Exception handling: PlatformException -> PrinterException
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint exception mapping', () {
    test('CONNECTION_FAILED maps to ConnectionException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'CONNECTION_FAILED',
          message: 'Could not connect',
        );
      });

      expect(
        () => platform.connectNetwork(ipAddress: '192.168.1.1'),
        throwsA(isA<ConnectionException>()),
      );
    });

    test('CONNECTION_LOST maps to ConnectionException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'CONNECTION_LOST',
          message: 'Connection dropped',
        );
      });

      expect(
        () => platform.printText('test'),
        throwsA(isA<ConnectionException>()),
      );
    });

    test('NOT_CONNECTED maps to ConnectionException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'NOT_CONNECTED',
          message: 'No active connection',
        );
      });

      expect(
        () => platform.printText('test'),
        throwsA(isA<ConnectionException>()),
      );
    });

    test('PERMISSION_DENIED maps to PermissionException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'PERMISSION_DENIED',
          message: 'Bluetooth permission denied',
          details: 'BLUETOOTH_SCAN',
        );
      });

      try {
        await platform.scanBluetooth();
        fail('Should have thrown');
      } on PermissionException catch (e) {
        expect(e.message, 'Bluetooth permission denied');
        expect(e.permissionName, 'BLUETOOTH_SCAN');
      }
    });

    test('DEVICE_NOT_FOUND maps to DeviceNotFoundException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'DEVICE_NOT_FOUND',
          message: 'Device not found',
          details: '00:11:22:33',
        );
      });

      expect(
        () => platform.connectBluetooth(macAddress: '00:11:22:33'),
        throwsA(isA<DeviceNotFoundException>()),
      );
    });

    test('TIMEOUT maps to PrintTimeoutException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'TIMEOUT',
          message: 'Operation timed out',
          details: 5000,
        );
      });

      try {
        await platform.printText('test');
        fail('Should have thrown');
      } on PrintTimeoutException catch (e) {
        expect(e.message, 'Operation timed out');
        expect(e.timeoutMs, 5000);
      }
    });

    test('NOT_SUPPORTED maps to NotSupportedException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'NOT_SUPPORTED',
          message: 'Feature not supported',
          details: 'qrCode',
        );
      });

      try {
        await platform.printQrCode('test');
        fail('Should have thrown');
      } on NotSupportedException catch (e) {
        expect(e.message, 'Feature not supported');
        expect(e.feature, 'qrCode');
      }
    });

    test('PRINTER_BUSY maps to PrinterBusyException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'PRINTER_BUSY',
          message: 'Printer is busy',
        );
      });

      expect(
        () => platform.printText('test'),
        throwsA(isA<PrinterBusyException>()),
      );
    });

    test('PAPER_OUT maps to PaperOutException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'PAPER_OUT',
          message: 'Paper is out',
        );
      });

      expect(
        () => platform.printText('test'),
        throwsA(isA<PaperOutException>()),
      );
    });

    test('COVER_OPEN maps to CoverOpenException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'COVER_OPEN',
          message: 'Cover is open',
        );
      });

      expect(
        () => platform.printText('test'),
        throwsA(isA<CoverOpenException>()),
      );
    });

    test('INVALID_DATA maps to InvalidDataException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'INVALID_DATA',
          message: 'Invalid data',
        );
      });

      expect(
        () => platform.printText('test'),
        throwsA(isA<InvalidDataException>()),
      );
    });

    test('unknown code maps to PrinterException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'SOME_UNKNOWN_ERROR',
          message: 'Something happened',
        );
      });

      expect(
        () => platform.printText('test'),
        throwsA(isA<PrinterException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // isFeatureSupported
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint isFeatureSupported', () {
    test('returns true when feature is supported', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'isFeatureSupported') {
          final feature = methodCall.arguments['feature'] as String;
          return feature == 'bluetooth';
        }
        return null;
      });

      final result = await platform.isFeatureSupported('bluetooth');
      expect(result, isTrue);
    });

    test('returns false when feature is not supported', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'isFeatureSupported') return false;
        return null;
      });

      final result = await platform.isFeatureSupported('usb');
      expect(result, isFalse);
    });

    test('returns false for null response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'isFeatureSupported') return null;
        return null;
      });

      final result = await platform.isFeatureSupported('ble');
      expect(result, isFalse);
    });

    test('passes feature name correctly', () async {
      String? capturedFeature;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'isFeatureSupported') {
          capturedFeature = methodCall.arguments['feature'] as String;
          return true;
        }
        return null;
      });

      await platform.isFeatureSupported('qrCode');
      expect(capturedFeature, 'qrCode');
    });
  });

  // ---------------------------------------------------------------------------
  // requestPermissions / checkPermissions
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint permissions', () {
    test('requestPermissions returns true when granted', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'requestPermissions') return true;
        return null;
      });

      final result = await platform.requestPermissions();
      expect(result, isTrue);
    });

    test('checkPermissions returns false when not granted', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'checkPermissions') return false;
        return null;
      });

      final result = await platform.checkPermissions();
      expect(result, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // getPlatformVersion
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint getPlatformVersion', () {
    test('returns platform version string', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getPlatformVersion') return '1.0.0';
        return null;
      });

      final result = await platform.getPlatformVersion();
      expect(result, '1.0.0');
    });

    test('returns unknown for null response', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getPlatformVersion') return null;
        return null;
      });

      final result = await platform.getPlatformVersion();
      expect(result, 'unknown');
    });
  });

  // ---------------------------------------------------------------------------
  // openCashDrawer
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint openCashDrawer', () {
    test('sends pin argument', () async {
      int? capturedPin;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'openCashDrawer') {
          capturedPin = methodCall.arguments['pin'] as int;
          return null;
        }
        return null;
      });

      await platform.openCashDrawer(pin: 1);
      expect(capturedPin, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // printQrCode / printBarcode / printImage
  // ---------------------------------------------------------------------------
  group('MethodChannelThunderThermalPrint other print methods', () {
    test('printQrCode sends data and size', () async {
      Map<String, dynamic>? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'printQrCode') {
          capturedArgs =
              Map<String, dynamic>.from(methodCall.arguments as Map);
          return null;
        }
        return null;
      });

      await platform.printQrCode('https://example.com', size: 8);
      expect(capturedArgs!['data'], 'https://example.com');
      expect(capturedArgs!['size'], 8);
    });

    test('printBarcode sends data and type', () async {
      Map<String, dynamic>? capturedArgs;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'printBarcode') {
          capturedArgs =
              Map<String, dynamic>.from(methodCall.arguments as Map);
          return null;
        }
        return null;
      });

      await platform.printBarcode('12345', type: 'EAN13');
      expect(capturedArgs!['data'], '12345');
      expect(capturedArgs!['type'], 'EAN13');
    });
  });
}
