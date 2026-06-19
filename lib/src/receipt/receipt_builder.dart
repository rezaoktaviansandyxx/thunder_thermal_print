import 'dart:typed_data';
import '../escpos/escpos_commands.dart';

/// Horizontal alignment for receipt text.
enum ReceiptAlign { left, center, right }

/// A fluent API for building ESC/POS receipt print jobs.
///
/// Usage:
/// ```dart
/// final bytes = ReceiptBuilder(maxCharsPerLine: 32)
///     .center()
///     .bold()
///     .text('MY STORE')
///     .normal()
///     .line()
///     .row(left: 'Subtotal', right: '\$12.50')
///     .doubleLine()
///     .row(left: 'TOTAL', right: '\$12.50')
///     .feed(lines: 3)
///     .cut()
///     .buildAsUint8List();
/// ```
class ReceiptBuilder {
  final List<int> _buffer = [];

  int _currentAlign = 0; // 0=left, 1=center, 2=right
  bool _bold = false;
  bool _underline = false;
  bool _doubleWidth = false;
  bool _doubleHeight = false;
  bool _inverse = false;
  int _fontSize = 0; // 0 = Font A, 1 = Font B
  int _maxCharsPerLine;

  /// Create a new [ReceiptBuilder].
  ///
  /// [maxCharsPerLine] is the number of monospaced characters that fit
  /// on one line at normal width. Defaults to 32 (typical 58 mm paper
  /// with 8-dot font). For 80 mm paper use 48.
  ReceiptBuilder({int maxCharsPerLine = 32})
      : _maxCharsPerLine = maxCharsPerLine;

  // ── Alignment ───────────────────────────────────────────────────

  /// Set text alignment to centre.
  ReceiptBuilder center() {
    _currentAlign = 1;
    _buffer.addAll(EscPosCommands.alignCenter());
    return this;
  }

  /// Set text alignment to left.
  ReceiptBuilder left() {
    _currentAlign = 0;
    _buffer.addAll(EscPosCommands.alignLeft());
    return this;
  }

  /// Set text alignment to right.
  ReceiptBuilder right() {
    _currentAlign = 2;
    _buffer.addAll(EscPosCommands.alignRight());
    return this;
  }

  // ── Text style ──────────────────────────────────────────────────

  /// Enable bold (emphasized) mode.
  ReceiptBuilder bold() {
    _bold = true;
    _buffer.addAll(EscPosCommands.enableBold());
    return this;
  }

  /// Reset all formatting to default (no bold, no underline, normal size,
  /// font A, left-aligned).
  ReceiptBuilder normal() {
    _resetFormatting();
    _buffer.addAll(EscPosCommands.alignLeft());
    return this;
  }

  /// Enable underline (1-dot).
  ReceiptBuilder underline() {
    _underline = true;
    _buffer.addAll(EscPosCommands.enableUnderline());
    return this;
  }

  /// Enable double-width mode.
  ReceiptBuilder doubleWidth() {
    _doubleWidth = true;
    _applyTextSize();
    return this;
  }

  /// Enable double-height mode.
  ReceiptBuilder doubleHeight() {
    _doubleHeight = true;
    _applyTextSize();
    return this;
  }

  /// Enable both double-width and double-height.
  ReceiptBuilder doubleSize() {
    _doubleWidth = true;
    _doubleHeight = true;
    _applyTextSize();
    return this;
  }

  /// Select Font A (the default, wider font on many printers).
  ReceiptBuilder fontA() {
    _fontSize = 0;
    _buffer.addAll(EscPosCommands.setFontA());
    return this;
  }

  /// Select Font B (the narrower font on many printers).
  ReceiptBuilder fontB() {
    _fontSize = 1;
    _buffer.addAll(EscPosCommands.setFontB());
    return this;
  }

  /// Enable inverse (white-on-black) printing.
  ReceiptBuilder inverse() {
    _inverse = true;
    _buffer.addAll(EscPosCommands.enableInverse());
    return this;
  }

