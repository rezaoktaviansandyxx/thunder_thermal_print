import 'package:flutter/material.dart';
import 'package:thunder_thermal_print/thunder_thermal_print.dart';

class DeviceDiscoveryScreen extends StatefulWidget {
  const DeviceDiscoveryScreen({super.key});

  @override
  State<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends State<DeviceDiscoveryScreen> {
  final List<PrinterDevice> _devices = [];
  bool _isScanning = false;
  String _scanStatus = '';

  Future<void> _scanBluetooth() async {
    setState(() {
      _isScanning = true;
      _scanStatus = 'Scanning Bluetooth...';
    });

    try {
      final devices = await ThunderThermalPrint.scanBluetooth(
        timeout: const Duration(seconds: 10),
      );
      setState(() {
        _devices.addAll(devices);
        _scanStatus = 'Found ${devices.length} Bluetooth devices';
      });
    } catch (e) {
      setState(() => _scanStatus = 'Error: $e');
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _scanBle() async {
    setState(() {
      _isScanning = true;
      _scanStatus = 'Scanning BLE...';
    });

    try {
      final devices = await ThunderThermalPrint.scanBle(
        timeout: const Duration(seconds: 10),
      );
      setState(() {
        _devices.addAll(devices);
        _scanStatus = 'Found ${devices.length} BLE devices';
      });
    } catch (e) {
      setState(() => _scanStatus = 'Error: $e');
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _scanUsb() async {
    setState(() {
      _isScanning = true;
      _scanStatus = 'Scanning USB...';
    });

    try {
      final devices = await ThunderThermalPrint.scanUsb();
      setState(() {
        _devices.addAll(devices);
        _scanStatus = 'Found ${devices.length} USB devices';
      });
    } catch (e) {
      setState(() => _scanStatus = 'Error: $e');
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _scanNetwork() async {
    setState(() {
      _isScanning = true;
      _scanStatus = 'Scanning Network...';
    });

    try {
      final devices = await ThunderThermalPrint.scanNetwork();
      setState(() {
        _devices.addAll(devices);
        _scanStatus = 'Found ${devices.length} Network devices';
      });
    } catch (e) {
      setState(() => _scanStatus = 'Error: $e');
    } finally {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _scanAll() async {
    setState(() {
      _devices.clear();
      _isScanning = true;
      _scanStatus = 'Scanning all...';
    });

    try {
      final devices = await ThunderThermalPrint.scanAll();
      setState(() {
        _devices.addAll(devices);
        _scanStatus = 'Found ${devices.length} devices total';
      });
    } catch (e) {
      setState(() => _scanStatus = 'Error: $e');
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _clearDevices() {
    setState(() {
      _devices.clear();
      _scanStatus = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Discovery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearDevices,
            tooltip: 'Clear devices',
          ),
        ],
      ),
      body: Column(
        children: [
          // Scan buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanBluetooth,
                  icon: const Icon(Icons.bluetooth),
                  label: const Text('Bluetooth'),
                ),
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanBle,
                  icon: const Icon(Icons.bluetooth_audio),
                  label: const Text('BLE'),
                ),
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanUsb,
                  icon: const Icon(Icons.usb),
                  label: const Text('USB'),
                ),
                ElevatedButton.icon(
                  onPressed: _isScanning ? null : _scanNetwork,
                  icon: const Icon(Icons.wifi),
                  label: const Text('Network'),
                ),
                FilledButton.icon(
                  onPressed: _isScanning ? null : _scanAll,
                  icon: const Icon(Icons.search),
                  label: const Text('Scan All'),
                ),
              ],
            ),
          ),

          // Status
          if (_scanStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _scanStatus,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),

          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),

          // Device list
          Expanded(
            child: _devices.isEmpty
                ? const Center(child: Text('No devices found. Start scanning!'))
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return ListTile(
                        leading: Icon(_getConnectionIcon(device.connectionType)),
                        title: Text(device.name),
                        subtitle: Text(
                          '${device.address} - ${device.connectionType.displayName}',
                        ),
                        trailing: device.rssi != null
                            ? Text('${device.rssi} dBm')
                            : null,
                        onTap: () => _showDeviceDetails(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  IconData _getConnectionIcon(PrinterConnectionType type) {
    switch (type) {
      case PrinterConnectionType.bluetooth:
        return Icons.bluetooth;
      case PrinterConnectionType.ble:
        return Icons.bluetooth_audio;
      case PrinterConnectionType.usb:
        return Icons.usb;
      case PrinterConnectionType.network:
      case PrinterConnectionType.wifi:
        return Icons.wifi;
      case PrinterConnectionType.ethernet:
        return Icons.lan;
      case PrinterConnectionType.tcp:
        return Icons.device_hub;
      case PrinterConnectionType.unknown:
        return Icons.devices_other;
    }
  }

  void _showDeviceDetails(PrinterDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(device.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Address: ${device.address}'),
            Text('Type: ${device.connectionType.displayName}'),
            if (device.rssi != null) Text('RSSI: ${device.rssi} dBm'),
            if (device.vendorId != null) Text('Vendor ID: ${device.vendorId}'),
            if (device.productId != null) Text('Product ID: ${device.productId}'),
            Text('Connected: ${device.isConnected}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
