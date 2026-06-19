import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_thermal_print/src/escpos/escpos_commands.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------
  group('EscPosCommands constants', () {
    test('ESC is 0x1B', () {
      expect(EscPosCommands.esc, 0x1B);
    });

    test('GS is 0x1D', () {
      expect(EscPosCommands.gs, 0x1D);
    });

    test('FS is 0x1C', () {
      expect(EscPosCommands.fs, 0x1C);
    });
  });

  // ---------------------------------------------------------------------------
  // Initialize
  // ---------------------------------------------------------------------------
  group('EscPosCommands.initialize', () {
    test('produces ESC @ (0x1B 0x40)', () {
      expect(EscPosCommands.initialize(), [0x1B, 0x40]);
    });

    test('always returns exactly 2 bytes', () {
      expect(EscPosCommands.initialize().length, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // Bold
  // ---------------------------------------------------------------------------
  group('EscPosCommands bold', () {
    test('enableBold produces ESC E 1', () {
      expect(EscPosCommands.enableBold(), [0x1B, 0x45, 0x01]);
    });

    test('disableBold produces ESC E 0', () {
      expect(EscPosCommands.disableBold(), [0x1B, 0x45, 0x00]);
    });

    test('bold commands are 3 bytes each', () {
      expect(EscPosCommands.enableBold().length, 3);
      expect(EscPosCommands.disableBold().length, 3);
    });
  });

  // ---------------------------------------------------------------------------
  // Underline
  // ---------------------------------------------------------------------------
  group('EscPosCommands underline', () {
    test('enableUnderline default mode 1', () {
      expect(EscPosCommands.enableUnderline(), [0x1B, 0x2D, 0x01]);
    });

    test('enableUnderline mode 2', () {
      expect(EscPosCommands.enableUnderline(mode: 2), [0x1B, 0x2D, 0x02]);
    });

    test('disableUnderline produces ESC - 0', () {
      expect(EscPosCommands.disableUnderline(), [0x1B, 0x2D, 0x00]);
    });
  });

  // ---------------------------------------------------------------------------
  // Inverse
  // ---------------------------------------------------------------------------
  group('EscPosCommands inverse', () {
    test('enableInverse produces GS B 1', () {
      expect(EscPosCommands.enableInverse(), [0x1D, 0x42, 0x01]);
    });

    test('disableInverse produces GS B 0', () {
      expect(EscPosCommands.disableInverse(), [0x1D, 0x42, 0x00]);
    });
  });

  // ---------------------------------------------------------------------------
  // Alignment
  // ---------------------------------------------------------------------------
  group('EscPosCommands alignment', () {
    test('alignLeft produces ESC a 0', () {
      expect(EscPosCommands.alignLeft(), [0x1B, 0x61, 0x00]);
    });

    test('alignCenter produces ESC a 1', () {
      expect(EscPosCommands.alignCenter(), [0x1B, 0x61, 0x01]);
    });

    test('alignRight produces ESC a 2', () {
      expect(EscPosCommands.alignRight(), [0x1B, 0x61, 0x02]);
    });

    test('all alignment commands are 3 bytes', () {
      for (final cmd in [
        EscPosCommands.alignLeft(),
        EscPosCommands.alignCenter(),
        EscPosCommands.alignRight(),
      ]) {
        expect(cmd.length, 3);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Font selection
  // ---------------------------------------------------------------------------
  group('EscPosCommands font', () {
    test('setFontA produces ESC M 0', () {
      expect(EscPosCommands.setFontA(), [0x1B, 0x4D, 0x00]);
    });

    test('setFontB produces ESC M 1', () {
      expect(EscPosCommands.setFontB(), [0x1B, 0x4D, 0x01]);
    });
  });

  // ---------------------------------------------------------------------------
  // Text size (double-width / double-height)
  // ---------------------------------------------------------------------------
  group('EscPosCommands text size', () {
    test('enableDoubleWidth produces GS ! 0x20', () {
      expect(EscPosCommands.enableDoubleWidth(), [0x1D, 0x21, 0x20]);
    });

    test('enableDoubleHeight produces GS ! 0x10', () {
      expect(EscPosCommands.enableDoubleHeight(), [0x1D, 0x21, 0x10]);
    });

    test('enableDoubleWidthAndHeight produces GS ! 0x30', () {
      expect(EscPosCommands.enableDoubleWidthAndHeight(), [0x1D, 0x21, 0x30]);
    });

    test('disableDoubleMode produces GS ! 0x00', () {
      expect(EscPosCommands.disableDoubleMode(), [0x1D, 0x21, 0x00]);
    });

    test('setTextSize with default values produces GS ! 0x00', () {
      expect(EscPosCommands.setTextSize(), [0x1D, 0x21, 0x00]);
    });

    test('setTextSize width=2 height=1 produces GS ! 0x10', () {
      // w = 2-1 = 1, h = 1-1 = 0 → (1 << 4) | 0 = 0x10
      expect(EscPosCommands.setTextSize(width: 2, height: 1), [0x1D, 0x21, 0x10]);
    });

    test('setTextSize width=1 height=2 produces GS ! 0x01', () {
      // w = 0, h = 1 → 0x01
      expect(EscPosCommands.setTextSize(width: 1, height: 2), [0x1D, 0x21, 0x01]);
    });

    test('setTextSize clamps values to 1-8', () {
      // width=0 → clamped to 1 (w=0), height=0 → clamped to 1 (h=0)
      expect(EscPosCommands.setTextSize(width: 0, height: 0), [0x1D, 0x21, 0x00]);
    });
  });

  // ---------------------------------------------------------------------------
  // Feed lines / dots
  // ---------------------------------------------------------------------------
  group('EscPosCommands feed', () {
    test('feedLines(3) produces ESC d 3', () {
      expect(EscPosCommands.feedLines(3), [0x1B, 0x64, 0x03]);
    });

    test('feedLines(0) produces ESC d 0', () {
      expect(EscPosCommands.feedLines(0), [0x1B, 0x64, 0x00]);
    });

    test('feedLines clamps to 0-255', () {
      expect(EscPosCommands.feedLines(300), [0x1B, 0x64, 0xFF]);
      expect(EscPosCommands.feedLines(-5), [0x1B, 0x64, 0x00]);
    });

    test('feedDots(5) produces ESC J 5', () {
      expect(EscPosCommands.feedDots(5), [0x1B, 0x4A, 0x05]);
    });

    test('feedDots clamps to 0-255', () {
      expect(EscPosCommands.feedDots(999), [0x1B, 0x4A, 0xFF]);
    });
  });

  // ---------------------------------------------------------------------------
  // Cut
  // ---------------------------------------------------------------------------
  group('EscPosCommands cut', () {
    test('partialCut produces GS V 66 0', () {
      expect(EscPosCommands.partialCut(), [0x1D, 0x56, 0x42, 0x00]);
    });

    test('partialCut is 4 bytes', () {
      expect(EscPosCommands.partialCut().length, 4);
    });

    test('fullCut produces GS V 1', () {
      expect(EscPosCommands.fullCut(), [0x1D, 0x56, 0x01]);
    });

    test('fullCut is 3 bytes', () {
      expect(EscPosCommands.fullCut().length, 3);
    });
  });

  // ---------------------------------------------------------------------------
  // Beep
  // ---------------------------------------------------------------------------
  group('EscPosCommands beep', () {
    test('default beep produces ESC B 1 3', () {
      expect(EscPosCommands.beep(), [0x1B, 0x42, 0x01, 0x03]);
    });

    test('beep with custom count and duration', () {
      expect(EscPosCommands.beep(count: 3, duration: 5), [0x1B, 0x42, 0x03, 0x05]);
    });

    test('beep clamps count to 1-9', () {
      expect(EscPosCommands.beep(count: 0).last, 0x01);
      expect(EscPosCommands.beep(count: 10).last, 0x09);
    });

    test('beep clamps duration to 1-9', () {
      expect(EscPosCommands.beep(duration: 0).last, 0x01);
      expect(EscPosCommands.beep(duration: 15).last, 0x09);
    });
  });

  // ---------------------------------------------------------------------------
  // Cash drawer
  // ---------------------------------------------------------------------------
  group('EscPosCommands openCashDrawer', () {
    test('default pin 0 produces ESC p 0 0x19', () {
      expect(EscPosCommands.openCashDrawer(), [0x1B, 0x70, 0x00, 0x19]);
    });

    test('pin 1 produces ESC p 1 0x19', () {
      expect(EscPosCommands.openCashDrawer(pin: 1), [0x1B, 0x70, 0x01, 0x19]);
    });

    test('pin clamps to 0-1', () {
      expect(EscPosCommands.openCashDrawer(pin: 5)[2], 0x01);
      expect(EscPosCommands.openCashDrawer(pin: -1)[2], 0x00);
    });
  });

  // ---------------------------------------------------------------------------
  // Line spacing
  // ---------------------------------------------------------------------------
  group('EscPosCommands lineSpacing', () {
    test('setLineSpacing produces ESC 3 n', () {
      expect(EscPosCommands.setLineSpacing(30), [0x1B, 0x33, 0x1E]);
    });

    test('resetLineSpacing produces ESC 2', () {
      expect(EscPosCommands.resetLineSpacing(), [0x1B, 0x32]);
    });

    test('setLineSpacing clamps to 0-255', () {
      expect(EscPosCommands.setLineSpacing(-1), [0x1B, 0x33, 0x00]);
      expect(EscPosCommands.setLineSpacing(300), [0x1B, 0x33, 0xFF]);
    });
  });

  // ---------------------------------------------------------------------------
  // Code page
  // ---------------------------------------------------------------------------
  group('EscPosCommands codePage', () {
    test('setCodePage produces ESC t n', () {
      expect(EscPosCommands.setCodePage(0), [0x1B, 0x74, 0x00]);
      expect(EscPosCommands.setCodePage(16), [0x1B, 0x74, 0x10]);
    });

    test('setCodePage clamps to 0-255', () {
      expect(EscPosCommands.setCodePage(300), [0x1B, 0x74, 0xFF]);
    });
  });

  // ---------------------------------------------------------------------------
  // printText
  // ---------------------------------------------------------------------------
  group('EscPosCommands.printText', () {
    test('encodes ASCII text as UTF-8 bytes', () {
      final result = EscPosCommands.printText('Hello');
      expect(result, utf8.encode('Hello'));
    });

    test('empty string returns empty bytes', () {
      expect(EscPosCommands.printText(''), isEmpty);
    });

    test('UTF-8 multi-byte characters', () {
      final result = EscPosCommands.printText('café');
      expect(result, utf8.encode('café'));
    });

    test('CJK text encodes as UTF-8', () {
      final result = EscPosCommands.printText('打印');
      expect(result, isNotEmpty);
      expect(result.length, 6); // 3 bytes per CJK char
    });
  });

  // ---------------------------------------------------------------------------
  // printQrCode
  // ---------------------------------------------------------------------------
  group('EscPosCommands.printQrCode', () {
    test('contains GS ( k sequence', () {
      final result = EscPosCommands.printQrCode('test');
      // GS ( k = 0x1D 0x28 0x6B
      expect(result, containsAll([0x1D, 0x28, 0x6B]));
    });

    test('contains model selection command', () {
      final result = EscPosCommands.printQrCode('data');
      // Model select: cn=0x65, fn=0x50
      expect(result, containsAll([0x65, 0x50]));
    });

    test('contains error correction command', () {
      final result = EscPosCommands.printQrCode('data');
      // Error correction: fn=0x45
      expect(result, contains(0x45));
    });

    test('contains size command', () {
      final result = EscPosCommands.printQrCode('data', size: 8);
      // Size command: cn=0x67, fn=0x43, d1=8
      expect(result, containsAll([0x67, 0x43, 0x08]));
    });

    test('contains data bytes', () {
      final result = EscPosCommands.printQrCode('ABC');
      // Should contain the ASCII bytes for 'ABC' (0x41, 0x42, 0x43)
      expect(result, containsAll([0x41, 0x42, 0x43]));
    });

    test('contains print command', () {
      final result = EscPosCommands.printQrCode('data');
      // Print: fn=0x51
      expect(result, contains(0x51));
    });

    test('has multiple GS ( k blocks', () {
      final result = EscPosCommands.printQrCode('test');
      // Count occurrences of GS ( k pattern
      int count = 0;
      for (int i = 0; i < result.length - 2; i++) {
        if (result[i] == 0x1D && result[i + 1] == 0x28 && result[i + 2] == 0x6B) {
          count++;
        }
      }
      expect(count, 5); // model, error correction, size, store data, print
    });
  });

  // ---------------------------------------------------------------------------
  // printBarcode
  // ---------------------------------------------------------------------------
  group('EscPosCommands.printBarcode', () {
    test('default CODE128 barcode contains GS k', () {
      final result = EscPosCommands.printBarcode('12345');
      expect(result, containsAll([0x1D, 0x6B]));
      // Type code for code128 is 73
      expect(result, contains(73));
    });

    test('contains NUL terminator at end', () {
      final result = EscPosCommands.printBarcode('123');
      expect(result.last, 0x00);
    });

    test('contains data bytes', () {
      final result = EscPosCommands.printBarcode('AB');
      expect(result, containsAll([0x41, 0x42]));
    });

    test('EAN13 type uses code 67', () {
      final result =
          EscPosCommands.printBarcode('5901234123457', type: BarcodeType.ean13);
      expect(result, contains(67));
    });

    test('EAN8 type uses code 68', () {
      final result =
          EscPosCommands.printBarcode('96385074', type: BarcodeType.ean8);
      expect(result, contains(68));
    });

    test('UPC-A type uses code 65', () {
      final result =
          EscPosCommands.printBarcode('012345678905', type: BarcodeType.upcA);
      expect(result, contains(65));
    });

    test('CODE39 type uses code 69', () {
      final result =
          EscPosCommands.printBarcode('CODE39', type: BarcodeType.code39);
      expect(result, contains(69));
    });

    test('custom height and width are applied', () {
      final result = EscPosCommands.printBarcode(
        '12345',
        height: 100,
        width: 3,
      );
      // GS h n → height
      expect(result, containsAll([0x1D, 0x68]));
      // GS w n → width
      expect(result, containsAll([0x1D, 0x77]));
    });

    test('font A sets font byte to 0', () {
      final result = EscPosCommands.printBarcode('123', font: 'A');
      // GS f n → n should be 0
      final idx = result.indexOf(0x66);
      expect(idx, greaterThan(-1));
      expect(result[idx + 1], 0);
    });

    test('font B sets font byte to 1', () {
      final result = EscPosCommands.printBarcode('123', font: 'b');
      final idx = result.indexOf(0x66);
      expect(idx, greaterThan(-1));
      expect(result[idx + 1], 1);
    });
  });

  // ---------------------------------------------------------------------------
  // printRasterImage
  // ---------------------------------------------------------------------------
  group('EscPosCommands.printRasterImage', () {
    test('8x8 white image returns header + 1 byte per row', () {
      // 8x8 image, all white (255)
      final imageData = List.filled(64, 255);
      final result = EscPosCommands.printRasterImage(imageData, 8);
      // Header: GS v 0 m xL xH yL yH = 8 bytes
      // Data: 1 byte per row × 8 rows = 8 bytes
      expect(result.length, 16);
      // Header starts with GS v 0
      expect(result[0], 0x1D);
      expect(result[1], 0x76);
      expect(result[2], 0x30); // '0' character
    });

    test('8x8 black image produces all-ones bytes', () {
      // 8x8 image, all black (0)
      final imageData = List.filled(64, 0);
      final result = EscPosCommands.printRasterImage(imageData, 8);
      // All pixel data bytes should be 0xFF (all bits set = black)
      for (int i = 8; i < result.length; i++) {
        expect(result[i], 0xFF);
      }
    });

    test('8x8 white image produces all-zero data bytes', () {
      final imageData = List.filled(64, 255);
      final result = EscPosCommands.printRasterImage(imageData, 8);
      for (int i = 8; i < result.length; i++) {
        expect(result[i], 0x00);
      }
    });

    test('empty image data returns empty list', () {
      expect(EscPosCommands.printRasterImage([], 8), isEmpty);
    });

    test('zero width returns empty list', () {
      expect(EscPosCommands.printRasterImage([0, 0, 0], 0), isEmpty);
    });

    test('partial row is padded to 8-pixel boundary', () {
      // 4 pixels wide, 1 row, all black
      final imageData = [0, 0, 0, 0];
      final result = EscPosCommands.printRasterImage(imageData, 4);
      // bytesPerRow = (4+7)/8 = 1
      // Header = 8 bytes, data = 1 byte
      expect(result.length, 9);
      // First 4 bits should be 1 (black), rest 0 (padding)
      // 0b11110000 = 0xF0
      expect(result[8], 0xF0);
    });

    test('xL and xH encode bytes per row', () {
      final imageData = List.filled(16 * 8, 0); // 16 pixels wide, 8 rows
      final result = EscPosCommands.printRasterImage(imageData, 16);
      // bytesPerRow = (16+7)/8 = 2 → xL=2, xH=0
      expect(result[3], 2); // xL
      expect(result[4], 0); // xH
    });

    test('yL and yH encode height', () {
      final imageData = List.filled(8 * 5, 0); // 8 pixels wide, 5 rows
      final result = EscPosCommands.printRasterImage(imageData, 8);
      // height = 5 → yL=5, yH=0
      expect(result[5], 5); // yL
      expect(result[6], 0); // yH
    });
  });

  // ---------------------------------------------------------------------------
  // BarcodeType enum
  // ---------------------------------------------------------------------------
  group('BarcodeType', () {
    test('code128 has code 73', () {
      expect(BarcodeType.code128.code, 73);
    });

    test('ean13 has code 67', () {
      expect(BarcodeType.ean13.code, 67);
    });

    test('ean8 has code 68', () {
      expect(BarcodeType.ean8.code, 68);
    });

    test('upcA has code 65', () {
      expect(BarcodeType.upcA.code, 65);
    });

    test('code39 has code 69', () {
      expect(BarcodeType.code39.code, 69);
    });

    test('itf has code 70', () {
      expect(BarcodeType.itf.code, 70);
    });

    test('codabar has code 72', () {
      expect(BarcodeType.codabar.code, 72);
    });

    test('pharmacode has code 80', () {
      expect(BarcodeType.pharmacode.code, 80);
    });
  });
}
