import '../models/models.dart';
import '../services/thermal_print_platform_interface.dart';

class PrinterStatusService {
  PrinterStatusService._();

  static Future<PrinterStatus> getStatus() async {
    final map = await ThunderThermalPrintPlatform.instance.getStatus();
    return PrinterStatus(
      online: map['online'] as bool? ?? false,
      paperOut: map['paperOut'] as bool? ?? false,
      paperNearEnd: map['paperNearEnd'] as bool? ?? false,
      coverOpen: map['coverOpen'] as bool? ?? false,
      drawerOpen: map['drawerOpen'] as bool? ?? false,
      batteryLow: map['batteryLow'] as bool? ?? false,
      batteryLevel: map['batteryLevel'] as int?,
      errorCode: map['errorCode'] as int?,
      errorMessage: map['errorMessage'] as String?,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : null,
    );
  }

  static Future<Map<String, dynamic>> getPrinterCapabilities() async {
    return ThunderThermalPrintPlatform.instance.getPrinterCapabilities();
  }

  static Future<Map<String, dynamic>> checkPaperStatus() async {
    final status = await getStatus();
    return {
      'hasRoll': !status.paperOut,
      'isLow': status.paperNearEnd,
      'isEmpty': status.paperOut,
    };
  }

  static Future<double?> getPrinterTemperature() async {
    await getStatus();
    return null;
  }

  static Future<int?> getPrintedBytesCount() async {
    return ThunderThermalPrintPlatform.instance.getPrintedBytesCount();
  }

  static Future<bool> canPrint() async {
    final status = await getStatus();
    return status.canPrint;
  }

  static Future<List<String>> getIssues() async {
    final status = await getStatus();
    return status.issues;
  }
}
