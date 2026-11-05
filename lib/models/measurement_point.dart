/// Represents a single measurement point from the CSV.
class MeasurementPoint {
  final int line;
  final int site;       // X-axis (measurement point)
  final double frequency; // Y-axis (depth proxy)
  final double voltage; // Signal value

  MeasurementPoint({
    required this.line,
    required this.site,
    required this.frequency,
    required this.voltage,
  });

  factory MeasurementPoint.fromCsvRow(List<dynamic> row) {
    return MeasurementPoint(
      line: int.tryParse(row[0].toString()) ?? 0,
      site: int.tryParse(row[1].toString()) ?? 0,
      frequency: double.tryParse(row[2].toString()) ?? 0.0,
      voltage: double.tryParse(row[3].toString()) ?? 0.0,
    );
  }

  @override
  String toString() => 'L$line S$site F$frequency V$voltage';
}