  // ── Line spacing ────────────────────────────────────────────────

  /// Set the line spacing to [spacing] dots (typically 20-255).
  ReceiptBuilder lineSpacing(int spacing) {
    _buffer.addAll(EscPosCommands.setLineSpacing(spacing));
    return this;
  }

  /// Reset line spacing to the printer default.
  ReceiptBuilder resetLineSpacing() {
    _buffer.addAll(EscPosCommands.resetLineSpacing());
    return this;
  }

  // ── Content ─────────────────────────────────────────────────────

  /// Print [text] with the current formatting.
  ///
  /// A newline (`\n`) is automatically appended.
  ReceiptBuilder text(String text) {
    _applyFormatting();
    _buffer.addAll(EscPosCommands.printText(text));
    _buffer.add(0x0A); // LF
    return this;
  }

  /// Print [text] with automatic word-wrapping at [_maxCharsPerLine]
  /// columns (adjusted for double-width). CJK characters count as
  /// 2 columns each.
  ReceiptBuilder textWrapped(String text) {
    _applyFormatting();
    final effectiveWidth = _doubleWidth
        ? (_maxCharsPerLine ~/ 2)
        : _maxCharsPerLine;
    final lines = _wrapText(text, effectiveWidth);
    for (final line in lines) {
      _buffer.addAll(EscPosCommands.printText(line));
      _buffer.add(0x0A); // LF
    }
    return this;
  }

  /// Print [count] empty lines.
  ReceiptBuilder emptyLine({int count = 1}) {
    for (int i = 0; i < count; i++) {
      _buffer.add(0x0A); // LF
    }
    return this;
  }

  /// Print a separator line made of [char], spanning the full
  /// [_maxCharsPerLine] (or [width] if specified).
  ReceiptBuilder line({String char = '-', int? width}) {
    final effectiveWidth = width ??
        (_doubleWidth ? (_maxCharsPerLine ~/ 2) : _maxCharsPerLine);
    _applyFormatting();
    final separator = char * effectiveWidth;
    _buffer.addAll(EscPosCommands.printText(separator));
    _buffer.add(0x0A);
    return this;
  }

  /// Print a double-line separator (`=`).
  ReceiptBuilder doubleLine({int? width}) {
    return line(char: '=', width: width);
  }

  /// Print a two-column row: [left] text left-aligned and [right]
  /// text right-aligned, separated by spaces.
  ///
  /// CJK-aware: CJK characters occupy 2 columns.
  ReceiptBuilder row({required String left, required String right}) {
    _applyFormatting();
    final effectiveWidth = _doubleWidth
        ? (_maxCharsPerLine ~/ 2)
        : _maxCharsPerLine;

    final leftColumns = _columnWidth(left);
    final rightColumns = _columnWidth(right);
    final spaces = (effectiveWidth - leftColumns - rightColumns)
        .clamp(0, effectiveWidth);
    final rowText = '$left${' ' * spaces}$right';
    _buffer.addAll(EscPosCommands.printText(rowText));
    _buffer.add(0x0A);
    return this;
  }

