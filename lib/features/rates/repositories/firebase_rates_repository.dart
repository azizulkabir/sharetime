import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/service_rates.dart';

class FirebaseRatesRepository {
  FirebaseRatesRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<ServiceRates> fetchMyRates() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }

    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    final data = snapshot.data();
    return ServiceRates.fromMap(data?['serviceRates'] as Map<String, dynamic>?);
  }

  Future<void> saveMyRates(ServiceRates rates) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }

    await _firestore.collection('users').doc(user.uid).set(
      {
        'serviceRates': rates.toMap(),
        'ratesUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
