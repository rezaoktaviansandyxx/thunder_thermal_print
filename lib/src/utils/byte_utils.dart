import 'dart:convert';
import 'dart:typed_data';

/// Utility class for byte-level operations common in ESC/POS thermal printing.
///
/// Provides helpers for encoding text, converting between hex strings and
/// byte arrays, CRC calculations, and receipt text padding.
class ByteUtils {
  ByteUtils._();

  /// Converts an integer to a list of bytes with the specified byte length.
  ///
  /// Uses big-endian byte order by default. The [value] is truncated to fit
  /// within [length] bytes (max 8 bytes / 64-bit).
  ///
  /// Example:
  /// ```dart
  /// ByteUtils.intToBytes(0x1B, 1); // [0x1B]
  /// ByteUtils.intToBytes(256, 2);  // [0x01, 0x00]
  /// ```
  static List<int> intToBytes(int value, int length) {
    assert(length >= 1 && length <= 8, 'Length must be between 1 and 8');

    final result = <int>[];
    // Mask the value to the requested number of bytes.
    int masked = value;
    if (length < 8) {
      masked = value & ((1 << (length * 8)) - 1);
    }

    for (int i = length - 1; i >= 0; i--) {
      result.add((masked >> (i * 8)) & 0xFF);
    }

    return result;
  }

  /// Encodes a string into a byte list using the specified character encoding.
  ///
  /// Defaults to UTF-8. For GBK encoding on platforms that support it,
  /// pass [encoding] as `'gbk'`. Falls back to UTF-8 if the encoding is
  /// not supported.
  ///
  /// Returns an empty list if [text] is empty.
  static List<int> stringToBytes(String text, {String encoding = 'utf-8'}) {
    if (text.isEmpty) return [];

    try {
      switch (encoding.toLowerCase()) {
        case 'utf-8':
        case 'utf8':
          return List<int>.from(utf8.encode(text));
        case 'ascii':
          return List<int>.from(ascii.encode(text));
        case 'latin-1':
        case 'latin1':
          return List<int>.from(latin1.encode(text));
        default:
          // For encodings not natively supported by dart:convert (e.g., GBK),
          // fall back to UTF-8. Platform-specific implementations should
          // override this in the native layer for full encoding support.
          return List<int>.from(utf8.encode(text));
      }
    } catch (_) {
      // Last resort: encode as UTF-8 and replace unencodable characters.
      return List<int>.from(utf8.encode(text));
    }
  }

