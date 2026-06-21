import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_thermal_print/src/receipt/receipt_builder.dart';
import 'package:thunder_thermal_print/src/escpos/escpos_commands.dart';

void main() {
  group('ReceiptBuilder', () {
    test('build returns initialized command + buffer', () {
      final builder = ReceiptBuilder(maxCharsPerLine: 32);
      builder.text('Hello');
      final bytes = builder.build();

      expect(bytes.length, greaterThan(0));
      expect(bytes[0], 0x1B); // ESC
      expect(bytes[1], 0x40); // @ (initialize)
    });

    test('text adds LF at end', () {
      final builder = ReceiptBuilder();
      builder.text('Hello');
      final bytes = builder.build();

      // Check that LF (0x0A) is present after text
      expect(bytes.contains(0x0A), true);
    });

    test('feed adds line feed commands', () {
      final builder = ReceiptBuilder();
      builder.feed(lines: 3);
      final bytes = builder.build();

      // ESC d 3 = feed 3 lines
      expect(bytes.contains(0x03), true);
    });

    test('cut generates correct command', () {
      final builder = ReceiptBuilder();
      builder.cut(partial: true);
      final bytes = builder.build();

      // GS V B 0 = partial cut
      expect(bytes.contains(0x56), true);
      expect(bytes.contains(0x42), true);
    });

    test('row creates left and right aligned text', () {
      final builder = ReceiptBuilder(maxCharsPerLine: 32);
      builder.row(left: 'Item', right: '\$10.00');
      final bytes = builder.build();

      expect(bytes.length, greaterThan(0));
    });

    test('qr generates QR code command', () {
      final builder = ReceiptBuilder();
      builder.qr('https://example.com');
      final bytes = builder.build();

      expect(bytes.length, greaterThan(0));
      // QR code uses GS ( k commands
      expect(bytes.contains(0x28), true); // (
    });

    test('barcode generates barcode command', () {
      final builder = ReceiptBuilder();
      builder.barcode('1234567890128', type: BarcodeType.ean13);
      final bytes = builder.build();

      expect(bytes.length, greaterThan(0));
    });

    test('line generates separator', () {
      final builder = ReceiptBuilder(maxCharsPerLine: 32);
      builder.line(char: '-');
      final bytes = builder.build();

      expect(bytes.length, greaterThan(32));
    });

    test('doubleLine generates == separator', () {
      final builder = ReceiptBuilder(maxCharsPerLine: 32);
      builder.doubleLine();
      final bytes = builder.build();

      // Check for '=' characters
      final equalsCount = bytes.where((b) => b == 0x3D).length;
      expect(equalsCount, greaterThan(30));
    });

    test('bold enables bold mode', () {
      final builder = ReceiptBuilder();
      builder.bold().text('Bold Text');
      final bytes = builder.build();

      // ESC E 1 = enable bold
      expect(bytes.contains(0x45), true);
      expect(bytes.contains(0x01), true);
    });

    test('normal resets formatting', () {
      final builder = ReceiptBuilder();
      builder.bold().text('Bold').normal().text('Normal');
      final bytes = builder.build();

      expect(bytes.length, greaterThan(0));
    });

    test('center aligns text', () {
      final builder = ReceiptBuilder();
      builder.center().text('Centered');
      final bytes = builder.build();

      // ESC a 1 = center align
      expect(bytes.contains(0x61), true);
      expect(bytes.contains(0x01), true);
    });

    test('right aligns text', () {
      final builder = ReceiptBuilder();
      builder.right().text('Right');
      final bytes = builder.build();

      // ESC a 2 = right align
      expect(bytes.contains(0x61), true);
      expect(bytes.contains(0x02), true);
    });

    test('underline enables underline', () {
      final builder = ReceiptBuilder();
      builder.underline().text('Underlined');
      final bytes = builder.build();

      // ESC - n = underline
      expect(bytes.contains(0x2D), true);
    });

    test('doubleWidth enables double width', () {
      final builder = ReceiptBuilder();
      builder.doubleWidth().text('Wide');
      final bytes = builder.build();

      // GS ! 0x20 = double width
      expect(bytes.contains(0x21), true);
      expect(bytes.contains(0x20), true);
    });

    test('doubleHeight enables double height', () {
      final builder = ReceiptBuilder();
      builder.doubleHeight().text('Tall');
      final bytes = builder.build();

      // GS ! 0x10 = double height
      expect(bytes.contains(0x21), true);
      expect(bytes.contains(0x10), true);
    });

    test('cashDrawer sends pulse command', () {
      final builder = ReceiptBuilder();
      builder.cashDrawer(pin: 0);
      final bytes = builder.build();

      // ESC p 0 = cash drawer pin 0
      expect(bytes.contains(0x70), true);
    });

    test('beep sends beep command', () {
      final builder = ReceiptBuilder();
      builder.beep(count: 2, duration: 5);
      final bytes = builder.build();

      // ESC B n m = beep
      expect(bytes.contains(0x42), true);
    });

    test('raw adds bytes directly', () {
      final builder = ReceiptBuilder();
      builder.raw([0x1B, 0x40]);
      final bytes = builder.build();

      expect(bytes.contains(0x1B), true);
      expect(bytes.contains(0x40), true);
    });

    test('emptyLine adds LF bytes', () {
      final builder = ReceiptBuilder();
      builder.emptyLine(count: 2);
      final bytes = builder.build();

      final lfCount = bytes.where((b) => b == 0x0A).length;
      expect(lfCount, greaterThanOrEqualTo(2));
    });

    test('spacing is alias for emptyLine', () {
      final builder = ReceiptBuilder();
      builder.spacing(3);
      final bytes = builder.build();

      final lfCount = bytes.where((b) => b == 0x0A).length;
      expect(lfCount, greaterThanOrEqualTo(3));
    });

    test('buildAsUint8List returns Uint8List', () {
      final builder = ReceiptBuilder();
      builder.text('Test');
      final uint8list = builder.buildAsUint8List();

      expect(uint8list, isA<Uint8List>());
      expect(uint8list.length, greaterThan(0));
    });

    test('row3 creates three column layout', () {
      final builder = ReceiptBuilder(maxCharsPerLine: 48);
      builder.row3(
        col1: 'Item',
        col2: 'Qty',
        col3: 'Price',
        col1Width: 20,
        col3Width: 10,
      );
      final bytes = builder.build();

      expect(bytes.length, greaterThan(0));
    });

    test('textWrapped wraps long text', () {
      final builder = ReceiptBuilder(maxCharsPerLine: 32);
      builder.textWrapped('This is a very long text that should be wrapped at 32 characters');
      final bytes = builder.build();

      expect(bytes.length, greaterThan(0));
    });

    test('fontA and fontB select correct fonts', () {
      final builder = ReceiptBuilder();
      builder.fontB().text('Font B');
      final bytes = builder.build();

      // ESC M 1 = Font B
      expect(bytes.contains(0x4D), true);
      expect(bytes.contains(0x01), true);
    });

    test('inverse enables inverse mode', () {
      final builder = ReceiptBuilder();
      builder.inverse().text('Inverse');
      final bytes = builder.build();

      // GS B 1 = inverse
      expect(bytes.contains(0x42), true);
    });

    test('lineSpacing sets custom spacing', () {
      final builder = ReceiptBuilder();
      builder.lineSpacing(24);
      final bytes = builder.build();

      // ESC 3 n = line spacing
      expect(bytes.contains(0x33), true);
      expect(bytes.contains(24), true);
    });

    test('resetLineSpacing resets to default', () {
      final builder = ReceiptBuilder();
      builder.resetLineSpacing();
      final bytes = builder.build();

      // ESC 2 = reset line spacing
      expect(bytes.contains(0x32), true);
    });
  });
}
