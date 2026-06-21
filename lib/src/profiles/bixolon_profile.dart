import 'printer_profile_base.dart';
import '../models/printer_profile.dart';

class BixolonProfile extends PrinterProfileBase {
  @override
  PrinterProfile get profile => PrinterProfile.bixolon;
}
