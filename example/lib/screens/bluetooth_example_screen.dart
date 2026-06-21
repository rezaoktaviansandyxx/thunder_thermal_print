import 'package:flutter/material.dart';
import 'package:thunder_thermal_print/thunder_thermal_print.dart';

class BluetoothExampleScreen extends StatefulWidget {
  const BluetoothExampleScreen({super.key});

  @override
  State<BluetoothExampleScreen> createState() => _BluetoothExampleScreenState();
}

class _BluetoothExampleScreenState extends State<BluetoothExampleScreen> {
  bool _isConnected = false;
  String _status = 'Not connected';
  PrinterConnectionState _connectionState = PrinterConnectionState.disconnected;

  Future<void> _scanAndConnect() async {
    setState(() {
      _status = 'Scanning for Bluetooth printers...';
    });

    try {
      final devices = await ThunderThermalPrint.scanBluetooth(
        timeout: const Duration(seconds: 10),
      );

      if (devices.isEmpty) {
        setState(() {
          _status = 'No Bluetooth printers found';
        });
        return;
      }

      final device = devices.first;
      setState(() => _status = 'Connecting to ${device.name}...');

      await ThunderThermalPrint.connectBluetooth(
        macAddress: device.address,
        profile: PrinterProfile.epson,
        autoReconnect: true,
        timeout: const Duration(seconds: 15),
      );

      setState(() {
        _isConnected = true;
        _status = 'Connected to ${device.name}';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _printTest() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected to printer')),
      );
      return;
    }

    try {
      final receipt = ReceiptBuilder(maxCharsPerLine: 32)
          .center()
          .bold()
          .text('TEST RECEIPT')
          .normal()
          .line()
          .row(left: 'Item A', right: '\$10.00')
          .row(left: 'Item B', right: '\$20.00')
          .line()
          .row(left: 'TOTAL', right: '\$30.00')
          .feed(lines: 2)
          .center()
          .text('Thank you!')
          .feed(lines: 3)
          .cut();

      await ThunderThermalPrint.printReceipt(receipt);
      setState(() => _status = 'Printed test receipt');
    } catch (e) {
      setState(() => _status = 'Print error: $e');
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
      setState(() => _status = 'Disconnect error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    ThunderThermalPrint.connectionStream.listen((state) {
      setState(() => _connectionState = state);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connection State',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _connectionState.displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(_status),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isConnected ? null : _scanAndConnect,
                    icon: const Icon(Icons.bluetooth),
                    label: const Text('Scan & Connect'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isConnected ? _disconnect : null,
                    icon: const Icon(Icons.bluetooth_disabled),
                    label: const Text('Disconnect'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isConnected ? _printTest : null,
              icon: const Icon(Icons.print),
              label: const Text('Print Test Receipt'),
            ),
          ],
        ),
      ),
    );
  }
}
