import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../auth/models/sharetime_user.dart';

class FirebaseProfileRepository {
  FirebaseProfileRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

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

  Future<void> updateProfile({
    required String fullName,
    required String phoneNumber,
    required String aboutMe,
    required String interests,
    required String hobbies,
    required String languages,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }

    await _firestore.collection('users').doc(user.uid).set(
      {
        'fullName': fullName.trim(),
        'phoneNumber': phoneNumber.trim(),
        'aboutMe': aboutMe.trim(),
        'interests': interests.trim(),
        'hobbies': hobbies.trim(),
        'languages': languages.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    ).timeout(const Duration(seconds: 8));

    final privateProfile =
        await _firestore.collection('users').doc(user.uid).get();
    final data = privateProfile.data() ?? <String, dynamic>{};

    await _firestore.collection('publicProfiles').doc(user.uid).set(
      {
        'fullName': fullName.trim(),
        'categoryId': (data['categoryId'] as String?) ?? '',
        'categoryName': (data['categoryName'] as String?) ?? '',
        'aboutMe': aboutMe.trim(),
        'interests': interests.trim(),
        'hobbies': hobbies.trim(),
        'languages': languages.trim(),
        'photoUrl': (data['photoUrl'] as String?) ?? '',
        'isAvailable': (data['isAvailable'] as bool?) ?? false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    ).timeout(const Duration(seconds: 8));

    try {
      await user
          .updateDisplayName(fullName.trim())
          .timeout(const Duration(seconds: 5));
    } on TimeoutException {
      // Firestore is the source of truth for the ShareTime profile.
    }
  }

  Future<String> uploadProfilePhoto({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }

    final extension = _safeImageExtension(fileName);
    final contentType = extension == 'png' ? 'image/png' : 'image/jpeg';
    final reference =
        _storage.ref().child('profilePhotos/${user.uid}/profile.$extension');

    await reference.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );

    final photoUrl = await reference.getDownloadURL();

    await _firestore.collection('users').doc(user.uid).set(
      {
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await _firestore.collection('publicProfiles').doc(user.uid).set(
      {
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    return photoUrl;
  }

  String _safeImageExtension(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    return 'jpg';
  }

  Future<void> updateAvailability(bool isAvailable) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No signed-in user.');
    }

    await _firestore.collection('users').doc(user.uid).set(
      {
        'isAvailable': isAvailable,
        'availabilityUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final privateProfile =
        await _firestore.collection('users').doc(user.uid).get();
    final data = privateProfile.data() ?? <String, dynamic>{};

    await _firestore.collection('publicProfiles').doc(user.uid).set(
      {
        'fullName': (data['fullName'] as String?) ?? user.displayName ?? '',
        'categoryId': (data['categoryId'] as String?) ?? '',
        'categoryName': (data['categoryName'] as String?) ?? '',
        'aboutMe': (data['aboutMe'] as String?) ?? '',
        'interests': (data['interests'] as String?) ?? '',
        'hobbies': (data['hobbies'] as String?) ?? '',
        'languages': (data['languages'] as String?) ?? '',
        'photoUrl': (data['photoUrl'] as String?) ?? '',
        'isAvailable': isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
