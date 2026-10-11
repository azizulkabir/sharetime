import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/provider_rate_setup.dart';
import '../models/rate_policy.dart';
import '../models/service_rates.dart';

class FirebaseRatesRepository {
  FirebaseRatesRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<ProviderRateSetup> fetchMyRateSetup() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }

    final results = await Future.wait([
      _firestore.collection('users').doc(user.uid).get(),
      _firestore.collection('appConfig').doc('ratePolicy').get(),
    ]);

    final userSnapshot = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final policySnapshot = results[1] as DocumentSnapshot<Map<String, dynamic>>;

    final userData = userSnapshot.data() ?? <String, dynamic>{};
    final policy = RatePolicy.fromMap(policySnapshot.data());

    final rates = ServiceRates.fromMap(
      userData['serviceRates'] is Map
          ? Map<String, dynamic>.from(userData['serviceRates'] as Map)
          : null,
    );

    final progress = ProviderRateProgress.fromMap(
      userData['providerProgress'] is Map
          ? Map<String, dynamic>.from(userData['providerProgress'] as Map)
          : null,
    );

    return ProviderRateSetup(
      rates: rates,
      policy: policy,
      progress: progress,
    );
  }

  Future<void> saveMyRates(ServiceRates rates) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }

    final setup = await fetchMyRateSetup();

    if (rates.textPerMinute > setup.maxTextRate ||
        rates.audioPerMinute > setup.maxAudioRate ||
        rates.videoPerMinute > setup.maxVideoRate) {
      throw StateError('One or more rates exceed the current level ceiling.');
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
