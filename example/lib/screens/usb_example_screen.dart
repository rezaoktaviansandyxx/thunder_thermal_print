import 'package:flutter/material.dart';
import 'package:thunder_thermal_print/thunder_thermal_print.dart';

class UsbExampleScreen extends StatefulWidget {
  const UsbExampleScreen({super.key});

  @override
  State<UsbExampleScreen> createState() => _UsbExampleScreenState();
}

class _UsbExampleScreenState extends State<UsbExampleScreen> {
  bool _isConnected = false;
  String _status = 'Not connected';
  List<PrinterDevice> _devices = [];

  Future<void> _scanUsb() async {
    setState(() {
      _status = 'Scanning USB printers...';
      _devices.clear();
    });

    try {
      final devices = await ThunderThermalPrint.scanUsb();
      setState(() {
        _devices = devices;
        _status = 'Found ${devices.length} USB printers';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _connect(PrinterDevice device) async {
    setState(() => _status = 'Connecting to ${device.name}...');

    try {
      await ThunderThermalPrint.connectUsb(
        vendorId: device.vendorId ?? 0,
        productId: device.productId ?? 0,
        profile: PrinterProfile.epson,
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
    if (!_isConnected) return;

    try {
      final receipt = ReceiptBuilder(maxCharsPerLine: 32)
          .center()
          .bold()
          .text('USB TEST')
          .normal()
          .line()
          .text('Printed via USB')
          .feed(lines: 3)
          .cut();

      await ThunderThermalPrint.printReceipt(receipt);
      setState(() => _status = 'Printed test receipt');
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
      appBar: AppBar(title: const Text('USB Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_status),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isConnected ? null : _scanUsb,
              child: const Text('Scan USB'),
            ),
            if (_isConnected) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: _printTest, child: const Text('Print Test')),
              OutlinedButton(onPressed: _disconnect, child: const Text('Disconnect')),
            ],
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return ListTile(
                    title: Text(device.name),
                    subtitle: Text('VID: ${device.vendorId}, PID: ${device.productId}'),
                    trailing: const Icon(Icons.usb),
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
