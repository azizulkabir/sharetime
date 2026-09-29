import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../auth/models/sharetime_user.dart';
import '../auth/repositories/firebase_auth_repository.dart';
import '../profile/repositories/firebase_profile_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authRepository = FirebaseAuthRepository();
  final _profileRepository = FirebaseProfileRepository();

  ShareTimeUser? _profile;
  User? _authUser;
  bool _isLoading = true;
  bool _isSigningOut = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _profileRepository.fetchCurrentUserProfile();

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _authUser = _profileRepository.currentAuthUser;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authUser = _profileRepository.currentAuthUser;
        _errorMessage = 'Could not load your profile from Firestore.';
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;

    setState(() {
      _isSigningOut = true;
    });

    try {
      await _authRepository.signOut();

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  String get _displayName {
    final profileName = _profile?.fullName.trim();
    if (profileName != null && profileName.isNotEmpty) {
      return profileName;
    }

    final authName = _authUser?.displayName?.trim();
    if (authName != null && authName.isNotEmpty) {
      return authName;
    }

    return 'ShareTime User';
  }

  String get _email {
    final profileEmail = _profile?.email.trim();
    if (profileEmail != null && profileEmail.isNotEmpty) {
      return profileEmail;
    }
    return _authUser?.email ?? 'Email unavailable';
  }

  String _verificationLabel() {
    switch (_profile?.verificationStatus) {
      case 'pending_submission':
        return 'Documents required';
      case 'pending_review':
        return 'Verification pending';
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Verification needs attention';
      default:
        return 'Not required';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ShareTime',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadProfile,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _isSigningOut ? null : _signOut,
            icon: _isSigningOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        child: _isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 220),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Text(
                    'Welcome, $_displayName',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your ShareTime dashboard',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: colors.primaryContainer,
                          child: Text(
                            _displayName.isEmpty
                                ? 'S'
                                : _displayName[0].toUpperCase(),
                            style: TextStyle(
                              color: colors.onPrimaryContainer,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayName,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _profile?.categoryName.isNotEmpty == true
                                    ? _profile!.categoryName
                                    : 'Category not synced',
                                style: TextStyle(color: colors.primary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _email,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_errorMessage != null || _profile == null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: colors.onErrorContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage ??
                                  'Your account is active, but the Firestore profile is still syncing.',
                              style: TextStyle(
                                color: colors.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    'Account overview',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _OverviewCard(
                    icon: Icons.category_outlined,
                    title: 'Category',
                    value: _profile?.categoryName.isNotEmpty == true
                        ? _profile!.categoryName
                        : 'Not available',
                  ),
                  const SizedBox(height: 10),
                  _OverviewCard(
                    icon: Icons.verified_user_outlined,
                    title: 'Verification',
                    value: _verificationLabel(),
                  ),
                  const SizedBox(height: 10),
                  _OverviewCard(
                    icon: Icons.radio_button_checked_rounded,
                    title: 'Service availability',
                    value: _profile?.isAvailable == true
                        ? 'Available'
                        : 'Unavailable',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Quick actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.35,
                    children: [
                      _QuickActionCard(
                        icon: Icons.person_outline_rounded,
                        title: 'My profile',
                        subtitle: 'Edit profile',
                        onTap: () async {
                          await Navigator.pushNamed(
                            context,
                            AppRoutes.profile,
                          );
                          if (mounted) {
                            _loadProfile();
                          }
                        },
                      ),
                      const _QuickActionCard(
                        icon: Icons.search_rounded,
                        title: 'Discover',
                        subtitle: 'Coming next',
                      ),
                      const _QuickActionCard(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Messages',
                        subtitle: 'Coming next',
                      ),
                      const _QuickActionCard(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Wallet',
                        subtitle: 'Coming next',
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.primary),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
