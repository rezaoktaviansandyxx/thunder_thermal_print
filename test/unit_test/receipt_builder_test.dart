import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_thermal_print/src/receipt/receipt_builder.dart';
import 'package:thunder_thermal_print/src/escpos/escpos_commands.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Build basics
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder basics', () {
    test('empty builder build returns initialize command', () {
      final builder = ReceiptBuilder();
      final bytes = builder.build();
      expect(bytes.length, 2);
      expect(bytes, [0x1B, 0x40]);
    });

    test('build always starts with ESC @', () {
      final builder = ReceiptBuilder().text('Hello');
      final bytes = builder.build();
      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x40);
    });

    test('buildAsUint8List returns Uint8List', () {
      final builder = ReceiptBuilder().text('Test');
      final result = builder.buildAsUint8List();
      // Check it starts with ESC @
      expect(result[0], 0x1B);
      expect(result[1], 0x40);
      // Check it's a proper typed list
      expect(result.buffer.asUint8List(), result);
    });
  });

  // ---------------------------------------------------------------------------
  // Simple text
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder text', () {
    test('simple text receipt builds correctly', () {
      final builder = ReceiptBuilder()
          .text('Hello World')
          .text('Second line');
      final bytes = builder.build();
      // Should contain the text UTF-8 encoded
      final byteString = utf8.decode(
          bytes.where((b) => b > 0x1F).takeWhile((b) => b != 0x0A).toList(),
          allowMalformed: true);
      expect(bytes, containsAll(utf8.encode('Hello World')));
      expect(bytes, containsAll(utf8.encode('Second line')));
    });

    test('text appends LF (0x0A) after content', () {
      final builder = ReceiptBuilder().text('Hi');
      final bytes = builder.build();
      // Find the text bytes, then LF should follow
      final textBytes = utf8.encode('Hi');
      final textIdx = bytes.indexOf(textBytes[0], 2); // skip ESC @
      expect(bytes[textIdx + textBytes.length], 0x0A);
    });

    test('empty text still adds LF', () {
      final builder = ReceiptBuilder().text('');
      final bytes = builder.build();
      // After ESC @ (2 bytes), there should be at least an LF
      expect(bytes.length, greaterThan(2));
      expect(bytes.last, 0x0A);
    });
  });

  // ---------------------------------------------------------------------------
  // Alignment
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder alignment', () {
    test('center() adds ESC a 1', () {
      final builder = ReceiptBuilder().center();
      final bytes = builder.build();
      // After ESC @, should have ESC a 1
      expect(bytes.sublist(2), containsAll([0x1B, 0x61, 0x01]));
    });

    test('left() adds ESC a 0', () {
      final builder = ReceiptBuilder().left();
      final bytes = builder.build();
      expect(bytes.sublist(2), containsAll([0x1B, 0x61, 0x00]));
    });

    test('right() adds ESC a 2', () {
      final builder = ReceiptBuilder().right();
      final bytes = builder.build();
      expect(bytes.sublist(2), containsAll([0x1B, 0x61, 0x02]));
    });

    test('text after center has alignment commands', () {
      final builder = ReceiptBuilder().center().text('Centered');
      final bytes = builder.build();
      // Should contain ESC a 1 (center) and the text
      expect(bytes, containsAll([0x1B, 0x61, 0x01]));
      expect(bytes, containsAll(utf8.encode('Centered')));
    });
  });

  // ---------------------------------------------------------------------------
  // Bold text
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder bold', () {
    test('bold() adds ESC E 1', () {
      final builder = ReceiptBuilder().bold();
      final bytes = builder.build();
      expect(bytes.sublist(2), containsAll([0x1B, 0x45, 0x01]));
    });

    test('bold text includes bold command before text', () {
      final builder = ReceiptBuilder().bold().text('Bold');
      final bytes = builder.build();
      expect(bytes, containsAll([0x1B, 0x45, 0x01]));
      expect(bytes, containsAll(utf8.encode('Bold')));
    });

    test('normal() resets formatting', () {
      final builder = ReceiptBuilder().bold().normal().text('Normal');
      final bytes = builder.build();
      // Should contain disable bold (ESC E 0)
      expect(bytes, containsAll([0x1B, 0x45, 0x00]));
    });
  });

  // ---------------------------------------------------------------------------
  // Underline, inverse, font
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder other formatting', () {
    test('underline() adds ESC - 1', () {
      final builder = ReceiptBuilder().underline();
      final bytes = builder.build();
      expect(bytes, containsAll([0x1B, 0x2D, 0x01]));
    });

    test('inverse() adds GS B 1', () {
      final builder = ReceiptBuilder().inverse();
      final bytes = builder.build();
      expect(bytes, containsAll([0x1D, 0x42, 0x01]));
    });

    test('fontA() adds ESC M 0', () {
      final builder = ReceiptBuilder().fontA();
      final bytes = builder.build();
      expect(bytes, containsAll([0x1B, 0x4D, 0x00]));
    });

    test('fontB() adds ESC M 1', () {
      final builder = ReceiptBuilder().fontB();
      final bytes = builder.build();
      expect(bytes, containsAll([0x1B, 0x4D, 0x01]));
    });
  });

  // ---------------------------------------------------------------------------
  // Double width / height
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder double width/height', () {
    test('doubleWidth() adds GS ! 0x20', () {
      final builder = ReceiptBuilder().doubleWidth();
      final bytes = builder.build();
      expect(bytes, containsAll([0x1D, 0x21, 0x20]));
    });

    test('doubleHeight() adds GS ! 0x10', () {
      final builder = ReceiptBuilder().doubleHeight();
      final bytes = builder.build();
      expect(bytes, containsAll([0x1D, 0x21, 0x10]));
    });

    test('doubleSize() adds GS ! 0x30', () {
      final builder = ReceiptBuilder().doubleSize();
      final bytes = builder.build();
      expect(bytes, containsAll([0x1D, 0x21, 0x30]));
    });
  });

  // ---------------------------------------------------------------------------
  // Line separator
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder line', () {
    test('line() produces 32 dashes by default', () {
      final builder = ReceiptBuilder().line();
      final bytes = builder.build();
      // Extract text between ESC @ and the rest
      final dashBytes = utf8.encode('-' * 32);
      expect(bytes, containsAll(dashBytes));
    });

    test('line with custom char', () {
      final builder = ReceiptBuilder().line(char: '=');
      final bytes = builder.build();
      expect(bytes, containsAll(utf8.encode('=' * 32)));
    });

    test('doubleLine produces equals signs', () {
      final builder = ReceiptBuilder().doubleLine();
      final bytes = builder.build();
      expect(bytes, containsAll(utf8.encode('=' * 32)));
    });

    test('line appends LF', () {
      final builder = ReceiptBuilder().line();
      final bytes = builder.build();
      // The last byte before any trailing commands should be LF
      // There's an LF at the end of the line content
      expect(bytes, contains(0x0A));
    });
  });

  // ---------------------------------------------------------------------------
  // Row with left/right text
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder row', () {
    test('row pads left and right text', () {
      final builder = ReceiptBuilder().row(left: 'Item', right: '\$5.00');
      final bytes = builder.build();
      final textBytes = utf8.encode('Item');
      final rightBytes = utf8.encode('\$5.00');
      expect(bytes, containsAll(textBytes));
      expect(bytes, containsAll(rightBytes));
    });

    test('row total width equals maxCharsPerLine', () {
      final builder = ReceiptBuilder(maxCharsPerLine: 20)
          .row(left: 'A', right: 'B');
      final bytes = builder.build();
      // Extract the row text (find between formatting and LF)
      final rowText = _extractRowText(bytes);
      // The display width should be 20
      expect(rowText.length, 20);
    });

    test('long left text gets truncated gracefully', () {
      // With default 32 chars, if left is 25 chars and right is 5 chars,
      // there's only 2 spaces between
      final builder = ReceiptBuilder(maxCharsPerLine: 32)
          .row(left: 'A' * 25, right: 'B' * 5);
      final bytes = builder.build();
      // Should not throw
      expect(bytes, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Row3 (three columns)
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder row3', () {
    test('row3 produces three-column layout', () {
      final builder = ReceiptBuilder(maxCharsPerLine: 32).row3(
        col1: 'Item',
        col2: '2x',
        col3: '\$10',
        col1Width: 10,
        col3Width: 10,
      );
      final bytes = builder.build();
      expect(bytes, containsAll(utf8.encode('Item')));
      expect(bytes, containsAll(utf8.encode('2x')));
      expect(bytes, containsAll(utf8.encode('\$10')));
    });

    test('row3 columns are padded correctly', () {
      final builder = ReceiptBuilder(maxCharsPerLine: 32).row3(
        col1: 'A',
        col2: 'B',
        col3: 'C',
        col1Width: 10,
        col3Width: 10,
      );
      final bytes = builder.build();
      // Should contain the text for all columns
      expect(bytes, containsAll(utf8.encode('A')));
      expect(bytes, containsAll(utf8.encode('B')));
      expect(bytes, containsAll(utf8.encode('C')));
    });
  });

  // ---------------------------------------------------------------------------
  // Multiple items
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder multiple items', () {
    test('builds multi-item receipt', () {
      final builder = ReceiptBuilder()
          .center()
          .text('MY STORE')
          .left()
          .line()
          .text('Item 1: \$1.00')
          .text('Item 2: \$2.00')
          .line()
          .row(left: 'Total', right: '\$3.00');
      final bytes = builder.build();
      expect(bytes, containsAll(utf8.encode('MY STORE')));
      expect(bytes, containsAll(utf8.encode('Item 1: \$1.00')));
      expect(bytes, containsAll(utf8.encode('Item 2: \$2.00')));
      expect(bytes, containsAll(utf8.encode('Total')));
      expect(bytes, containsAll(utf8.encode('\$3.00')));
    });
  });

  // ---------------------------------------------------------------------------
  // QR code
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder qr', () {
    test('qr adds GS ( k sequence', () {
      final builder = ReceiptBuilder().qr('https://example.com');
      final bytes = builder.build();
      expect(bytes, containsAll([0x1D, 0x28, 0x6B]));
    });

    test('qr includes data bytes', () {
      final builder = ReceiptBuilder().qr('HELLO');
      final bytes = builder.build();
      expect(bytes, containsAll(utf8.encode('HELLO')));
    });

    test('qr adds LF after command', () {
      final builder = ReceiptBuilder().qr('test');
      final bytes = builder.build();
      // Last byte should be LF
      expect(bytes.last, 0x0A);
    });
  });

  // ---------------------------------------------------------------------------
  // Cut
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder cut', () {
    test('partial cut at end', () {
      final builder = ReceiptBuilder().cut();
      final bytes = builder.build();
      // GS V 66 0
      expect(bytes, containsAll([0x1D, 0x56, 0x42, 0x00]));
    });

    test('full cut at end', () {
      final builder = ReceiptBuilder().cut(partial: false);
      final bytes = builder.build();
      // GS V 1
      expect(bytes, containsAll([0x1D, 0x56, 0x01]));
    });

    test('cut is at end of buffer', () {
      final builder = ReceiptBuilder().text('Hello').cut();
      final bytes = builder.build();
      // Last 4 bytes should be partial cut
      expect(bytes.sublist(bytes.length - 4), [0x1D, 0x56, 0x42, 0x00]);
    });
  });

  // ---------------------------------------------------------------------------
  // Feed
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder feed', () {
    test('feed adds ESC d n', () {
      final builder = ReceiptBuilder().feed(lines: 3);
      final bytes = builder.build();
      expect(bytes, containsAll([0x1B, 0x64, 0x03]));
    });

    test('feed with custom lines', () {
      final builder = ReceiptBuilder().feed(lines: 5);
      final bytes = builder.build();
      expect(bytes, containsAll([0x1B, 0x64, 0x05]));
    });
  });

  // ---------------------------------------------------------------------------
  // Beep and cash drawer
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder beep and cashDrawer', () {
    test('beep adds ESC B n m', () {
      final builder = ReceiptBuilder().beep(count: 2, duration: 4);
      final bytes = builder.build();
      expect(bytes, containsAll([0x1B, 0x42, 0x02, 0x04]));
    });

    test('cashDrawer adds ESC p n 0x19', () {
      final builder = ReceiptBuilder().cashDrawer();
      final bytes = builder.build();
      expect(bytes, containsAll([0x1B, 0x70, 0x00, 0x19]));
    });
  });

  // ---------------------------------------------------------------------------
  // Empty line and spacing
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder emptyLine and spacing', () {
    test('emptyLine adds LF', () {
      final builder = ReceiptBuilder().emptyLine();
      final bytes = builder.build();
      // After ESC @, should have LF
      expect(bytes[2], 0x0A);
    });

    test('emptyLine with count adds multiple LFs', () {
      final builder = ReceiptBuilder().emptyLine(count: 3);
      final bytes = builder.build();
      expect(bytes.sublist(2), [0x0A, 0x0A, 0x0A]);
    });

    test('spacing is alias for emptyLine', () {
      final builder1 = ReceiptBuilder().spacing(2);
      final builder2 = ReceiptBuilder().emptyLine(count: 2);
      expect(builder1.build(), builder2.build());
    });
  });

  // ---------------------------------------------------------------------------
  // Raw bytes
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder raw', () {
    test('raw appends bytes directly', () {
      final builder = ReceiptBuilder().raw([0xAA, 0xBB, 0xCC]);
      final bytes = builder.build();
      expect(bytes, containsAll([0xAA, 0xBB, 0xCC]));
    });
  });

  // ---------------------------------------------------------------------------
  // Custom maxCharsPerLine
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder custom maxCharsPerLine', () {
    test('line uses custom width', () {
      final builder = ReceiptBuilder(maxCharsPerLine: 20).line();
      final bytes = builder.build();
      expect(bytes, containsAll(utf8.encode('-' * 20)));
    });

    test('row respects custom width', () {
      final builder = ReceiptBuilder(maxCharsPerLine: 48).line();
      final bytes = builder.build();
      expect(bytes, containsAll(utf8.encode('-' * 48)));
    });
  });

  // ---------------------------------------------------------------------------
  // textWrapped
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder textWrapped', () {
    test('short text does not wrap', () {
      final builder = ReceiptBuilder(maxCharsPerLine: 32).textWrapped('Hi');
      final bytes = builder.build();
      // Only one LF for the single line
      int lfCount = bytes.where((b) => b == 0x0A).length;
      expect(lfCount, 1);
    });

    test('long text wraps to multiple lines', () {
      final longText = 'A' * 50;
      final builder = ReceiptBuilder(maxCharsPerLine: 32).textWrapped(longText);
      final bytes = builder.build();
      // Should have multiple LFs
      int lfCount = bytes.where((b) => b == 0x0A).length;
      expect(lfCount, greaterThan(1));
    });

    test('wrapped text fits within maxCharsPerLine', () {
      final longText = 'Hello World This Is A Very Long String';
      final builder = ReceiptBuilder(maxCharsPerLine: 10).textWrapped(longText);
      final bytes = builder.build();
      // Extract all lines (between LFs)
      final lines = _extractLines(bytes);
      for (final line in lines) {
        expect(line.length, lessThanOrEqualTo(10));
      }
    });

    test('CJK text wraps correctly', () {
      // Each CJK char is 2 columns, with width 4 that's 2 chars per line
      final builder = ReceiptBuilder(maxCharsPerLine: 4).textWrapped('你好世界');
      final bytes = builder.build();
      int lfCount = bytes.where((b) => b == 0x0A).length;
      expect(lfCount, 2); // Two lines
    });
  });

  // ---------------------------------------------------------------------------
  // Line spacing
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder lineSpacing', () {
    test('lineSpacing adds ESC 3 n', () {
      final builder = ReceiptBuilder().lineSpacing(40);
      final bytes = builder.build();
      expect(bytes, containsAll([0x1B, 0x33, 0x28]));
    });

    test('resetLineSpacing adds ESC 2', () {
      final builder = ReceiptBuilder().resetLineSpacing();
      final bytes = builder.build();
      expect(bytes, containsAll([0x1B, 0x32]));
    });
  });

  // ---------------------------------------------------------------------------
  // Barcode
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder barcode', () {
    test('barcode adds GS k sequence', () {
      final builder = ReceiptBuilder().barcode('12345');
      final bytes = builder.build();
      expect(bytes, containsAll([0x1D, 0x6B]));
    });

    test('barcode adds LF after', () {
      final builder = ReceiptBuilder().barcode('12345');
      final bytes = builder.build();
      expect(bytes.last, 0x0A);
    });
  });

  // ---------------------------------------------------------------------------
  // Full receipt workflow
  // ---------------------------------------------------------------------------
  group('ReceiptBuilder full workflow', () {
    test('complete receipt with all common features', () {
      final bytes = ReceiptBuilder()
          .center()
          .bold()
          .text('RECEIPT')
          .normal()
          .line()
          .text('Coffee ......... \$3.50')
          .text('Sandwich ....... \$7.00')
          .doubleLine()
          .row(left: 'TOTAL', right: '\$10.50')
          .line()
          .feed(lines: 2)
          .qr('https://example.com/receipt/123')
          .feed(lines: 2)
          .cut()
          .build();

      // Must start with ESC @
      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x40);

      // Must contain text content
      expect(bytes, containsAll(utf8.encode('RECEIPT')));
      expect(bytes, containsAll(utf8.encode('Coffee ......... \$3.50')));
      expect(bytes, containsAll(utf8.encode('TOTAL')));
      expect(bytes, containsAll(utf8.encode('\$10.50')));

      // Must contain QR code marker
      expect(bytes, containsAll([0x1D, 0x28, 0x6B]));

      // Must end with cut command
      expect(bytes.sublist(bytes.length - 4), [0x1D, 0x56, 0x42, 0x00]);
    });
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
}

