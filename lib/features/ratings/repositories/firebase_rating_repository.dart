import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../sessions/models/service_session.dart';
import '../../service_requests/models/service_request.dart';

class FirebaseRatingRepository {
  FirebaseRatingRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _myRatingRef(String sessionId) {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }

    return _firestore
        .collection('serviceSessions')
        .doc(sessionId)
        .collection('ratings')
        .doc(user.uid);
  }

  Stream<int?> watchMyRating(String sessionId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _myRatingRef(sessionId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return (snapshot.data()?['score'] as num?)?.toInt();
    });
  }

  Future<void> submitRating({
    required ServiceSession session,
    required int score,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    if (score < 1 || score > 5) {
      throw ArgumentError.value(score, 'score', 'Rating must be between 1 and 5.');
    }

    final ratedUserId = user.uid == session.requesterId
        ? session.providerId
        : session.requesterId;

    if (ratedUserId.isEmpty || ratedUserId == user.uid) {
      throw StateError('Could not determine the other participant.');
    }

    await _myRatingRef(session.id).set(<String, dynamic>{
      'sessionId': session.id,
      'raterId': user.uid,
      'ratedUserId': ratedUserId,
      'serviceType': session.serviceType.key,
      'score': score,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
