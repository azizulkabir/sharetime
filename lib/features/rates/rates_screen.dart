import 'package:flutter/material.dart';

import 'models/provider_rate_setup.dart';
import 'models/service_rates.dart';
import 'repositories/firebase_rates_repository.dart';

class RatesScreen extends StatefulWidget {
  const RatesScreen({super.key});

  @override
  State<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends State<RatesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = FirebaseRatesRepository();

  final _textController = TextEditingController();
  final _audioController = TextEditingController();
  final _videoController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  ProviderRateSetup? _setup;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  @override
  void dispose() {
    _textController.dispose();
    _audioController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _loadRates() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final setup = await _repository.fetchMyRateSetup();
      if (!mounted) return;

      _textController.text = _displayValue(setup.rates.textPerMinute);
      _audioController.text = _displayValue(setup.rates.audioPerMinute);
      _videoController.text = _displayValue(setup.rates.videoPerMinute);

      setState(() {
        _setup = setup;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load your service rate settings.';
        _isLoading = false;
      });
    }
  }

  String _displayValue(double value) {
    if (value == 0) return '';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  String? _validateRate(String? value, double maximum) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final parsed = double.tryParse(trimmed);
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0) return 'Rate cannot be negative';
    if (parsed > maximum) {
      return 'Maximum for this level is ${_displayValue(maximum)} BDT/min';
    }
    return null;
  }

  double _parseRate(TextEditingController controller) {
    return double.tryParse(controller.text.trim()) ?? 0;
  }

  Future<void> _saveRates() async {
    final setup = _setup;
    if (setup == null || _isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final rates = ServiceRates(
        textPerMinute: _parseRate(_textController),
        audioPerMinute: _parseRate(_audioController),
        videoPerMinute: _parseRate(_videoController),
      );

      await _repository.saveMyRates(rates);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service rates saved.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save service rates.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final setup = _setup;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My service rates',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadRates,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : setup == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage ?? 'Rate settings are unavailable.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.layers_outlined, color: colors.primary),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Current rate level',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                'Level ${setup.level}',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          LinearProgressIndicator(
                            value: setup.policy.pointsPerLevel <= 0
                                ? 0
                                : setup.pointsIntoLevel /
                                    setup.policy.pointsPerLevel,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '${setup.pointsIntoLevel}/${setup.policy.pointsPerLevel} points',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${setup.pointsNeededForNextLevel} points to Level ${setup.level + 1}',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'Level ${setup.level} maximum rates: '
                        'Text ${_displayValue(setup.maxTextRate)}, '
                        'Audio ${_displayValue(setup.maxAudioRate)}, '
                        'Video ${_displayValue(setup.maxVideoRate)} BDT/min.',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Each completed audio or video operation earns '
                      '${setup.policy.pointsPerCompletedOperation} point. '
                      'Every ${setup.policy.pointsPerLevel} points unlocks the next level. '
                      'At Level 2 the ceilings are 2× Level 1, Level 3 is 3×, and so on.',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _RateField(
                            controller: _textController,
                            label: 'Text chat rate',
                            icon: Icons.chat_bubble_outline_rounded,
                            maximum: setup.maxTextRate,
                            validator: (value) =>
                                _validateRate(value, setup.maxTextRate),
                          ),
                          const SizedBox(height: 14),
                          _RateField(
                            controller: _audioController,
                            label: 'Audio call rate',
                            icon: Icons.call_outlined,
                            maximum: setup.maxAudioRate,
                            validator: (value) =>
                                _validateRate(value, setup.maxAudioRate),
                          ),
                          const SizedBox(height: 14),
                          _RateField(
                            controller: _videoController,
                            label: 'Video call rate',
                            icon: Icons.videocam_outlined,
                            maximum: setup.maxVideoRate,
                            validator: (value) =>
                                _validateRate(value, setup.maxVideoRate),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.lock_outline_rounded, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Operation points are read-only in the app. '
                                    'When the calling system is added, only successfully completed '
                                    'audio/video operations will increase the count and points.',
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isSaving ? null : _saveRates,
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Save rates'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _RateField extends StatelessWidget {
  const _RateField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.maximum,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final double maximum;
  final String? Function(String?) validator;

  String _display(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: '0',
        helperText: 'Maximum: ${_display(maximum)} BDT/min',
        prefixIcon: Icon(icon),
        suffixText: 'BDT/min',
      ),
    );
  }
}
