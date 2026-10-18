import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/sharetime_user.dart';
import 'auth_repository.dart';

class ProfileSaveException implements Exception {
  const ProfileSaveException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FirebaseAuthRepository implements AuthRepository {
  static String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  static String _internalEmailForPhone(String phone) {
    final normalized = _normalizePhone(phone);
    return 'phone_$normalized@sharetime.internal';
  }

  static bool _looksLikeEmail(String value) {
    final trimmed = value.trim();
    return trimmed.contains('@') && trimmed.contains('.');
  }
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
    String firstName = '',
    String lastName = '',
    String loginIdentifier = '',
    required String email,
    required String phoneNumber,
    required String password,
    required String categoryId,
    required String categoryName,
    required bool requiresVerification,
  }) async {
    final identifier = loginIdentifier.trim().isEmpty
        ? (email.trim().isNotEmpty ? email.trim() : phoneNumber.trim())
        : loginIdentifier.trim();
    final isEmailLogin = _looksLikeEmail(identifier);
    final authEmail = isEmailLogin
        ? identifier
        : _internalEmailForPhone(identifier);

    final credential = await _auth.createUserWithEmailAndPassword(
      email: authEmail,
      password: password,
    );

    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw StateError('Firebase did not return a user after registration.');
    }

    final user = ShareTimeUser(
      id: firebaseUser.uid,
      fullName: fullName.trim(),
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      loginIdentifier: identifier,
      email: isEmailLogin ? identifier : '',
      phoneNumber: isEmailLogin ? phoneNumber.trim() : identifier,
      categoryId: categoryId,
      categoryName: categoryName,
      requiresVerification: requiresVerification,
      verificationStatus:
          requiresVerification ? 'pending_submission' : 'not_required',
      createdAt: DateTime.now().toUtc(),
    );

    try {
      await firebaseUser
          .updateDisplayName(fullName.trim())
          .timeout(const Duration(seconds: 8));

      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(user.toMap())
          .timeout(const Duration(seconds: 10));

      await _firestore
          .collection('publicProfiles')
          .doc(firebaseUser.uid)
          .set({
            'fullName': user.fullName,
            'categoryId': user.categoryId,
            'categoryName': user.categoryName,
            'aboutMe': '',
            'interests': '',
            'hobbies': '',
            'languages': '',
            'photoUrl': '',
            'isAvailable': false,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const ProfileSaveException(
        'Account was created, but profile sync timed out.',
      );
    } on FirebaseException catch (error) {
      throw ProfileSaveException(
        'Account was created, but profile could not be saved: ${error.code}',
      );
    }

    return user;
  }

  @override
  Future<void> signInWithIdentifierAndPassword({
    required String identifier,
    required String password,
  }) async {
    final trimmed = identifier.trim();
    final authEmail =
        _looksLikeEmail(trimmed) ? trimmed : _internalEmailForPhone(trimmed);

    await _auth.signInWithEmailAndPassword(
      email: authEmail,
      password: password,
    );
  }

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return signInWithIdentifierAndPassword(
      identifier: email,
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
