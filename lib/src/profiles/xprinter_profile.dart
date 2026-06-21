import 'printer_profile_base.dart';
import '../models/printer_profile.dart';

class XprinterProfile extends PrinterProfileBase {
  @override
  PrinterProfile get profile => PrinterProfile.xprinter;
}
