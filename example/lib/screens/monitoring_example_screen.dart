import 'package:flutter/material.dart';
import 'package:thunder_thermal_print/thunder_thermal_print.dart';

class MonitoringExampleScreen extends StatefulWidget {
  const MonitoringExampleScreen({super.key});

  @override
  State<MonitoringExampleScreen> createState() => _MonitoringExampleScreenState();
}

class _MonitoringExampleScreenState extends State<MonitoringExampleScreen> {
  final List<String> _logs = [];
  PrinterConnectionState _connectionState = PrinterConnectionState.disconnected;
  PrinterStatus? _printerStatus;

  @override
  void initState() {
    super.initState();
    _initStreams();
  }

  void _initStreams() {
    ThunderThermalPrint.connectionStream.listen((state) {
      setState(() => _connectionState = state);
      _addLog('Connection: ${state.displayName}');
    });

    ThunderThermalPrint.deviceEventStream.listen((event) {
      _addLog('Event: ${event.type.name} - ${event.message ?? ''}');
    });
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(0, 19);
    setState(() {
      _logs.insert(0, '[$timestamp] $message');
      if (_logs.length > 100) {
        _logs.removeLast();
      }
    });
  }

  Future<void> _getStatus() async {
    try {
      final status = await ThunderThermalPrint.getStatus();
      setState(() => _printerStatus = status);
      _addLog('Status retrieved: online=${status.online}');
    } catch (e) {
      _addLog('Error getting status: $e');
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final granted = await ThunderThermalPrint.requestPermissions();
      _addLog('Permissions granted: $granted');
    } catch (e) {
      _addLog('Permission error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connection Monitoring')),
      body: Column(
        children: [
          // Connection state card
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
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _connectionState.isConnected
                              ? Colors.green
                              : _connectionState.isConnecting
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _connectionState.displayName,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Printer status card
          if (_printerStatus != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Printer Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildStatusChip('Online', _printerStatus!.online),
                        _buildStatusChip('Paper', !_printerStatus!.paperOut),
                        _buildStatusChip('Cover', !_printerStatus!.coverOpen),
                        _buildStatusChip('Drawer', !_printerStatus!.drawerOpen),
                        if (_printerStatus!.batteryLevel != null)
                          _buildStatusChip(
                            'Battery: ${_printerStatus!.batteryLevel}%',
                            !_printerStatus!.batteryLow,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _getStatus,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Get Status'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _requestPermissions,
                    icon: const Icon(Icons.security),
                    label: const Text('Permissions'),
                  ),
                ),
              ],
            ),
          ),

          // Log viewer
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Event Log', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                reverse: true,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Text(
                    _logs[_logs.length - 1 - index],
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, bool ok) {
    return Chip(
      label: Text(label),
      backgroundColor: ok ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
      side: BorderSide(color: ok ? Colors.green : Colors.red),
    );
  }
}
