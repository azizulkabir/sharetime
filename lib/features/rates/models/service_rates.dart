class ServiceRates {
  const ServiceRates({
    this.textPerMinute = 0,
    this.audioPerMinute = 0,
    this.videoPerMinute = 0,
    this.level = 1,
  });

  final double textPerMinute;
  final double audioPerMinute;
  final double videoPerMinute;
  final int level;

  factory ServiceRates.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return ServiceRates(
      textPerMinute: _toDouble(map['textPerMinute']),
      audioPerMinute: _toDouble(map['audioPerMinute']),
      videoPerMinute: _toDouble(map['videoPerMinute']),
      level: (map['level'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'textPerMinute': textPerMinute,
      'audioPerMinute': audioPerMinute,
      'videoPerMinute': videoPerMinute,
      'level': level,
    };
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
