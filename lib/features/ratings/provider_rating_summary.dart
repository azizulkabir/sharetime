import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProviderRatingSummary extends StatelessWidget {
  const ProviderRatingSummary({
    super.key,
    required this.providerId,
  });

  final String providerId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('providerRatingScores')
          .doc(providerId)
          .collection('received')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Rating unavailable',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 14,
            width: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final scores = snapshot.data!.docs
            .map((doc) => doc.data()['score'])
            .whereType<num>()
            .map((value) => value.toDouble())
            .where((value) => value >= 1 && value <= 5)
            .toList();

        if (scores.isEmpty) {
          return const Text(
            'No ratings yet',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
          );
        }

        final average =
            scores.reduce((first, second) => first + second) / scores.length;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
            const SizedBox(width: 4),
            Text(
              average.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 5),
            Text(
              '(${scores.length} ratings)',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}
