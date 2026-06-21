import 'package:flutter/material.dart';
import 'package:thunder_thermal_print/thunder_thermal_print.dart';

class NetworkExampleScreen extends StatefulWidget {
  const NetworkExampleScreen({super.key});

  @override
  State<NetworkExampleScreen> createState() => _NetworkExampleScreenState();
}

class _NetworkExampleScreenState extends State<NetworkExampleScreen> {
  final _ipController = TextEditingController(text: '192.168.1.100');
  final _portController = TextEditingController(text: '9100');
  bool _isConnected = false;
  String _status = 'Not connected';
  List<PrinterDevice> _devices = [];

  Future<void> _scanNetwork() async {
    setState(() {
      _status = 'Scanning network...';
      _devices.clear();
    });

    try {
      final devices = await ThunderThermalPrint.scanNetwork();
      setState(() {
        _devices = devices;
        _status = 'Found ${devices.length} network printers';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _connect() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text) ?? 9100;

    setState(() => _status = 'Connecting to $ip:$port...');

    try {
      await ThunderThermalPrint.connectNetwork(
        ipAddress: ip,
        port: port,
        profile: PrinterProfile.epson,
        autoReconnect: true,
      );

      setState(() {
        _isConnected = true;
        _status = 'Connected to $ip:$port';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _printTest() async {
    if (!_isConnected) return;

    try {
      final receipt = ReceiptBuilder(maxCharsPerLine: 48)
          .center()
          .bold()
          .doubleWidth()
          .text('NETWORK TEST')
          .normal()
          .doubleWidth()
          .line()
          .text('Printed via TCP/IP')
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
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                hintText: '192.168.1.100',
              ),
              enabled: !_isConnected,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
                hintText: '9100',
              ),
              enabled: !_isConnected,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isConnected ? null : _connect,
                    icon: const Icon(Icons.lan),
                    label: const Text('Connect'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isConnected ? _disconnect : null,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Disconnect'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isConnected ? null : _scanNetwork,
              icon: const Icon(Icons.search),
              label: const Text('Scan Network'),
            ),
            const SizedBox(height: 16),
            Text('Status: $_status'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isConnected ? _printTest : null,
              icon: const Icon(Icons.print),
              label: const Text('Print Test Receipt'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index];
                  return ListTile(
                    title: Text(device.name),
                    subtitle: Text(device.address),
                    trailing: const Icon(Icons.wifi),
                    onTap: () {
                      final parts = device.address.split(':');
                      if (parts.length == 2) {
                        _ipController.text = parts[0];
                        _portController.text = parts[1];
                      }
                    },
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
