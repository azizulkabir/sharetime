import 'dart:async';

import 'package:flutter/material.dart';

import '../sessions/models/service_session.dart';

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
    final providerName = widget.session.providerName.trim();
    final requesterName = widget.session.requesterName.trim();
    return providerName.isNotEmpty ? providerName : requesterName;
  }

  String get _durationLabel {
    final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
                    onPressed: () => Navigator.of(context).pop(),
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
                _ended ? 'Call ended' : 'Audio call • $_durationLabel',
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
                    onPressed: () => setState(() => _muted = !_muted),
                  ),
                  _CallAction(
                    icon: _speakerOn
                        ? Icons.volume_up_rounded
                        : Icons.volume_down_rounded,
                    label: 'Speaker',
                    active: _speakerOn,
                    onPressed: () => setState(() => _speakerOn = !_speakerOn),
                  ),
                  _CallAction(
                    icon: Icons.call_end_rounded,
                    label: 'End',
                    destructive: true,
                    onPressed: _endCall,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                'This is the Step 11 call UI foundation. Live audio will be connected in the WebRTC step.',
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
