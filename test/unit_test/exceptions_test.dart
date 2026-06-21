import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_thermal_print/src/exceptions/exceptions.dart';

void main() {
  group('PrinterException', () {
    test('creates with message', () {
      final exception = PrinterException('Test error');
      expect(exception.message, 'Test error');
    });

    test('creates with code and details', () {
      final exception = PrinterException(
        'Test error',
        code: 'TEST_CODE',
        details: 'Some details',
      );

      expect(exception.message, 'Test error');
      expect(exception.code, 'TEST_CODE');
      expect(exception.details, 'Some details');
    });

    test('toString includes message', () {
      final exception = PrinterException('Error occurred');
      expect(exception.toString(), contains('PrinterException: Error occurred'));
    });

    test('toString includes code when present', () {
      final exception = PrinterException('Error', code: 'CODE123');
      expect(exception.toString(), contains('CODE123'));
    });

    test('toString includes details when present', () {
      final exception = PrinterException('Error', details: 'Detail info');
      expect(exception.toString(), contains('Detail info'));
    });
  });

  group('ConnectionException', () {
    test('extends PrinterException', () {
      final exception = ConnectionException('Connection failed');
      expect(exception, isA<PrinterException>());
      expect(exception.message, 'Connection failed');
    });

    test('toString includes correct type', () {
      final exception = ConnectionException('Failed');
      expect(exception.toString(), contains('ConnectionException: Failed'));
    });
  });

  group('PermissionException', () {
    test('creates with permission name', () {
      final exception = PermissionException(
        'Permission denied',
        permissionName: 'BLUETOOTH_CONNECT',
      );

      expect(exception.message, 'Permission denied');
      expect(exception.permissionName, 'BLUETOOTH_CONNECT');
    });

    test('toString includes permission name', () {
      final exception = PermissionException(
        'Denied',
        permissionName: 'LOCATION',
      );
      expect(exception.toString(), contains('LOCATION'));
    });
  });

  group('PaperOutException', () {
    test('creates correctly', () {
      final exception = PaperOutException('No paper');
      expect(exception.message, 'No paper');
      expect(exception, isA<PrinterException>());
    });

    test('toString includes correct type', () {
      final exception = PaperOutException('Empty');
      expect(exception.toString(), contains('PaperOutException: Empty'));
    });
  });

  group('CoverOpenException', () {
    test('creates correctly', () {
      final exception = CoverOpenException('Cover is open');
      expect(exception.message, 'Cover is open');
      expect(exception, isA<PrinterException>());
    });
  });

  group('DeviceNotFoundException', () {
    test('creates with searched address', () {
      final exception = DeviceNotFoundException(
        'Device not found',
        searchedAddress: '00:11:22:33:44:55',
      );

      expect(exception.message, 'Device not found');
      expect(exception.searchedAddress, '00:11:22:33:44:55');
    });

    test('toString includes searched address', () {
      final exception = DeviceNotFoundException(
        'Not found',
        searchedAddress: '192.168.1.100',
      );
      expect(exception.toString(), contains('192.168.1.100'));
    });
  });

  group('PrintTimeoutException', () {
    test('creates with timeout ms', () {
      final exception = PrintTimeoutException(
        'Timed out',
        timeoutMs: 10000,
      );

      expect(exception.message, 'Timed out');
      expect(exception.timeoutMs, 10000);
    });

    test('toString includes timeout ms', () {
      final exception = PrintTimeoutException('Timeout', timeoutMs: 5000);
      expect(exception.toString(), contains('5000'));
    });
  });

  group('NotSupportedException', () {
    test('creates with feature', () {
      final exception = NotSupportedException(
        'Not supported',
        feature: 'qrCode',
      );

      expect(exception.message, 'Not supported');
      expect(exception.feature, 'qrCode');
    });
  });

  group('PrinterBusyException', () {
    test('creates correctly', () {
      final exception = PrinterBusyException('Printer is busy');
      expect(exception.message, 'Printer is busy');
      expect(exception, isA<PrinterException>());
    });
  });

  group('InvalidDataException', () {
    test('creates correctly', () {
      final exception = InvalidDataException('Invalid data');
      expect(exception.message, 'Invalid data');
      expect(exception, isA<PrinterException>());
    });
  });
}
