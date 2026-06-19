import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_thermal_print/src/exceptions/exceptions.dart';

void main() {
  // ---------------------------------------------------------------------------
  // PrinterException (base class)
  // ---------------------------------------------------------------------------
  group('PrinterException', () {
    test('can be created with message only', () {
      final e = PrinterException('Something went wrong');
      expect(e.message, 'Something went wrong');
      expect(e.code, isNull);
      expect(e.details, isNull);
    });

    test('can be created with code', () {
      final e = PrinterException('Error', code: 'ERR_001');
      expect(e.code, 'ERR_001');
    });

    test('can be created with details', () {
      final e = PrinterException('Error', details: {'key': 'value'});
      expect(e.details, {'key': 'value'});
    });

    test('can be created with all fields', () {
      final e = PrinterException('Full error',
          code: 'CODE', details: 42);
      expect(e.message, 'Full error');
      expect(e.code, 'CODE');
      expect(e.details, 42);
    });

    test('toString format without code and details', () {
      final e = PrinterException('base error');
      expect(e.toString(), 'PrinterException: base error');
    });

    test('toString format with code only', () {
      final e = PrinterException('base error', code: 'C1');
      expect(e.toString(), 'PrinterException: base error (code: C1)');
    });

    test('toString format with details only', () {
      final e = PrinterException('base error', details: 'extra info');
      expect(
          e.toString(), 'PrinterException: base error | details: extra info');
    });

    test('toString format with code and details', () {
      final e = PrinterException('base error',
          code: 'C1', details: {'x': 1});
      expect(e.toString(),
          'PrinterException: base error (code: C1) | details: {x: 1}');
    });

    test('implements Exception interface', () {
      final e = PrinterException('test');
      expect(e, isA<Exception>());
    });
  });

  // ---------------------------------------------------------------------------
  // ConnectionException
  // ---------------------------------------------------------------------------
  group('ConnectionException', () {
    test('can be thrown and caught as PrinterException', () {
      Exception? caught;
      try {
        throw ConnectionException('Lost connection');
      } on PrinterException catch (e) {
        caught = e;
      }
      expect(caught, isA<ConnectionException>());
      expect((caught as ConnectionException).message, 'Lost connection');
    });

    test('can be thrown and caught as specific type', () {
      ConnectionException? caught;
      try {
        throw ConnectionException('Failed');
      } on ConnectionException catch (e) {
        caught = e;
      }
      expect(caught, isNotNull);
      expect(caught!.message, 'Failed');
    });

    test('is a PrinterException', () {
      final e = ConnectionException('test');
      expect(e, isA<PrinterException>());
    });

    test('toString starts with ConnectionException', () {
      final e = ConnectionException('conn error', code: 'CON_ERR');
      expect(e.toString(), startsWith('ConnectionException: conn error'));
    });

    test('toString includes code and details', () {
      final e = ConnectionException('conn error',
          code: 'CON_ERR', details: 'timeout');
      expect(e.toString(), contains('(code: CON_ERR)'));
      expect(e.toString(), contains('| details: timeout'));
    });

    test('code and details are accessible', () {
      final e = ConnectionException('msg', code: 'C', details: 123);
      expect(e.code, 'C');
      expect(e.details, 123);
    });
  });

  // ---------------------------------------------------------------------------
  // PermissionException
  // ---------------------------------------------------------------------------
  group('PermissionException', () {
    test('can be thrown and caught as PrinterException', () {
      PrinterException? caught;
      try {
        throw PermissionException('Denied',
            permissionName: 'BLUETOOTH');
      } on PrinterException catch (e) {
        caught = e;
      }
      expect(caught, isA<PermissionException>());
    });

    test('permissionName is accessible', () {
      final e = PermissionException('No access',
          permissionName: 'LOCATION');
      expect(e.permissionName, 'LOCATION');
    });

    test('permissionName can be null', () {
      final e = PermissionException('No access');
      expect(e.permissionName, isNull);
    });

    test('toString includes permission name', () {
      final e = PermissionException('Denied',
          permissionName: 'BLUETOOTH', code: 'PERM');
      expect(e.toString(), contains('(permission: BLUETOOTH)'));
      expect(e.toString(), contains('(code: PERM)'));
    });

    test('toString without permission still valid', () {
      final e = PermissionException('No perm', code: 'P1');
      final str = e.toString();
      expect(str, contains('PermissionException: No perm'));
      expect(str, isNot(contains('(permission:')));
    });

    test('inherits from PrinterException', () {
      final e = PermissionException('test');
      expect(e, isA<PrinterException>());
    });
  });

  // ---------------------------------------------------------------------------
  // PaperOutException
  // ---------------------------------------------------------------------------
  group('PaperOutException', () {
    test('can be thrown and caught as PrinterException', () {
      PrinterException? caught;
      try {
        throw PaperOutException('No paper');
      } on PrinterException catch (e) {
        caught = e;
      }
      expect(caught, isA<PaperOutException>());
    });

    test('message and code are correct', () {
      final e = PaperOutException('Empty', code: 'PAPER');
      expect(e.message, 'Empty');
      expect(e.code, 'PAPER');
    });

    test('toString format is correct', () {
      final e = PaperOutException('Out', code: 'P1', details: 'tray empty');
      final str = e.toString();
      expect(str, startsWith('PaperOutException: Out'));
      expect(str, contains('(code: P1)'));
      expect(str, contains('| details: tray empty'));
    });

    test('inherits from PrinterException', () {
      final e = PaperOutException('test');
      expect(e, isA<PrinterException>());
    });
  });

  // ---------------------------------------------------------------------------
  // CoverOpenException
  // ---------------------------------------------------------------------------
  group('CoverOpenException', () {
    test('can be thrown and caught as PrinterException', () {
      PrinterException? caught;
      try {
        throw CoverOpenException('Lid is open');
      } on PrinterException catch (e) {
        caught = e;
      }
      expect(caught, isA<CoverOpenException>());
    });

    test('toString format is correct', () {
      final e = CoverOpenException('Open', code: 'COVER');
      expect(e.toString(), startsWith('CoverOpenException: Open'));
      expect(e.toString(), contains('(code: COVER)'));
    });
  });

  // ---------------------------------------------------------------------------
  // DeviceNotFoundException
  // ---------------------------------------------------------------------------
  group('DeviceNotFoundException', () {
    test('searchedAddress is accessible', () {
      final e = DeviceNotFoundException('Not found',
          searchedAddress: '00:11:22');
      expect(e.searchedAddress, '00:11:22');
    });

    test('searchedAddress can be null', () {
      final e = DeviceNotFoundException('Not found');
      expect(e.searchedAddress, isNull);
    });

    test('toString includes searchedAddress', () {
      final e = DeviceNotFoundException('Not found',
          searchedAddress: 'AA:BB:CC', code: 'DNF');
      final str = e.toString();
      expect(str, contains('(searchedAddress: AA:BB:CC)'));
      expect(str, contains('(code: DNF)'));
    });

    test('can be caught as PrinterException', () {
      PrinterException? caught;
      try {
        throw DeviceNotFoundException('Gone');
      } on PrinterException catch (e) {
        caught = e;
      }
      expect(caught, isA<DeviceNotFoundException>());
    });
  });

  // ---------------------------------------------------------------------------
  // PrintTimeoutException
  // ---------------------------------------------------------------------------
  group('PrintTimeoutException', () {
    test('timeoutMs is accessible', () {
      final e = PrintTimeoutException('Timed out', timeoutMs: 5000);
      expect(e.timeoutMs, 5000);
    });

    test('timeoutMs can be null', () {
      final e = PrintTimeoutException('Timed out');
      expect(e.timeoutMs, isNull);
    });

    test('toString includes timeoutMs', () {
      final e = PrintTimeoutException('Slow', timeoutMs: 3000, code: 'TOUT');
      final str = e.toString();
      expect(str, contains('(timeoutMs: 3000)'));
      expect(str, contains('(code: TOUT)'));
    });

    test('can be caught as PrinterException', () {
      PrinterException? caught;
      try {
        throw PrintTimeoutException('Too slow', timeoutMs: 1000);
      } on PrinterException catch (e) {
        caught = e;
      }
      expect(caught, isA<PrintTimeoutException>());
    });
  });

  // ---------------------------------------------------------------------------
  // NotSupportedException
  // ---------------------------------------------------------------------------
  group('NotSupportedException', () {
    test('feature is accessible', () {
      final e = NotSupportedException('Not available',
          feature: 'qrCode');
      expect(e.feature, 'qrCode');
    });

    test('feature can be null', () {
      final e = NotSupportedException('Not available');
      expect(e.feature, isNull);
    });

    test('toString includes feature', () {
      final e = NotSupportedException('Unsupported',
          feature: 'bluetooth', code: 'NS');
      final str = e.toString();
      expect(str, contains('(feature: bluetooth)'));
      expect(str, contains('(code: NS)'));
    });

    test('can be caught as PrinterException', () {
      PrinterException? caught;
      try {
        throw NotSupportedException('Nope');
      } on PrinterException catch (e) {
        caught = e;
      }
      expect(caught, isA<NotSupportedException>());
    });
  });

  // ---------------------------------------------------------------------------
  // PrinterBusyException
  // ---------------------------------------------------------------------------
  group('PrinterBusyException', () {
    test('can be thrown and caught as PrinterException', () {
      PrinterException? caught;
      try {
        throw PrinterBusyException('Busy');
      } on PrinterException catch (e) {
        caught = e;
      }
      expect(caught, isA<PrinterBusyException>());
    });

    test('toString format is correct', () {
      final e = PrinterBusyException('Occupied', code: 'BUSY', details: 'job 1');
      final str = e.toString();
      expect(str, startsWith('PrinterBusyException: Occupied'));
      expect(str, contains('(code: BUSY)'));
      expect(str, contains('| details: job 1'));
    });
  });

  // ---------------------------------------------------------------------------
  // InvalidDataException
  // ---------------------------------------------------------------------------
  group('InvalidDataException', () {
    test('can be thrown and caught as PrinterException', () {
      PrinterException? caught;
      try {
        throw InvalidDataException('Bad data');
      } on PrinterException catch (e) {
        caught = e;
      }
      expect(caught, isA<InvalidDataException>());
    });

    test('toString format is correct', () {
      final e = InvalidDataException('Malformed', code: 'DATA_ERR');
      final str = e.toString();
      expect(str, startsWith('InvalidDataException: Malformed'));
      expect(str, contains('(code: DATA_ERR)'));
    });
  });

  // ---------------------------------------------------------------------------
  // Inheritance – all exceptions extend PrinterException
  // ---------------------------------------------------------------------------
  group('Exception inheritance', () {
    test('every subtype is a PrinterException', () {
      final exceptions = <PrinterException>[
        PrinterException('base'),
        ConnectionException('conn'),
        PermissionException('perm'),
        PaperOutException('paper'),
        CoverOpenException('cover'),
        DeviceNotFoundException('device'),
        PrintTimeoutException('timeout'),
        NotSupportedException('not supported'),
        PrinterBusyException('busy'),
        InvalidDataException('invalid'),
      ];
      for (final e in exceptions) {
        expect(e, isA<PrinterException>());
      }
    });

    test('every subtype implements Exception', () {
      final exceptions = <Exception>[
        PrinterException('base'),
        ConnectionException('conn'),
        PermissionException('perm'),
        PaperOutException('paper'),
        CoverOpenException('cover'),
        DeviceNotFoundException('device'),
        PrintTimeoutException('timeout'),
        NotSupportedException('not supported'),
        PrinterBusyException('busy'),
        InvalidDataException('invalid'),
      ];
      for (final e in exceptions) {
        expect(e, isA<Exception>());
      }
    });

    test('catching PrinterException catches all subtypes', () {
      final allExceptions = <PrinterException>[
        ConnectionException('a'),
        PermissionException('b'),
        PaperOutException('c'),
        CoverOpenException('d'),
        DeviceNotFoundException('e'),
        PrintTimeoutException('f'),
        NotSupportedException('g'),
        PrinterBusyException('h'),
        InvalidDataException('i'),
      ];

      for (final ex in allExceptions) {
        PrinterException? caught;
        try {
          throw ex;
        } on PrinterException catch (e) {
          caught = e;
        }
        expect(caught, isNotNull);
        expect(caught!.message, isNotEmpty);
      }
    });
  });
}
