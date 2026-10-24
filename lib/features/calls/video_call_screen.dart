import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../ratings/rating_screen.dart';
import '../sessions/models/service_session.dart';
import '../sessions/repositories/firebase_service_session_repository.dart';
import 'services/webrtc_call_service.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({
    super.key,
    required this.session,
  });

  final ServiceSession session;

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _muted = false;
  bool _cameraOff = false;
  bool _speakerOn = true;
  bool _frontCamera = true;
  bool _ended = false;
  bool _endingCall = false;
  bool _renderersReady = false;
  bool _liveVideoStarted = false;
  String _connectionLabel = 'Connecting...';

  late final FirebaseServiceSessionRepository _sessionRepository;
  late final WebRtcCallService _webRtcService;
  StreamSubscription<ServiceSession?>? _sessionSubscription;

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
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => RatingScreen(session: session),
          ),
        );
      });
    });

    _initializeRenderersAndCall();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _ended) return;
      setState(() => _elapsedSeconds++);
    });
  }

  Future<void> _initializeRenderersAndCall() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    if (!mounted) return;
    setState(() => _renderersReady = true);

    await _startLiveVideo();
  }

  Future<void> _startLiveVideo() async {
    if (_liveVideoStarted) return;
    _liveVideoStarted = true;

    try {
      await _webRtcService.startVideoCall(
        session: widget.session,
        onConnectionState: (state) {
          if (!mounted) return;

          setState(() {
            switch (state) {
              case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
                _connectionLabel = 'Live video';
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
        onLocalStream: (stream) {
          if (!mounted) return;
          _localRenderer.srcObject = stream;
          setState(() {});
        },
        onRemoteStream: (stream) {
          if (!mounted) return;
          _remoteRenderer.srcObject = stream;
          setState(() {});
        },
      );

      await _webRtcService.setSpeakerphone(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _connectionLabel = 'Video connection unavailable';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Live video could not start: $error')),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sessionSubscription?.cancel();
    unawaited(_webRtcService.dispose());
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
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

  String get _rateLabel {
    final rate = widget.session.ratePerMinute;
    return rate == rate.roundToDouble()
        ? rate.toInt().toString()
        : rate.toStringAsFixed(2);
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
    final remoteReady =
        _renderersReady && _remoteRenderer.srcObject != null;

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _renderersReady && _remoteRenderer.srcObject != null
                  ? RTCVideoView(
                      _remoteRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : Container(
                      alignment: Alignment.center,
                      color: const Color(0xFF0F172A),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 64,
                            backgroundColor: colors.primaryContainer,
                            child: Text(
                              initial,
                              style: TextStyle(
                                color: colors.onPrimaryContainer,
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            remoteReady ? 'Live video' : _connectionLabel,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            Positioned(
              top: 14,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _endingCall ? null : _endCall,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _otherName.isEmpty ? 'ShareTime user' : _otherName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _ended
                              ? 'Call ended'
                              : '$_connectionLabel • $_durationLabel • $_rateLabel BDT/min',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 86,
              right: 16,
              child: Container(
                width: 112,
                height: 164,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24),
                ),
                clipBehavior: Clip.antiAlias,
                child: _cameraOff ||
                        !_renderersReady ||
                        _localRenderer.srcObject == null
                    ? Center(
                        child: Icon(
                          _cameraOff
                              ? Icons.videocam_off_rounded
                              : Icons.person_rounded,
                          color: Colors.white54,
                          size: 34,
                        ),
                      )
                    : RTCVideoView(
                        _localRenderer,
                        mirror: _frontCamera,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 22,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xCC0F172A),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _VideoAction(
                      icon:
                          _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: _muted ? 'Unmute' : 'Mute',
                      active: _muted,
                      onPressed: () async {
                        final muted = !_muted;
                        setState(() => _muted = muted);
                        await _webRtcService.setMuted(muted);
                      },
                    ),
                    _VideoAction(
                      icon: _cameraOff
                          ? Icons.videocam_off_rounded
                          : Icons.videocam_rounded,
                      label: 'Camera',
                      active: _cameraOff,
                      onPressed: () async {
                        final cameraOff = !_cameraOff;
                        setState(() => _cameraOff = cameraOff);
                        await _webRtcService.setCameraEnabled(!cameraOff);
                      },
                    ),
                    _VideoAction(
                      icon: Icons.cameraswitch_rounded,
                      label: 'Flip',
                      active: !_frontCamera,
                      onPressed: () async {
                        await _webRtcService.switchCamera();
                        if (!mounted) return;
                        setState(() => _frontCamera = !_frontCamera);
                      },
                    ),
                    _VideoAction(
                      icon: _speakerOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      label: 'Speaker',
                      active: _speakerOn,
                      onPressed: () async {
                        final speakerOn = !_speakerOn;
                        setState(() => _speakerOn = speakerOn);
                        await _webRtcService.setSpeakerphone(speakerOn);
                      },
                    ),
                    _VideoAction(
                      icon: Icons.call_end_rounded,
                      label: 'End',
                      destructive: true,
                      onPressed: _endingCall ? () {} : _endCall,
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(
              left: 24,
              right: 24,
              bottom: 120,
              child: Text(
                'Live camera and microphone are connected with WebRTC.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoAction extends StatelessWidget {
  const _VideoAction({
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
              width: 50,
              height: 50,
              child: Icon(icon, color: foreground, size: 23),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
