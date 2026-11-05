import 'dart:math';
import 'package:csv/csv.dart';
import '../models/measurement_point.dart';
import '../models/heatmap_data.dart';

class CsvProcessor {
  /// Parse CSV content (Long format: Line,Site,Frequency,Voltage)
  static List<MeasurementPoint> parseCsv(String csvContent) {
    // Remove possible BOM and normalize line endings
    String cleaned = csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (cleaned.startsWith('\uFEFF')) cleaned = cleaned.substring(1);

    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(cleaned);

    if (rows.isEmpty) return [];

    // Skip header if present
    int start = 0;
    if (rows.first.any((c) => c.toString().toLowerCase().contains('site') ||
        c.toString().toLowerCase().contains('frequency') ||
        c.toString().toLowerCase().contains('voltage'))) {
      start = 1;
    }

    final points = <MeasurementPoint>[];
    for (int i = start; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 4) continue;
      try {
        points.add(MeasurementPoint.fromCsvRow(row));
      } catch (_) {
        // skip malformed rows
      }
    }
    return points;
  }

  /// Build a 2D matrix + metadata from the list of points.
  /// Automatically detects unique Sites (X) and Frequencies (Y).
  static HeatmapData buildHeatmapData(List<MeasurementPoint> points, String fileName) {
    if (points.isEmpty) {
      throw Exception('No valid measurement points found');
    }

    // Unique sorted sites (X)
    final sites = points.map((p) => p.site).toSet().toList()..sort();

    // Unique sorted frequencies (Y) - ascending
    final frequencies = points.map((p) => p.frequency).toSet().toList()..sort();

    // Create lookup: (site, frequency) → voltage
    // If multiple readings for same point, average them
    final Map<String, List<double>> lookup = {};
    for (var p in points) {
      final key = '${p.site}_${p.frequency}';
      lookup.putIfAbsent(key, () => []).add(p.voltage);
    }

    final matrix = List.generate(
      frequencies.length,
      (fi) => List.generate(sites.length, (si) {
        final key = '${sites[si]}_${frequencies[fi]}';
        final values = lookup[key];
        if (values == null || values.isEmpty) return double.nan;
        return values.reduce((a, b) => a + b) / values.length;
      }),
    );

    // Find min / max ignoring NaN
    double minV = double.infinity;
    double maxV = -double.infinity;
    for (var row in matrix) {
      for (var v in row) {
        if (!v.isNaN) {
          if (v < minV) minV = v;
          if (v > maxV) maxV = v;
        }
      }
    }
    if (minV == double.infinity) {
      minV = 0;
      maxV = 1;
    }

    return HeatmapData(
      sites: sites,
      frequencies: frequencies,
      matrix: matrix,
      minVoltage: minV,
      maxVoltage: maxV,
      fileName: fileName,
    );
  }

  /// Simple bilinear interpolation to create a denser grid for smoother heatmap.
  /// factor = how many times denser (e.g. 3 → 3x resolution)
  static HeatmapData interpolate(HeatmapData data, {int factor = 3}) {
    if (factor <= 1) return data;

    final oldRows = data.rows;
    final oldCols = data.cols;
    final newRows = (oldRows - 1) * factor + 1;
    final newCols = (oldCols - 1) * factor + 1;

    final newFreqs = List<double>.generate(newRows, (i) {
      final t = i / factor;
      final i0 = t.floor().clamp(0, oldRows - 2);
      final frac = t - i0;
      return data.frequencies[i0] * (1 - frac) + data.frequencies[i0 + 1] * frac;
    });

    final newSites = List<int>.generate(newCols, (i) {
      final t = i / factor;
      final i0 = t.floor().clamp(0, oldCols - 2);
      final frac = t - i0;
      return (data.sites[i0] * (1 - frac) + data.sites[i0 + 1] * frac).round();
    });

    final newMatrix = List.generate(newRows, (r) {
      return List.generate(newCols, (c) {
        // Map new coordinate back to old fractional indices
        final fr = r / factor;
        final fc = c / factor;
        final r0 = fr.floor().clamp(0, oldRows - 2);
        final c0 = fc.floor().clamp(0, oldCols - 2);
        final dr = fr - r0;
        final dc = fc - c0;

        double v00 = data.matrix[r0][c0];
        double v10 = data.matrix[r0][c0 + 1];
        double v01 = data.matrix[r0 + 1][c0];
        double v11 = data.matrix[r0 + 1][c0 + 1];

        // Handle NaN by falling back to nearest valid
        if (v00.isNaN) v00 = _nearestValid(data.matrix, r0, c0);
        if (v10.isNaN) v10 = _nearestValid(data.matrix, r0, c0 + 1);
        if (v01.isNaN) v01 = _nearestValid(data.matrix, r0 + 1, c0);
        if (v11.isNaN) v11 = _nearestValid(data.matrix, r0 + 1, c0 + 1);

        // Bilinear
        final v0 = v00 * (1 - dc) + v10 * dc;
        final v1 = v01 * (1 - dc) + v11 * dc;
        return v0 * (1 - dr) + v1 * dr;
      });
    });

    return HeatmapData(
      sites: newSites,
      frequencies: newFreqs,
      matrix: newMatrix,
      minVoltage: data.minVoltage,
      maxVoltage: data.maxVoltage,
      fileName: data.fileName,
    );
  }

  static double _nearestValid(List<List<double>> matrix, int r, int c) {
    // Simple search in a small neighborhood
    for (int d = 0; d < 5; d++) {
      for (int dr = -d; dr <= d; dr++) {
        for (int dc = -d; dc <= d; dc++) {
          final nr = r + dr;
          final nc = c + dc;
          if (nr >= 0 && nr < matrix.length && nc >= 0 && nc < matrix[0].length) {
            final v = matrix[nr][nc];
            if (!v.isNaN) return v;
          }
        }
      }
    }
    return 0.0;
  }
}
