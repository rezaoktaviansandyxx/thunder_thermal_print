import '../escpos/escpos_commands.dart';
import '../models/printer_profile.dart';

abstract class PrinterProfileBase {
  PrinterProfile get profile;

  List<int> get initializeCommand => EscPosCommands.initialize();

  List<int> get partialCutCommand => EscPosCommands.partialCut();

  List<int> get fullCutCommand => EscPosCommands.fullCut();

  List<int> get enableBoldCommand => EscPosCommands.enableBold();

  List<int> get disableBoldCommand => EscPosCommands.disableBold();

  List<int> get enableUnderlineCommand => EscPosCommands.enableUnderline();

  List<int> get disableUnderlineCommand => EscPosCommands.disableUnderline();

  List<int> get enableInverseCommand => EscPosCommands.enableInverse();

  List<int> get disableInverseCommand => EscPosCommands.disableInverse();

  List<int> get alignLeftCommand => EscPosCommands.alignLeft();

  List<int> get alignCenterCommand => EscPosCommands.alignCenter();

  List<int> get alignRightCommand => EscPosCommands.alignRight();

  List<int> get fontACommand => EscPosCommands.setFontA();

  List<int> get fontBCommand => EscPosCommands.setFontB();

  List<int> get doubleWidthCommand => EscPosCommands.enableDoubleWidth();

  List<int> get doubleHeightCommand => EscPosCommands.enableDoubleHeight();

  List<int> get doubleWidthAndHeightCommand =>
      EscPosCommands.enableDoubleWidthAndHeight();

  List<int> get normalSizeCommand => EscPosCommands.disableDoubleMode();

  List<int> feedLines(int count) => EscPosCommands.feedLines(count);

  List<int> printText(String text) => EscPosCommands.printText(text);

  List<int> printQrCode(String data, {int size = 6}) =>
      EscPosCommands.printQrCode(data, size: size);

  List<int> printBarcode(String data, {BarcodeType type = BarcodeType.code128}) =>
      EscPosCommands.printBarcode(data, type: type);

  List<int> openCashDrawer({int pin = 0}) =>
      EscPosCommands.openCashDrawer(pin: pin);

  List<int> beep({int count = 1, int duration = 3}) =>
      EscPosCommands.beep(count: count, duration: duration);

  bool get supportsQrCode => profile.supportsQrCode;

  bool get supportsBarcode => profile.supportsBarcode;

  bool get supportsImage => profile.supportsImage;

  int get maxCharsPerLine => profile.maxCharsPerLine;

  int get paperWidth => profile.paperWidth;
}
