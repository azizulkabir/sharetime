import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../service_requests/models/service_request.dart';
import '../calls/audio_call_screen.dart';
import '../chat/chat_screen.dart';
import 'models/service_session.dart';
import 'repositories/firebase_service_session_repository.dart';

class ServiceSessionScreen extends StatelessWidget {
  const ServiceSessionScreen({
    super.key,
    required this.sessionId,
  });

  final String sessionId;

  IconData _iconFor(ServiceType type) {
    switch (type) {
      case ServiceType.text:
        return Icons.chat_bubble_outline_rounded;
      case ServiceType.audio:
        return Icons.call_outlined;
      case ServiceType.video:
        return Icons.videocam_outlined;
    }
  }

  String _formatRate(double rate) {
    if (rate == rate.roundToDouble()) return rate.toInt().toString();
    return rate.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final repository = FirebaseServiceSessionRepository();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Service session',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<ServiceSession?>(
        stream: repository.watchSession(sessionId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Could not load this session.'),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final session = snapshot.data;
          if (session == null) {
            return const Center(child: Text('Session not found.'));
          }

          final isRequester = currentUid == session.requesterId;
          final otherName =
              isRequester ? session.providerName : session.requesterName;
          final colors = Theme.of(context).colorScheme;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: colors.primaryContainer,
                      child: Icon(
                        _iconFor(session.serviceType),
                        color: colors.onPrimaryContainer,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      session.serviceType.label,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'With $otherName',
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Ready',
                        style: TextStyle(
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _InfoCard(
                title: 'Rate snapshot',
                value: '${_formatRate(session.ratePerMinute)} BDT/min',
                icon: Icons.payments_outlined,
              ),
              const SizedBox(height: 10),
              _InfoCard(
                title: 'Session ID',
                value: session.id,
                icon: Icons.tag_rounded,
              ),
              const SizedBox(height: 18),
              if (session.serviceType == ServiceType.text)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ChatScreen(session: session),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Open chat'),
                  ),
                )
              else if (session.serviceType == ServiceType.audio)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AudioCallScreen(session: session),
                        ),
                      );
                    },
                    icon: const Icon(Icons.call_rounded),
                    label: const Text('Open audio call'),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    session.serviceType == ServiceType.audio
                        ? 'The audio calling engine will connect to this session in the WebRTC step.'
                        : 'The video calling engine will connect to this session in the WebRTC step.',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      height: 1.4,
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

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
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
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
