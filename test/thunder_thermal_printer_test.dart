import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_thermal_print/thunder_thermal_printer.dart';
import 'package:thunder_thermal_print/thunder_thermal_printer_method_channel.dart';
import 'package:thunder_thermal_print/thunder_thermal_printer_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockThunderThermalPrinterPlatform
    with MockPlatformInterfaceMixin
    implements ThunderThermalPrinterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final ThunderThermalPrinterPlatform initialPlatform = ThunderThermalPrinterPlatform.instance;

  test('$MethodChannelThunderThermalPrinter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelThunderThermalPrinter>());
  });

  test('getPlatformVersion', () async {
    ThunderThermalPrinter thunderThermalPrinterPlugin = ThunderThermalPrinter();
    MockThunderThermalPrinterPlatform fakePlatform = MockThunderThermalPrinterPlatform();
    ThunderThermalPrinterPlatform.instance = fakePlatform;

    expect(await thunderThermalPrinterPlugin.getPlatformVersion(), '42');
  });
}
