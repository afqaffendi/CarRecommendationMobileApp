import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/user_preferences.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_title.dart';
import 'recommendation_results_screen.dart';

class PreferenceSlidersScreen extends StatefulWidget {
  final UserPreferences preferences;

  const PreferenceSlidersScreen({super.key, required this.preferences});

  @override
  State<PreferenceSlidersScreen> createState() => _PreferenceSlidersScreenState();
}

class _PreferenceSlidersScreenState extends State<PreferenceSlidersScreen> {
  late UserPreferences _prefs;

  static const double _budgetMax = 500000;
  static const double _budgetStep = 10000;
  // Fallback if car cache is empty
  static const double _budgetFallbackMin = 30000;

  late double _budgetMin;

  @override
  void initState() {
    super.initState();
    _prefs = widget.preferences;
    _budgetMin = _computeBudgetMin();
    _prefs.budget = _prefs.budget.clamp(_budgetMin, _budgetMax);
    _prefs.budget = (_prefs.budget / _budgetStep).round() * _budgetStep;
    // EVs have no fuel consumption — zero out the weight so TOPSIS ignores it.
    if (_prefs.fuelType == 'ev') {
      _prefs.fuelConsumptionWeight = 0.0;
    }
  }

  bool get _isEV => _prefs.fuelType == 'ev';

  // Derives the minimum budget from the cheapest car in the dataset.
  // Rounds UP to the nearest step so the minimum always returns at least one car.
  double _computeBudgetMin() {
    final cars = DatabaseService.getCachedCars();
    if (cars.isEmpty) return _budgetFallbackMin;
    final cheapest = cars.map((c) => c.price).reduce((a, b) => a < b ? a : b);
    final stepped = (cheapest / _budgetStep).ceil() * _budgetStep;
    return stepped.clamp(_budgetFallbackMin, _budgetMax - _budgetStep);
  }

