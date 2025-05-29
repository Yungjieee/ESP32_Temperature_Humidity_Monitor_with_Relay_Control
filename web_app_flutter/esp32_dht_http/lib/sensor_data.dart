import 'package:intl/intl.dart';

class SensorData {
  final int id;
  final double temperature;
  final double humidity;
  final String timestamp;
  final String relayStatus;

  SensorData({
    required this.id,
    required this.temperature,
    required this.humidity,
    required this.timestamp,
    required this.relayStatus,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      id: json['id'] ?? 0,
      temperature: (json['temp'] ?? 0).toDouble(),
      humidity: (json['hum'] ?? 0).toDouble(),
      timestamp: json['timestamp'] ?? 'Unknown',
      relayStatus: json['relay_status'] ?? 'OFF',
    );
  }

    String get formattedTimestamp {
    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat('d MMM yyyy, h:mm:ss a').format(dateTime);
    } catch (_) {
      return 'Invalid Date';
    }
  }

   // Add this getter for DateTimeAxis usage
  DateTime get dateTime {
    try {
      return DateTime.parse(timestamp);
    } catch (_) {
      return DateTime.now(); // fallback to now or handle as needed
    }
  }
}
