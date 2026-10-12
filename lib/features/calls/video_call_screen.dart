import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../sessions/models/service_session.dart';

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
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _muted = false;
  bool _cameraOff = false;
  bool _speakerOn = true;
  bool _frontCamera = true;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _ended) return;
      setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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

  void _endCall() {
    if (_ended) return;
    setState(() => _ended = true);
    _timer?.cancel();
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final initial = _otherName.isEmpty ? 'S' : _otherName[0].toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _cameraOff
                  ? Container(
                      alignment: Alignment.center,
                      color: const Color(0xFF0F172A),
                      child: CircleAvatar(
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
                    )
                  : Container(
                      alignment: Alignment.center,
                      color: const Color(0xFF111827),
                      child: const Icon(
                        Icons.videocam_rounded,
                        color: Colors.white24,
                        size: 84,
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
                    onPressed: () => Navigator.of(context).pop(),
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
                              : 'Video call • $_durationLabel • $_rateLabel BDT/min',
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
                width: 108,
                height: 154,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white24),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _cameraOff
                          ? Icons.videocam_off_rounded
                          : Icons.person_rounded,
                      color: Colors.white54,
                      size: 34,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _frontCamera ? 'You • Front' : 'You • Back',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 22,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xCC0F172A),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _VideoAction(
                      icon: _muted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      label: _muted ? 'Unmute' : 'Mute',
                      active: _muted,
                      onPressed: () => setState(() => _muted = !_muted),
                    ),
                    _VideoAction(
                      icon: _cameraOff
                          ? Icons.videocam_off_rounded
                          : Icons.videocam_rounded,
                      label: 'Camera',
                      active: _cameraOff,
                      onPressed: () => setState(() => _cameraOff = !_cameraOff),
                    ),
                    _VideoAction(
                      icon: Icons.cameraswitch_rounded,
                      label: 'Flip',
                      active: !_frontCamera,
                      onPressed: () =>
                          setState(() => _frontCamera = !_frontCamera),
                    ),
                    _VideoAction(
                      icon: _speakerOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      label: 'Speaker',
                      active: _speakerOn,
                      onPressed: () =>
                          setState(() => _speakerOn = !_speakerOn),
                    ),
                    _VideoAction(
                      icon: Icons.call_end_rounded,
                      label: 'End',
                      destructive: true,
                      onPressed: _endCall,
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
                'Step 12 video UI foundation. Live camera/audio will be connected in the WebRTC step.',
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
