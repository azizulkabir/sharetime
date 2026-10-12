import 'package:flutter/material.dart';

import '../chat/chat_screen.dart';
import '../sessions/models/service_session.dart';
import '../sessions/repositories/firebase_service_session_repository.dart';
import 'models/service_request.dart';
import 'repositories/firebase_service_request_repository.dart';

class WaitingForTextRequestScreen extends StatefulWidget {
  const WaitingForTextRequestScreen({
    super.key,
    required this.requestId,
    required this.providerName,
  });

  final String requestId;
  final String providerName;

  @override
  State<WaitingForTextRequestScreen> createState() =>
      _WaitingForTextRequestScreenState();
}

class _WaitingForTextRequestScreenState
    extends State<WaitingForTextRequestScreen> {
  final _requestRepository = FirebaseServiceRequestRepository();
  final _sessionRepository = FirebaseServiceSessionRepository();
  bool _openingChat = false;

  void _openChat(ServiceSession session) {
    if (_openingChat || !mounted) return;
    _openingChat = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(session: session),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Waiting for response',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<IncomingServiceRequest?>(
        stream: _requestRepository.watchRequest(widget.requestId),
        builder: (context, requestSnapshot) {
          if (requestSnapshot.hasError) {
            return const Center(
              child: Text('Could not load request status.'),
            );
          }

          if (!requestSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final request = requestSnapshot.data;
          if (request == null) {
            return const Center(child: Text('Request not found.'));
          }

          if (request.status == 'declined') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cancel_outlined, size: 56),
                    const SizedBox(height: 14),
                    const Text(
                      'Request declined',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.providerName} declined this text request.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (request.status == 'accepted') {
            return StreamBuilder<ServiceSession?>(
              stream: _sessionRepository.watchSession(widget.requestId),
              builder: (context, sessionSnapshot) {
                final session = sessionSnapshot.data;
                if (session != null) {
                  _openChat(session);
                }

                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 14),
                      Text(
                        'Accepted. Opening chat...',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              },
            );
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 18),
                  Text(
                    'Waiting for ${widget.providerName}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your text request has been sent. The chat will open automatically when the provider accepts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
