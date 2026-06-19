import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'thunder_thermal_printer_method_channel.dart';

abstract class ThunderThermalPrinterPlatform extends PlatformInterface {
  /// Constructs a ThunderThermalPrinterPlatform.
  ThunderThermalPrinterPlatform() : super(token: _token);

  static final Object _token = Object();

  static ThunderThermalPrinterPlatform _instance = MethodChannelThunderThermalPrinter();

  /// The default instance of [ThunderThermalPrinterPlatform] to use.
  ///
  /// Defaults to [MethodChannelThunderThermalPrinter].
  static ThunderThermalPrinterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ThunderThermalPrinterPlatform] when
  /// they register themselves.
  static set instance(ThunderThermalPrinterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
