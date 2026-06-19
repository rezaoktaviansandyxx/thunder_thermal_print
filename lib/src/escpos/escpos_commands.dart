import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

/// ESC/POS barcode type enumeration with corresponding type codes.
enum BarcodeType {
  code128(73),
  ean13(67),
  ean8(68),
  upcA(65),
  code39(69),
  itf(70),
  codabar(72),
  pharmacode(80);

  const BarcodeType(this.code);
  final int code;
}

/// Complete ESC/POS command library.
///
/// All methods are static and return [List<int>] byte arrays ready to be
/// sent directly to a thermal printer.
///
/// Reference byte constants:
/// - ESC = 0x1B
/// - GS  = 0x1D
/// - FS  = 0x1C
class EscPosCommands {
  // ── Byte constants ──────────────────────────────────────────────
  static const int esc = 0x1B;
  static const int gs = 0x1D;
  static const int fs = 0x1C;

  // Private constructor – this class is never instantiated.
  EscPosCommands._();

  // ── Initialise / reset ──────────────────────────────────────────

  /// ESC @ (0x1B 0x40) – Initialise the printer.
  /// Resets all settings to defaults.
  static List<int> initialize() => [esc, 0x40];

  // ── Character attributes ────────────────────────────────────────

  /// ESC E 1 (0x1B 0x45 0x01) – Turn on bold / emphasized mode.
  static List<int> enableBold() => [esc, 0x45, 0x01];

  /// ESC E 0 (0x1B 0x45 0x00) – Turn off bold / emphasized mode.
  static List<int> disableBold() => [esc, 0x45, 0x00];

  /// ESC - n (0x1B 0x2D n) – Turn on underline.
  ///
  /// [mode]: 1 = 1-dot underline, 2 = 2-dot underline.
  static List<int> enableUnderline({int mode = 1}) => [esc, 0x2D, mode];

  /// ESC - 0 (0x1B 0x2D 0x00) – Turn off underline.
  static List<int> disableUnderline() => [esc, 0x2D, 0x00];

  /// GS B 1 (0x1D 0x42 0x01) – Turn on white-on-black (inverse) mode.
  static List<int> enableInverse() => [gs, 0x42, 0x01];

  /// GS B 0 (0x1D 0x42 0x00) – Turn off white-on-black (inverse) mode.
  static List<int> disableInverse() => [gs, 0x42, 0x00];

  // ── Alignment ───────────────────────────────────────────────────

  /// ESC a 0 (0x1B 0x61 0x00) – Left justification.
  static List<int> alignLeft() => [esc, 0x61, 0x00];

  /// ESC a 1 (0x1B 0x61 0x01) – Centre justification.
  static List<int> alignCenter() => [esc, 0x61, 0x01];

  /// ESC a 2 (0x1B 0x61 0x02) – Right justification.
  static List<int> alignRight() => [esc, 0x61, 0x02];

  // ── Font selection ──────────────────────────────────────────────

  /// ESC M 0 (0x1B 0x4D 0x00) – Select Font A.
  static List<int> setFontA() => [esc, 0x4D, 0x00];

  /// ESC M 1 (0x1B 0x4D 0x01) – Select Font B.
  static List<int> setFontB() => [esc, 0x4D, 0x01];

  // ── Character size (double-width / double-height) ───────────────

  /// GS ! 0x20 (0x1D 0x21 0x20) – Enable double-width only.
  static List<int> enableDoubleWidth() => [gs, 0x21, 0x20];

  /// GS ! 0x10 (0x1D 0x21 0x10) – Enable double-height only.
  static List<int> enableDoubleHeight() => [gs, 0x21, 0x10];

  /// GS ! 0x30 (0x1D 0x21 0x30) – Enable both double-width and double-height.
  static List<int> enableDoubleWidthAndHeight() => [gs, 0x21, 0x30];

  /// GS ! 0x00 (0x1D 0x21 0x00) – Disable double-width and double-height.
  static List<int> disableDoubleMode() => [gs, 0x21, 0x00];

  /// GS ! n (0x1D 0x21 n) – Set text size.
  ///
  /// [width]  – horizontal multiplier (1-8).
  /// [height] – vertical multiplier (1-8).
  ///
  /// The byte is composed as `(width - 1) * 16 + (height - 1)` in the low
  /// nibble layout: upper nibble = width-1, lower nibble = height-1.
  ///
  /// Note: some printers use the reverse convention (width in lower nibble).
  /// This implementation follows the common convention where the upper nibble
  /// controls horizontal (width) and the lower nibble controls vertical (height).
  /// Adjust if your printer differs.
  static List<int> setTextSize({int width = 1, int height = 1}) {
    final int w = (width - 1).clamp(0, 7);
    final int h = (height - 1).clamp(0, 7);
    return [gs, 0x21, (w << 4) | h];
  }

