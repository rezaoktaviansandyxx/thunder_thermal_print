/// Predefined printer profiles for common thermal printer brands.
/// Each profile defines ESC/POS command variations specific to a brand.
class PrinterProfile {
  /// Human-readable name of the printer profile.
  final String name;

  /// Paper width in millimeters (e.g., 48 for 58mm, 80 for 80mm).
  final int paperWidth;

  /// Maximum number of monospaced characters per line.
  final int maxCharsPerLine;

  /// Default code page number for character encoding.
  final int codePage;

  /// Whether the printer supports QR code printing via ESC/POS.
  final bool supportsQrCode;

  /// Whether the printer supports barcode printing via ESC/POS.
  final bool supportsBarcode;

  /// Whether the printer supports raster image printing.
  final bool supportsImage;

  /// Number of dots per print line (horizontal resolution).
  final int defaultDotsPerLine;

  /// Number of feed lines to advance after printing.
  final int feedLines;

  /// Duration of the paper cut pulse in milliseconds.
  final int cutPulseDuration;

  /// Custom ESC/POS commands specific to this printer brand.
  final Map<String, List<int>> customCommands;

  const PrinterProfile._({
    required this.name,
    required this.paperWidth,
    required this.maxCharsPerLine,
    required this.codePage,
    required this.supportsQrCode,
    required this.supportsBarcode,
    required this.supportsImage,
    required this.defaultDotsPerLine,
    required this.feedLines,
    required this.cutPulseDuration,
    this.customCommands = const {},
  });

  /// Standard Epson thermal printer profile (58mm paper width).
  static const PrinterProfile epson = PrinterProfile._(
    name: 'Epson',
    paperWidth: 48,
    maxCharsPerLine: 32,
    codePage: 0,
    supportsQrCode: true,
    supportsBarcode: true,
    supportsImage: true,
    defaultDotsPerLine: 384,
    feedLines: 3,
    cutPulseDuration: 100,
  );

  /// Standard Epson thermal printer profile (80mm paper width).
  static const PrinterProfile epson80 = PrinterProfile._(
    name: 'Epson 80mm',
    paperWidth: 80,
    maxCharsPerLine: 48,
    codePage: 0,
    supportsQrCode: true,
    supportsBarcode: true,
    supportsImage: true,
    defaultDotsPerLine: 576,
    feedLines: 3,
    cutPulseDuration: 100,
  );

  /// XPrinter profile (common budget thermal printer brand).
  static const PrinterProfile xprinter = PrinterProfile._(
    name: 'XPrinter',
    paperWidth: 58,
    maxCharsPerLine: 32,
    codePage: 0,
    supportsQrCode: true,
    supportsBarcode: true,
    supportsImage: true,
    defaultDotsPerLine: 384,
    feedLines: 3,
    cutPulseDuration: 80,
  );

  /// Sunmi profile (common in Android POS devices).
  static const PrinterProfile sunmi = PrinterProfile._(
    name: 'Sunmi',
    paperWidth: 58,
    maxCharsPerLine: 32,
    codePage: 0,
    supportsQrCode: true,
    supportsBarcode: true,
    supportsImage: true,
    defaultDotsPerLine: 384,
    feedLines: 3,
    cutPulseDuration: 100,
  );

  /// Bixolon profile (Samsung-affiliated POS printer brand).
  static const PrinterProfile bixolon = PrinterProfile._(
    name: 'Bixolon',
    paperWidth: 58,
    maxCharsPerLine: 32,
    codePage: 0,
    supportsQrCode: true,
    supportsBarcode: true,
    supportsImage: true,
    defaultDotsPerLine: 384,
    feedLines: 3,
    cutPulseDuration: 100,
  );

  /// Rongta profile (Chinese thermal printer manufacturer).
  static const PrinterProfile rongta = PrinterProfile._(
    name: 'Rongta',
    paperWidth: 58,
    maxCharsPerLine: 32,
    codePage: 0,
    supportsQrCode: true,
    supportsBarcode: true,
    supportsImage: true,
    defaultDotsPerLine: 384,
    feedLines: 3,
    cutPulseDuration: 100,
  );

  /// ZJiang profile (common Chinese POS printer brand).
  static const PrinterProfile zjiang = PrinterProfile._(
    name: 'ZJiang',
    paperWidth: 58,
    maxCharsPerLine: 32,
    codePage: 0,
    supportsQrCode: true,
    supportsBarcode: true,
    supportsImage: true,
    defaultDotsPerLine: 384,
    feedLines: 3,
    cutPulseDuration: 100,
  );

  /// Built-in profile registry for lookup by name.
  static const Map<String, PrinterProfile> _registry = {
    'Epson': epson,
    'Epson 80mm': epson80,
    'XPrinter': xprinter,
    'Sunmi': sunmi,
    'Bixolon': bixolon,
    'Rongta': rongta,
    'ZJiang': zjiang,
  };

  /// Looks up a built-in profile by its [name] (case-insensitive).
  /// Returns null if no matching profile is found.
  static PrinterProfile? lookup(String name) {
    for (final entry in _registry.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  /// Returns a list of all built-in profile names.
  static List<String> get availableProfiles =>
      _registry.keys.toList();

  /// Creates a custom printer profile with configurable parameters.
  factory PrinterProfile.custom({
    required String name,
    int paperWidth = 58,
    int maxCharsPerLine = 32,
    int codePage = 0,
    bool supportsQrCode = true,
    bool supportsBarcode = true,
    bool supportsImage = true,
    int defaultDotsPerLine = 384,
    int feedLines = 3,
    int cutPulseDuration = 100,
    Map<String, List<int>> customCommands = const {},
  }) {
    return PrinterProfile._(
      name: name,
      paperWidth: paperWidth,
      maxCharsPerLine: maxCharsPerLine,
      codePage: codePage,
      supportsQrCode: supportsQrCode,
      supportsBarcode: supportsBarcode,
      supportsImage: supportsImage,
      defaultDotsPerLine: defaultDotsPerLine,
      feedLines: feedLines,
      cutPulseDuration: cutPulseDuration,
      customCommands: customCommands,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'paperWidth': paperWidth,
      'maxCharsPerLine': maxCharsPerLine,
      'codePage': codePage,
      'supportsQrCode': supportsQrCode,
      'supportsBarcode': supportsBarcode,
      'supportsImage': supportsImage,
      'defaultDotsPerLine': defaultDotsPerLine,
      'feedLines': feedLines,
      'cutPulseDuration': cutPulseDuration,
    };
  }

  @override
  String toString() =>
      'PrinterProfile(name: $name, paperWidth: ${paperWidth}mm, '
      'maxCharsPerLine: $maxCharsPerLine)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterProfile &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          paperWidth == other.paperWidth &&
          maxCharsPerLine == other.maxCharsPerLine &&
          codePage == other.codePage;

  @override
  int get hashCode => Object.hash(name, paperWidth, maxCharsPerLine, codePage);
}
