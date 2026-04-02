class VitalLog {
  final String id;
  final String type; // 'bp', 'hr', 'weight'
  final String value;
  final DateTime timestamp;

  VitalLog({
    required this.id,
    required this.type,
    required this.value,
    required this.timestamp,
  });

  factory VitalLog.fromJson(Map<String, dynamic> json) {
    return VitalLog(
      id: json['id'] as String,
      type: json['type'] as String,
      value: json['value'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'value': value,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String get unit {
    switch (type) {
      case 'bp':
        return 'mmHg';
      case 'hr':
        return 'BPM';
      case 'weight':
        return 'lbs'; // Assumed lbs for MVP simplicity, can be dynamic
      default:
        return '';
    }
  }

  String get label {
    switch (type) {
      case 'bp':
        return 'Blood Pressure';
      case 'hr':
        return 'Heart Rate';
      case 'weight':
        return 'Weight';
      default:
        return 'Vital';
    }
  }
}
