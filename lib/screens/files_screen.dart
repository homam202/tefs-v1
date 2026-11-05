import 'dart:io';
import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import 'map_screen.dart';

class FilesScreen extends StatefulWidget {
  final TefsmBluetoothService btService;

  const FilesScreen({super.key, required this.btService});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  List<String> _files = [];
  bool _loadingList = false;
  String? _downloading;
  String? _error;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    widget.btService.logStream.listen((msg) {
      if (mounted) {
        setState(() {
          _logs.insert(0, msg);
          if (_logs.length > 30) _logs.removeLast();
        });
      }
    });
    _refreshList();
  }

  Future<void> _refreshList() async {
    setState(() {
      _loadingList = true;
      _error = null;
    });
    try {
      final files = await widget.btService.listFiles();
      setState(() {
        _files = files;
        _loadingList = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingList = false;
      });
    }
  }

  Future<void> _download(String fileName) async {
    setState(() {
      _downloading = fileName;
      _error = null;
    });
    try {
      final file = await widget.btService.downloadFile(fileName);
      if (!mounted) return;
      setState(() => _downloading = null);

      // Go to map screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MapScreen(csvFile: file),
        ),
      );
    } catch (e) {
      setState(() {
        _downloading = null;
        _error = 'Download failed: $e';
      });
    }
  }

  Future<void> _disconnect() async {
    await widget.btService.disconnect();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CSV Files on Device'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadingList ? null : _refreshList,
            tooltip: 'Refresh list',
          ),
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            onPressed: _disconnect,
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!, style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.red.shade700,
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('DISMISS', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),

          Expanded(
            child: _loadingList
                ? const Center(child: CircularProgressIndicator())
                : _files.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_off, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text('No CSV files found'),
                            const SizedBox(height: 8),
                            Text(
                              'Make sure the ESP32 responds to "LIST" command\nwith filenames ending in .csv then END_LIST',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _files.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final name = _files[i];
                          final isDownloading = _downloading == name;
                          return Card(
                            elevation: 2,
                            child: ListTile(
                              leading: const Icon(Icons.insert_drive_file, color: Color(0xFF1565C0)),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              trailing: isDownloading
                                  ? const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(strokeWidth: 2.5),
                                    )
                                  : ElevatedButton.icon(
                                      onPressed: _downloading != null ? null : () => _download(name),
                                      icon: const Icon(Icons.download, size: 18),
                                      label: const Text('Download'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2E7D32),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
          ),

          // Simple log panel
          Container(
            height: 120,
            width: double.infinity,
            color: Colors.grey.shade900,
            padding: const EdgeInsets.all(8),
            child: ListView.builder(
              itemCount: _logs.length,
              itemBuilder: (_, i) => Text(
                _logs[i],
                style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