  // ── Paper feed ──────────────────────────────────────────────────

  /// ESC d n (0x1B 0x64 n) – Print and feed [count] lines.
  static List<int> feedLines(int count) => [esc, 0x64, count.clamp(0, 255)];

  /// ESC J n (0x1B 0x4A n) – Print and feed paper by [count] dots.
  static List<int> feedDots(int count) => [esc, 0x4A, count.clamp(0, 255)];

  // ── Cutting ─────────────────────────────────────────────────────

  /// GS V 66 0 (0x1D 0x56 0x42 0x00) – Partial cut (cuts part-way).
  static List<int> partialCut() => [gs, 0x56, 0x42, 0x00];

  /// GS V 1 (0x1D 0x56 0x01) – Full cut (cuts completely).
  static List<int> fullCut() => [gs, 0x56, 0x01];

  // ── Beeper / buzzer ─────────────────────────────────────────────

  /// ESC B n m (0x1B 0x42 n m) – Sound the buzzer.
  ///
  /// [count]    – number of beeps (1-9).
  /// [duration] – duration of each beep: 1=100 ms, 2=200 ms, 3=300 ms, … 9=900 ms.
  static List<int> beep({int count = 1, int duration = 3}) => [
        esc,
        0x42,
        count.clamp(1, 9),
        duration.clamp(1, 9),
      ];

  // ── Cash drawer ─────────────────────────────────────────────────

  /// ESC p n m (0x1B 0x70 n m) – Pulse the cash drawer kick-out solenoid.
  ///
  /// [pin] – drawer pin (0 or 1).
  /// Pulse time is always 200 ms (m = 0x19, 25 × 2 ms).
  static List<int> openCashDrawer({int pin = 0}) => [
        esc,
        0x70,
        pin.clamp(0, 1),
        0x19,
      ];

  // ── Line spacing ────────────────────────────────────────────────

  /// ESC 3 n (0x1B 0x33 n) – Set line spacing to [spacing] dots.
  static List<int> setLineSpacing(int spacing) =>
      [esc, 0x33, spacing.clamp(0, 255)];

  /// ESC 2 (0x1B 0x32) – Reset line spacing to default (approx. 30 dots).
  static List<int> resetLineSpacing() => [esc, 0x32];

  // ── Code page ───────────────────────────────────────────────────

  /// ESC t n (0x1B 0x74 n) – Select the character code table.
  ///
  /// Common code-page numbers:
  /// 0 = CP437 (USA), 1 = Katakana, 2 = CP850, 3 = CP860,
  /// 4 = CP863, 5 = CP865, 16 = CP1252, 19 = CP866,
  /// 21 = CP1251, 25 = CP858, 32 = Thai (TIS-620),
  /// 255 = custom / page-dependent.
  static List<int> setCodePage(int codePage) =>
      [esc, 0x74, codePage.clamp(0, 255)];

  // ── Text printing ───────────────────────────────────────────────

  /// Encode [text] using [encoding] (default `'utf-8'`) and return the
  /// raw byte array ready to be sent to the printer.
  static List<int> printText(String text, {String encoding = 'utf-8'}) {
    return encodeString(text, encoding: encoding);
  }

  /// Internal helper: encode a string to bytes, handling code-page
  /// fallback gracefully.
  static List<int> encodeString(String text, {String encoding = 'utf-8'}) {
    try {
      final encoded = Encoding.getByName(encoding);
      if (encoded != null) {
        return encoded.encode(text);
      }
    } catch (_) {
      // Fall through to UTF-8
    }
    return utf8.encode(text);
  }

  // ── QR Code printing ────────────────────────────────────────────

