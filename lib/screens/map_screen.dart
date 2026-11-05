import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/heatmap_data.dart';
import '../services/csv_processor.dart';
import '../widgets/heatmap_painter.dart';

class MapScreen extends StatefulWidget {
  final File csvFile;

  const MapScreen({super.key, required this.csvFile});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  HeatmapData? _data;
  HeatmapData? _interpolated;
  bool _loading = true;
  String? _error;
  bool _useInterpolation = true;
  int _interpFactor = 3;

  // Contour controls
  bool _showContours = true;
  int _contourLevels = 8;

  // For capturing the heatmap image
  final GlobalKey _heatmapKey = GlobalKey();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _processFile();
  }

  Future<void> _processFile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final content = await widget.csvFile.readAsString();
      final points = CsvProcessor.parseCsv(content);
      if (points.isEmpty) {
        throw Exception('No valid data rows found in CSV');
      }
      final raw = CsvProcessor.buildHeatmapData(
        points,
        widget.csvFile.path.split(Platform.pathSeparator).last,
      );
      final interp = CsvProcessor.interpolate(raw, factor: _interpFactor);

      setState(() {
        _data = raw;
        _interpolated = interp;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Capture the heatmap widget and save it as a PNG file.
  Future<void> _saveHeatmapImage() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      // Find the RenderRepaintBoundary
      final boundary = _heatmapKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not find heatmap render object');
      }

      // Capture at higher resolution for better quality
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode image');

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to a public-ish location
      final dir = await getApplicationDocumentsDirectory();
      final mapsDir = Directory(p.join(dir.path, 'tefsm_maps'));
      if (!await mapsDir.exists()) await mapsDir.create(recursive: true);

      final baseName = widget.csvFile.path.split(Platform.pathSeparator).last.replaceAll('.csv', '');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = p.join(mapsDir.path, '${baseName}_map_$timestamp.png');

      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Map saved:\n${file.path}'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heatmap / Contour Map'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          // Toggle contours
          if (_data != null)
            IconButton(
              icon: Icon(_showContours ? Icons.timeline : Icons.timeline_outlined),
              tooltip: _showContours ? 'Hide contours' : 'Show contours',
              onPressed: () => setState(() => _showContours = !_showContours),
            ),
          // Toggle interpolation
          if (_data != null)
            IconButton(
              icon: Icon(_useInterpolation ? Icons.grid_on : Icons.grid_off),
              tooltip: _useInterpolation ? 'Show raw grid' : 'Show interpolated',
              onPressed: () => setState(() => _useInterpolation = !_useInterpolation),
            ),
          // Save image
          if (_data != null)
            IconButton(
              icon: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_alt),
              tooltip: 'Save map as PNG',
              onPressed: _saving ? null : _saveHeatmapImage,
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Parsing CSV & generating map...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 56, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _processFile,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Info chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.table_rows, size: 18),
                            label: Text('${_data!.rows} frequencies'),
                          ),
                          Chip(
                            avatar: const Icon(Icons.view_column, size: 18),
                            label: Text('${_data!.cols} sites'),
                          ),
                          Chip(
                            avatar: const Icon(Icons.thermostat, size: 18),
                            label: Text(
                              '${_data!.minVoltage.toStringAsFixed(1)} – ${_data!.maxVoltage.toStringAsFixed(1)} mV',
                            ),
                          ),
                          if (_showContours)
                            Chip(
                              avatar: const Icon(Icons.timeline, size: 18),
                              label: Text('$_contourLevels contours'),
                              backgroundColor: Colors.blue.shade50,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // The map
                      HeatmapWidget(
                        data: _useInterpolation ? _interpolated! : _data!,
                        height: MediaQuery.of(context).size.width * 0.95,
                        showContours: _showContours,
                        contourLevels: _contourLevels,
                        repaintKey: _heatmapKey,
                      ),

                      const SizedBox(height: 20),

                      // Controls card
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Interpolation
                              const Text(
                                'Smoothing (Bilinear Interpolation)',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Row(
                                children: [
                                  const Text('Factor:'),
                                  Expanded(
                                    child: Slider(
                                      value: _interpFactor.toDouble(),
                                      min: 1,
                                      max: 6,
                                      divisions: 5,
                                      label: '$_interpFactor×',
                                      onChanged: (v) {
                                        setState(() => _interpFactor = v.round());
                                      },
                                      onChangeEnd: (_) {
                                        if (_data != null) {
                                          setState(() {
                                            _interpolated = CsvProcessor.interpolate(
                                              _data!,
                                              factor: _interpFactor,
                                            );
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  Text('$_interpFactor×'),
                                ],
                              ),

                              const Divider(height: 24),

                              // Contour levels
                              const Text(
                                'Contour Lines',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Show contour lines'),
                                value: _showContours,
                                onChanged: (v) => setState(() => _showContours = v),
                              ),
                              if (_showContours)
                                Row(
                                  children: [
                                    const Text('Levels:'),
                                    Expanded(
                                      child: Slider(
                                        value: _contourLevels.toDouble(),
                                        min: 3,
                                        max: 16,
                                        divisions: 13,
                                        label: '$_contourLevels',
                                        onChanged: (v) {
                                          setState(() => _contourLevels = v.round());
                                        },
                                      ),
                                    ),
                                    Text('$_contourLevels'),
                                  ],
                                ),

                              const Divider(height: 24),

                              // Save button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _saving ? null : _saveHeatmapImage,
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.save_alt),
                                  label: Text(_saving ? 'Saving...' : 'Save Map as PNG'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
