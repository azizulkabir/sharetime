import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    required this.deliveredAt,
    required this.readAt,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  bool get isDelivered => deliveredAt != null;
  bool get isRead => readAt != null;

  factory ChatMessage.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return ChatMessage(
      id: document.id,
      senderId: (data['senderId'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
    );
  }
}
