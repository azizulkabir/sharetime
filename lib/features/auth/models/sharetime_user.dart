class ShareTimeUser {
  const ShareTimeUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.categoryId,
    required this.categoryName,
    required this.requiresVerification,
    required this.verificationStatus,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String categoryId;
  final String categoryName;
  final bool requiresVerification;
  final String verificationStatus;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'requiresVerification': requiresVerification,
      'verificationStatus': verificationStatus,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  factory ShareTimeUser.fromMap(String id, Map<String, dynamic> data) {
    return ShareTimeUser(
      id: id,
      fullName: (data['fullName'] as String?) ?? '',
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
    );
  }
}
