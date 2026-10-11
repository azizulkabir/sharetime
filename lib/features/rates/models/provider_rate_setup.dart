import 'rate_policy.dart';
import 'service_rates.dart';

class ProviderRateSetup {
  const ProviderRateSetup({
    required this.rates,
    required this.policy,
    required this.progress,
  });

  final ServiceRates rates;
  final RatePolicy policy;
  final ProviderRateProgress progress;

  int get level => policy.levelForPoints(progress.points);

  double get maxTextRate => policy.maxTextRate(level);
  double get maxAudioRate => policy.maxAudioRate(level);
  double get maxVideoRate => policy.maxVideoRate(level);

  int get pointsIntoLevel => policy.pointsIntoCurrentLevel(progress.points);
  int get pointsNeededForNextLevel =>
      policy.pointsPerLevel - pointsIntoLevel;
}
