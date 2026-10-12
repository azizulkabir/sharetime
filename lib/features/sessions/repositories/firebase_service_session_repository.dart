import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/service_session.dart';

class FirebaseServiceSessionRepository {
  FirebaseServiceSessionRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<ServiceSession?> watchSession(String sessionId) {
    return _firestore
        .collection('serviceSessions')
        .doc(sessionId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return ServiceSession.fromDocument(snapshot);
    });
  }

  Stream<List<ServiceSession>> watchMySessions() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(const <ServiceSession>[]);
    }

    return _firestore
        .collection('serviceSessions')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
      final sessions =
          snapshot.docs.map(ServiceSession.fromDocument).toList();

      sessions.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return sessions;
    });
  }
}
