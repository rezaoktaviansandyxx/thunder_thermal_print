import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_thermal_print/src/escpos/escpos_commands.dart';

void main() {
  group('EscPosCommands', () {
    test('initialize returns correct bytes', () {
      final bytes = EscPosCommands.initialize();
      expect(bytes, [0x1B, 0x40]);
    });

    test('bold commands work correctly', () {
      final enableBold = EscPosCommands.enableBold();
      expect(enableBold, [0x1B, 0x45, 0x01]);

      final disableBold = EscPosCommands.disableBold();
      expect(disableBold, [0x1B, 0x45, 0x00]);
    });

    test('underline commands work correctly', () {
      final enableUnderline = EscPosCommands.enableUnderline(mode: 1);
      expect(enableUnderline, [0x1B, 0x2D, 0x01]);

      final disableUnderline = EscPosCommands.disableUnderline();
      expect(disableUnderline, [0x1B, 0x2D, 0x00]);
    });

    test('alignment commands work correctly', () {
      final alignLeft = EscPosCommands.alignLeft();
      expect(alignLeft, [0x1B, 0x61, 0x00]);

      final alignCenter = EscPosCommands.alignCenter();
      expect(alignCenter, [0x1B, 0x61, 0x01]);

      final alignRight = EscPosCommands.alignRight();
      expect(alignRight, [0x1B, 0x61, 0x02]);
    });

    test('text size commands work correctly', () {
      final doubleWidth = EscPosCommands.enableDoubleWidth();
      expect(doubleWidth, [0x1D, 0x21, 0x20]);

      final doubleHeight = EscPosCommands.enableDoubleHeight();
      expect(doubleHeight, [0x1D, 0x21, 0x10]);

      final doubleBoth = EscPosCommands.enableDoubleWidthAndHeight();
      expect(doubleBoth, [0x1D, 0x21, 0x30]);

      final normal = EscPosCommands.disableDoubleMode();
      expect(normal, [0x1D, 0x21, 0x00]);
    });

    test('setTextSize with custom width and height', () {
      final size2x2 = EscPosCommands.setTextSize(width: 2, height: 2);
      expect(size2x2, [0x1D, 0x21, 0x11]);

      final size4x4 = EscPosCommands.setTextSize(width: 4, height: 4);
      expect(size4x4, [0x1D, 0x21, 0x33]);
    });

    test('feed lines command works correctly', () {
      final feed3 = EscPosCommands.feedLines(3);
      expect(feed3, [0x1B, 0x64, 0x03]);
    });

    test('cut commands work correctly', () {
      final partialCut = EscPosCommands.partialCut();
      expect(partialCut, [0x1D, 0x56, 0x42, 0x00]);

      final fullCut = EscPosCommands.fullCut();
      expect(fullCut, [0x1D, 0x56, 0x01]);
    });

    test('beep command works correctly', () {
      final beep1 = EscPosCommands.beep(count: 1, duration: 3);
      expect(beep1, [0x1B, 0x42, 0x01, 0x03]);
    });

    test('cash drawer command works correctly', () {
      final drawer0 = EscPosCommands.openCashDrawer(pin: 0);
      expect(drawer0, [0x1B, 0x70, 0x00, 0x19]);

      final drawer1 = EscPosCommands.openCashDrawer(pin: 1);
      expect(drawer1, [0x1B, 0x70, 0x01, 0x19]);
    });

    test('code page command works correctly', () {
      final cp437 = EscPosCommands.setCodePage(0);
      expect(cp437, [0x1B, 0x74, 0x00]);

      final cp858 = EscPosCommands.setCodePage(25);
      expect(cp858, [0x1B, 0x74, 0x19]);
    });

    test('printText encodes UTF-8 correctly', () {
      final bytes = EscPosCommands.printText('Hello');
      expect(bytes, [72, 101, 108, 108, 111]); // ASCII for "Hello"
    });

    group('QR Code', () {
      test('printQrCode returns non-empty bytes', () {
        final bytes = EscPosCommands.printQrCode('https://example.com', size: 6);
        expect(bytes.isNotEmpty, true);
        expect(bytes.first, 0x1D); // GS
      });
    });

    group('Barcode', () {
      test('printBarcode returns non-empty bytes', () {
        final bytes = EscPosCommands.printBarcode('1234567890128', type: BarcodeType.ean13);
        expect(bytes.isNotEmpty, true);
      });
    });

    group('Raster Image', () {
      test('printRasterImage with empty data returns empty', () {
        final bytes = EscPosCommands.printRasterImage([], 384);
        expect(bytes.isEmpty, true);
      });

      test('printRasterImage with valid data returns bytes', () {
        final imageData = List.generate(384 * 100, (i) => i % 2 == 0 ? 0 : 255);
        final bytes = EscPosCommands.printRasterImage(imageData, 384);
        expect(bytes.isNotEmpty, true);
        expect(bytes[0], 0x1D); // GS
        expect(bytes[1], 0x76); // v
        expect(bytes[2], 0x30); // 0
      });
    });
  });
}
