import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/user_preferences.dart';
import '../services/database_service.dart';
import '../services/topsis_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

const _ratingLabels = [
  'Not Relevant',
  'Slightly',
  'Moderate',
  'Relevant',
  'Perfectly',
];

class ExpertEvaluationScreen extends StatefulWidget {
  const ExpertEvaluationScreen({super.key});

  @override
  State<ExpertEvaluationScreen> createState() =>
      _ExpertEvaluationScreenState();
}

class _ExpertEvaluationScreenState extends State<ExpertEvaluationScreen> {
  final String _scenarioInput =
      'Keluarga 4 orang, bajet RM80k, nak jimat minyak';

  List<RankedCar> _scenarioCars = [];
  List<int> _expertRatings = [];
  List<int> _dragOrder = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _submitted = false;
  double? _overallMae;
  List<double> _perCarMae = [];

  @override
  void initState() {
    super.initState();
    _loadScenarioCars();
  }

  Future<void> _loadScenarioCars() async {
    final allCars = DatabaseService.getCachedCars();
    final prefs = UserPreferences(
      budget: 80000,
      hasBudgetConstraint: true,
      usageType: 'both',
      carType: 'any',
      fuelType: 'any',
      priceWeight: 0.4,
      fuelConsumptionWeight: 0.4,
      safetyWeight: 0.2,
    );
    final budgetFiltered =
        allCars.where((c) => c.price <= 80000).toList();
    final carsToRank =
        budgetFiltered.isNotEmpty ? budgetFiltered : allCars;
    final ranked = TopsisService.rankCars(carsToRank, prefs);
    final top5 = ranked.take(5).toList();
    setState(() {
      _scenarioCars = top5;
      _expertRatings = List.filled(top5.length, 3);
      _dragOrder = List.generate(top5.length, (i) => i);
      _isLoading = false;
    });
  }

  // Maps TOPSIS score (0–1) to 1–5 scale for MAE comparison
  double _normalizeTopsis(double score) => (score * 4) + 1;

  List<double> _calcPerCarMae() {
    return List.generate(_scenarioCars.length, (i) {
      final normalized = _normalizeTopsis(_scenarioCars[i].score);
      return (_expertRatings[i] - normalized).abs();
    });
  }

  String _getMaeInterpretation(double mae) {
    if (mae < 0.5) return 'Excellent — TOPSIS aligns very well with expert judgment';
    if (mae < 1.0) return 'Good — Minor differences between algorithm and expert';
    if (mae < 1.5) return 'Fair — Some disagreement; review criteria weights';
    return 'Poor — Significant mismatch; algorithm needs recalibration';
  }

