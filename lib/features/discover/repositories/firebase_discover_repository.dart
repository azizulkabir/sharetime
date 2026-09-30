import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/public_provider.dart';

class FirebaseDiscoverRepository {
  FirebaseDiscoverRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<List<PublicProvider>> fetchAvailableProviders() async {
    final currentUid = _auth.currentUser?.uid;

    final snapshot = await _firestore
        .collection('publicProfiles')
        .where('isAvailable', isEqualTo: true)
        .get();

    final providers = snapshot.docs
        .where((doc) => doc.id != currentUid)
        .map((doc) => PublicProvider.fromMap(doc.id, doc.data()))
        .where((provider) => provider.fullName.trim().isNotEmpty)
        .toList();

    providers.sort((a, b) {
      final categoryCompare =
          a.categoryName.toLowerCase().compareTo(b.categoryName.toLowerCase());
      if (categoryCompare != 0) return categoryCompare;
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });

    return providers;
  }
}
