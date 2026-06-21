import 'dart:convert';

class CharsetConverter {
  CharsetConverter._();

  static final Map<String, int> _codePages = {
    'CP437': 0,
    'Katakana': 1,
    'CP850': 2,
    'CP860': 3,
    'CP863': 4,
    'CP865': 5,
    'CP1252': 16,
    'CP866': 19,
    'CP1251': 21,
    'CP858': 25,
    'TIS-620': 32,
  };

  static int getCodePageNumber(String name) {
    return _codePages[name] ?? 0;
  }

  static List<String> getAvailableCharsets() {
    return _codePages.keys.toList();
  }

  static List<int> convert(String text, String encoding) {
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

  static List<int> encodeWithCodePage(String text, int codePage) {
    final esc = 0x1B;
    final t = 0x74;
    return [esc, t, codePage, ...convert(text, _encodingForCodePage(codePage))];
  }

  static String _encodingForCodePage(int codePage) {
    switch (codePage) {
      case 0:
        return 'CP437';
      case 2:
      case 3:
      case 4:
      case 5:
        return 'CP850';
      case 16:
        return 'CP1252';
      case 19:
        return 'CP866';
      case 21:
        return 'CP1251';
      case 25:
        return 'CP858';
      case 32:
        return 'TIS-620';
      default:
        return 'utf-8';
    }
  }
}
