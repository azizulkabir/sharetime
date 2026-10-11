enum ServiceType {
  text,
  audio,
  video,
}

extension ServiceTypeX on ServiceType {
  String get key {
    switch (this) {
      case ServiceType.text:
        return 'text';
      case ServiceType.audio:
        return 'audio';
      case ServiceType.video:
        return 'video';
    }
  }

  String get label {
    switch (this) {
      case ServiceType.text:
        return 'Text Chat';
      case ServiceType.audio:
        return 'Audio Call';
      case ServiceType.video:
        return 'Video Call';
    }
  }
}

class ProviderRateQuote {
  const ProviderRateQuote({
    required this.textPerMinute,
    required this.audioPerMinute,
    required this.videoPerMinute,
  });

  final double textPerMinute;
  final double audioPerMinute;
  final double videoPerMinute;

  factory ProviderRateQuote.fromMap(Map<String, dynamic> data) {
    return ProviderRateQuote(
      textPerMinute: _toDouble(data['textPerMinute']),
      audioPerMinute: _toDouble(data['audioPerMinute']),
      videoPerMinute: _toDouble(data['videoPerMinute']),
    );
  }

  double rateFor(ServiceType type) {
    switch (type) {
      case ServiceType.text:
        return textPerMinute;
      case ServiceType.audio:
        return audioPerMinute;
      case ServiceType.video:
        return videoPerMinute;
    }
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