  /// Print a QR code using the ESC/POS GS ( k extended command set.
  ///
  /// [data]            – the text/data to encode in the QR code.
  /// [size]            – module size in dots (1-16, default 6).
  /// [errorCorrection] – error correction level:
  ///   48 = L (7%), 49 = M (15%), 50 = Q (25%), 51 = H (30%).
  static List<int> printQrCode(
    String data, {
    int size = 6,
    int errorCorrection = 48,
  }) {
    final List<int> bytes = [];

    // ── Step 1: Select the QR code model ──────────────────────────
    // GS ( k pL pH cn fn m d1...dk
    // cn = 65 (function for model selection)
    // fn = 50 (model 2)
    // m  = 0
    // d1 = 49 (model 2)
    final modelCmd = <int>[
      gs, 0x28, 0x6B, // GS ( k
      0x04, 0x00, // pL pH = 4 (parameter length)
      0x65, // cn = 65 (select model)
      0x50, // fn = 80 (specify model)
      0x31, // m = 49
      0x31, // d1 = 49 (model 2)
    ];
    bytes.addAll(modelCmd);

    // ── Step 2: Set the error correction level ────────────────────
    // GS ( k pL pH cn fn m d1...dk
    // cn = 65, fn = 69 (set error correction)
    // m = 48..51
    final ecCmd = <int>[
      gs, 0x28, 0x6B,
      0x03, 0x00, // pL pH = 3
      0x65, // cn = 65
      0x45, // fn = 69
      errorCorrection.clamp(48, 51),
    ];
    bytes.addAll(ecCmd);

    // ── Step 3: Set the module size ──────────────────────────────
    // GS ( k pL pH cn fn m d1
    // cn = 67, fn = 67, d1 = size
    final sizeCmd = <int>[
      gs, 0x28, 0x6B,
      0x03, 0x00,
      0x67, // cn = 67
      0x43, // fn = 67
      size.clamp(1, 16),
    ];
    bytes.addAll(sizeCmd);

    // ── Step 4: Store the data ───────────────────────────────────
    final dataBytes = utf8.encode(data);
    final dataLen = dataBytes.length + 3; // +3 for m, cn, fn
    final pL = dataLen & 0xFF;
    final pH = (dataLen >> 8) & 0xFF;
    final storeCmd = <int>[
      gs, 0x28, 0x6B,
      pL, pH,
      0x31, // cn = 49
      0x50, // fn = 80
      0x30, // m = 48
    ];
    bytes.addAll(storeCmd);
    bytes.addAll(dataBytes);

    // ── Step 5: Print the QR code ────────────────────────────────
    final printCmd = <int>[
      gs, 0x28, 0x6B,
      0x03, 0x00, // pL pH = 3
      0x31, // cn = 49
      0x51, // fn = 81
      0x30, // m = 48
    ];
    bytes.addAll(printCmd);

    return bytes;
  }

  // ── Barcode printing ────────────────────────────────────────────

  /// Print a barcode.
  ///
  /// [data]          – the data to encode.
  /// [type]          – barcode symbology (see [BarcodeType]).
  /// [width]         – barcode module width in dots (1-6, default 2).
  /// [height]        – barcode height in dots (1-255, default 50).
  /// [textPosition]  – 0 = not printed, 1 = below barcode, 2 = both, 3 = above.
  /// [font]          – HRI font: 'A' or 'B'.
  static List<int> printBarcode(
    String data, {
    BarcodeType type = BarcodeType.code128,
    int width = 2,
    int height = 50,
    int textPosition = 0,
    String font = 'B',
  }) {
    final List<int> bytes = [];

    // GS h n – Set barcode height
    bytes.addAll([gs, 0x68, height.clamp(1, 255)]);

    // GS H n – Set HRI character print position
    bytes.addAll([gs, 0x48, textPosition.clamp(0, 3)]);

    // GS f n – Set HRI character font (0 = A, 1 = B)
    final fontByte = font.toUpperCase() == 'A' ? 0 : 1;
    bytes.addAll([gs, 0x66, fontByte]);

    // GS w n – Set barcode module width
    bytes.addAll([gs, 0x77, width.clamp(1, 6)]);

    // GS k m n d1...dk – Print barcode
    final dataBytes = utf8.encode(data);
    final barcodeTypeCode = _barcodeTypeCode(type);

    // Format A: GS k m d1...dk NUL
    // m = type code
    bytes.add(gs);
    bytes.add(0x6B);
    bytes.add(barcodeTypeCode);
    bytes.addAll(dataBytes);
    bytes.add(0x00); // NUL terminator

    return bytes;
  }

  /// Returns the correct ESC/POS barcode type code byte.
  ///
  /// For types that use the "function B" format (CODE128, CODE39, etc.)
  /// the type code is 73+; for EAN/UPC variants the codes are 65-72, 80.
  /// We use the [BarcodeType.code] value directly as the 'm' parameter
  /// for the GS k command (Format A: GS k m d1...dk NUL).
  static int _barcodeTypeCode(BarcodeType type) {
    // The enum already carries the correct ESC/POS type byte.
    return type.code;
  }

