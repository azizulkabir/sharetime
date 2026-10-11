import 'package:flutter/material.dart';

import 'models/public_provider.dart';

class PublicProviderProfileScreen extends StatelessWidget {
  const PublicProviderProfileScreen({
    super.key,
    required this.provider,
  });

  final PublicProvider provider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial =
        provider.fullName.isEmpty ? 'S' : provider.fullName[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Provider Profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: colors.primaryContainer,
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                          fontSize: 30,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 19,
                        height: 19,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  provider.fullName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  provider.categoryName.isEmpty
                      ? 'Service provider'
                      : provider.categoryName,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 9,
                        color: Color(0xFF16A34A),
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Available now',
                        style: TextStyle(
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ProfileSection(
            title: 'About Me',
            icon: Icons.person_outline_rounded,
            value: provider.aboutMe,
            emptyText: 'No information added yet.',
          ),
          const SizedBox(height: 12),
          _ProfileSection(
            title: 'Interests',
            icon: Icons.favorite_border_rounded,
            value: provider.interests,
            emptyText: 'No interests added yet.',
          ),
          const SizedBox(height: 12),
          _ProfileSection(
            title: 'Hobbies',
            icon: Icons.auto_awesome_outlined,
            value: provider.hobbies,
            emptyText: 'No hobbies added yet.',
          ),
          const SizedBox(height: 12),
          _ProfileSection(
            title: 'Languages',
            icon: Icons.language_rounded,
            value: provider.languages,
            emptyText: 'No languages added yet.',
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Private contact information such as email and phone number is not shown on public profiles.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.value,
    required this.emptyText,
  });

  final String title;
  final IconData icon;
  final String value;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final cleanValue = value.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            cleanValue.isEmpty ? emptyText : cleanValue,
            style: TextStyle(
              color: cleanValue.isEmpty
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF475569),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
