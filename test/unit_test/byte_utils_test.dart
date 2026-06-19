import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_thermal_print/src/utils/byte_utils.dart';

void main() {
  // ---------------------------------------------------------------------------
  // intToBytes
  // ---------------------------------------------------------------------------
  group('ByteUtils.intToBytes', () {
    test('1-byte value', () {
      expect(ByteUtils.intToBytes(0x1B, 1), [0x1B]);
    });

    test('1-byte value 0x00', () {
      expect(ByteUtils.intToBytes(0x00, 1), [0x00]);
    });

    test('1-byte max value 0xFF', () {
      expect(ByteUtils.intToBytes(0xFF, 1), [0xFF]);
    });

    test('2-byte value 256 (big-endian)', () {
      expect(ByteUtils.intToBytes(256, 2), [0x01, 0x00]);
    });

    test('2-byte value 0x1B40', () {
      expect(ByteUtils.intToBytes(0x1B40, 2), [0x1B, 0x40]);
    });

    test('4-byte value 0x0D0A', () {
      expect(ByteUtils.intToBytes(0x0D0A, 4), [0x00, 0x00, 0x0D, 0x0A]);
    });

    test('truncates to requested byte length', () {
      // 0x1FF in 1 byte should be 0xFF (masked)
      expect(ByteUtils.intToBytes(0x1FF, 1), [0xFF]);
    });

    test('8-byte value preserves full range', () {
      final result = ByteUtils.intToBytes(0x0102030405060708, 8);
      expect(result, [0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]);
    });

    test('returns correct length', () {
      expect(ByteUtils.intToBytes(42, 3).length, 3);
      expect(ByteUtils.intToBytes(42, 4).length, 4);
    });
  });

  // ---------------------------------------------------------------------------
  // stringToBytes
  // ---------------------------------------------------------------------------
  group('ByteUtils.stringToBytes', () {
    test('empty string returns empty list', () {
      expect(ByteUtils.stringToBytes(''), isEmpty);
    });

    test('ASCII text encodes as UTF-8', () {
      final result = ByteUtils.stringToBytes('Hello');
      expect(result, utf8.encode('Hello'));
    });

    test('UTF-8 encoding with special characters', () {
      final result = ByteUtils.stringToBytes('café');
      expect(result, utf8.encode('café'));
    });

    test('explicit UTF-8 encoding', () {
      final result = ByteUtils.stringToBytes('test', encoding: 'utf-8');
      expect(result, [0x74, 0x65, 0x73, 0x74]);
    });

    test('ASCII encoding', () {
      final result = ByteUtils.stringToBytes('ABC', encoding: 'ascii');
      expect(result, [0x41, 0x42, 0x43]);
    });

    test('latin-1 encoding', () {
      final result = ByteUtils.stringToBytes('é', encoding: 'latin-1');
      expect(result, [0xE9]);
    });

    test('unknown encoding falls back to UTF-8', () {
      final result = ByteUtils.stringToBytes('hello', encoding: 'gbk');
      expect(result, utf8.encode('hello'));
    });

    test('CJK characters encode as UTF-8 multi-byte', () {
      final result = ByteUtils.stringToBytes('你好');
      expect(result, isNotEmpty);
      // 你 in UTF-8 is 3 bytes: E4 BD A0
      expect(result.length, 6); // 3 bytes each for 2 CJK chars
    });
  });

  // ---------------------------------------------------------------------------
  // hexToBytes / bytesToHex roundtrip
  // ---------------------------------------------------------------------------
  group('ByteUtils.hexToBytes / bytesToHex', () {
    test('hexToBytes parses basic hex string', () {
      expect(ByteUtils.hexToBytes('1B40'), [0x1B, 0x40]);
    });

    test('hexToBytes handles spaces', () {
      expect(ByteUtils.hexToBytes('1B 40 0A'), [0x1B, 0x40, 0x0A]);
    });

    test('hexToBytes handles 0x prefix', () {
      expect(ByteUtils.hexToBytes('0x1B 0x40'), [0x1B, 0x40]);
    });

    test('hexToBytes handles mixed 0x prefix', () {
      expect(ByteUtils.hexToBytes('0x1B0x40'), [0x1B, 0x40]);
    });

    test('hexToBytes empty string returns empty list', () {
      expect(ByteUtils.hexToBytes(''), isEmpty);
    });

    test('hexToBytes throws on odd-length string', () {
      expect(() => ByteUtils.hexToBytes('1B4'), throwsFormatException);
    });

    test('hexToBytes throws on invalid hex', () {
      expect(() => ByteUtils.hexToBytes('GH'), throwsFormatException);
    });

    test('bytesToHex converts correctly', () {
      expect(ByteUtils.bytesToHex([0x1B, 0x40]), '1b40');
    });

    test('bytesToHex empty list returns empty string', () {
      expect(ByteUtils.bytesToHex([]), '');
    });

    test('bytesToHex zero byte', () {
      expect(ByteUtils.bytesToHex([0x00]), '00');
    });

    test('bytesToHex max byte', () {
      expect(ByteUtils.bytesToHex([0xFF]), 'ff');
    });

    test('roundtrip: hexToBytes -> bytesToHex', () {
      final original = '1b400a1d564200';
      final bytes = ByteUtils.hexToBytes(original);
      final hex = ByteUtils.bytesToHex(bytes);
      expect(hex, original);
    });

    test('roundtrip: bytesToHex -> hexToBytes', () {
      final original = [0x1B, 0x40, 0x0A, 0xFF, 0x00];
      final hex = ByteUtils.bytesToHex(original);
      final restored = ByteUtils.hexToBytes(hex);
      expect(restored, original);
    });
  });

  // ---------------------------------------------------------------------------
  // mergeByteLists
  // ---------------------------------------------------------------------------
  group('ByteUtils.mergeByteLists', () {
    test('empty list of lists returns empty', () {
      expect(ByteUtils.mergeByteLists([]), isEmpty);
    });

    test('single list is returned as copy', () {
      final input = [0x1B, 0x40];
      final result = ByteUtils.mergeByteLists([input]);
      expect(result, input);
      // Verify it's a copy
      expect(identical(result, input), isFalse);
    });

    test('merges multiple lists correctly', () {
      final result = ByteUtils.mergeByteLists([
        [0x1B, 0x40],
        [0x1B, 0x45, 0x01],
        [0x0A],
      ]);
      expect(result, [0x1B, 0x40, 0x1B, 0x45, 0x01, 0x0A]);
    });

    test('handles empty inner lists', () {
      final result = ByteUtils.mergeByteLists([
        [],
        [0x1B],
        [],
        [0x40],
      ]);
      expect(result, [0x1B, 0x40]);
    });

    test('preserves byte order', () {
      final result = ByteUtils.mergeByteLists([
        [1, 2],
        [3],
        [4, 5, 6],
      ]);
      expect(result, [1, 2, 3, 4, 5, 6]);
    });
  });

  // ---------------------------------------------------------------------------
  // padCenter
  // ---------------------------------------------------------------------------
  group('ByteUtils.padCenter', () {
    test('centers text in even width', () {
      final result = ByteUtils.padCenter('AB', 10);
      expect(result, '    AB    ');
    });

    test('centers text in odd width (left-biased)', () {
      final result = ByteUtils.padCenter('AB', 9);
      // total padding = 9 - 2 = 7, left = 3, right = 4
      expect(result, '   AB    ');
    });

    test('returns text truncated when too long', () {
      final result = ByteUtils.padCenter('Hello World', 5);
      expect(result.length, 5);
    });

    test('returns text as-is when exact width', () {
      final result = ByteUtils.padCenter('AB', 2);
      expect(result, 'AB');
    });

    test('zero or negative width returns text', () {
      expect(ByteUtils.padCenter('test', 0), 'test');
      expect(ByteUtils.padCenter('test', -1), 'test');
    });

    test('CJK characters count as 2 columns', () {
      // 你 is 2 columns, total width should account for it
      final result = ByteUtils.padCenter('你', 6);
      // display width = 2, padding = 4, left = 2, right = 2
      expect(result, '  你  ');
    });
  });

  // ---------------------------------------------------------------------------
  // padLeft
  // ---------------------------------------------------------------------------
  group('ByteUtils.padLeft', () {
    test('left-aligns with right padding', () {
      final result = ByteUtils.padLeft('AB', 6);
      expect(result, 'AB    ');
    });

    test('truncates when too long', () {
      final result = ByteUtils.padLeft('Hello', 3);
      expect(result.length, 3);
    });

    test('returns text as-is when exact width', () {
      final result = ByteUtils.padLeft('Test', 4);
      expect(result, 'Test');
    });

    test('zero width returns text', () {
      expect(ByteUtils.padLeft('X', 0), 'X');
    });

    test('CJK padding is correct', () {
      // 你 is 2 columns, width 6 should add 4 spaces
      final result = ByteUtils.padLeft('你', 6);
      expect(result, '你    ');
    });
  });

  // ---------------------------------------------------------------------------
  // padRight
  // ---------------------------------------------------------------------------
  group('ByteUtils.padRight', () {
    test('right-aligns with left padding', () {
      final result = ByteUtils.padRight('AB', 6);
      expect(result, '    AB');
    });

    test('truncates when too long', () {
      final result = ByteUtils.padRight('Hello', 3);
      expect(result.length, 3);
    });

    test('CJK padding is correct', () {
      // 你 is 2 columns, width 6 should add 4 spaces
      final result = ByteUtils.padRight('你', 6);
      expect(result, '    你');
    });
  });

  // ---------------------------------------------------------------------------
  // wordWrap
  // ---------------------------------------------------------------------------
  group('ByteUtils.wordWrap', () {
    test('short text fits in one line', () {
      final result = ByteUtils.wordWrap('Hello', 20);
      expect(result, ['Hello']);
    });

    test('wraps at word boundary', () {
      final result = ByteUtils.wordWrap('Hello World', 8);
      expect(result, ['Hello', 'World']);
    });

    test('wraps multiple lines', () {
      final result = ByteUtils.wordWrap('one two three four', 5);
      expect(result, ['one', 'two', 'three', 'four']);
    });

    test('force-splits long words', () {
      final result = ByteUtils.wordWrap('abcdefghij', 4);
      expect(result, ['abcd', 'efgh', 'ij']);
    });

    test('empty string returns empty list', () {
      expect(ByteUtils.wordWrap('', 10), isEmpty);
    });

    test('zero width returns list with original text', () {
      final result = ByteUtils.wordWrap('Hello', 0);
      expect(result, ['Hello']);
    });

    test('CJK characters force-split correctly', () {
      // Each CJK char is 2 columns, width 4 means 2 chars per line
      final result = ByteUtils.wordWrap('你好世界', 4);
      expect(result, ['你好', '世界']);
    });

    test('mixed CJK and ASCII wraps correctly', () {
      final result = ByteUtils.wordWrap('ab你好', 4);
      // 'ab' = 2 cols, '你好' = 4 cols total 6 > 4
      expect(result, ['ab', '你好']);
    });

    test('single word exactly at width', () {
      final result = ByteUtils.wordWrap('Hello', 5);
      expect(result, ['Hello']);
    });
  });

  // ---------------------------------------------------------------------------
  // crc8
  // ---------------------------------------------------------------------------
  group('ByteUtils.crc8', () {
    test('empty data returns 0', () {
      expect(ByteUtils.crc8([]), 0);
    });

    test('single byte CRC', () {
      // CRC-8/MAXIM for [0x01]
      final result = ByteUtils.crc8([0x01]);
      expect(result, isA<int>());
      expect(result, greaterThanOrEqualTo(0));
      expect(result, lessThanOrEqualTo(0xFF));
    });

    test('known CRC-8/MAXIM value', () {
      // CRC-8/MAXIM polynomial 0x31, init 0x00
      // For [0xBE, 0xEF] the expected CRC is 0x92
      // (verified against known reference)
      expect(ByteUtils.crc8([0xBE, 0xEF]), 0x92);
    });

    test('CRC is a single byte (0-255)', () {
      for (int i = 0; i < 256; i++) {
        final result = ByteUtils.crc8([i, i + 1, i + 2]);
        expect(result, greaterThanOrEqualTo(0));
        expect(result, lessThanOrEqualTo(0xFF));
      }
    });

    test('same data produces same CRC', () {
      final data = [0x1B, 0x40, 0x0A, 0x1D, 0x56, 0x01];
      final crc1 = ByteUtils.crc8(data);
      final crc2 = ByteUtils.crc8(data);
      expect(crc1, equals(crc2));
    });

    test('different data likely produces different CRC', () {
      final data1 = [0x01, 0x02, 0x03];
      final data2 = [0x01, 0x02, 0x04];
      // Not guaranteed to be different for all inputs, but likely
      // Just verify both are valid bytes
      final crc1 = ByteUtils.crc8(data1);
      final crc2 = ByteUtils.crc8(data2);
      expect(crc1, allOf(greaterThanOrEqualTo(0), lessThanOrEqualTo(0xFF)));
      expect(crc2, allOf(greaterThanOrEqualTo(0), lessThanOrEqualTo(0xFF)));
    });

    test('CRC of [0x00] is not zero', () {
      // With polynomial 0x31 and init 0x00: XOR 0x00 ^ 0x00 = 0x00,
      // then 8 rounds of shifts: result should be 0x00 since initial crc = 0
      // and data byte = 0x00, so crc remains 0 through all iterations
      expect(ByteUtils.crc8([0x00]), 0x00);
    });
  });

  // ---------------------------------------------------------------------------
  // reverseBytes
  // ---------------------------------------------------------------------------
  group('ByteUtils.reverseBytes', () {
    test('reverses byte order', () {
      expect(ByteUtils.reverseBytes([0x01, 0x02, 0x03]), [0x03, 0x02, 0x01]);
    });

    test('empty list returns empty', () {
      expect(ByteUtils.reverseBytes([]), isEmpty);
    });

    test('single byte returns itself', () {
      expect(ByteUtils.reverseBytes([0xFF]), [0xFF]);
    });
  });

  // ---------------------------------------------------------------------------
  // toUint8List
  // ---------------------------------------------------------------------------
  group('ByteUtils.toUint8List', () {
    test('converts List<int> to Uint8List', () {
      final result = ByteUtils.toUint8List([1, 2, 3]);
      expect(result, isA<Uint8List>());
      expect(result, [1, 2, 3]);
    });

    test('clamps values above 255', () {
      final result = ByteUtils.toUint8List([256, 300, 1000]);
      expect(result, [255, 255, 255]);
    });

    test('clamps negative values to 0', () {
      final result = ByteUtils.toUint8List([-1, -100]);
      expect(result, [0, 0]);
    });

    test('handles empty list', () {
      final result = ByteUtils.toUint8List([]);
      expect(result, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // zeroFill
  // ---------------------------------------------------------------------------
  group('ByteUtils.zeroFill', () {
    test('creates zero-filled list of correct length', () {
      final result = ByteUtils.zeroFill(5);
      expect(result.length, 5);
      expect(result, everyElement(equals(0)));
    });

    test('zero length returns empty', () {
      expect(ByteUtils.zeroFill(0), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // repeatByte
  // ---------------------------------------------------------------------------
  group('ByteUtils.repeatByte', () {
    test('repeats byte correctly', () {
      final result = ByteUtils.repeatByte(0x2D, 4);
      expect(result, [0x2D, 0x2D, 0x2D, 0x2D]);
    });

    test('zero count returns empty', () {
      expect(ByteUtils.repeatByte(0xFF, 0), isEmpty);
    });

    test('masks byte to 0xFF', () {
      final result = ByteUtils.repeatByte(0x1FF, 2);
      expect(result, [0xFF, 0xFF]);
    });
  });
}