  // ── Raster image printing ───────────────────────────────────────

  /// Print a 1-bit raster image using GS v 0.
  ///
  /// [imageData] – flat list of pixel values (0 or 255 per byte,
  ///   one byte per pixel, row-major order). Values <= 128 are treated
  ///   as black (0), values > 128 as white (1).
  /// [width]    – image width in pixels.
  ///
  /// The image data is dithered with a threshold of 128 and packed
  /// into bytes (8 pixels per byte, MSB first), padded to 8-pixel
  /// alignment per row.
  static List<int> printRasterImage(List<int> imageData, int width) {
    if (imageData.isEmpty || width <= 0) return [];

    // Dither: convert grayscale to 1-bit
    final height = (imageData.length / width).floor();
    if (height <= 0) return [];

    // Bytes per row (padded to 8-pixel boundary)
    final bytesPerRow = ((width + 7) ~/ 8);

    final List<int> bytes = [];

    // GS v 0 – Print raster bit image
    // Format: GS v 0 m xL xH yL yH d1...dk
    // m = 0 (normal), xL/xH = horizontal bytes, yL/yH = vertical dots
    final xL = bytesPerRow & 0xFF;
    final xH = (bytesPerRow >> 8) & 0xFF;
    final yL = height & 0xFF;
    final yH = (height >> 8) & 0xFF;

    bytes.addAll([gs, 0x76, 0x30, 0x00, xL, xH, yL, yH]);

    // Pack pixels into bytes
    for (int row = 0; row < height; row++) {
      for (int col = 0; col < bytesPerRow; col++) {
        int byte = 0;
        for (int bit = 0; bit < 8; bit++) {
          final pixelIndex = row * width + col * 8 + bit;
          if (pixelIndex < imageData.length) {
            final pixel = imageData[pixelIndex];
            // White (1) means no ink, black (0) means ink.
            // ESC/POS raster: bit = 1 → print dot (black).
            // Grayscale value <= 128 → dark → set bit.
            if (pixel <= 128) {
              byte |= (1 << (7 - bit));
            }
          }
        }
        bytes.add(byte);
      }
    }

    return bytes;
  }

  /// Decode a PNG or JPEG image from raw bytes, resize it to fit
  /// [maxWidth] dots, dither it to 1-bit, and return ESC/POS raster
  /// commands.
  ///
  /// This uses a simple manual approach for PNG/JPEG parsing without
  /// external image libraries. For production use with complex images,
  /// consider using the `image` package for full decoding.
  static List<int> printImageFromBytes(Uint8List imageBytes, int maxWidth) {
    final imageInfo = _parseImageHeader(imageBytes);
    if (imageInfo == null) {
      // Fallback: return empty
      return [];
    }

    final rawPixels = _extractRawPixels(imageBytes, imageInfo);
    if (rawPixels == null || rawPixels.isEmpty) {
      return [];
    }

    // Resize to maxWidth if needed
    List<int> pixels = rawPixels;
    final origWidth = imageInfo['width'] as int;
    final origHeight = imageInfo['height'] as int;
    int targetWidth = origWidth;
    int targetHeight = origHeight;

    if (origWidth > maxWidth) {
      final scale = maxWidth / origWidth;
      targetWidth = maxWidth;
      targetHeight = (origHeight * scale).round();
      pixels = _resizePixels(rawPixels, origWidth, origHeight, targetWidth,
          targetHeight, imageInfo['channels'] as int);
    }

    // Convert to grayscale and dither
    final channels = imageInfo['channels'] as int;
    final grayscale = _toGrayscale(pixels, channels);

    return printRasterImage(grayscale, targetWidth);
  }

  // ── Image parsing helpers ───────────────────────────────────────

