import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Bluetooth LE service for communicating with the ESP32 TEFSM device.
///
/// Protocol assumed:
/// - Device advertises a known name (or any ESP32).
/// - After connection we look for a characteristic that supports write + notify.
/// - Commands are sent as plain text ending with \n
/// - File list: send "LIST\n" → device replies with filenames separated by \n then "END_LIST\n"
/// - Download: send "GET filename.csv\n" → device streams file content then "END_FILE\n"
class TefsmBluetoothService {
  // Common Nordic UART / ESP32 BLE UUIDs (change if your firmware uses different ones)
  static final Guid serviceUuid = Guid("6E400001-B5A3-F393-E0A9-E50E24DCCA9E"); // Nordic UART Service
  static final Guid rxCharUuid = Guid("6E400002-B5A3-F393-E0A9-E50E24DCCA9E");  // Write to device
  static final Guid txCharUuid = Guid("6E400003-B5A3-F393-E0A9-E50E24DCCA9E");  // Notify from device

  // Fallback UUIDs often used by Chinese modules / simple ESP32 sketches
  static final Guid altServiceUuid = Guid("0000FFE0-0000-1000-8000-00805F9B34FB");
  static final Guid altCharUuid = Guid("0000FFE1-0000-1000-8000-00805F9B34FB");

  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeChar;
  BluetoothCharacteristic? _notifyChar;

  StreamSubscription<List<int>>? _notifySub;
  final StringBuffer _receiveBuffer = StringBuffer();

  final StreamController<String> _logController = StreamController<String>.broadcast();
  Stream<String> get logStream => _logController.stream;

  bool get isConnected => _device != null && _device!.isConnected;

  void _log(String msg) {
    debugPrint('[BT] $msg');
    _logController.add(msg);
  }

  /// Start scanning for BLE devices.
  Stream<List<ScanResult>> startScan({Duration timeout = const Duration(seconds: 8)}) {
    FlutterBluePlus.startScan(timeout: timeout);
    return FlutterBluePlus.scanResults;
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Connect to a device and discover the required characteristics.
  Future<bool> connect(BluetoothDevice device) async {
    try {
      _log('Connecting to ${device.platformName}...');
      await device.connect(timeout: const Duration(seconds: 10), autoConnect: false);
      _device = device;

      _log('Discovering services...');
      List<BluetoothService> services = await device.discoverServices();

      // Try Nordic UART first, then fallback
      BluetoothService? targetService;
      for (var s in services) {
        if (s.uuid == serviceUuid || s.uuid == altServiceUuid) {
          targetService = s;
          break;
        }
      }

      // If not found, take the first service that has a writable + notifiable char
      if (targetService == null && services.isNotEmpty) {
        targetService = services.firstWhere(
          (s) => s.characteristics.any((c) =>
              c.properties.write || c.properties.writeWithoutResponse),
          orElse: () => services.first,
        );
      }

      if (targetService == null) {
        _log('No suitable service found');
        await disconnect();
        return false;
      }

      _log('Using service: ${targetService.uuid}');

      for (var char in targetService.characteristics) {
        if (char.properties.write || char.properties.writeWithoutResponse) {
          _writeChar = char;
          _log('Write characteristic: ${char.uuid}');
        }
        if (char.properties.notify || char.properties.indicate) {
          _notifyChar = char;
          _log('Notify characteristic: ${char.uuid}');
        }
        // Some firmwares use the same characteristic for both
        if (_writeChar == null && (char.properties.write || char.properties.writeWithoutResponse)) {
          _writeChar = char;
        }
        if (_notifyChar == null && (char.properties.notify || char.properties.indicate)) {
          _notifyChar = char;
        }
      }

      if (_writeChar == null) {
        _log('No writable characteristic found');
        await disconnect();
        return false;
      }

      if (_notifyChar != null) {
        await _notifyChar!.setNotifyValue(true);
        _notifySub = _notifyChar!.onValueReceived.listen((value) {
          final chunk = utf8.decode(value, allowMalformed: true);
          _receiveBuffer.write(chunk);
        });
        _log('Notifications enabled');
      }

      _log('Connected successfully');
      return true;
    } catch (e) {
      _log('Connection error: $e');
      await disconnect();
      return false;
    }
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    _writeChar = null;
    _notifyChar = null;
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
      _device = null;
    }
    _receiveBuffer.clear();
    _log('Disconnected');
  }

  /// Send a plain-text command ending with \n
  Future<void> sendCommand(String cmd) async {
    if (_writeChar == null) throw Exception('Not connected');
    final data = utf8.encode('$cmd\n');
    await _writeChar!.write(data, withoutResponse: _writeChar!.properties.writeWithoutResponse);
    _log('Sent: $cmd');
  }

  /// Clear the receive buffer
  void clearBuffer() => _receiveBuffer.clear();

  /// Wait until the buffer contains [terminator] or timeout.
  Future<String> waitForTerminator(String terminator, {Duration timeout = const Duration(seconds: 30)}) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      final content = _receiveBuffer.toString();
      if (content.contains(terminator)) {
        return content;
      }
      await Future.delayed(const Duration(milliseconds: 80));
    }
    throw TimeoutException('Timed out waiting for $terminator');
  }

  /// Request list of CSV files from the device.
  /// Expected device response:
  ///   file1.csv
  ///   file2.csv
  ///   END_LIST
  Future<List<String>> listFiles() async {
    clearBuffer();
    await sendCommand('LIST');
    final raw = await waitForTerminator('END_LIST', timeout: const Duration(seconds: 15));
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != 'END_LIST' && e.toLowerCase().endsWith('.csv'))
        .toList();
    _log('Found ${lines.length} files');
    return lines;
  }

  /// Download a file by name.
  /// Protocol: send "GET filename.csv" → device streams content → ends with "END_FILE"
  Future<File> downloadFile(String fileName) async {
    clearBuffer();
    await sendCommand('GET $fileName');

    final raw = await waitForTerminator('END_FILE', timeout: const Duration(seconds: 60));

    // Remove the terminator and any trailing garbage
    String content = raw.split('END_FILE').first.trim();

    // Save to local storage
    final dir = await getApplicationDocumentsDirectory();
    final savePath = p.join(dir.path, 'tefsm_downloads', fileName);
    final file = File(savePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, encoding: utf8);

    _log('Saved ${fileName} (${content.length} bytes) → ${file.path}');
    return file;
  }
}
