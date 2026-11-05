import 'measurement_point.dart';

/// Holds the processed 2D matrix ready for heatmap rendering.
class HeatmapData {
  final List<int> sites;          // Unique sorted X values (columns)
  final List<double> frequencies; // Unique sorted Y values (rows) - will be inverted
  final List<List<double>> matrix; // matrix[freqIndex][siteIndex] = voltage
  final double minVoltage;
  final double maxVoltage;
  final String fileName;

  HeatmapData({
    required this.sites,
    required this.frequencies,
    required this.matrix,
    required this.minVoltage,
    required this.maxVoltage,
    required this.fileName,
  });

  int get rows => frequencies.length;
  int get cols => sites.length;
}
