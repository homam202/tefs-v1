import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/heatmap_data.dart';

/// CustomPainter that draws a smooth colored heatmap + optional contour lines.
/// Blue = low voltage (water potential), Red = high voltage (dry).
class HeatmapPainter extends CustomPainter {
  final HeatmapData data;
  final bool showGrid;
  final bool showContours;
  final int contourLevels;
  final bool showContourLabels;

  HeatmapPainter({
    required this.data,
    this.showGrid = false,
    this.showContours = true,
    this.contourLevels = 8,
    this.showContourLabels = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.rows == 0 || data.cols == 0) return;

    final cellW = size.width / data.cols;
    final cellH = size.height / data.rows;

    // ---------- 1. Draw Heatmap cells ----------
    for (int r = 0; r < data.rows; r++) {
      for (int c = 0; c < data.cols; c++) {
        final value = data.matrix[r][c];
        if (value.isNaN) continue;

        final color = _voltageToColor(value, data.minVoltage, data.maxVoltage);
        final paint = Paint()..color = color;

        // Invert Y: row 0 (lowest freq) goes to the bottom
        final top = size.height - (r + 1) * cellH;
        canvas.drawRect(
          Rect.fromLTWH(c * cellW, top, cellW + 0.6, cellH + 0.6),
          paint,
        );
      }
    }

    // ---------- 2. Draw Contour Lines (Marching Squares style) ----------
    if (showContours && data.rows > 1 && data.cols > 1) {
      _drawContours(canvas, size, cellW, cellH);
    }

    // ---------- 3. Optional grid ----------
    if (showGrid) {
      final gridPaint = Paint()
        ..color = Colors.black26
        ..strokeWidth = 0.4
        ..style = PaintingStyle.stroke;

      for (int c = 0; c <= data.cols; c++) {
        final x = c * cellW;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (int r = 0; r <= data.rows; r++) {
        final y = r * cellH;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }
  }

  /// Simple Marching-Squares contour extraction + drawing.
  void _drawContours(Canvas canvas, Size size, double cellW, double cellH) {
    final minV = data.minVoltage;
    final maxV = data.maxVoltage;
    if (maxV <= minV) return;

    final levels = List<double>.generate(contourLevels, (i) {
      return minV + (maxV - minV) * (i + 1) / (contourLevels + 1);
    });

    final contourPaint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final labelStyle = TextStyle(
      color: Colors.black87,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      backgroundColor: Colors.white.withOpacity(0.7),
    );

    for (final level in levels) {
      // Collect line segments for this isolevel
      final segments = <List<Offset>>[];

      for (int r = 0; r < data.rows - 1; r++) {
        for (int c = 0; c < data.cols - 1; c++) {
          // Four corners of the cell (in matrix indices)
          // Note: matrix[r][c] where r=0 is lowest frequency → bottom of screen
          final v00 = _safe(data.matrix[r][c]);
          final v10 = _safe(data.matrix[r][c + 1]);
          final v01 = _safe(data.matrix[r + 1][c]);
          final v11 = _safe(data.matrix[r + 1][c + 1]);

          // Screen coordinates (Y inverted)
          final x0 = c * cellW;
          final x1 = (c + 1) * cellW;
          final y0 = size.height - r * cellH;       // bottom of this cell
          final y1 = size.height - (r + 1) * cellH; // top of this cell

          // Marching squares binary index
          int idx = 0;
          if (v00 >= level) idx |= 1;
          if (v10 >= level) idx |= 2;
          if (v11 >= level) idx |= 4;
          if (v01 >= level) idx |= 8;

          if (idx == 0 || idx == 15) continue; // no crossing

          // Linear interpolation helpers
          Offset interp(Offset a, Offset b, double va, double vb) {
            final t = ((level - va) / (vb - va)).clamp(0.0, 1.0);
            return Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t);
          }

          final p00 = Offset(x0, y0);
          final p10 = Offset(x1, y0);
          final p11 = Offset(x1, y1);
          final p01 = Offset(x0, y1);

          // Edge midpoints (interpolated)
          final bottom = interp(p00, p10, v00, v10);
          final right  = interp(p10, p11, v10, v11);
          final top    = interp(p01, p11, v01, v11);
          final left   = interp(p00, p01, v00, v01);

          // Cases (simplified, no saddle ambiguity handling for speed)
          switch (idx) {
            case 1:  case 14: segments.add([left, bottom]); break;
            case 2:  case 13: segments.add([bottom, right]); break;
            case 3:  case 12: segments.add([left, right]); break;
            case 4:  case 11: segments.add([right, top]); break;
            case 5:           segments.add([left, top]); segments.add([bottom, right]); break;
            case 6:  case 9:  segments.add([bottom, top]); break;
            case 7:  case 8:  segments.add([left, top]); break;
            case 10:          segments.add([left, bottom]); segments.add([right, top]); break;
          }
        }
      }

      // Draw all segments for this level
      for (final seg in segments) {
        if (seg.length >= 2) {
          canvas.drawLine(seg[0], seg[1], contourPaint);
        }
      }

      // Optional: place a small label near the first segment of this level
      if (showContourLabels && segments.isNotEmpty && segments.first.length >= 2) {
        final mid = Offset(
          (segments.first[0].dx + segments.first[1].dx) / 2,
          (segments.first[0].dy + segments.first[1].dy) / 2,
        );
        final tp = TextPainter(
          text: TextSpan(text: level.toStringAsFixed(0), style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  double _safe(double v) => v.isNaN ? data.minVoltage : v;

  /// Maps voltage to a Blue → Cyan → Green → Yellow → Red gradient.
  static Color _voltageToColor(double v, double minV, double maxV) {
    if (maxV <= minV) return Colors.grey;
    double t = ((v - minV) / (maxV - minV)).clamp(0.0, 1.0);

    if (t < 0.25) {
      return Color.lerp(const Color(0xFF0D47A1), const Color(0xFF00BCD4), t / 0.25)!;
    } else if (t < 0.5) {
      return Color.lerp(const Color(0xFF00BCD4), const Color(0xFF4CAF50), (t - 0.25) / 0.25)!;
    } else if (t < 0.75) {
      return Color.lerp(const Color(0xFF4CAF50), const Color(0xFFFFEB3B), (t - 0.5) / 0.25)!;
    } else {
      return Color.lerp(const Color(0xFFFFEB3B), const Color(0xFFD32F2F), (t - 0.75) / 0.25)!;
    }
  }

  @override
  bool shouldRepaint(covariant HeatmapPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showContours != showContours ||
        oldDelegate.contourLevels != contourLevels ||
        oldDelegate.showContourLabels != showContourLabels;
  }
}

/// Widget that shows the heatmap + axes labels + color legend.
/// Uses a GlobalKey so the parent can capture the image.
class HeatmapWidget extends StatelessWidget {
  final HeatmapData data;
  final double height;
  final bool showContours;
  final int contourLevels;
  final GlobalKey? repaintKey;

  const HeatmapWidget({
    super.key,
    required this.data,
    this.height = 420,
    this.showContours = true,
    this.contourLevels = 8,
    this.repaintKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            data.fileName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),

        // Heatmap + Y axis
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Y-axis labels (Frequency / Depth)
              SizedBox(
                width: 52,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data.frequencies.isNotEmpty
                          ? data.frequencies.last.toStringAsFixed(0)
                          : '',
                      style: const TextStyle(fontSize: 11),
                    ),
                    const RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        'Frequency (Depth)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      data.frequencies.isNotEmpty
                          ? data.frequencies.first.toStringAsFixed(0)
                          : '',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),

              // The actual heatmap (wrapped in RepaintBoundary for capture)
              Expanded(
                child: RepaintBoundary(
                  key: repaintKey,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: CustomPaint(
                        painter: HeatmapPainter(
                          data: data,
                          showContours: showContours,
                          contourLevels: contourLevels,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // X-axis label
        const Text(
          'Site (Measurement Point)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),

        // X ticks
        if (data.sites.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 52, top: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${data.sites.first}', style: const TextStyle(fontSize: 11)),
                if (data.sites.length > 2)
                  Text(
                    '${data.sites[data.sites.length ~/ 2]}',
                    style: const TextStyle(fontSize: 11),
                  ),
                Text('${data.sites.last}', style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Color legend
        _buildLegend(),
      ],
    );
  }

  Widget _buildLegend() {
    return Column(
      children: [
        Container(
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0D47A1),
                Color(0xFF00BCD4),
                Color(0xFF4CAF50),
                Color(0xFFFFEB3B),
                Color(0xFFD32F2F),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Low ${data.minVoltage.toStringAsFixed(1)} (Water)',
                style: const TextStyle(fontSize: 11, color: Color(0xFF0D47A1)),
              ),
              Text(
                'High ${data.maxVoltage.toStringAsFixed(1)} (Dry)',
                style: const TextStyle(fontSize: 11, color: Color(0xFFD32F2F)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
