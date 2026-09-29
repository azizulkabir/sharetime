import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/sharetime_user.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Stream<String?> authStateChanges() {
    return _auth.authStateChanges().map((user) => user?.uid);
  }

  @override
  Future<ShareTimeUser> registerWithEmailAndPassword({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String categoryId,
    required String categoryName,
    required bool requiresVerification,
  }) async {
    UserCredential? credential;

    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw StateError('Firebase did not return a user after registration.');
      }

      await firebaseUser.updateDisplayName(fullName.trim());

      final user = ShareTimeUser(
        id: firebaseUser.uid,
        fullName: fullName.trim(),
        email: email.trim(),
        phoneNumber: phoneNumber.trim(),
        categoryId: categoryId,
        categoryName: categoryName,
        requiresVerification: requiresVerification,
        verificationStatus:
            requiresVerification ? 'pending_submission' : 'not_required',
        createdAt: DateTime.now().toUtc(),
      );

      await _firestore.collection('users').doc(firebaseUser.uid).set(
            user.toMap(),
          );

      return user;
    } catch (_) {
      if (credential?.user != null) {
        try {
          await credential!.user!.delete();
        } catch (_) {
          // If rollback fails, backend/admin cleanup can handle the orphaned
          // authentication record later.
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  @override
  Future<void> signOut() {
    return _auth.signOut();
  }
}