  /// Print a three-column row.
  ///
  /// [col1] and [col3] are padded to their respective widths; [col2]
  /// is placed in the middle with any remaining space distributed
  /// as padding.
  ///
  /// CJK-aware character width calculation is applied to all columns.
  ReceiptBuilder row3({
    required String col1,
    required String col2,
    required String col3,
    int col1Width = 10,
    int col3Width = 10,
  }) {
    _applyFormatting();
    final effectiveWidth = _doubleWidth
        ? (_maxCharsPerLine ~/ 2)
        : _maxCharsPerLine;

    // Adjust column widths for double-width
    final adjCol1 = _doubleWidth ? (col1Width ~/ 2) : col1Width;
    final adjCol3 = _doubleWidth ? (col3Width ~/ 2) : col3Width;

    final col1Columns = _columnWidth(col1);
    final col3Columns = _columnWidth(col3);
    final col2Columns = _columnWidth(col2);

    // Pad col1
    final col1Spaces = (adjCol1 - col1Columns).clamp(0, adjCol1);
    final col1Padded = col1 + ' ' * col1Spaces;

    // Pad col3
    final col3Spaces = (adjCol3 - col3Columns).clamp(0, adjCol3);
    final col3Padded = ' ' * col3Spaces + col3;

    // Middle space for col2
    final middleTotal =
        effectiveWidth - adjCol1 - adjCol3 - col2Columns;
    final middleSpace = middleTotal.clamp(1, effectiveWidth);
    final col2Padded = ' ' * middleSpace + col2;

    final rowText = col1Padded + col2Padded + col3Padded;
    _buffer.addAll(EscPosCommands.printText(rowText));
    _buffer.add(0x0A);
    return this;
  }

  /// Print a QR code containing [data].
  ReceiptBuilder qr(String data, {int size = 6}) {
    _buffer.addAll(EscPosCommands.printQrCode(data, size: size));
    _buffer.add(0x0A);
    return this;
  }

  /// Print a barcode.
  ReceiptBuilder barcode(
    String data, {
    BarcodeType type = BarcodeType.code128,
  }) {
    _buffer.addAll(EscPosCommands.printBarcode(data, type: type));
    _buffer.add(0x0A);
    return this;
  }

  /// Feed [lines] lines of paper.
  ReceiptBuilder feed({int lines = 3}) {
    _buffer.addAll(EscPosCommands.feedLines(lines));
    return this;
  }

  /// Cut the paper.
  ///
  /// [partial] = true  → partial cut (faster, leaves a small tab).
  /// [partial] = false → full cut.
  ReceiptBuilder cut({bool partial = true}) {
    if (partial) {
      _buffer.addAll(EscPosCommands.partialCut());
    } else {
      _buffer.addAll(EscPosCommands.fullCut());
    }
    return this;
  }

  /// Sound the printer buzzer.
  ReceiptBuilder beep({int count = 1, int duration = 3}) {
    _buffer.addAll(EscPosCommands.beep(count: count, duration: duration));
    return this;
  }

  /// Pulse the cash drawer solenoid on pin [pin].
  ReceiptBuilder cashDrawer({int pin = 0}) {
    _buffer.addAll(EscPosCommands.openCashDrawer(pin: pin));
    return this;
  }

  /// Print an image from raw bytes (PNG/JPEG).
  ///
  /// [maxWidth] defaults to the printer's paper width in dots.
  /// For 58 mm paper this is typically 384; for 80 mm paper, 576.
  ReceiptBuilder image(Uint8List imageBytes, {int? maxWidth}) {
    final effectiveWidth = maxWidth ?? (_maxCharsPerLine * 8);
    _buffer
        .addAll(EscPosCommands.printImageFromBytes(imageBytes, effectiveWidth));
    _buffer.add(0x0A);
    return this;
  }

  /// Append raw ESC/POS bytes directly to the buffer.
  ReceiptBuilder raw(List<int> bytes) {
    _buffer.addAll(bytes);
    return this;
  }

  /// Alias for [emptyLine] – adds [lines] blank lines.
  ReceiptBuilder spacing(int lines) {
    return emptyLine(count: lines);
  }

  // ── Build ───────────────────────────────────────────────────────

  /// Build and return the complete byte buffer.
  ///
  /// An [EscPosCommands.initialize] command is automatically prepended
  /// to ensure the printer is in a known state.
  List<int> build() {
    return [
      ...EscPosCommands.initialize(),
      ..._buffer,
    ];
  }

  /// Build and return the complete byte buffer as a [Uint8List].
  Uint8List buildAsUint8List() {
    return Uint8List.fromList(build());
  }

  // ── Internal helpers ────────────────────────────────────────────

