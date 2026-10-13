import 'package:flutter/material.dart';

import '../calls/audio_call_screen.dart';
import '../calls/video_call_screen.dart';
import '../chat/chat_screen.dart';
import '../sessions/models/service_session.dart';
import '../sessions/repositories/firebase_service_session_repository.dart';
import 'models/service_request.dart';
import 'repositories/firebase_service_request_repository.dart';

class WaitingForServiceRequestScreen extends StatefulWidget {
  const WaitingForServiceRequestScreen({
    super.key,
    required this.requestId,
    required this.providerName,
    required this.serviceType,
  });

  final String requestId;
  final String providerName;
  final ServiceType serviceType;

  @override
  State<WaitingForServiceRequestScreen> createState() =>
      _WaitingForServiceRequestScreenState();
}

class _WaitingForServiceRequestScreenState
    extends State<WaitingForServiceRequestScreen> {
  final _requestRepository = FirebaseServiceRequestRepository();
  final _sessionRepository = FirebaseServiceSessionRepository();
  bool _openingSession = false;

  void _openSession(ServiceSession session) {
    if (_openingSession || !mounted) return;
    _openingSession = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Widget screen;
      switch (session.serviceType) {
        case ServiceType.text:
          screen = ChatScreen(session: session);
          break;
        case ServiceType.audio:
          screen = AudioCallScreen(session: session);
          break;
        case ServiceType.video:
          screen = VideoCallScreen(session: session);
          break;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => screen),
      );
    });
  }

  IconData get _serviceIcon {
    switch (widget.serviceType) {
      case ServiceType.text:
        return Icons.chat_bubble_outline_rounded;
      case ServiceType.audio:
        return Icons.call_outlined;
      case ServiceType.video:
        return Icons.videocam_outlined;
    }
  }

  String get _acceptedLabel {
    switch (widget.serviceType) {
      case ServiceType.text:
        return 'Accepted. Opening chat...';
      case ServiceType.audio:
        return 'Accepted. Opening audio call...';
      case ServiceType.video:
        return 'Accepted. Opening video call...';
    }
  }

  String get _waitingDescription {
    switch (widget.serviceType) {
      case ServiceType.text:
        return 'Your text request has been sent. The chat will open automatically when the provider accepts.';
      case ServiceType.audio:
        return 'Your audio request has been sent. The call screen will open automatically when the provider accepts.';
      case ServiceType.video:
        return 'Your video request has been sent. The video call screen will open automatically when the provider accepts.';
    }
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
                      '${widget.providerName} declined this ${widget.serviceType.label.toLowerCase()} request.',
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
                  _openSession(session);
                }

                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text(
                        _acceptedLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
                  Icon(_serviceIcon, size: 52),
                  const SizedBox(height: 18),
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
                  Text(
                    _waitingDescription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
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
