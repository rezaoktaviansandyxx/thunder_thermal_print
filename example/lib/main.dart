import 'dart:async';

import 'package:flutter/material.dart';
import 'package:thunder_thermal_print/thunder_thermal_print.dart';

void main() {
  runApp(const ThermalPrintDemoApp());
}

// =============================================================================
// App Root
// =============================================================================

class ThermalPrintDemoApp extends StatelessWidget {
  const ThermalPrintDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thermal Print Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const HomePage(),
    );
  }
}

// =============================================================================
// Home Page with Tabs
// =============================================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  StreamSubscription<PrinterConnectionState>? _connectionSub;
  StreamSubscription<PrinterEvent>? _eventSub;
  PrinterConnectionState _connectionState = PrinterConnectionState.disconnected;
  PrinterEvent? _lastEvent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    _connectionSub = ThunderThermalPrint.connectionStream.listen((state) {
      if (mounted) {
        setState(() => _connectionState = state);
      }
    });

    _eventSub = ThunderThermalPrint.deviceEventStream.listen((event) {
      if (mounted) {
        setState(() => _lastEvent = event);
      }
    });
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _eventSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🖨️ Thermal Print Demo'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Bluetooth'),
            Tab(text: 'BLE'),
            Tab(text: 'Network'),
            Tab(text: 'Print'),
            Tab(text: 'Status'),
          ],
        ),
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildConnectionIndicator(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const BluetoothScanTab(),
          const BleScanTab(),
          const NetworkTab(),
          const PrintTab(),
          StatusTab(
            connectionState: _connectionState,
            lastEvent: _lastEvent,
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    final color = switch (_connectionState) {
      PrinterConnectionState.connected => Colors.green,
      PrinterConnectionState.connecting ||
      PrinterConnectionState.reconnecting =>
        Colors.orange,
      PrinterConnectionState.connectionLost ||
      PrinterConnectionState.reconnectFailed =>
        Colors.red,
      _ => Colors.grey,
    };

    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 8),
      label: Text(
        _connectionState.displayName,
        style: const TextStyle(fontSize: 12),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

// =============================================================================
// Bluetooth Scan Tab
// =============================================================================

class BluetoothScanTab extends StatefulWidget {
  const BluetoothScanTab({super.key});

  @override
  State<BluetoothScanTab> createState() => _BluetoothScanTabState();
}

class _BluetoothScanTabState extends State<BluetoothScanTab> {
  List<PrinterDevice> _devices = [];
  bool _scanning = false;
  bool _connecting = false;
  String? _error;

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _devices = [];
    });

    try {
      final granted = await ThunderThermalPrint.requestPermissions();
      if (!granted) {
        setState(() => _error = 'Permissions denied');
        return;
      }

      final devices = await ThunderThermalPrint.scanBluetooth(
        timeout: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _devices = devices;
          _scanning = false;
        });
      }
    } on PrinterException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _scanning = false;
        });
      }
    }
  }

  Future<void> _connect(PrinterDevice device) async {
    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      await ThunderThermalPrint.connectBluetooth(
        macAddress: device.address,
        profile: PrinterProfile.epson,
        autoReconnect: true,
        timeout: const Duration(seconds: 10),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${device.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on PrinterException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    try {
      await ThunderThermalPrint.disconnect();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disconnected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on PrinterException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bluetooth_searching),
            label: Text(_scanning ? 'Scanning...' : 'Scan Bluetooth'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _disconnect,
            icon: const Icon(Icons.bluetooth_disabled),
            label: const Text('Disconnect'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade50,
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Discovered Printers',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Text(
                      _scanning
                          ? 'Scanning for printers...'
                          : 'Tap "Scan" to discover printers',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return ListTile(
                        leading: const Icon(Icons.print, color: Colors.teal),
                        title: Text(device.name),
                        subtitle: Text(
                          '${device.address}\nRSSI: ${device.rssi ?? 'N/A'} dBm',
                        ),
                        trailing: _connecting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.link),
                        onTap: _connecting ? null : () => _connect(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// BLE Scan Tab
// =============================================================================

class BleScanTab extends StatefulWidget {
  const BleScanTab({super.key});

  @override
  State<BleScanTab> createState() => _BleScanTabState();
}

class _BleScanTabState extends State<BleScanTab> {
  List<PrinterDevice> _devices = [];
  bool _scanning = false;
  bool _connecting = false;
  String? _error;

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _devices = [];
    });

    try {
      final granted = await ThunderThermalPrint.requestPermissions();
      if (!granted) {
        setState(() => _error = 'Permissions denied');
        return;
      }

      final devices = await ThunderThermalPrint.scanBle(
        timeout: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          _devices = devices;
          _scanning = false;
        });
      }
    } on PrinterException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _scanning = false;
        });
      }
    }
  }

  Future<void> _connect(PrinterDevice device) async {
    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      await ThunderThermalPrint.connectBle(
        deviceId: device.address,
        profile: PrinterProfile.sunmi,
        autoReconnect: true,
        timeout: const Duration(seconds: 10),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${device.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on PrinterException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: _scanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bluetooth_searching),
            label: Text(_scanning ? 'Scanning...' : 'Scan BLE Printers'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade50,
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Discovered BLE Printers',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Text(
                      _scanning
                          ? 'Scanning for BLE printers...'
                          : 'Tap "Scan" to discover BLE printers',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return ListTile(
                        leading: const Icon(
                          Icons.bluetooth,
                          color: Colors.blue,
                        ),
                        title: Text(device.name),
                        subtitle: Text(device.address),
                        trailing: _connecting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.link),
                        onTap: _connecting ? null : () => _connect(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Network Tab
// =============================================================================

class NetworkTab extends StatefulWidget {
  const NetworkTab({super.key});

  @override
  State<NetworkTab> createState() => _NetworkTabState();
}

class _NetworkTabState extends State<NetworkTab> {
  final TextEditingController _ipController = TextEditingController(
    text: '192.168.1.100',
  );
  final TextEditingController _portController = TextEditingController(
    text: '9100',
  );
  final TextEditingController _subnetController = TextEditingController(
    text: '192.168.1.0/24',
  );
  List<PrinterDevice> _discovered = [];
  bool _scanning = false;
  bool _connecting = false;
  String? _error;

  Future<void> _scanNetwork() async {
    setState(() {
      _scanning = true;
      _error = null;
      _discovered = [];
    });

    try {
      final devices = await ThunderThermalPrint.scanNetwork(
        subnet: _subnetController.text.isEmpty
            ? null
            : _subnetController.text,
      );

      if (mounted) {
        setState(() {
          _discovered = devices;
          _scanning = false;
        });
      }
    } on PrinterException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _scanning = false;
        });
      }
    }
  }

  Future<void> _connectDirect() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9100;

    if (ip.isEmpty) {
      setState(() => _error = 'Please enter an IP address');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    try {
      await ThunderThermalPrint.connectNetwork(
        ipAddress: ip,
        port: port,
        profile: PrinterProfile.xprinter,
        autoReconnect: true,
        timeout: const Duration(seconds: 5),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to $ip:$port'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on PrinterException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _subnetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Direct connect section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Direct Connect',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ipController,
                      decoration: const InputDecoration(
                        labelText: 'IP Address',
                        hintText: '192.168.1.100',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.wifi),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '9100',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _connecting ? null : _connectDirect,
                        icon: _connecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.link),
                        label: Text(
                          _connecting ? 'Connecting...' : 'Connect',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Network scan section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Network Scan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _subnetController,
                      decoration: const InputDecoration(
                        labelText: 'Subnet (optional)',
                        hintText: '192.168.1.0/24',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lan),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _scanning ? null : _scanNetwork,
                        icon: _scanning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search),
                        label: Text(
                          _scanning ? 'Scanning...' : 'Scan Network',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade50,
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            ],

            if (_discovered.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Discovered Printers',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ..._discovered.map(
                (device) => ListTile(
                  leading: const Icon(Icons.print, color: Colors.teal),
                  title: Text(device.name),
                  subtitle: Text(device.address),
                  onTap: () {
                    _ipController.text = device.address;
                    _connectDirect();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Print Tab
// =============================================================================

class PrintTab extends StatefulWidget {
  const PrintTab({super.key});

  @override
  State<PrintTab> createState() => _PrintTabState();
}

class _PrintTabState extends State<PrintTab> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _qrController = TextEditingController();
  final TextEditingController _barcodeController = TextEditingController();
  bool _printing = false;
  String? _error;
  String? _success;

  Future<void> _printText() async {
    if (!_await(await _checkConnected())) return;
    setState(() {
      _printing = true;
      _error = null;
      _success = null;
    });

    try {
      await ThunderThermalPrint.printText(_textController.text);
      _showSuccess('Text printed');
    } on PrinterException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _printQrCode() async {
    if (!_await(await _checkConnected())) return;
    setState(() {
      _printing = true;
      _error = null;
      _success = null;
    });

    try {
      await ThunderThermalPrint.printQrCode(
        _qrController.text,
        size: 6,
      );
      _showSuccess('QR code printed');
    } on PrinterException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _printBarcode() async {
    if (!_await(await _checkConnected())) return;
    setState(() {
      _printing = true;
      _error = null;
      _success = null;
    });

    try {
      await ThunderThermalPrint.printBarcode(
        _barcodeController.text,
        type: 'CODE128',
      );
      _showSuccess('Barcode printed');
    } on PrinterException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _printSampleReceipt() async {
    if (!_await(await _checkConnected())) return;
    setState(() {
      _printing = true;
      _error = null;
      _success = null;
    });

    try {
      final receipt = ReceiptBuilder(maxCharsPerLine: 32)
          .center()
          .bold()
          .text('THERMAL PRINT DEMO')
          .normal()
          .line()
          .text('Sample Receipt')
          .text('Generated by Flutter Plugin')
          .line()
          .row(left: 'Espresso', right: '\$3.50')
          .row(left: 'Latte', right: '\$4.50')
          .row(left: 'Croissant', right: '\$2.75')
          .line()
          .bold()
          .row(left: 'TOTAL', right: '\$10.75')
          .normal()
          .doubleLine()
          .center()
          .text('Payment: Cash')
          .text('Thank you!')
          .feed(lines: 3)
          .cut();

      await ThunderThermalPrint.printReceipt(receipt);
      _showSuccess('Receipt printed');
    } on PrinterException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _openDrawer() async {
    if (!_await(await _checkConnected())) return;
    setState(() {
      _printing = true;
      _error = null;
      _success = null;
    });

    try {
      await ThunderThermalPrint.openCashDrawer(pin: 0);
      _showSuccess('Cash drawer opened');
    } on PrinterException catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<bool> _checkConnected() async {
    final connected = await ThunderThermalPrint.isConnected();
    if (!connected) {
      _showError('No printer connected. Connect first.');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  void _showSuccess(String message) {
    if (mounted) {
      setState(() => _success = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  bool _await(bool value) => value;

  @override
  void dispose() {
    _textController.dispose();
    _qrController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          // Status messages
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.red.shade50,
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
          if (_success != null)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.green.shade50,
              child: Text(
                _success!,
                style: TextStyle(color: Colors.green.shade800),
              ),
            ),

          // Print Text
          _SectionCard(
            title: 'Print Text',
            icon: Icons.text_fields,
            child: Column(
              children: [
                TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    labelText: 'Text to print',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _printing ? null : _printText,
                    icon: _printing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print),
                    label: const Text('Print Text'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Print QR Code
          _SectionCard(
            title: 'Print QR Code',
            icon: Icons.qr_code,
            child: Column(
              children: [
                TextField(
                  controller: _qrController,
                  decoration: const InputDecoration(
                    labelText: 'QR Code Data',
                    hintText: 'https://example.com',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _printing ? null : _printQrCode,
                    icon: _printing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.qr_code_2),
                    label: const Text('Print QR Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Print Barcode
          _SectionCard(
            title: 'Print Barcode',
            icon: Icons.barcode_reader,
            child: Column(
              children: [
                TextField(
                  controller: _barcodeController,
                  decoration: const InputDecoration(
                    labelText: 'Barcode Data',
                    hintText: '123456789',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _printing ? null : _printBarcode,
                    icon: _printing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.barcode_reader),
                    label: const Text('Print Barcode'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Sample Receipt
          _SectionCard(
            title: 'Receipt Builder Demo',
            icon: Icons.receipt_long,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _printing ? null : _printSampleReceipt,
                icon: _printing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt),
                label: const Text('Print Sample Receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Cash Drawer
          _SectionCard(
            title: 'Cash Drawer',
            icon: Icons.point_of_sale,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _printing ? null : _openDrawer,
                icon: _printing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_open),
                label: const Text('Open Cash Drawer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Disconnect
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  await ThunderThermalPrint.disconnect();
                } on PrinterException catch (_) {}
              },
              icon: const Icon(Icons.link_off),
              label: const Text('Disconnect Printer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Status Tab
// =============================================================================

class StatusTab extends StatefulWidget {
  final PrinterConnectionState connectionState;
  final PrinterEvent? lastEvent;

  const StatusTab({
    super.key,
    required this.connectionState,
    required this.lastEvent,
  });

  @override
  State<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<StatusTab> {
  PrinterStatus? _status;
  bool _loading = false;
  String _platformVersion = '';

  @override
  void initState() {
    super.initState();
    _loadPlatformVersion();
  }

  Future<void> _loadPlatformVersion() async {
    try {
      final version = await ThunderThermalPrint.getPlatformVersion();
      if (mounted) setState(() => _platformVersion = version);
    } on PrinterException {
      // ignore
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _loading = true);
    try {
      final status = await ThunderThermalPrint.getStatus();
      if (mounted) setState(() => _status = status);
    } on PrinterException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final check = await ThunderThermalPrint.checkPermissions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permissions check: ${check ? 'GRANTED' : 'DENIED'}'),
            backgroundColor: check ? Colors.green : Colors.red,
          ),
        );
      }
    } on PrinterException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionColor = switch (widget.connectionState) {
      PrinterConnectionState.connected => Colors.green,
      PrinterConnectionState.connecting ||
      PrinterConnectionState.reconnecting =>
        Colors.orange,
      PrinterConnectionState.connectionLost ||
      PrinterConnectionState.reconnectFailed =>
        Colors.red,
      _ => Colors.grey,
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          // Connection State
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connection State',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: connectionColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.connectionState.displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: connectionColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Last Event
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Last Device Event',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.lastEvent != null) ...[
                    _InfoRow(
                      label: 'Type',
                      value: widget.lastEvent!.type.name,
                    ),
                    if (widget.lastEvent!.message != null)
                      _InfoRow(
                        label: 'Message',
                        value: widget.lastEvent!.message!,
                      ),
                    _InfoRow(
                      label: 'Time',
                      value: widget.lastEvent!.timestamp
                          .toIso8601String(),
                    ),
                  ] else
                    const Text(
                      'No events received yet.',
                      style: TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Printer Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Printer Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _refreshStatus,
                        icon: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          textStyle: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_status != null) ...[
                    _StatusIndicator(
                      label: 'Online',
                      value: _status!.online,
                    ),
                    _StatusIndicator(
                      label: 'Paper Out',
                      value: _status!.paperOut,
                      danger: true,
                    ),
                    _StatusIndicator(
                      label: 'Paper Near End',
                      value: _status!.paperNearEnd,
                      warning: true,
                    ),
                    _StatusIndicator(
                      label: 'Cover Open',
                      value: _status!.coverOpen,
                      danger: true,
                    ),
                    _StatusIndicator(
                      label: 'Drawer Open',
                      value: _status!.drawerOpen,
                    ),
                    _StatusIndicator(
                      label: 'Battery Low',
                      value: _status!.batteryLow,
                      warning: true,
                    ),
                    if (_status!.batteryLevel != null)
                      _InfoRow(
                        label: 'Battery Level',
                        value: '${_status!.batteryLevel}%',
                      ),
                    if (_status!.errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(8),
                        color: Colors.red.shade50,
                        child: Text(
                          'Error: ${_status!.errorMessage}',
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    const Divider(height: 24),
                    Text(
                      _status!.canPrint
                          ? '✅ Printer is ready to print'
                          : '⚠️ Cannot print: ${_status!.issues.join(", ")}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _status!.canPrint
                            ? Colors.green.shade800
                            : Colors.orange.shade800,
                      ),
                    ),
                  ] else
                    const Text(
                      'Tap "Refresh" to query printer status.\n'
                      '(A connected printer is required)',
                      style: TextStyle(color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Platform Info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Platform Info',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'Plugin Version',
                    value: _platformVersion.isEmpty
                        ? 'Loading...'
                        : _platformVersion,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Permissions
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _checkPermissions,
              icon: const Icon(Icons.shield),
              label: const Text('Check Permissions'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Reusable Widgets
// =============================================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final String label;
  final bool value;
  final bool danger;
  final bool warning;

  const _StatusIndicator({
    required this.label,
    required this.value,
    this.danger = false,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    if (danger) {
      color = value ? Colors.red : Colors.green.shade200;
    } else if (warning) {
      color = value ? Colors.orange : Colors.green.shade200;
    } else {
      color = value ? Colors.green : Colors.grey.shade300;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: (danger || warning) && value ? Colors.red.shade900 : null,
              ),
            ),
          ),
          Text(
            value ? 'YES' : 'NO',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: (danger || warning) && value
                  ? Colors.red
                  : value
                      ? Colors.green.shade700
                      : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