  String _formatRM(double value) {
    final int v = value.toInt();
    final String s = v.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
      buffer.write(s[i]);
    }
    return 'RM ${buffer.toString()}';
  }

  String _fuelEconomyLabel(double weight) {
    if (weight < 0.05) return 'Any';
    // Maps 0→20 L/100km (any) to 1→6 L/100km (very efficient)
    final lPer100 = (20 - weight * 14).clamp(6.0, 20.0);
    return '≤ ${lPer100.toStringAsFixed(0)} L/100km';
  }

  String _safetyLabel(double weight) {
    if (weight < 0.1) return 'Any';
    // Maps 0.1→1.0 to 1–5 stars
    final stars = (weight * 4 + 1).clamp(1.0, 5.0).round();
    return '${'★' * stars}${'☆' * (5 - stars)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your Priorities',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background orbs
          Positioned(
            bottom: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 80,
            left: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accentBlue.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedTitle(
                  text: 'What matters\nmost to you?',
                  charDelayMs: 36,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedFadeSlide(
                  delay: const Duration(milliseconds: 1100),
                  child: const Text(
                    'Adjust sliders to fine-tune your preferences',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                _buildSliderSection(
                  icon: Icons.attach_money_rounded,
                  title: 'Budget',
                  subtitle: 'Maximum price you\'re willing to pay',
                  value: _prefs.budget,
                  min: _budgetMin,
                  max: _budgetMax,
                  divisions: ((_budgetMax - _budgetMin) / _budgetStep).round(),
                  displayLabel: _formatRM(_prefs.budget),
                  minLabel: _formatRM(_budgetMin),
                  maxLabel: _formatRM(_budgetMax),
                  onChanged: (v) => setState(() {
                    _prefs.budget = v;
                    // Touching the slider always means the user wants a hard budget cap.
                    _prefs.hasBudgetConstraint = true;
                  }),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1, end: 0, delay: 200.ms, duration: 400.ms, curve: Curves.easeOutCubic),
                const SizedBox(height: 24),

                if (_isEV)
                  _buildEvFuelNote()
                      .animate()
                      .fadeIn(delay: 320.ms, duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, delay: 320.ms, duration: 400.ms, curve: Curves.easeOutCubic)
                else
                  _buildSliderSection(
                    icon: Icons.local_gas_station_rounded,
                    title: 'Fuel Economy',
                    subtitle: 'Target fuel consumption',
                    value: _prefs.fuelConsumptionWeight,
                    min: 0,
                    max: 1,
                    divisions: 10,
                    displayLabel: _fuelEconomyLabel(_prefs.fuelConsumptionWeight),
                    minLabel: 'Not Important',
                    maxLabel: '≤ 6 L/100km',
                    onChanged: (v) => setState(() => _prefs.fuelConsumptionWeight = v),
                  ).animate().fadeIn(delay: 320.ms, duration: 400.ms).slideY(begin: 0.1, end: 0, delay: 320.ms, duration: 400.ms, curve: Curves.easeOutCubic),
                const SizedBox(height: 24),

                _buildSliderSection(
                  icon: Icons.health_and_safety_rounded,
                  title: 'Safety',
                  subtitle: 'NCAP star rating priority',
                  value: _prefs.safetyWeight,
                  min: 0,
                  max: 1,
                  divisions: 10,
                  displayLabel: _safetyLabel(_prefs.safetyWeight),
                  minLabel: 'Not Important',
                  maxLabel: '5 Stars Only',
                  onChanged: (v) => setState(() => _prefs.safetyWeight = v),
                ).animate().fadeIn(delay: 440.ms, duration: 400.ms).slideY(begin: 0.1, end: 0, delay: 440.ms, duration: 400.ms, curve: Curves.easeOutCubic),
                const SizedBox(height: 32),

                _buildWeightSummary()
                    .animate()
                    .fadeIn(delay: 560.ms, duration: 400.ms)
                    .slideY(begin: 0.1, end: 0, delay: 560.ms, duration: 400.ms, curve: Curves.easeOutCubic),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _onGetRecommendations,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome_rounded),
                        const SizedBox(width: 8),
                        Text(
                          'Get Recommendations',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 680.ms, duration: 400.ms).slideY(begin: 0.1, end: 0, delay: 680.ms, duration: 400.ms, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayLabel,
    required String minLabel,
    required String maxLabel,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.warmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.accent, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Text(
                  displayLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accent,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: AppTheme.cardBorder,
              thumbColor: AppTheme.accent,
              overlayColor: AppTheme.accent.withValues(alpha: 0.15),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel,
                  style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12)),
              Text(maxLabel,
                  style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEvFuelNote() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF82).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF82).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.bolt_rounded, color: Color(0xFF2E7D32), size: 20),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fuel Economy — Not Applicable',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'EVs run on electricity, so fuel consumption is not used in ranking. Only price and safety matter.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2E7D32),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightSummary() {
    if (_isEV) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.warmSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Priority Distribution',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'EV mode — ranking based on price and safety only',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 32,
                child: Row(
                  children: [
                    Expanded(
                      flex: 50,
                      child: Container(
                        color: AppTheme.accent,
                        alignment: Alignment.center,
                        child: const Text('Price 50%',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    ),
                    Expanded(
                      flex: 50,
                      child: Container(
                        color: const Color(0xFF4CAF82),
                        alignment: Alignment.center,
                        child: const Text('Safety 50%',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(AppTheme.accent, 'Price'),
                _buildLegendItem(const Color(0xFF4CAF82), 'Safety'),
              ],
            ),
          ],
        ),
      );
    }

    final total = _prefs.fuelConsumptionWeight + _prefs.safetyWeight;
    final fuelPercent = total > 0 ? (_prefs.fuelConsumptionWeight / total * 100).toInt() : 50;
    final safetyPercent = total > 0 ? (_prefs.safetyWeight / total * 100).toInt() : 50;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.warmSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Priority Distribution',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Relative weight between fuel economy and safety',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 32,
              child: Row(
                children: [
                  Expanded(
                    flex: fuelPercent,
                    child: Container(
                      color: AppTheme.accentBlue,
                      alignment: Alignment.center,
                      child: Text(
                        '$fuelPercent%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: safetyPercent,
                    child: Container(
                      color: const Color(0xFF4CAF82),
                      alignment: Alignment.center,
                      child: Text(
                        '$safetyPercent%',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(AppTheme.accentBlue, 'Fuel Economy'),
              _buildLegendItem(const Color(0xFF4CAF82), 'Safety'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }

  Future<void> _onGetRecommendations() async {
    await DatabaseService.savePreferences(_prefs);

    if (mounted) {
      Navigator.push(
        context,
        AppTheme.slideRoute(RecommendationResultsScreen(preferences: _prefs)),
      );
    }
  }
}
