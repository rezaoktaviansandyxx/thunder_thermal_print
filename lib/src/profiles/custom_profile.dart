import 'printer_profile_base.dart';
import '../models/printer_profile.dart';

class CustomProfile extends PrinterProfileBase {
  final String name;
  final int paperWidthMm;
  final int maxCharsPerLine;
  final bool qrCode;
  final bool barcode;
  final bool image;

  CustomProfile({
    this.name = 'Custom',
    this.paperWidthMm = 58,
    this.maxCharsPerLine = 32,
    this.qrCode = true,
    this.barcode = true,
    this.image = true,
  });

  @override
  PrinterProfile get profile => PrinterProfile.custom(
        name: name,
        paperWidth: paperWidthMm,
        maxCharsPerLine: maxCharsPerLine,
        supportsQrCode: qrCode,
        supportsBarcode: barcode,
        supportsImage: image,
      );
}
