import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/bluetooth_service.dart';
import 'files_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final TefsmBluetoothService _bt = TefsmBluetoothService();
  List<ScanResult> _results = [];
  StreamSubscription? _scanSub;
  bool _scanning = false;
  bool _connecting = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();
  }

  Future<void> _startScan() async {
    setState(() {
      _scanning = true;
      _results = [];
      _status = 'Scanning...';
    });

    try {
      // Check if Bluetooth is on
      if (await FlutterBluePlus.isSupported == false) {
        setState(() => _status = 'Bluetooth not supported on this device');
        return;
      }

      await FlutterBluePlus.adapterState
          .where((s) => s == BluetoothAdapterState.on)
          .first
          .timeout(const Duration(seconds: 5));

      _scanSub?.cancel();
      _scanSub = _bt.startScan(timeout: const Duration(seconds: 8)).listen((results) {
        // Filter devices that have a name (ESP32 usually advertises one)
        final filtered = results.where((r) => r.device.platformName.isNotEmpty).toList();
        // Keep unique by id
        final map = <String, ScanResult>{};
        for (var r in filtered) {
          map[r.device.remoteId.str] = r;
        }
        setState(() => _results = map.values.toList());
      });

      await Future.delayed(const Duration(seconds: 8));
      await _bt.stopScan();
      setState(() {
        _scanning = false;
        _status = _results.isEmpty ? 'No devices found' : 'Select a device';
      });
    } catch (e) {
      setState(() {
        _scanning = false;
        _status = 'Scan error: $e';
      });
    }
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() {
      _connecting = true;
      _status = 'Connecting to ${device.platformName}...';
    });

    final ok = await _bt.connect(device);
    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => FilesScreen(btService: _bt),
        ),
      );
    } else {
      setState(() {
        _connecting = false;
        _status = 'Connection failed. Check UUIDs / firmware.';
      });
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TEFSM Water Finder'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _scanning ? Icons.bluetooth_searching : Icons.bluetooth,
                      color: _scanning ? Colors.blue : Colors.grey,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _status ?? 'Press Scan to find your ESP32 device',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Scan button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: (_scanning || _connecting) ? null : _startScan,
                icon: _scanning
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.search),
                label: Text(_scanning ? 'Scanning...' : 'Scan & Connect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Results list
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _scanning ? '' : 'No devices yet',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = _results[i];
                        final name = r.device.platformName.isNotEmpty
                            ? r.device.platformName
                            : 'Unknown';
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE3F2FD),
                            child: Icon(Icons.memory, color: Color(0xFF1565C0)),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${r.device.remoteId}   RSSI: ${r.rssi} dBm'),
                          trailing: _connecting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: _connecting ? null : () => _connect(r.device),
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
