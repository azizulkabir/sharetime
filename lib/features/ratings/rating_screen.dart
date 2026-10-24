import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../sessions/models/service_session.dart';
import 'repositories/firebase_rating_repository.dart';

class RatingScreen extends StatefulWidget {
  const RatingScreen({
    super.key,
    required this.session,
  });

  final ServiceSession session;

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  late final FirebaseRatingRepository _repository;
  int _selectedScore = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _repository = FirebaseRatingRepository();
  }

  String get _otherName {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final name = uid == widget.session.requesterId
        ? widget.session.providerName
        : widget.session.requesterName;
    return name.trim().isEmpty ? 'this user' : name.trim();
  }

  Future<void> _submit() async {
    if (_selectedScore == 0 || _submitting) return;

    setState(() => _submitting = true);
    try {
      await _repository.submitRating(
        session: widget.session,
        score: _selectedScore,
      );
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 42,
            ),
            title: const Text('Thank you for your rating'),
            content: Text(
              'You rated $_otherName $_selectedScore/5.',
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit rating: $error')),
      );
    }
  }

  void _cancel() {
    if (_submitting) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rate session',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<int?>(
        stream: _repository.watchMyRating(widget.session.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load rating.'));
          }
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final existingScore = snapshot.data;
          if (existingScore != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 64,
                      color: Color(0xFF16A34A),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Thanks for your rating',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'You rated $_otherName $existingScore/5.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
            children: [
              const Icon(Icons.star_rounded, size: 58),
              const SizedBox(height: 18),
              Text(
                'How was your session with $_otherName?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose a rating from 1 to 5 stars.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final value = index + 1;
                  final selected = value <= _selectedScore;
                  return IconButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _selectedScore = value),
                    iconSize: 46,
                    icon: Icon(
                      selected ? Icons.star_rounded : Icons.star_border_rounded,
                      color: selected
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF94A3B8),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 30),
              FilledButton(
                onPressed:
                    _selectedScore == 0 || _submitting ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Submit rating',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _submitting ? null : _cancel,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
