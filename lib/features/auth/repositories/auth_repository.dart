import '../models/sharetime_user.dart';

abstract class AuthRepository {
  Stream<String?> authStateChanges();

  Future<ShareTimeUser> registerWithEmailAndPassword({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String categoryId,
    required String categoryName,
    required bool requiresVerification,
  });

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}
