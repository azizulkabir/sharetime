import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Balances are read-only in the Flutter client. Only a trusted backend
/// using Firebase Admin SDK may initialize or modify wallet documents.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  String _money(dynamic raw) {
    if (raw is! int) return 'Unavailable';
    return 'BDT ${(raw / 100).toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('My wallet')),
      body: uid == null
          ? const Center(child: Text('Please sign in to view your wallet.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('walletAccounts')
                  .doc(uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Unable to load wallet securely.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!.data();
                if (data == null) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Your wallet has not been initialized yet. '
                        'Balance and bonus will appear after the secure '
                        'wallet backend is activated. No money is being '
                        'deducted for calls at this stage.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final spending = data['spendingBalancePaisa'];
                final earnings = data['providerEarningsPaisa'];
                final pending = data['pendingWithdrawalPaisa'];
                final valid = spending is int &&
                    earnings is int &&
                    pending is int &&
                    spending >= 0 &&
                    earnings >= 0 &&
                    pending >= 0;

                if (!valid) {
                  return const Center(
                    child: Text('Wallet data needs backend verification.'),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _BalanceCard(
                      title: 'Spending balance',
                      value: _money(spending),
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                    const SizedBox(height: 12),
                    _BalanceCard(
                      title: 'Provider earnings',
                      value: _money(earnings),
                      icon: Icons.trending_up_rounded,
                    ),
                    const SizedBox(height: 12),
                    _BalanceCard(
                      title: 'Pending withdrawal',
                      value: _money(pending),
                      icon: Icons.schedule_outlined,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Balances are updated by the secure server only. '
                      'Wallet top-up, billing, bonuses, and withdrawals '
                      'will become available after backend activation.',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
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
