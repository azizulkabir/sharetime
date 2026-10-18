class ShareTimeUser {
  const ShareTimeUser({
    required this.id,
    required this.fullName,
    this.firstName = '',
    this.lastName = '',
    this.loginIdentifier = '',
    required this.email,
    required this.phoneNumber,
    required this.categoryId,
    required this.categoryName,
    required this.requiresVerification,
    required this.verificationStatus,
    required this.createdAt,
    this.aboutMe = '',
    this.interests = '',
    this.hobbies = '',
    this.languages = '',
    this.isAvailable = false,
    this.photoUrl = '',
    this.serviceRates = const <String, dynamic>{
      'textPerMinute': 0.0,
      'audioPerMinute': 0.0,
      'videoPerMinute': 0.0,
      'level': 1,
    },
  });

  final String id;
  final String fullName;
  final String firstName;
  final String lastName;
  final String loginIdentifier;
  final String email;
  final String phoneNumber;
  final String categoryId;
  final String categoryName;
  final bool requiresVerification;
  final String verificationStatus;
  final DateTime createdAt;
  final String aboutMe;
  final String interests;
  final String hobbies;
  final String languages;
  final bool isAvailable;
  final String photoUrl;
  final Map<String, dynamic> serviceRates;

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'firstName': firstName,
      'lastName': lastName,
      'loginIdentifier': loginIdentifier,
      'email': email,
      'phoneNumber': phoneNumber,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'requiresVerification': requiresVerification,
      'verificationStatus': verificationStatus,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'aboutMe': aboutMe,
      'interests': interests,
      'hobbies': hobbies,
      'languages': languages,
      'isAvailable': isAvailable,
      'photoUrl': photoUrl,
      'serviceRates': serviceRates,
      'providerProgress': const {
        'completedOperations': 0,
        'points': 0,
      },
    };
  }

  factory ShareTimeUser.fromMap(String id, Map<String, dynamic> data) {
    return ShareTimeUser(
      id: id,
      fullName: (data['fullName'] as String?) ?? '',
      firstName: (data['firstName'] as String?) ?? '',
      lastName: (data['lastName'] as String?) ?? '',
      loginIdentifier: (data['loginIdentifier'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      phoneNumber: (data['phoneNumber'] as String?) ?? '',
      categoryId: (data['categoryId'] as String?) ?? '',
      categoryName: (data['categoryName'] as String?) ?? '',
      requiresVerification:
          (data['requiresVerification'] as bool?) ?? false,
      verificationStatus:
          (data['verificationStatus'] as String?) ?? 'not_required',
      createdAt: DateTime.tryParse(
            (data['createdAt'] as String?) ?? '',
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      aboutMe: (data['aboutMe'] as String?) ?? '',
      interests: (data['interests'] as String?) ?? '',
      hobbies: (data['hobbies'] as String?) ?? '',
      languages: (data['languages'] as String?) ?? '',
      isAvailable: (data['isAvailable'] as bool?) ?? false,
      photoUrl: (data['photoUrl'] as String?) ?? '',
      serviceRates: Map<String, dynamic>.from(
        (data['serviceRates'] as Map?) ?? const <String, dynamic>{},
      ),
    );
  }
}
