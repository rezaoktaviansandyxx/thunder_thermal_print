import '../escpos/escpos_commands.dart';

class BarcodeGenerator {
  BarcodeGenerator._();

  static List<int> generate(
    String data, {
    BarcodeType type = BarcodeType.code128,
    int width = 2,
    int height = 50,
    bool showText = false,
  }) {
    return EscPosCommands.printBarcode(
      data,
      type: type,
      width: width,
      height: height,
      textPosition: showText ? 2 : 0,
    );
  }

  static bool isValidForType(String data, BarcodeType type) {
    switch (type) {
      case BarcodeType.code128:
        return data.isNotEmpty;
      case BarcodeType.ean13:
        return RegExp(r'^\d{12,13}$').hasMatch(data);
      case BarcodeType.ean8:
        return RegExp(r'^\d{7,8}$').hasMatch(data);
      case BarcodeType.upcA:
        return RegExp(r'^\d{11,12}$').hasMatch(data);
      case BarcodeType.code39:
        return RegExp(r'^[A-Z0-9\-\.\ \$\/\+\%]+$').hasMatch(data);
      case BarcodeType.itf:
        return RegExp(r'^\d+$').hasMatch(data) && data.length.isEven;
      case BarcodeType.codabar:
        return RegExp(r'^[ABCD][0-9\-\.\ \$\/\+\:]+[ABCD]$').hasMatch(data);
      case BarcodeType.pharmacode:
        return RegExp(r'^\d+$').hasMatch(data);
    }
  }
}
