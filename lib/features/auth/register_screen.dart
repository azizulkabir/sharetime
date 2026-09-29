import 'package:flutter/material.dart';

import '../category/models/service_category.dart';
import '../category/repositories/category_repository.dart';
import '../category/repositories/mock_category_repository.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final CategoryRepository _categoryRepository = MockCategoryRepository();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoadingCategories = true;
  String? _categoryError;
  List<ServiceCategory> _categories = const [];
  ServiceCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _categoryError = null;
    });

    try {
      final categories = await _categoryRepository.fetchActiveCategories();

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _isLoadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categoryError = 'Could not load categories';
        _isLoadingCategories = false;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final category = _selectedCategory;
    if (category == null) return;

    final verificationText = category.requiresVerification
        ? ' Verification documents will be requested in the next step.'
        : '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Registration form is ready for ${category.name}.$verificationText',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = _selectedCategory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Join ShareTime',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your account and choose the service category that fits you.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF64748B),
                          ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
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
                    const SizedBox(height: 16),
                    TextFormField(
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter your phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_isLoadingCategories)
                      const InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Loading categories...'),
                          ],
                        ),
                      )
                    else if (_categoryError != null)
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _categoryError!,
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadCategories,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<ServiceCategory>(
                        initialValue: _selectedCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        hint: const Text('Select category'),
                        items: _categories
                            .map(
                              (category) => DropdownMenuItem<ServiceCategory>(
                                value: category,
                                child: Text(category.name),
                              ),
                            )
                            .toList(),
                        onChanged: (category) {
                          setState(() {
                            _selectedCategory = category;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Select a category';
                          }
                          return null;
                        },
                      ),
                    if (selectedCategory?.requiresVerification == true) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'This category requires document verification. You will be able to submit the required documents after account creation.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Use at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoadingCategories ? null : _submit,
                      child: const Text('Create account'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'By creating an account, you agree to the future ShareTime Terms and Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF64748B),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
