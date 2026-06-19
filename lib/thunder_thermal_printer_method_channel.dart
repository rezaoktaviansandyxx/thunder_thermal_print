import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'thunder_thermal_printer_platform_interface.dart';

/// An implementation of [ThunderThermalPrinterPlatform] that uses method channels.
class MethodChannelThunderThermalPrinter extends ThunderThermalPrinterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('thunder_thermal_printer');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
