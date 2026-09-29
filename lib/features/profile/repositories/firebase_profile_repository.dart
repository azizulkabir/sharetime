import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/models/sharetime_user.dart';

class FirebaseProfileRepository {
  FirebaseProfileRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  User? get currentAuthUser => _auth.currentUser;

  Future<ShareTimeUser?> fetchCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    final data = snapshot.data();

    if (!snapshot.exists || data == null) {
      return null;
    }

    return ShareTimeUser.fromMap(snapshot.id, data);
  }
}
