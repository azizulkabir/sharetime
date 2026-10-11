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
