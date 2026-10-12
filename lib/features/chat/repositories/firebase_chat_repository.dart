import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../sessions/models/service_session.dart';
import '../../sessions/repositories/firebase_service_session_repository.dart';
import '../models/chat_message.dart';

class FirebaseChatRepository {
  FirebaseChatRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _sessionRepository = FirebaseServiceSessionRepository(
          auth: auth,
          firestore: firestore,
        );

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseServiceSessionRepository _sessionRepository;

  Stream<List<ServiceSession>> watchMyTextChats() {
    return _sessionRepository.watchMySessions().map(
          (sessions) => sessions
              .where((session) => session.serviceType.key == 'text')
              .toList(),
        );
  }

  Stream<List<ChatMessage>> watchMessages(String sessionId) {
    return _firestore
        .collection('serviceSessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(ChatMessage.fromDocument).toList(),
        );
  }

  Future<void> sendMessage({
    required String sessionId,
    required String text,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }

    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final sessionRef =
        _firestore.collection('serviceSessions').doc(sessionId);
    final messageRef = sessionRef.collection('messages').doc();

    final batch = _firestore.batch();
    batch.set(messageRef, {
      'senderId': user.uid,
      'text': cleanText,
      'sentAt': FieldValue.serverTimestamp(),
    });
    batch.update(sessionRef, {
      'lastMessage': cleanText,
      'lastMessageSenderId': user.uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }
}