  Color _getMaeColor(double mae) {
    if (mae < 0.5) return const Color(0xFF4CAF50);
    if (mae < 1.0) return AppTheme.accent;
    if (mae < 1.5) return const Color(0xFFFFC107);
    return Colors.red;
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    final perCarMae = _calcPerCarMae();
    final overallMae =
        perCarMae.reduce((a, b) => a + b) / perCarMae.length;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

    final carEvaluations = List.generate(_scenarioCars.length, (i) {
      final normalized = _normalizeTopsis(_scenarioCars[i].score);
      return {
        'rank': _scenarioCars[i].rank,
        'carName': _scenarioCars[i].car.displayName,
        'topsisScore': _scenarioCars[i].score,
        'normalizedTopsisScore': normalized,
        'expertRating': _expertRatings[i],
        'mae': perCarMae[i],
      };
    });

    final expertRanking = _dragOrder
        .map((i) => _scenarioCars[i].car.displayName)
        .toList();

    try {
      await FirebaseFirestore.instance
          .collection('expert_evaluations')
          .add({
        'evaluatorId': uid,
        'scenarioInput': _scenarioInput,
        'carEvaluations': carEvaluations,
        'expertRanking': expertRanking,
        'overallMae': overallMae,
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() {
        _isSubmitting = false;
        _submitted = true;
        _overallMae = overallMae;
        _perCarMae = perCarMae;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      body: Stack(
        children: [
          _buildBackground(),
          CustomScrollView(
            slivers: [
              _buildAppBar(),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
                )
              else if (_scenarioCars.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_rounded,
                              size: 48, color: AppTheme.textSecondary),
                          const SizedBox(height: 16),
                          const Text(
                            'No car data available',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Please check your internet connection and try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                height: 1.5),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: () {
                              setState(() => _isLoading = true);
                              _loadScenarioCars();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.accent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (_submitted)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildResultCard(),
                  ),
                )
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: _buildScenarioCard(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: _buildSectionHeader(
                      'Rate Each Car',
                      'How relevant is each TOPSIS result to the scenario?',
                      Icons.star_rounded,
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                      child: _buildCarRatingCard(index)
                          .animate()
                          .fadeIn(
                            delay: Duration(
                                milliseconds: 80 + index * 80),
                            duration: 350.ms,
                          )
                          .slideY(
                            begin: 0.1,
                            end: 0,
                            delay: Duration(
                                milliseconds: 80 + index * 80),
                            duration: 350.ms,
                          ),
                    ),
                    childCount: _scenarioCars.length,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: _buildSectionHeader(
                      'Your Ideal Ranking',
                      'Drag to reorder cars by your expert judgment',
                      Icons.drag_handle_rounded,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: _buildReorderSection(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: _buildSubmitButton(),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded,
            color: AppTheme.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Expert Evaluation',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: AppTheme.textPrimary,
          letterSpacing: -0.3,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildScenarioCard() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.science_rounded,
                    size: 20, color: AppTheme.accent),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Scenario',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Fixed evaluation input',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warmBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Text(
              '"$_scenarioInput"',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            children: [
              _InfoChip(label: 'Budget RM80k'),
              _InfoChip(label: 'Family'),
              _InfoChip(label: 'Fuel Economy'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Top ${_scenarioCars.length} cars ranked by TOPSIS algorithm:',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms);
  }

  Widget _buildSectionHeader(
      String title, String subtitle, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.accentLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: AppTheme.accent),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 42),
          child: Text(
            subtitle,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildCarRatingCard(int index) {
    final rc = _scenarioCars[index];
    final rating = _expertRatings[index];
    final normalizedScore = _normalizeTopsis(rc.score);

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppTheme.gradientOrange,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '#${rc.rank}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rc.car.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'TOPSIS: ${(rc.score * 100).toStringAsFixed(1)}%  ·  Norm: ${normalizedScore.toStringAsFixed(2)}/5',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Expert Relevance Rating',
            style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (starIdx) {
              final star = starIdx + 1;
              return GestureDetector(
                onTap: () =>
                    setState(() => _expertRatings[index] = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    star <= rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: star <= rating
                        ? AppTheme.accent
                        : AppTheme.cardBorder,
                    size: 36,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _ratingLabels[rating - 1],
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReorderSection() {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: ReorderableListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = _dragOrder.removeAt(oldIndex);
            _dragOrder.insert(newIndex, item);
          });
        },
        children: [
          for (int pos = 0; pos < _dragOrder.length; pos++)
            Container(
              key: ValueKey(_dragOrder[pos]),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.warmBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.accentLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${pos + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _scenarioCars[_dragOrder[pos]].car.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.drag_handle_rounded,
                      color: AppTheme.textSecondary, size: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: _isSubmitting ? null : _submit,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.accent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'Submit Evaluation',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }

  Widget _buildResultCard() {
    final mae = _overallMae!;
    final maeColor = _getMaeColor(mae);
    final interpretation = _getMaeInterpretation(mae);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: maeColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.analytics_rounded, color: maeColor, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Overall MAE Result',
            style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            mae.toStringAsFixed(3),
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w700,
              color: maeColor,
              letterSpacing: -2,
            ),
          ),
          const Text(
            'Mean Absolute Error',
            style: TextStyle(
                fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: maeColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: maeColor.withValues(alpha: 0.30)),
            ),
            child: Text(
              interpretation,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: maeColor,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Per-Car Breakdown',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(
            _scenarioCars.length,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Text(
                    '#${_scenarioCars[i].rank}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _scenarioCars[i].car.displayName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'MAE: ${_perCarMae[i].toStringAsFixed(3)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: _getMaeColor(_perCarMae[i]),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 24, color: AppTheme.divider),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Done',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.1, end: 0, duration: 500.ms);
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -40,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.accent.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -70,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.accentBlue.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.accentLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AppTheme.accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
