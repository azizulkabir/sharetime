class PublicProvider {
  const PublicProvider({
    required this.id,
    required this.fullName,
    required this.categoryId,
    required this.categoryName,
    required this.aboutMe,
    required this.interests,
    required this.hobbies,
    required this.languages,
    required this.isAvailable,
  });

  final String id;
  final String fullName;
  final String categoryId;
  final String categoryName;
  final String aboutMe;
  final String interests;
  final String hobbies;
  final String languages;
  final bool isAvailable;

  factory PublicProvider.fromMap(String id, Map<String, dynamic> data) {
    return PublicProvider(
      id: id,
      fullName: (data['fullName'] as String?) ?? '',
      categoryId: (data['categoryId'] as String?) ?? '',
      categoryName: (data['categoryName'] as String?) ?? '',
      aboutMe: (data['aboutMe'] as String?) ?? '',
      interests: (data['interests'] as String?) ?? '',
      hobbies: (data['hobbies'] as String?) ?? '',
      languages: (data['languages'] as String?) ?? '',
      isAvailable: (data['isAvailable'] as bool?) ?? false,
    );
  }
}
