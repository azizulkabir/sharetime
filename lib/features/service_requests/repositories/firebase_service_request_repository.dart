import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/service_request.dart';

class FirebaseServiceRequestRepository {
  FirebaseServiceRequestRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<ProviderRateQuote?> fetchProviderRateQuote(String providerId) async {
    final snapshot =
        await _firestore.collection('serviceRateQuotes').doc(providerId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return ProviderRateQuote.fromMap(data);
  }

  Stream<List<IncomingServiceRequest>> watchIncomingRequests() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(const <IncomingServiceRequest>[]);
    }

    return _firestore
        .collection('serviceRequests')
        .where('providerId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs
          .map(IncomingServiceRequest.fromDocument)
          .where((request) => request.status == 'pending')
          .toList();

      requests.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return requests;
    });
  }

  Stream<List<IncomingServiceRequest>> watchMyRequests() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(const <IncomingServiceRequest>[]);
    }

    return _firestore
        .collection('serviceRequests')
        .where('requesterId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final requests =
          snapshot.docs.map(IncomingServiceRequest.fromDocument).toList();

      requests.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return requests;
    });
  }

  Future<void> respondToRequest({
    required String requestId,
    required bool accept,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }

    await _firestore.collection('serviceRequests').doc(requestId).update({
      'status': accept ? 'accepted' : 'declined',
      'respondedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String> createRequest({
    required String providerId,
    required String providerName,
    required ServiceType serviceType,
    required double ratePerMinute,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }
    if (providerId == user.uid) {
      throw StateError('You cannot request your own service.');
    }

    final requesterName = (user.displayName ?? '').trim();

    final document = _firestore.collection('serviceRequests').doc();
    await document.set({
      'requesterId': user.uid,
      'requesterName':
          requesterName.isEmpty ? 'ShareTime User' : requesterName,
      'providerId': providerId,
      'providerName': providerName.trim(),
      'serviceType': serviceType.key,
      'ratePerMinute': ratePerMinute,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }
}