  /// Apply all current formatting state to the buffer.
  ///
  /// This is called before any text-printing method to ensure the
  /// printer is in the correct state.
  void _applyFormatting() {
    // Alignment
    switch (_currentAlign) {
      case 0:
        _buffer.addAll(EscPosCommands.alignLeft());
        break;
      case 1:
        _buffer.addAll(EscPosCommands.alignCenter());
        break;
      case 2:
        _buffer.addAll(EscPosCommands.alignRight());
        break;
    }

    // Bold
    if (_bold) {
      _buffer.addAll(EscPosCommands.enableBold());
    } else {
      _buffer.addAll(EscPosCommands.disableBold());
    }

    // Underline
    if (_underline) {
      _buffer.addAll(EscPosCommands.enableUnderline());
    } else {
      _buffer.addAll(EscPosCommands.disableUnderline());
    }

    // Inverse
    if (_inverse) {
      _buffer.addAll(EscPosCommands.enableInverse());
    } else {
      _buffer.addAll(EscPosCommands.disableInverse());
    }

    // Font
    if (_fontSize == 0) {
      _buffer.addAll(EscPosCommands.setFontA());
    } else {
      _buffer.addAll(EscPosCommands.setFontB());
    }

    // Text size
    _applyTextSize();
  }

  /// Send the GS ! command based on current _doubleWidth and
  /// _doubleHeight state.
  void _applyTextSize() {
    if (_doubleWidth && _doubleHeight) {
      _buffer.addAll(EscPosCommands.enableDoubleWidthAndHeight());
    } else if (_doubleWidth) {
      _buffer.addAll(EscPosCommands.enableDoubleWidth());
    } else if (_doubleHeight) {
      _buffer.addAll(EscPosCommands.enableDoubleHeight());
    } else {
      _buffer.addAll(EscPosCommands.disableDoubleMode());
    }
  }

  /// Reset all formatting state to defaults.
  void _resetFormatting() {
    _currentAlign = 0;
    _bold = false;
    _underline = false;
    _doubleWidth = false;
    _doubleHeight = false;
    _inverse = false;
    _fontSize = 0;

    _buffer.addAll(EscPosCommands.disableBold());
    _buffer.addAll(EscPosCommands.disableUnderline());
    _buffer.addAll(EscPosCommands.disableInverse());
    _buffer.addAll(EscPosCommands.disableDoubleMode());
    _buffer.addAll(EscPosCommands.setFontA());
  }

  /// Calculate the display column width of [text], where CJK characters
  /// count as 2 columns and all other characters count as 1.
  static int _columnWidth(String text) {
    int width = 0;
    for (int i = 0; i < text.length; i++) {
      final codeUnit = text.codeUnitAt(i);
      if (_isCJK(codeUnit)) {
        width += 2;
      } else {
        width += 1;
      }
    }
    return width;
  }

