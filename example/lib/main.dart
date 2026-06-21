import 'package:flutter/material.dart';
import 'screens/device_discovery_screen.dart';
import 'screens/bluetooth_example_screen.dart';
import 'screens/ble_example_screen.dart';
import 'screens/usb_example_screen.dart';
import 'screens/network_example_screen.dart';
import 'screens/receipt_builder_example_screen.dart';
import 'screens/monitoring_example_screen.dart';

void main() {
  runApp(const ThunderThermalPrintExampleApp());
}

class ThunderThermalPrintExampleApp extends StatelessWidget {
  const ThunderThermalPrintExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Thunder Thermal Print Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      routes: {
        '/discovery': (context) => const DeviceDiscoveryScreen(),
        '/bluetooth': (context) => const BluetoothExampleScreen(),
        '/ble': (context) => const BleExampleScreen(),
        '/usb': (context) => const UsbExampleScreen(),
        '/network': (context) => const NetworkExampleScreen(),
        '/receipt': (context) => const ReceiptBuilderExampleScreen(),
        '/monitoring': (context) => const MonitoringExampleScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thunder Thermal Print'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildExampleTile(
            context,
            icon: Icons.search,
            title: 'Device Discovery',
            subtitle: 'Scan for Bluetooth, BLE, USB, and Network printers',
            route: '/discovery',
          ),
          _buildExampleTile(
            context,
            icon: Icons.bluetooth,
            title: 'Bluetooth Classic',
            subtitle: 'Connect and print via Bluetooth Classic',
            route: '/bluetooth',
          ),
          _buildExampleTile(
            context,
            icon: Icons.bluetooth_audio,
            title: 'Bluetooth Low Energy',
            subtitle: 'Connect and print via BLE',
            route: '/ble',
          ),
          _buildExampleTile(
            context,
            icon: Icons.usb,
            title: 'USB Printer',
            subtitle: 'Connect and print via USB',
            route: '/usb',
          ),
          _buildExampleTile(
            context,
            icon: Icons.wifi,
            title: 'Network Printer',
            subtitle: 'Connect and print via TCP/IP',
            route: '/network',
          ),
          _buildExampleTile(
            context,
            icon: Icons.receipt_long,
            title: 'Receipt Builder',
            subtitle: 'Build and print formatted receipts',
            route: '/receipt',
          ),
          _buildExampleTile(
            context,
            icon: Icons.monitor_heart,
            title: 'Connection Monitoring',
            subtitle: 'Monitor printer events and connection state',
            route: '/monitoring',
          ),
        ],
      ),
    );
  }

  Widget _buildExampleTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => Navigator.pushNamed(context, route),
      ),
    );
  }
}
