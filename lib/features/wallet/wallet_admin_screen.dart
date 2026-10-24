import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const walletApiUrl = String.fromEnvironment('SHARETIME_WALLET_API_URL');

class WalletAdminScreen extends StatefulWidget {
  const WalletAdminScreen({super.key});

  @override
  State<WalletAdminScreen> createState() => _WalletAdminScreenState();
}

class _WalletAdminScreenState extends State<WalletAdminScreen> {
  final _uid = TextEditingController();
  final _bonus = TextEditingController(text: '50');
  bool _admin = false;
  bool _checking = true;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _uid.addListener(_refreshUid);
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdTokenResult(true);
      if (!mounted) return;
      setState(() {
        _admin = token?.claims?['admin'] == true;
        _checking = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  void _refreshUid() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _uid.removeListener(_refreshUid);
    _uid.dispose();
    _bonus.dispose();
    super.dispose();
  }

  Future<void> _invoke(Map<String, dynamic> payload) async {
    if (_busy || !_admin || walletApiUrl.isEmpty) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (token == null) throw StateError('Sign in required');
      final response = await http.post(
        Uri.parse(walletApiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 20));
      final decoded = jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(
          decoded is Map ? (decoded['message'] ?? 'Request failed').toString() : 'Request failed',
        );
      }
      if (!mounted) return;
      setState(() => _status = 'Saved successfully.');
    } catch (error) {
      if (mounted) setState(() => _status = 'Could not save: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet administration')),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : !_admin
              ? const Center(child: Text('Admin access required.'))
              : walletApiUrl.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Wallet API is not deployed/configured. '
                          'Admin controls remain disabled until the secure endpoint is active.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text('Welcome bonus (BDT)',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _bonus,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Welcome bonus amount',
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: _busy ? null : () {
                            final amount = int.tryParse(_bonus.text.trim());
                            if (amount == null || amount < 0 || amount > 10000) {
                              setState(() => _status = 'Enter an integer from 0 to 10000 BDT.');
                              return;
                            }
                            _invoke({
                              'action': 'setWelcomeBonus',
                              'amountPaisa': amount * 100,
                            });
                          },
                          child: const Text('Save welcome bonus'),
                        ),
                        const SizedBox(height: 28),
                        Text('User withdrawal permission',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _uid,
                          decoration: const InputDecoration(
                            labelText: 'Firebase user UID',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: _busy || _uid.text.trim().isEmpty
                                    ? null
                                    : () => _invoke({
                                          'action': 'setWithdrawalPermission',
                                          'userId': _uid.text.trim(),
                                          'enabled': true,
                                        }),
                                child: const Text('Enable'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _busy || _uid.text.trim().isEmpty
                                    ? null
                                    : () => _invoke({
                                          'action': 'setWithdrawalPermission',
                                          'userId': _uid.text.trim(),
                                          'enabled': false,
                                        }),
                                child: const Text('Disable'),
                              ),
                            ),
                          ],
                        ),
                        if (_status != null) ...[
                          const SizedBox(height: 16),
                          Text(_status!),
                        ],
                        const SizedBox(height: 20),
                        const Text(
                          'Admin actions require a verified Firebase admin claim. '
                          'Money transfers and payout reconciliation are not enabled here.',
                        ),
                      ],
                    ),
    );
  }
}