  /// Parse PNG or JPEG header to extract width, height, and channel count.
  /// Returns `null` if the format is unrecognised.
  static Map<String, int>? _parseImageHeader(Uint8List bytes) {
    if (bytes.length < 8) return null;

    // PNG signature: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return _parsePngHeader(bytes);
    }

    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return _parseJpegHeader(bytes);
    }

    return null;
  }

  /// Parse PNG IHDR chunk for width, height, bit depth, color type.
  static Map<String, int>? _parsePngHeader(Uint8List bytes) {
    // IHDR starts at byte 8 (after 8-byte signature)
    if (bytes.length < 24) return null;

    final width = _readBigEndian32(bytes, 16);
    final height = _readBigEndian32(bytes, 20);
    final bitDepth = bytes[24];
    final colorType = bytes[25];

    int channels;
    switch (colorType) {
      case 0: // Greyscale
        channels = 1;
        break;
      case 2: // RGB
        channels = 3;
        break;
      case 4: // Greyscale + alpha
        channels = 2;
        break;
      case 6: // RGBA
        channels = 4;
        break;
      default:
        channels = 3;
    }

    return {
      'width': width,
      'height': height,
      'channels': channels,
      'bitDepth': bitDepth,
      'format': 0, // 0 = PNG
    };
  }

  /// Parse JPEG markers for width and height from SOF0/SOF2 markers.
  static Map<String, int>? _parseJpegHeader(Uint8List bytes) {
    int offset = 2; // skip SOI

    while (offset < bytes.length - 1) {
      if (bytes[offset] != 0xFF) {
        offset++;
        continue;
      }

      final marker = bytes[offset + 1];

      // SOF0 (0xC0) or SOF2 (0xC2) – Start of Frame
      if (marker == 0xC0 || marker == 0xC2) {
        if (offset + 9 >= bytes.length) return null;
        final height = _readBigEndian16(bytes, offset + 5);
        final width = _readBigEndian16(bytes, offset + 7);
        final numComponents = bytes[offset + 9];
        // JPEG components are typically YCbCr (3 channels) or grayscale (1)
        final channels = numComponents >= 3 ? 3 : 1;
        return {
          'width': width,
          'height': height,
          'channels': channels,
          'bitDepth': 8,
          'format': 1, // 1 = JPEG
        };
      }

      // SOS (0xDA) – Start of Scan: image data follows, stop parsing headers
      if (marker == 0xDA) break;

      // Skip marker + length
      if (offset + 3 < bytes.length) {
        final segLen = _readBigEndian16(bytes, offset + 2);
        offset += 2 + segLen;
      } else {
        break;
      }
    }

    return null;
  }

  /// Extract raw (uncompressed) pixel data from an image.
  ///
  /// For PNG, this performs a basic inflate of the IDAT data.
  /// For JPEG, this is not trivially possible without a full decoder,
  /// so JPEG returns null (use a library like `image` for JPEG support).
  ///
  /// **Note:** For production use with JPEG, use the `image` pub package.
  static List<int>? _extractRawPixels(Uint8List bytes, Map<String, int> info) {
    final format = info['format'];

    if (format == 0) {
      return _extractPngPixels(bytes, info);
    }
    // JPEG requires a full decoder – not implemented here.
    // In production, delegate to the `image` package.
    return null;
  }

  /// Basic PNG pixel extraction (IDAT decompression).
  ///
  /// Uses a minimal zlib/deflate stream reader. For complex PNGs
  /// (interlaced, palette, etc.), use the `image` package.
  static List<int>? _extractPngPixels(Uint8List bytes, Map<String, int> info) {
    final width = info['width']!;
    final height = info['height']!;
    final channels = info['channels']!;

    // Find and concatenate all IDAT chunk data
    final idatData = <int>[];
    int offset = 8; // skip PNG signature

    while (offset < bytes.length - 4) {
      final chunkLen = _readBigEndian32(bytes, offset);
      final chunkType = String.fromCharCodes([
        bytes[offset + 4],
        bytes[offset + 5],
        bytes[offset + 6],
        bytes[offset + 7]
      ]);

      if (chunkType == 'IDAT') {
        final dataStart = offset + 8;
        final dataEnd = dataStart + chunkLen;
        if (dataEnd <= bytes.length) {
          idatData.addAll(bytes.sublist(dataStart, dataEnd));
        }
      }

      offset += 12 + chunkLen; // 4(len) + 4(type) + data + 4(CRC)
    }

    if (idatData.isEmpty) return null;

    // Decompress zlib stream (RFC 1950)
    final decompressed = _zlibDecompress(Uint8List.fromList(idatData));
    if (decompressed == null || decompressed.isEmpty) return null;

    // PNG rows each start with a filter byte (0 = None).
    // For a simple implementation, handle filter type 0 (None) and
    // type 1 (Sub).
    final rawPixels = <int>[];
    int rowBytes = width * channels;
    int srcOffset = 0;

    List<int> prevRow = List.filled(rowBytes, 0);

    for (int y = 0; y < height; y++) {
      if (srcOffset >= decompressed.length) break;
      final filterType = decompressed[srcOffset++];
      final currentRow = <int>[];

      for (int x = 0; x < rowBytes; x++) {
        if (srcOffset >= decompressed.length) break;
        int val = decompressed[srcOffset++];

        switch (filterType) {
          case 1: // Sub
            final left = x >= channels ? currentRow[x - channels] : 0;
            val = (val + left) & 0xFF;
            break;
          case 2: // Up
            val = (val + prevRow[x]) & 0xFF;
            break;
          case 3: // Average
            final left = x >= channels ? currentRow[x - channels] : 0;
            val = (val + ((left + prevRow[x]) >> 1)) & 0xFF;
            break;
          case 4: // Paeth
            final left = x >= channels ? currentRow[x - channels] : 0;
            final up = prevRow[x];
            final upLeft = x >= channels ? prevRow[x - channels] : 0;
            val = (val + _paethPredictor(left, up, upLeft)) & 0xFF;
            break;
          default:
            // Filter type 0 (None) or unknown – keep as-is
            break;
        }

        currentRow.add(val);
      }

      rawPixels.addAll(currentRow);
      prevRow = List.from(currentRow);
    }

    return rawPixels;
  }

  /// Paeth predictor function used in PNG filter type 4.
  static int _paethPredictor(int a, int b, int c) {
    final p = a + b - c;
    final pa = (p - a).abs();
    final pb = (p - b).abs();
    final pc = (p - c).abs();
    if (pa <= pb && pa <= pc) return a;
    if (pb <= pc) return b;
    return c;
  }

  /// Minimal zlib/deflate decompression (stored blocks only + fixed Huffman).
  ///
  /// This is a simplified implementation that handles:
  /// - Stored (uncompressed) deflate blocks
  /// - Fixed Huffman coded blocks (common for small images)
  ///
  /// For full support, use `dart:io`'s `ZLibDecoder` or the `archive` package.
  static List<int>? _zlibDecompress(Uint8List compressed) {
    // Skip zlib header (CMF + FLG = 2 bytes)
    if (compressed.length < 6) return null;

    // Check for stored blocks first, then attempt using dart:convert ZLibCodec
    try {
      final codec = ZLibCodec();
      final result = codec.decode(compressed);
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Resize pixel data using nearest-neighbour interpolation.
  static List<int> _resizePixels(
    List<int> srcPixels,
    int srcWidth,
    int srcHeight,
    int dstWidth,
    int dstHeight,
    int channels,
  ) {
    final result = <int>[];
    final xRatio = srcWidth / dstWidth;
    final yRatio = srcHeight / dstHeight;

    for (int y = 0; y < dstHeight; y++) {
      final srcY = (y * yRatio).floor();
      for (int x = 0; x < dstWidth; x++) {
        final srcX = (x * xRatio).floor();
        final srcIdx = (srcY * srcWidth + srcX) * channels;
        for (int c = 0; c < channels; c++) {
          result.add(srcPixels[srcIdx + c]);
        }
      }
    }

    return result;
  }

  /// Convert raw pixel data (possibly multi-channel) to grayscale.
  static List<int> _toGrayscale(List<int> pixels, int channels) {
    final grayscale = <int>[];
    for (int i = 0; i < pixels.length; i += channels) {
      if (channels == 1) {
        grayscale.add(pixels[i]);
      } else if (channels == 3) {
        // Luminosity method: 0.299R + 0.587G + 0.114B
        final gray =
            (0.299 * pixels[i] + 0.587 * pixels[i + 1] + 0.114 * pixels[i + 2])
                .round()
                .clamp(0, 255);
        grayscale.add(gray);
      } else if (channels >= 4) {
        // RGBA – ignore alpha
        final gray =
            (0.299 * pixels[i] + 0.587 * pixels[i + 1] + 0.114 * pixels[i + 2])
                .round()
                .clamp(0, 255);
        grayscale.add(gray);
      } else {
        grayscale.add(pixels[i]);
      }
    }
    return grayscale;
  }

  // ── Utility helpers ─────────────────────────────────────────────

  /// Read a 16-bit big-endian unsigned integer.
  static int _readBigEndian16(List<int> bytes, int offset) {
    return (bytes[offset] << 8) | bytes[offset + 1];
  }

  /// Read a 32-bit big-endian unsigned integer.
  static int _readBigEndian32(List<int> bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }
}
