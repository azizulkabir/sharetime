import 'package:cloud_firestore/cloud_firestore.dart';

import '../../service_requests/models/service_request.dart';

class ServiceSession {
  const ServiceSession({
    required this.id,
    required this.requestId,
    required this.requesterId,
    required this.requesterName,
    required this.providerId,
    required this.providerName,
    required this.serviceType,
    required this.ratePerMinute,
    required this.status,
    required this.createdAt,
    this.lastMessage = '',
    this.lastMessageAt,
    this.lastMessageSenderId = '',
    this.lastMessageReadBy = const <String>[],
  });

  final String id;
  final String requestId;
  final String requesterId;
  final String requesterName;
  final String providerId;
  final String providerName;
  final ServiceType serviceType;
  final double ratePerMinute;
  final String status;
  final DateTime? createdAt;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String lastMessageSenderId;
  final List<String> lastMessageReadBy;

  factory ServiceSession.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    final rawType = (data['serviceType'] as String?) ?? 'text';

    return ServiceSession(
      id: document.id,
      requestId: (data['requestId'] as String?) ?? document.id,
      requesterId: (data['requesterId'] as String?) ?? '',
      requesterName:
          (data['requesterName'] as String?) ?? 'ShareTime User',
      providerId: (data['providerId'] as String?) ?? '',
      providerName: (data['providerName'] as String?) ?? 'Service provider',
      serviceType: ServiceType.values.firstWhere(
        (type) => type.key == rawType,
        orElse: () => ServiceType.text,
      ),
      ratePerMinute: _toDouble(data['ratePerMinute']),
      status: (data['status'] as String?) ?? 'ready',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastMessage: (data['lastMessage'] as String?) ?? '',
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessageSenderId: (data['lastMessageSenderId'] as String?) ?? '',
      lastMessageReadBy: List<String>.from(
        (data['lastMessageReadBy'] as List?) ?? const <String>[],
      ),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
