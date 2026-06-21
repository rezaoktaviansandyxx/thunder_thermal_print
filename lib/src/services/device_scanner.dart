import '../models/models.dart';
import '../bluetooth/bluetooth_handler.dart';
import '../ble/ble_handler.dart';
import '../usb/usb_handler.dart';
import '../network/network_handler.dart';

class DeviceScanner {
  DeviceScanner._();

  static Future<List<PrinterDevice>> scanBluetooth({Duration? timeout}) {
    return BluetoothHandler.scan(timeout: timeout);
  }

  static Future<List<PrinterDevice>> scanBle({Duration? timeout}) {
    return BleHandler.scan(timeout: timeout);
  }

  static Future<List<PrinterDevice>> scanUsb() {
    return UsbHandler.scan();
  }

  static Future<List<PrinterDevice>> scanNetwork({String? subnet}) {
    return NetworkHandler.scan(subnet: subnet);
  }

  static Future<List<PrinterDevice>> scanAll({
    Duration? timeout,
    bool includeBluetooth = true,
    bool includeBle = true,
    bool includeUsb = true,
    bool includeNetwork = true,
  }) async {
    final allDevices = <PrinterDevice>[];

    final futures = <Future<List<PrinterDevice>>>[];

    if (includeBluetooth) {
      futures.add(scanBluetooth(timeout: timeout));
    }
    if (includeBle) {
      futures.add(scanBle(timeout: timeout));
    }
    if (includeUsb) {
      futures.add(scanUsb());
    }
    if (includeNetwork) {
      futures.add(scanNetwork());
    }

    final results = await Future.wait(futures);
    for (final devices in results) {
      allDevices.addAll(devices);
    }

    final seen = <String>{};
    allDevices.removeWhere((device) {
      final key = '${device.address}:${device.connectionType.name}';
      if (seen.contains(key)) return true;
      seen.add(key);
      return false;
    });

    return allDevices;
  }

  static Future<List<PrinterDevice>> getPairedDevices() {
    return BluetoothHandler.getPairedDevices();
  }

  static Future<List<PrinterDevice>> getConnectedDevices() {
    return UsbHandler.getConnectedDevices();
  }

  static Stream<PrinterDevice> bluetoothDeviceStream() {
    return BluetoothHandler.deviceStream;
  }

  static Stream<PrinterDevice> bleDeviceStream() {
    return BleHandler.deviceStream;
  }

  static Stream<PrinterDevice> usbDeviceStream() {
    return UsbHandler.deviceStream;
  }

  static Stream<PrinterDevice> networkDeviceStream() {
    return NetworkHandler.deviceStream;
  }
}
