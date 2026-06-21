import 'printer_profile_base.dart';
import '../models/printer_profile.dart';

class EpsonProfile extends PrinterProfileBase {
  @override
  PrinterProfile get profile => PrinterProfile.epson;
}

class Epson80Profile extends PrinterProfileBase {
  @override
  PrinterProfile get profile => PrinterProfile.epson80;
}
