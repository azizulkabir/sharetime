import 'package:flutter/material.dart';

import '../auth/models/sharetime_user.dart';
import 'repositories/firebase_profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = FirebaseProfileRepository();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _aboutController = TextEditingController();
  final _interestsController = TextEditingController();
  final _hobbiesController = TextEditingController();
  final _languagesController = TextEditingController();

  ShareTimeUser? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUpdatingAvailability = false;
  bool _isAvailable = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _aboutController.dispose();
    _interestsController.dispose();
    _hobbiesController.dispose();
    _languagesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profile = await _repository.fetchCurrentUserProfile();
      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _errorMessage = 'Profile data is not available yet.';
          _isLoading = false;
        });
        return;
      }

      _fullNameController.text = profile.fullName;
      _phoneController.text = profile.phoneNumber;
      _aboutController.text = profile.aboutMe;
      _interestsController.text = profile.interests;
      _hobbiesController.text = profile.hobbies;
      _languagesController.text = profile.languages;

      setState(() {
        _profile = profile;
        _isAvailable = profile.isAvailable;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load profile.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _repository.updateProfile(
        fullName: _fullNameController.text,
        phoneNumber: _phoneController.text,
        aboutMe: _aboutController.text,
        interests: _interestsController.text,
        hobbies: _hobbiesController.text,
        languages: _languagesController.text,
      );

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(Icons.check_circle_rounded),
            title: const Text('Save your profile'),
            content: const Text(
              'Your profile has been saved successfully.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update profile.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _setAvailability(bool value) async {
    if (_isUpdatingAvailability) return;

    final previous = _isAvailable;
    setState(() {
      _isAvailable = value;
      _isUpdatingAvailability = true;
    });

    try {
      await _repository.updateAvailability(value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'You are now available for service.'
                : 'You are now unavailable for service.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAvailable = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update availability.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingAvailability = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My profile',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isAvailable
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: _isAvailable
                              ? colors.primary
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Service availability',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _isAvailable
                                    ? 'Available to receive service requests'
                                    : 'Unavailable for new service requests',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isAvailable,
                          onChanged: _isUpdatingAvailability
                              ? null
                              : _setAvailability,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _fullNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter your full name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          initialValue: _profile?.email ?? '',
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          initialValue: _profile?.categoryName ?? '',
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _aboutController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'About me',
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.info_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _interestsController,
                          decoration: const InputDecoration(
                            labelText: 'Interests',
                            hintText: 'Example: Technology, books, travel',
                            prefixIcon: Icon(Icons.favorite_border_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _hobbiesController,
                          decoration: const InputDecoration(
                            labelText: 'Hobbies',
                            prefixIcon: Icon(Icons.interests_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _languagesController,
                          decoration: const InputDecoration(
                            labelText: 'Languages',
                            hintText: 'Example: Bangla, English',
                            prefixIcon: Icon(Icons.translate_rounded),
                          ),
                        ),
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Save profile'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
