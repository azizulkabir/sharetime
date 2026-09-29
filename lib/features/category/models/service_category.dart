class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.requiresVerification,
  });

  final String id;
  final String name;
  final bool requiresVerification;

  factory ServiceCategory.fromMap(String id, Map<String, dynamic> data) {
    return ServiceCategory(
      id: id,
      name: (data['name'] as String?) ?? '',
      requiresVerification:
          (data['requiresVerification'] as bool?) ?? false,
    );
  }
}
