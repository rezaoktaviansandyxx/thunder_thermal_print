import '../escpos/escpos_commands.dart';

class QrCodeGenerator {
  QrCodeGenerator._();

  static List<int> generate(String data, {int size = 6}) {
    return EscPosCommands.printQrCode(data, size: size);
  }

  static List<int> generateWithCorrection(
    String data, {
    int size = 6,
    QrErrorCorrection errorCorrection = QrErrorCorrection.low,
  }) {
    return EscPosCommands.printQrCode(
      data,
      size: size,
      errorCorrection: errorCorrection.level,
    );
  }
}

enum QrErrorCorrection {
  low(48),
  medium(49),
  quartile(50),
  high(51);

  const QrErrorCorrection(this.level);
  final int level;
}
