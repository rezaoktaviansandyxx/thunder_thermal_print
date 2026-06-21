import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageProcessor {
  ImageProcessor._();

  static Uint8List processImage(
    Uint8List imageBytes, {
    int? maxWidth,
    bool dither = true,
    bool flip = false,
  }) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      throw FormatException('Unable to decode image');
    }

    img.Image processed = decoded;

    if (maxWidth != null && processed.width > maxWidth) {
      final scale = maxWidth / processed.width;
      final newHeight = (processed.height * scale).round();
      processed = img.copyResize(
        processed,
        width: maxWidth,
        height: newHeight,
        interpolation: img.Interpolation.nearest,
      );
    }

    processed = img.grayscale(processed);

    if (dither) {
      processed = _applyThreshold(processed);
    }

    return _convertTo1Bit(processed);
  }

  static img.Image _applyThreshold(img.Image image) {
    final result = img.Image(width: image.width, height: image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final lum = img.getLuminance(pixel);
        if (lum < 128) {
          result.setPixel(x, y, img.ColorUint8.rgb(0, 0, 0));
        } else {
          result.setPixel(x, y, img.ColorUint8.rgb(255, 255, 255));
        }
      }
    }

    return result;
  }

  static Uint8List _convertTo1Bit(img.Image image) {
    final width = image.width;
    final height = image.height;
    final bytesPerRow = ((width + 7) ~/ 8);
    final result = Uint8List(bytesPerRow * height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        final lum = img.getLuminance(pixel);
        if (lum < 128) {
          final byteIndex = y * bytesPerRow + (x ~/ 8);
          final bitIndex = 7 - (x % 8);
          result[byteIndex] |= (1 << bitIndex);
        }
      }
    }

    return result;
  }

  static List<int> toEscPosRaster(
    Uint8List imageBytes, {
    int? maxWidth,
  }) {
    final processed = processImage(imageBytes, maxWidth: maxWidth);
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return [];

    final width = maxWidth != null && decoded.width > maxWidth
        ? maxWidth
        : decoded.width;
    final height = decoded.height;
    final bytesPerRow = ((width + 7) ~/ 8);

    final gs = 0x1D;
    final v = 0x76;
    final zero = 0x30;
    final xL = bytesPerRow & 0xFF;
    final xH = (bytesPerRow >> 8) & 0xFF;
    final yL = height & 0xFF;
    final yH = (height >> 8) & 0xFF;

    return [
      gs, v, zero, 0x00, xL, xH, yL, yH,
      ...processed,
    ];
  }
}