  /// Returns `true` if the Unicode code point is a CJK character.
  ///
  /// Covers:
  /// - CJK Unified Ideographs (4E00–9FFF, 3400–4DBF, 20000–2A6DF)
  /// - CJK Compatibility Ideographs (F900–FAFF)
  /// - CJK Unified Ideographs Extension A-B
  /// - Hiragana (3040–309F)
  /// - Katakana (30A0–30FF)
  /// - Hangul Syllables (AC00–D7AF)
  /// - Fullwidth Forms (FF01–FF60,FFE0–FFE6)
  static bool _isCJK(int codeUnit) {
    // CJK Unified Ideographs
    if (codeUnit >= 0x4E00 && codeUnit <= 0x9FFF) return true;
    // CJK Unified Ideographs Extension A
    if (codeUnit >= 0x3400 && codeUnit <= 0x4DBF) return true;
    // CJK Compatibility Ideographs
    if (codeUnit >= 0xF900 && codeUnit <= 0xFAFF) return true;
    // Hiragana
    if (codeUnit >= 0x3040 && codeUnit <= 0x309F) return true;
    // Katakana
    if (codeUnit >= 0x30A0 && codeUnit <= 0x30FF) return true;
    // Hangul Syllables
    if (codeUnit >= 0xAC00 && codeUnit <= 0xD7AF) return true;
    // CJK Radicals Supplement
    if (codeUnit >= 0x2E80 && codeUnit <= 0x2EFF) return true;
    // Kangxi Radicals
    if (codeUnit >= 0x2F00 && codeUnit <= 0x2FDF) return true;
    // Ideographic Description Characters
    if (codeUnit >= 0x2FF0 && codeUnit <= 0x2FFF) return true;
    // CJK Symbols and Punctuation
    if (codeUnit >= 0x3000 && codeUnit <= 0x303F) return true;
    // Fullwidth Forms (common CJK punctuation and digits)
    if (codeUnit >= 0xFF01 && codeUnit <= 0xFF60) return true;
    if (codeUnit >= 0xFFE0 && codeUnit <= 0xFFE6) return true;
    // CJK Unified Ideographs Extension B (supplementary plane – surrogate pair)
    // Note: in Dart strings, supplementary characters are represented as
    // surrogate pairs. We check the high surrogate range here.
    if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) return true;
    // Common CJK punctuation used in Chinese/Japanese/Korean text
    if (codeUnit == 0x3001 || codeUnit == 0x3002) return true; // 、。
    if (codeUnit == 0xFF08 || codeUnit == 0xFF09) return true; // （）
    if (codeUnit == 0xFF0C || codeUnit == 0xFF0E) return true; // ，．
    if (codeUnit == 0x2018 || codeUnit == 0x2019) return true; // ''
    if (codeUnit == 0x201C || codeUnit == 0x201D) return true; // ""
    if (codeUnit == 0x300A || codeUnit == 0x300B) return true; // 《》
    if (codeUnit == 0x3008 || codeUnit == 0x3009) return true; // 〈〉

    return false;
  }

  /// Word-wrap [text] to fit within [maxColumns].
  ///
  /// CJK characters count as 2 columns. Words are wrapped at space
  /// boundaries when possible; long words that exceed the line width
  /// are broken mid-word.
  static List<String> _wrapText(String text, int maxColumns) {
    if (maxColumns <= 0) return [text];
    if (text.isEmpty) return [''];

    final List<String> lines = [];
    final buffer = StringBuffer();
    int currentColumns = 0;

    int i = 0;
    while (i < text.length) {
      final codeUnit = text.codeUnitAt(i);
      final charWidth = _isCJK(codeUnit) ? 2 : 1;
      final char = text[i];

      // Handle line breaks in the input
      if (char == '\n') {
        lines.add(buffer.toString());
        buffer.clear();
        currentColumns = 0;
        i++;
        continue;
      }

      // Check if adding this character would overflow
      if (currentColumns + charWidth > maxColumns) {
        // For CJK characters, always break before the character
        if (_isCJK(codeUnit)) {
          lines.add(buffer.toString());
          buffer.clear();
          buffer.write(char);
          currentColumns = charWidth;
          i++;
          continue;
        }

        // For non-CJK: try to find a word break point in the buffer
        final bufferStr = buffer.toString();
        final lastSpace = bufferStr.lastIndexOf(' ');

        if (lastSpace > 0) {
          // Break at the last space
          final before = bufferStr.substring(0, lastSpace);
          final after = bufferStr.substring(lastSpace + 1);
          lines.add(before);
          buffer.clear();
          buffer.write(after);
          buffer.write(char);
          currentColumns = _columnWidth(after) + charWidth;
        } else {
          // No space found – break mid-word
          lines.add(bufferStr);
          buffer.clear();
          buffer.write(char);
          currentColumns = charWidth;
        }
        i++;
        continue;
      }

      buffer.write(char);
      currentColumns += charWidth;
      i++;
    }

    // Flush remaining buffer
    if (buffer.isNotEmpty) {
      lines.add(buffer.toString());
    }

    return lines.isEmpty ? [''] : lines;
  }
}