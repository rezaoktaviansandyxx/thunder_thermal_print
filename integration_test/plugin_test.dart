import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_thermal_print/thunder_thermal_print.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThunderThermalPrint Integration', () {
    test('plugin can be accessed', () {
      expect(ThunderThermalPrint, isNotNull);
    });

    test('getPlatformVersion returns non-empty string', () async {
      try {
        final version = await ThunderThermalPrint.getPlatformVersion();
        expect(version, isNotEmpty);
      } catch (e) {
        // Expected on platforms without the native plugin registered
        expect(e, isA<NotSupportedException>());
      }
    });

    test('scanBluetooth handles unsupported platform', () async {
      try {
        final devices = await ThunderThermalPrint.scanBluetooth();
        expect(devices, isA<List<PrinterDevice>>());
      } catch (e) {
        expect(e, isA<Exception>());
      }
    });

    test('scanNetwork handles unsupported platform', () async {
      try {
        final devices = await ThunderThermalPrint.scanNetwork();
        expect(devices, isA<List<PrinterDevice>>());
      } catch (e) {
        expect(e, isA<Exception>());
      }
    });

    test('connection stream is available', () {
      final stream = ThunderThermalPrint.connectionStream;
      expect(stream, isA<Stream<PrinterConnectionState>>());
    });

    test('device event stream is available', () {
      final stream = ThunderThermalPrint.deviceEventStream;
      expect(stream, isA<Stream<PrinterEvent>>());
    });

    test('PrinterDevice model round-trip', () {
      const device = PrinterDevice(
        address: '00:11:22:33:44:55',
        name: 'Test Printer',
        connectionType: PrinterConnectionType.bluetooth,
        rssi: -50,
      );
      final map = device.toMap();
      final restored = PrinterDevice.fromMap(map);
      expect(restored.address, device.address);
      expect(restored.name, device.name);
      expect(restored.connectionType, device.connectionType);
      expect(restored.rssi, device.rssi);
    });

    test('ReceiptBuilder produces valid output', () {
      final receipt = ReceiptBuilder()
          .center()
          .bold()
          .text('TEST STORE')
          .normal()
          .line()
          .row(left: 'Coffee', right: '25.000')
          .cut();

      final bytes = receipt.build();
      expect(bytes, isNotEmpty);
      expect(bytes.first, 0x1B); // ESC
      expect(bytes[1], 0x40);   // @ (initialize)
    });

    test('PrinterProfile has all built-in profiles', () {
      expect(PrinterProfile.epson.name, 'Epson');
      expect(PrinterProfile.xprinter.name, 'XPrinter');
      expect(PrinterProfile.sunmi.name, 'Sunmi');
      expect(PrinterProfile.bixolon.name, 'Bixolon');
      expect(PrinterProfile.rongta.name, 'Rongta');
      expect(PrinterProfile.zjiang.name, 'ZJiang');
      expect(PrinterProfile.epson80.name, 'Epson 80mm');
    });

    test('PrinterStatus canPrint logic', () {
      const online = PrinterStatus(online: true);
      expect(online.canPrint, true);

      const offline = PrinterStatus(online: false);
      expect(offline.canPrint, false);

      const paperOut = PrinterStatus(online: true, paperOut: true);
      expect(paperOut.canPrint, false);

      const coverOpen = PrinterStatus(online: true, coverOpen: true);
      expect(coverOpen.canPrint, false);
    });

    test('EscPosCommands initialize', () {
      final init = EscPosCommands.initialize();
      expect(init, [0x1B, 0x40]);
    });

    test('EscPosCommands alignment', () {
      expect(EscPosCommands.alignLeft(), [0x1B, 0x61, 0x00]);
      expect(EscPosCommands.alignCenter(), [0x1B, 0x61, 0x01]);
      expect(EscPosCommands.alignRight(), [0x1B, 0x61, 0x02]);
    });

    test('exceptions hierarchy', () {
      expect(ConnectionException('test'), isA<PrinterException>());
      expect(PermissionException('test'), isA<PrinterException>());
      expect(PaperOutException('test'), isA<PrinterException>());
      expect(CoverOpenException('test'), isA<PrinterException>());
      expect(DeviceNotFoundException('test'), isA<PrinterException>());
      expect(PrintTimeoutException('test', timeoutMs: 5000), isA<PrinterException>());
      expect(NotSupportedException('test'), isA<PrinterException>());
      expect(PrinterBusyException('test'), isA<PrinterException>());
      expect(InvalidDataException('test'), isA<PrinterException>());
    });
  });
}