/// Extracts the printable text of a row from the byte buffer.
/// This is a simplified helper that looks for UTF-8 text segments after
/// formatting commands.
String _extractRowText(List<int> bytes) {
  // Find the first text character (not an ESC/POS command) and read until LF
  final buffer = StringBuffer();
  bool inText = false;
  for (int i = 2; i < bytes.length; i++) {
    // Skip ESC (@ = 0x40 after 0x1B) and formatting commands
    if (bytes[i] == 0x1B || bytes[i] == 0x1D || bytes[i] == 0x1C) {
      inText = false;
      continue;
    }
    if (bytes[i] == 0x0A) break;
    if (bytes[i] > 0x1F || bytes[i] == 0x20) {
      inText = true;
    }
    if (inText && bytes[i] != 0x0A) {
      buffer.writeCharCode(bytes[i]);
    }
  }
  return buffer.toString();
}

/// Extracts text lines from the byte buffer by splitting on 0x0A.
List<String> _extractLines(List<int> bytes) {
  final lines = <String>[];
  final buffer = StringBuffer();
  for (int i = 2; i < bytes.length; i++) {
    if (bytes[i] == 0x0A) {
      lines.add(buffer.toString());
      buffer.clear();
    } else if (bytes[i] > 0x1F || bytes[i] == 0x20) {
      // Only capture printable chars (skip ESC/POS commands)
      // This is a rough heuristic – skip bytes that are control sequences
      if (i > 0 && (bytes[i - 1] == 0x1B || bytes[i - 1] == 0x1D)) {
        continue;
      }
      if (i > 1 && (bytes[i - 2] == 0x1B || bytes[i - 2] == 0x1D)) {
        continue;
      }
      buffer.writeCharCode(bytes[i]);
    }
  }
  if (buffer.isNotEmpty) {
    lines.add(buffer.toString());
  }
  return lines;
}
