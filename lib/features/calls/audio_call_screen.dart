import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../sessions/models/service_session.dart';
import '../sessions/repositories/firebase_service_session_repository.dart';
import 'services/webrtc_call_service.dart';

class AudioCallScreen extends StatefulWidget {
  const AudioCallScreen({
    super.key,
    required this.session,
  });

  final ServiceSession session;

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _muted = false;
  bool _speakerOn = false;
  bool _ended = false;
  bool _endingCall = false;
  late final FirebaseServiceSessionRepository _sessionRepository;
  late final WebRtcCallService _webRtcService;
  StreamSubscription<ServiceSession?>? _sessionSubscription;
  String _connectionLabel = 'Connecting...';
  bool _liveAudioStarted = false;

  @override
  void initState() {
    super.initState();
    _sessionRepository = FirebaseServiceSessionRepository();
    _webRtcService = WebRtcCallService();
    _sessionSubscription =
        _sessionRepository.watchSession(widget.session.id).listen((session) {
      if (!mounted || session == null || !session.isCallEnded || _ended) return;
      setState(() => _ended = true);
      _timer?.cancel();
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (mounted) Navigator.of(context).pop();
      });
    });

    _startLiveAudio();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _ended) return;
      setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sessionSubscription?.cancel();
    unawaited(_webRtcService.dispose());
    super.dispose();
  }

  Future<void> _startLiveAudio() async {
    if (_liveAudioStarted) return;
    _liveAudioStarted = true;

    try {
      await _webRtcService.startAudioCall(
        session: widget.session,
        onConnectionState: (state) {
          if (!mounted) return;

          setState(() {
            switch (state) {
              case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
                _connectionLabel = 'Live audio';
                break;
              case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
                _connectionLabel = 'Connecting...';
                break;
              case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
                _connectionLabel = 'Reconnecting...';
                break;
              case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
                _connectionLabel = 'Connection failed';
                break;
              case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
                _connectionLabel = 'Call ended';
                break;
              default:
                _connectionLabel = 'Connecting...';
            }
          });
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connectionLabel = 'Audio connection unavailable';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Live audio could not start: $error')),
      );
    }
  }

  String get _otherName {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final name = currentUid == widget.session.requesterId
        ? widget.session.providerName
        : widget.session.requesterName;
    return name.trim();
  }

  String get _durationLabel {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _endCall() async {
    if (_ended || _endingCall) return;

    _endingCall = true;
    try {
      await _sessionRepository.endCall(widget.session.id);
    } catch (_) {
      if (!mounted) return;
      _endingCall = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not end the call.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial = _otherName.isEmpty ? 'S' : _otherName[0].toUpperCase();
    final rate = widget.session.ratePerMinute;
    final rateLabel =
        rate == rate.roundToDouble() ? rate.toInt().toString() : rate.toStringAsFixed(2);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _endingCall ? null : _endCall,
                    color: Colors.white,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  const Spacer(),
                  const Text(
                    'ShareTime Audio',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
              const Spacer(),
              CircleAvatar(
                radius: 58,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _otherName.isEmpty ? 'ShareTime user' : _otherName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _ended ? 'Call ended' : '$_connectionLabel • $_durationLabel',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$rateLabel BDT/min',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallAction(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _muted ? 'Unmute' : 'Mute',
                    active: _muted,
                    onPressed: () async {
                      final muted = !_muted;
                      setState(() => _muted = muted);
                      await _webRtcService.setMuted(muted);
                    },
                  ),
                  _CallAction(
                    icon: _speakerOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_down_rounded,
                    label: 'Speaker',
                    active: _speakerOn,
                    onPressed: () async {
                      final speakerOn = !_speakerOn;
                      setState(() => _speakerOn = speakerOn);
                      await _webRtcService.setSpeakerphone(speakerOn);
                    },
                  ),
                  _CallAction(
                    icon: Icons.call_end_rounded,
                    label: 'End',
                    destructive: true,
                    onPressed: _endingCall ? () {} : _endCall,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'Live audio is connected with WebRTC. A TURN server will be added later for stronger connectivity across difficult networks.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallAction extends StatelessWidget {
  const _CallAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final background = destructive
        ? const Color(0xFFDC2626)
        : active
            ? Colors.white
            : Colors.white12;
    final foreground = destructive
        ? Colors.white
        : active
            ? const Color(0xFF0F172A)
            : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: foreground, size: 29),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
