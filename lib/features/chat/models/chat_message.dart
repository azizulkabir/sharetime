import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime? sentAt;

  factory ChatMessage.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return ChatMessage(
      id: document.id,
      senderId: (data['senderId'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
    );
  }
}
