class RatePolicy {
  const RatePolicy({
    this.baseTextRate = 2,
    this.baseAudioRate = 5,
    this.baseVideoRate = 7,
    this.pointsPerLevel = 100,
    this.pointsPerCompletedOperation = 1,
  });

  final double baseTextRate;
  final double baseAudioRate;
  final double baseVideoRate;
  final int pointsPerLevel;
  final int pointsPerCompletedOperation;

  factory RatePolicy.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return RatePolicy(
      baseTextRate: _toDouble(map['baseTextRate'], 2),
      baseAudioRate: _toDouble(map['baseAudioRate'], 5),
      baseVideoRate: _toDouble(map['baseVideoRate'], 7),
      pointsPerLevel: _toInt(map['pointsPerLevel'], 100),
      pointsPerCompletedOperation:
          _toInt(map['pointsPerCompletedOperation'], 1),
    );
  }

  double maxTextRate(int level) => baseTextRate * level;
  double maxAudioRate(int level) => baseAudioRate * level;
  double maxVideoRate(int level) => baseVideoRate * level;

  int levelForPoints(int points) {
    if (pointsPerLevel <= 0) return 1;
    return (points ~/ pointsPerLevel) + 1;
  }

  int pointsIntoCurrentLevel(int points) {
    if (pointsPerLevel <= 0) return 0;
    return points % pointsPerLevel;
  }

  static double _toDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static int _toInt(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class ProviderRateProgress {
  const ProviderRateProgress({
    this.completedOperations = 0,
    this.points = 0,
  });

  final int completedOperations;
  final int points;

  factory ProviderRateProgress.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return ProviderRateProgress(
      completedOperations: (map['completedOperations'] as num?)?.toInt() ?? 0,
      points: (map['points'] as num?)?.toInt() ?? 0,
    );
  }
}
