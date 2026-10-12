import 'package:cloud_firestore/cloud_firestore.dart';

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


class IncomingServiceRequest {
  const IncomingServiceRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.providerId,
    required this.providerName,
    required this.serviceType,
    required this.ratePerMinute,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String requesterId;
  final String requesterName;
  final String providerId;
  final String providerName;
  final ServiceType serviceType;
  final double ratePerMinute;
  final String status;
  final DateTime? createdAt;

  factory IncomingServiceRequest.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final rawType = (data['serviceType'] as String?) ?? 'text';

    return IncomingServiceRequest(
      id: document.id,
      requesterId: (data['requesterId'] as String?) ?? '',
      requesterName:
          (data['requesterName'] as String?) ?? 'ShareTime User',
      providerId: (data['providerId'] as String?) ?? '',
      providerName: (data['providerName'] as String?) ?? '',
      serviceType: ServiceType.values.firstWhere(
        (type) => type.key == rawType,
        orElse: () => ServiceType.text,
      ),
      ratePerMinute: ProviderRateQuote._toDouble(data['ratePerMinute']),
      status: (data['status'] as String?) ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