  /// Computes the CRC-8 checksum of a byte array.
  ///
  /// Uses the CRC-8/MAXIM polynomial (0x31, init 0x00, no reflection).
  /// This is commonly used in thermal printer communication protocols
  /// for data integrity verification.
  ///
  /// Returns 0 for an empty [data] list.
  static int crc8(List<int> data) {
    if (data.isEmpty) return 0;

    const int polynomial = 0x31; // CRC-8/MAXIM
    int crc = 0x00;

    for (final byte in data) {
      crc ^= byte & 0xFF;
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x80) != 0) {
          crc = ((crc << 1) ^ polynomial) & 0xFF;
        } else {
          crc = (crc << 1) & 0xFF;
        }
      }
    }

    return crc & 0xFF;
  }

  /// Converts a hexadecimal string to a list of bytes.
  ///
  /// Handles strings with or without '0x' prefix, and with or without
  /// whitespace separators. Characters that are not valid hex digits
  /// or whitespace are ignored.
  ///
  /// Throws [FormatException] if the cleaned hex string has an odd length
  /// or contains no valid hex digits.
  ///
  /// Example:
  /// ```dart
  /// ByteUtils.hexToBytes('1B 40');     // [0x1B, 0x40]
  /// ByteUtils.hexToBytes('0x1B0x40'); // [0x1B, 0x40]
  /// ```
  static List<int> hexToBytes(String hex) {
    // Remove '0x' prefixes and whitespace.
    final cleaned = hex
        .replaceAll(RegExp(r'0x', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), '');

    if (cleaned.isEmpty) return [];

    if (cleaned.length % 2 != 0) {
      throw FormatException(
        'Hex string must have an even number of characters: "$hex"',
      );
    }

    final result = <int>[];
    for (int i = 0; i < cleaned.length; i += 2) {
      final hexByte = cleaned.substring(i, i + 2);
      final byte = int.tryParse(hexByte, radix: 16);
      if (byte == null || byte < 0 || byte > 0xFF) {
        throw FormatException(
          'Invalid hex byte at position $i: "$hexByte"',
        );
      }
      result.add(byte);
    }

    return result;
  }

  /// Converts a list of bytes to a lowercase hexadecimal string.
  ///
  /// Bytes are formatted as two-digit hex values with no separators.
  ///
  /// Example:
  /// ```dart
  /// ByteUtils.bytesToHex([0x1B, 0x40]); // '1b40'
  /// ```
  static String bytesToHex(List<int> bytes) {
    if (bytes.isEmpty) return '';

    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }

    return buffer.toString();
  }

  /// Merges multiple byte lists into a single contiguous byte list.
  ///
  /// This is a common operation when building ESC/POS command sequences
  /// from multiple fragments. The returned list is a new allocation;
  /// the original lists are not modified.
  ///
  /// Example:
  /// ```dart
  /// ByteUtils.mergeByteLists([
  ///   [0x1B, 0x40],  // ESC @ (initialize)
  ///   [0x1B, 0x45, 0x01],  // ESC E 1 (bold on)
  /// ]); // [0x1B, 0x40, 0x1B, 0x45, 0x01]
  /// ```
  static List<int> mergeByteLists(List<List<int>> lists) {
    if (lists.isEmpty) return [];
    if (lists.length == 1) return List<int>.from(lists.first);

    final totalLength = lists.fold<int>(0, (sum, list) => sum + list.length);
    final result = List<int>.filled(totalLength, 0);

    int offset = 0;
    for (final list in lists) {
      if (list.isEmpty) continue;
      result.setRange(offset, offset + list.length, list);
      offset += list.length;
    }

    return result;
  }

  /// Centers text within the given [width] using space padding on both sides.
  ///
  /// If [text] is longer than [width], it is returned truncated.
  /// CJK (double-width) characters are counted as two columns to ensure
  /// proper alignment on thermal printers.
  ///
  /// Example:
  /// ```dart
  /// ByteUtils.padCenter('Total', 20); // '       Total        '
  /// ```
  static String padCenter(String text, int width) {
    if (width <= 0) return text;
    final displayWidth = _stringDisplayWidth(text);

    if (displayWidth >= width) {
      return _truncateToWidth(text, width);
    }

    final totalPadding = width - displayWidth;
    final leftPadding = totalPadding ~/ 2;
    final rightPadding = totalPadding - leftPadding;

    return '${' ' * leftPadding}$text${' ' * rightPadding}';
  }

  /// Left-aligns text within the given [width] using space padding on the right.
  ///
  /// If [text] is longer than [width], it is returned truncated.
  /// CJK (double-width) characters are counted as two columns.
  ///
  /// Example:
  /// ```dart
  /// ByteUtils.padLeft('Cola', 20); // 'Cola                '
  /// ```
  static String padLeft(String text, int width) {
    if (width <= 0) return text;
    final displayWidth = _stringDisplayWidth(text);

    if (displayWidth >= width) {
      return _truncateToWidth(text, width);
    }

    return '$text${' ' * (width - displayWidth)}';
  }

  /// Right-aligns text within the given [width] using space padding on the left.
  ///
  /// If [text] is longer than [width], it is returned truncated.
  /// CJK (double-width) characters are counted as two columns.
  ///
  /// Example:
  /// ```dart
  /// ByteUtils.padRight('5.00', 20); // '                5.00'
  /// ```
  static String padRight(String text, int width) {
    if (width <= 0) return text;
    final displayWidth = _stringDisplayWidth(text);

    if (displayWidth >= width) {
      return _truncateToWidth(text, width);
    }

    return '${' ' * (width - displayWidth)}$text';
  }

  /// Truncates text to fit within the given display [width].
  ///
  /// Respects CJK double-width characters and does not split a double-width
  /// character in half — the character is dropped entirely if it would
  /// overflow.
  static String _truncateToWidth(String text, int width) {
    if (text.isEmpty) return text;

    final buffer = StringBuffer();
    int currentWidth = 0;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final charWidth = _charDisplayWidth(char);

      if (currentWidth + charWidth > width) {
        break;
      }

      buffer.write(char);
      currentWidth += charWidth;
    }

    return buffer.toString();
  }

  /// Returns the display column width of a single character.
  ///
  /// CJK characters (Unicode ranges for CJK Unified Ideographs, Hiragana,
  /// Katakana, Hangul Syllables, Full-width Forms, etc.) count as 2 columns.
  /// All other characters count as 1 column.
  static int _charDisplayWidth(String char) {
    if (char.isEmpty) return 0;
    final codeUnit = char.codeUnitAt(0);

    // CJK Unified Ideographs: U+4E00–U+9FFF
    // CJK Extension A: U+3400–U+4DBF
    // CJK Extension B: U+20000–U+2A6DF (surrogate pairs)
    // Hiragana: U+3040–U+309F
    // Katakana: U+30A0–U+30FF
    // Hangul Syllables: U+AC00–U+D7AF
    // Full-width Forms: U+FF00–U+FFEF
    // CJK Compatibility Ideographs: U+F900–U+FAFF
    // CJK Unified Ideographs Extension: various blocks
    if (char.length > 1) {
      // Surrogate pair (emoji or CJK Extension B+)
      return 2;
    }

    if ((codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) ||       // CJK Unified Ideographs
        (codeUnit >= 0x3400 && codeUnit <= 0x4DBF) ||       // CJK Extension A
        (codeUnit >= 0x3040 && codeUnit <= 0x309F) ||       // Hiragana
        (codeUnit >= 0x30A0 && codeUnit <= 0x30FF) ||       // Katakana
        (codeUnit >= 0xAC00 && codeUnit <= 0xD7AF) ||       // Hangul Syllables
        (codeUnit >= 0xFF00 && codeUnit <= 0xFFEF) ||       // Full-width Forms
        (codeUnit >= 0xF900 && codeUnit <= 0xFAFF) ||       // CJK Compatibility Ideographs
        (codeUnit >= 0x3000 && codeUnit <= 0x303F) ||       // CJK Symbols
        (codeUnit >= 0xFE30 && codeUnit <= 0xFE4F)) {       // CJK Compatibility Forms
      return 2;
    }

    return 1;
  }

  /// Returns the total display column width of a string.
  static int _stringDisplayWidth(String text) {
    int width = 0;
    for (int i = 0; i < text.length; i++) {
      width += _charDisplayWidth(text[i]);
    }
    return width;
  }

  /// Splits a string into multiple lines that fit within [width] columns.
  ///
  /// This is useful for wrapping long descriptions or addresses on receipts.
  /// Words are split at space boundaries when possible; if a single word
  /// exceeds [width], it is force-split.
  static List<String> wordWrap(String text, int width) {
    if (width <= 0 || text.isEmpty) {
      return text.isEmpty ? <String>[] : <String>[text];
    }

    final lines = <String>[];
    final words = text.split(' ');
    var currentLine = StringBuffer();

    for (final word in words) {
      final wordWidth = _stringDisplayWidth(word);
      final currentWidth = _stringDisplayWidth(currentLine.toString());

      if (currentWidth == 0) {
        // First word on the line.
        if (wordWidth <= width) {
          currentLine.write(word);
        } else {
          // Single word wider than the line — split it.
          lines.addAll(_forceSplit(word, width));
          currentLine.clear();
        }
      } else if (currentWidth + 1 + wordWidth <= width) {
        // Word fits on the current line.
        currentLine.write(' $word');
      } else {
        // Start a new line.
        lines.add(currentLine.toString());
        currentLine.clear();

        if (wordWidth <= width) {
          currentLine.write(word);
        } else {
          lines.addAll(_forceSplit(word, width));
          currentLine.clear();
        }
      }
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine.toString());
    }

    return lines.isEmpty ? <String>[] : lines;
  }

  /// Force-splits a string into chunks that each fit within [width] columns.
  static List<String> _forceSplit(String text, int width) {
    final chunks = <String>[];
    var buffer = StringBuffer();
    int currentWidth = 0;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final charWidth = _charDisplayWidth(char);

      if (currentWidth + charWidth > width) {
        chunks.add(buffer.toString());
        buffer.clear();
        currentWidth = 0;
      }

      buffer.write(char);
      currentWidth += charWidth;
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString());
    }

    return chunks;
  }

  /// Reverses the byte order of a list of bytes (endianness swap).
  ///
  /// Useful for converting between big-endian and little-endian
  /// representations of multi-byte values.
  static List<int> reverseBytes(List<int> bytes) {
    return bytes.reversed.toList();
  }

  /// Creates a Uint8List from a regular List<int>, clamping values to 0–255.
  ///
  /// Values outside the 0–255 byte range are clamped silently.
  static Uint8List toUint8List(List<int> data) {
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      final v = data[i];
      result[i] = v < 0 ? 0 : (v > 0xFF ? 0xFF : v);
    }
    return result;
  }

  /// Creates a zero-filled byte list of the specified [length].
  ///
  /// Useful for allocating buffer space in ESC/POS commands.
  static List<int> zeroFill(int length) {
    return List<int>.filled(length, 0);
  }

  /// Repeats a byte [count] times.
  ///
  /// Commonly used for generating dash/dot separator lines on receipts.
  ///
  /// Example:
  /// ```dart
  /// ByteUtils.repeatByte(0x2D, 32); // 32 dashes
  /// ```
  static List<int> repeatByte(int byte, int count) {
    return List<int>.filled(count, byte & 0xFF);
  }
}
