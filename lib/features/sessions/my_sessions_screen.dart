import 'package:flutter/material.dart';

import '../ratings/rating_screen.dart';
import '../service_requests/models/service_request.dart';
import 'models/service_session.dart';
import 'repositories/firebase_service_session_repository.dart';
import 'service_session_screen.dart';

class MySessionsScreen extends StatelessWidget {
  const MySessionsScreen({super.key});

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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My sessions',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<ServiceSession>>(
        stream: repository.watchMySessions(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load sessions.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = snapshot.data!;
          if (sessions.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: const [
                SizedBox(height: 120),
                Icon(Icons.meeting_room_outlined, size: 54),
                SizedBox(height: 14),
                Text(
                  'No sessions yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Accepted service requests will create sessions here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ServiceSessionScreen(
                          sessionId: session.id,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          child: Icon(_iconFor(session.serviceType)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.serviceType.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_formatRate(session.ratePerMinute)} BDT/min',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              session.isCallEnded ? 'Ended' : 'Ready',
                              style: TextStyle(
                                color: session.isCallEnded
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF16A34A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (session.isCallEnded &&
                                session.serviceType != ServiceType.text) ...[
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => RatingScreen(
                                        session: session,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.star_outline_rounded),
                                label: const Text('Rate'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
