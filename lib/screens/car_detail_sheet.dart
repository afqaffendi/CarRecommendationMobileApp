import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/car.dart';
import '../models/user_preferences.dart';
import '../services/ai_explanation_service.dart';
import '../widgets/car_image_widget.dart';
import '../theme/app_theme.dart';

String get _groqKey => dotenv.env['GROQ_API_KEY'] ?? '';

class CarDetailSheet extends StatefulWidget {
  final Car car;
  final UserPreferences preferences;
  final int rank;

  const CarDetailSheet({
    super.key,
    required this.car,
    required this.preferences,
    required this.rank,
  });

  @override
  State<CarDetailSheet> createState() => _CarDetailSheetState();
}

class _CarDetailSheetState extends State<CarDetailSheet> {
  String _explanation = '';
  bool _loadingExplanation = true;
  int _loanYears = 7;

  @override
  void initState() {
    super.initState();
    _fetchExplanation();
  }

  Future<void> _fetchExplanation() async {
    final svc = AIExplanationService(apiKey: _groqKey);
    final result = await svc.explainSingleCar(
      car: widget.car,
      prefs: widget.preferences,
      rank: widget.rank,
    );
    if (mounted) {
      setState(() {
        _explanation = result;
        _loadingExplanation = false;
      });
    }
  }

  double _calcMonthlyPayment(int years) {
    final price = widget.car.price;
    if (price <= 0) return 0;
    final principal = price * 0.9;
    const monthlyRate = 0.035 / 12;
    final n = years * 12;
    return principal * monthlyRate / (1 - math.pow(1 + monthlyRate, -n));
  }

  @override
  Widget build(BuildContext context) {
    final car = widget.car;
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: AppTheme.warmBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageHeader(car),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildNameSection(car)
                            .animate()
                            .fadeIn(delay: 100.ms, duration: 350.ms)
                            .slideY(begin: 0.06, end: 0, delay: 100.ms, duration: 350.ms, curve: Curves.easeOutCubic),
                        const SizedBox(height: 20),
                        _buildPaymentSection()
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 350.ms)
                            .slideY(begin: 0.06, end: 0, delay: 200.ms, duration: 350.ms, curve: Curves.easeOutCubic),
                        const SizedBox(height: 20),
                        _buildSpecsSection(car)
                            .animate()
                            .fadeIn(delay: 300.ms, duration: 350.ms)
                            .slideY(begin: 0.06, end: 0, delay: 300.ms, duration: 350.ms, curve: Curves.easeOutCubic),
                        const SizedBox(height: 20),
                        _buildAISection()
                            .animate()
                            .fadeIn(delay: 400.ms, duration: 350.ms)
                            .slideY(begin: 0.06, end: 0, delay: 400.ms, duration: 350.ms, curve: Curves.easeOutCubic),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageHeader(Car car) {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: CarImageWidget(
                car: car,
                width: double.infinity,
                height: 220,
                size: 'large',
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
          Positioned(
            bottom: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: widget.rank == 1
                    ? AppTheme.accent
                    : Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.rank == 1) ...[
                    const Icon(Icons.emoji_events_rounded,
                        size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    widget.rank == 1 ? 'Best Pick' : '#${widget.rank}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameSection(Car car) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          car.displayName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'RM ${_formatPrice(car.price)}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.accentLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                car.year.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    final monthly = _calcMonthlyPayment(_loanYears);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.92),
            AppTheme.accentBlue.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calculate_rounded,
                    size: 15, color: AppTheme.accent),
              ),
              const SizedBox(width: 10),
              const Text(
                'Monthly Payment',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'RM ${_formatPrice(monthly)} / month',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '90% financing · 3.5% p.a. · $_loanYears years',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Term:',
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withValues(alpha: 0.55)),
              ),
              const SizedBox(width: 10),
              ...[5, 7, 9].map((y) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _loanYears = y),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _loanYears == y
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${y}yr',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _loanYears == y
                                ? AppTheme.accent
                                : Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsSection(Car car) {
    final specs = <Widget>[
      _specCell(Icons.directions_car_rounded, 'Type', car.type.isEmpty ? 'N/A' : car.type),
      _specCell(Icons.settings_rounded, 'Transmission', car.transmission),
      _specCell(Icons.local_gas_station_rounded, 'Fuel Economy', '${car.fuelConsumption}L/100km'),
      _specCell(Icons.shield_rounded, 'Safety', car.safetyRating.isEmpty ? 'N/A' : car.safetyRating),
      _specCell(Icons.people_rounded, 'Seats', '${car.seats} seats'),
      _specCell(Icons.speed_rounded, 'Power', '${car.horsepower.toStringAsFixed(0)} hp'),
      _specCell(Icons.bolt_rounded, 'Fuel Type', car.fuelCategory.toUpperCase()),
      if (car.bootSpace > 0)
        _specCell(Icons.inventory_2_rounded, 'Boot Space', '${car.bootSpace}L'),
      if (car.engine.isNotEmpty)
        _specCell(Icons.engineering_rounded, 'Engine', car.engine),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Specifications',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: specs,
        ),
      ],
    );
  }

  Widget _specCell(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warmSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAISection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    size: 15, color: AppTheme.accent),
              ),
              const SizedBox(width: 10),
              const Text(
                'Why this car?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (_loadingExplanation)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppTheme.accent),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _loadingExplanation
              ? Text(
                  'Generating AI explanation...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                ).animate(onPlay: (c) => c.repeat()).shimmer(
                    duration: 1800.ms,
                    color: AppTheme.accent.withValues(alpha: 0.12),
                  )
              : Text(
                  _explanation,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.6,
                  ),
                ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    final s = price.toStringAsFixed(0);
    final result = StringBuffer();
    var count = 0;
    for (var i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) result.write(',');
      result.write(s[i]);
      count++;
    }
    return result.toString().split('').reversed.join();
  }
}
