import 'package:flutter/material.dart';
import 'package:thunder_thermal_print/thunder_thermal_print.dart';

class BleExampleScreen extends StatefulWidget {
  const BleExampleScreen({super.key});

  @override
  State<BleExampleScreen> createState() => _BleExampleScreenState();
}

class _BleExampleScreenState extends State<BleExampleScreen> {
  bool _isConnected = false;
  String _status = 'Not connected';
  List<PrinterDevice> _devices = [];

  Future<void> _scanBle() async {
    setState(() {
      _status = 'Scanning for BLE printers...';
      _devices.clear();
    });

    try {
      final devices = await ThunderThermalPrint.scanBle(
        timeout: const Duration(seconds: 10),
      );
      setState(() {
        _devices = devices;
        _status = 'Found ${devices.length} BLE devices';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _connect(PrinterDevice device) async {
    setState(() => _status = 'Connecting to ${device.name}...');

    try {
      await ThunderThermalPrint.connectBle(
        deviceId: device.address,
        profile: PrinterProfile.sunmi,
        autoReconnect: true,
      );

      setState(() {
        _isConnected = true;
        _status = 'Connected to ${device.name}';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _printText() async {
    if (!_isConnected) return;

    try {
      await ThunderThermalPrint.printText('Hello from BLE!');
      setState(() => _status = 'Printed text');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _disconnect() async {
    try {
      await ThunderThermalPrint.disconnect();
      setState(() {
        _isConnected = false;
        _status = 'Disconnected';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_status),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isConnected ? null : _scanBle,
              child: const Text('Scan BLE'),
            ),
            if (_isConnected) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: _printText, child: const Text('Print Text')),
              OutlinedButton(onPressed: _disconnect, child: const Text('Disconnect')),
            ],
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return ListTile(
                    title: Text(device.name),
                    subtitle: Text(device.address),
                    trailing: const Icon(Icons.connect_without_contact),
                    onTap: () => _connect(device),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
