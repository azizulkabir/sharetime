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

  Stream<IncomingServiceRequest?> watchRequest(String requestId) {
    return _firestore
        .collection('serviceRequests')
        .doc(requestId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return IncomingServiceRequest.fromDocument(snapshot);
    });
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

    final requestRef = _firestore.collection('serviceRequests').doc(requestId);
    final requestSnapshot = await requestRef.get();
    final requestData = requestSnapshot.data();

    if (!requestSnapshot.exists || requestData == null) {
      throw StateError('Service request not found.');
    }

    if (!accept) {
      await requestRef.update({
        'status': 'declined',
        'respondedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final sessionRef = _firestore.collection('serviceSessions').doc(requestId);
    final batch = _firestore.batch();

    batch.update(requestRef, {
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'sessionId': requestId,
    });

    batch.set(sessionRef, {
      'requestId': requestId,
      'requesterId': requestData['requesterId'],
      'requesterName': requestData['requesterName'],
      'providerId': requestData['providerId'],
      'providerName': requestData['providerName'],
      'participants': [
        requestData['requesterId'],
        requestData['providerId'],
      ],
      'serviceType': requestData['serviceType'],
      'ratePerMinute': requestData['ratePerMinute'],
      'status': 'ready',
      if (requestData['serviceType'] == 'audio' ||
          requestData['serviceType'] == 'video') ...{
        'callStatus': 'active',
        'callEndedBy': '',
        'callEndedAt': null,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
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
