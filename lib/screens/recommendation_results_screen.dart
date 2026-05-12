import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/car.dart';
import '../models/user_preferences.dart';
import '../services/database_service.dart';
import '../services/groq_recommendation_service.dart';
import '../services/topsis_service.dart';
import '../services/cbf_service.dart';
import '../services/firestore_service.dart';
import '../widgets/animated_title.dart';
import '../widgets/car_image_widget.dart';
import '../widgets/glass_card.dart';
import '../widgets/pressable_button.dart';
import '../theme/app_theme.dart';
import 'car_detail_sheet.dart';
import 'favorites_screen.dart';
import 'preference_sliders_screen.dart';
import 'admin/car_management_screen.dart';

String get _groqKey => dotenv.env['GROQ_API_KEY'] ?? '';

class RecommendationResultsScreen extends StatefulWidget {
  final UserPreferences preferences;

  const RecommendationResultsScreen({super.key, required this.preferences});

  @override
  State<RecommendationResultsScreen> createState() =>
      _RecommendationResultsScreenState();
}

class _RecommendationResultsScreenState
    extends State<RecommendationResultsScreen> {
  List<RankedCar> _rankedCars = [];
  String _explanation = '';
  bool _isLoading = true;
  int _totalCars = 0;
  final FirestoreService _firestoreService = FirestoreService();
  final List<Car> _favoriteCars = [];
  bool _aiFalledBack = false;

  @override
  void initState() {
    super.initState();
    _loadAndRankCars();
  }

  Future<void> _loadAndRankCars() async {
    setState(() {
      _isLoading = true;
      _aiFalledBack = false;
    });

    try {
      List<Car> allCars = DatabaseService.hasCachedCars()
          ? DatabaseService.getCachedCars()
          : await _firestoreService.getCars();

      if (!DatabaseService.hasCachedCars() && allCars.isNotEmpty) {
        DatabaseService.cacheCars(allCars);
      }

      _totalCars = allCars.length;

      if (allCars.isEmpty) {
        setState(() {
          _rankedCars = [];
          _isLoading = false;
          _explanation =
              'No cars found. Check your Firestore collection name and security rules.';
        });
        return;
      }

      await _runAIRanking(allCars);

      setState(() => _isLoading = false);

      if (_aiFalledBack && mounted) {
        final reason = GroqRecommendationService.lastError.isNotEmpty
            ? GroqRecommendationService.lastError
            : 'AI returned no results — using classic ranking.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(reason),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
        _explanation = 'Error loading cars: $e';
      });
    }
  }

  Future<void> _runAIRanking(List<Car> allCars) async {
    final groqService = GroqRecommendationService(apiKey: _groqKey);
    final recommendedCars = await groqService.getRecommendations(
      preferences: widget.preferences,
      allCars: allCars,
    );

    if (recommendedCars.isEmpty) {
      _aiFalledBack = true;
      await _runClassicFallback(allCars);
      return;
    }

    // Re-rank Groq's picks with TOPSIS so scores reflect actual user weights.
    _rankedCars = TopsisService.rankCars(recommendedCars, widget.preferences);
  }

  Future<void> _runClassicFallback(List<Car> allCars) async {
    final filteredCars = CBFService.filterCars(allCars, widget.preferences);
    if (filteredCars.isEmpty) {
      final diagnostics =
          CBFService.getNoMatchDiagnostics(allCars, widget.preferences);
      setState(() {
        _rankedCars = [];
        _explanation = _buildNoMatchExplanation(diagnostics);
      });
      return;
    }

    final rankedCars = TopsisService.rankCars(filteredCars, widget.preferences);

    final uniqueRankedCars = <RankedCar>[];
    final seenModels = <String>{};
    for (final ranked in rankedCars) {
      final modelKey = ranked.car.displayName.toLowerCase();
      if (seenModels.contains(modelKey)) continue;
      seenModels.add(modelKey);
      uniqueRankedCars.add(ranked);
      if (uniqueRankedCars.length == 10) break;
    }

    _rankedCars = List<RankedCar>.generate(uniqueRankedCars.length, (index) {
      final ranked = uniqueRankedCars[index];
      return RankedCar(car: ranked.car, score: ranked.score, rank: index + 1);
    });
  }

  String _buildNoMatchExplanation(Map<String, dynamic> diagnostics) {
    final afterBudget = diagnostics['afterBudget'] as int? ?? 0;
    final afterUsage = diagnostics['afterUsage'] as int? ?? 0;
    final afterType = diagnostics['afterType'] as int? ?? 0;
    final afterFuel = diagnostics['afterFuel'] as int? ?? 0;
    final fuelAcrossAll = diagnostics['fuelAcrossAll'] as int? ?? 0;
    final typeAcrossAll = diagnostics['typeAcrossAll'] as int? ?? 0;
    final minFuelPrice = diagnostics['minPriceForPreferredFuel'] as double?;

    final budget = widget.preferences.budget;
    final hasBudget = widget.preferences.hasBudgetConstraint;
    final usage = widget.preferences.usageType;
    final type = widget.preferences.carType;
    final fuel = widget.preferences.fuelType;

    if (hasBudget && afterBudget == 0) {
      return 'No cars are within your budget (RM ${budget.toStringAsFixed(0)}). Try increasing budget.';
    }
    if (afterUsage == 0) {
      return hasBudget
          ? 'Cars exist in your budget, but none match usage "$usage" with your other constraints.'
          : 'No cars match usage "$usage" with your selected type/fuel constraints.';
    }
    if (afterType == 0) {
      if (type != 'any' && typeAcrossAll == 0) {
        return 'No "$type" cars exist in the dataset.';
      }
      return 'No "$type" cars remain after budget and usage filtering.';
    }
    if (afterFuel == 0) {
      if (fuel != 'any' && fuelAcrossAll == 0) {
        return 'No "$fuel" cars exist in the dataset.';
      }
      if (hasBudget &&
          fuel != 'any' &&
          minFuelPrice != null &&
          minFuelPrice > budget) {
        return '"$fuel" cars start from RM ${minFuelPrice.toStringAsFixed(0)}, above your budget of RM ${budget.toStringAsFixed(0)}.';
      }
      return hasBudget
          ? 'Fuel filter "$fuel" removed all remaining cars. Try "any" fuel or increase budget.'
          : 'Fuel filter "$fuel" removed all remaining cars. Try "any" fuel.';
    }
    return 'No cars match your exact preferences. Try broadening one filter.';
  }

  void _openCarDetail(RankedCar rankedCar) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CarDetailSheet(
        car: rankedCar.car,
        preferences: widget.preferences,
        rank: rankedCar.rank,
      ),
    );
  }

  bool _isFavorite(Car car) =>
      _favoriteCars.any((f) => f.displayName == car.displayName);

  void _toggleFavorite(Car car) {
    setState(() {
      if (_isFavorite(car)) {
        _favoriteCars.removeWhere((f) => f.displayName == car.displayName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${car.displayName}')),
        );
      } else {
        _favoriteCars.add(car);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${car.displayName} to favorites')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.warmBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: AnimatedTitle(
          text: 'Results',
          charDelayMs: 55,
          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_rounded),
            onPressed: () => Navigator.push(
              context,
              AppTheme.slideRoute(const FavoritesScreen()),
            ),
            tooltip: 'Favorites',
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.push(
              context,
              AppTheme.slideRoute(
                  PreferenceSlidersScreen(preferences: widget.preferences)),
            ),
            tooltip: 'Adjust preferences',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: AppTheme.warmSurface,
            onSelected: (value) {
              if (value == 'admin') {
                Navigator.push(
                  context,
                  AppTheme.slideRoute(const CarManagementScreen()),
                );
              } else if (value == 'retry') {
                _loadAndRankCars();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'retry',
                child: Row(children: [
                  Icon(Icons.refresh_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Retry'),
                ]),
              ),
              const PopupMenuItem(
                value: 'admin',
                child: Row(children: [
                  Icon(Icons.admin_panel_settings, size: 18),
                  SizedBox(width: 10),
                  Text('Admin Panel'),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Peach orb — top right
          Positioned(
            top: -50,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accentLight.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Blue orb — bottom left
          Positioned(
            bottom: 60,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accentBlue.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          _isLoading
              ? _buildLoadingState()
              : _rankedCars.isEmpty
                  ? _buildEmptyState()
                  : _buildResultsList(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                color: AppTheme.accent,
                strokeWidth: 2.5,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'AI is finding your best matches...',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.accentLight.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded,
                size: 48, color: AppTheme.accent),
          ),
          const SizedBox(height: 20),
          const Text(
            'No matches found',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your budget or preferences.',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (_explanation.isNotEmpty) ...[
            const SizedBox(height: 16),
            GlassCard(
              blur: false,
              padding: const EdgeInsets.all(16),
              child: Text(
                _explanation,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: PressableButton(
              glass: true,
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.symmetric(vertical: 16),
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Adjust Preferences',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildSummaryHeader()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Row(
              children: [
                AnimatedFadeSlide(
                  delay: const Duration(milliseconds: 200),
                  child: Text(
                    'Top ${_rankedCars.length} Picks',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const Spacer(),
                if (_aiFalledBack)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accentLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Classic fallback',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildCarCard(_rankedCars[index]),
            childCount: _rankedCars.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF221028), Color(0xFF130A18)],
        ),
        border: Border.all(color: AppTheme.cardBorder, width: 1.0),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.directions_car_rounded,
              value: '$_totalCars',
              label: 'Total',
            ),
          ),
          Container(
              width: 1,
              height: 44,
              color: Colors.white.withValues(alpha: 0.12)),
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.auto_awesome_rounded,
              value: '${_rankedCars.length}',
              label: 'AI Picks',
            ),
          ),
          Container(
              width: 1,
              height: 44,
              color: Colors.white.withValues(alpha: 0.12)),
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.emoji_events_rounded,
              value: _rankedCars.isNotEmpty
                  ? '${(_rankedCars.first.score * 100).toStringAsFixed(0)}%'
                  : '-',
              label: 'Top Score',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      {required IconData icon, required String value, required String label}) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildCarCard(RankedCar rankedCar) {
    final car = rankedCar.car;
    final isTop = rankedCar.rank == 1;
    final isFavorited = _isFavorite(car);

    return GestureDetector(
      onTap: () => _openCarDetail(rankedCar),
      child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: GlassCard(
        blur: false,
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(22),
        backgroundColor: isTop
            ? AppTheme.warmSurface.withValues(alpha: 1.0)
            : const Color(0xFF111111),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with overlaid badges
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(21)),
              child: Stack(
                children: [
                  CarImageWidget(
                    car: car,
                    width: double.infinity,
                    height: 180,
                    size: 'medium',
                    borderRadius: BorderRadius.zero,
                  ),
                  // Gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.1),
                          ],
                          stops: const [0, 0.3, 0.65, 1],
                        ),
                      ),
                    ),
                  ),
                  // Rank badge — top left
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isTop
                            ? AppTheme.accent
                            : Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isTop)
                            const Icon(Icons.emoji_events_rounded,
                                size: 12, color: Colors.white),
                          if (isTop) const SizedBox(width: 4),
                          Text(
                            isTop ? 'Best Pick' : '#${rankedCar.rank}',
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
                  // Score badge — top right
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${(rankedCar.score * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Card body
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              car.displayName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'RM ${_formatPrice(car.price)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _toggleFavorite(car),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isFavorited
                                ? Colors.red.withValues(alpha: 0.20)
                                : AppTheme.accentLight.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFavorited
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFavorited
                                ? Colors.red
                                : AppTheme.textSecondary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _specChip(Icons.local_gas_station_rounded,
                          '${car.fuelConsumption}L/100km'),
                      _specChip(Icons.shield_rounded,
                          '${_numericSafety(car.safetyRating)}/5'),
                      _specChip(
                          Icons.people_rounded, '${car.seats} seats'),
                      _specChip(Icons.bolt_rounded,
                          car.fuelCategory.toUpperCase()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _specChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accentLight.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.accent),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _numericSafety(String rating) {
    if (rating.isEmpty) return 'N/A';
    return RegExp(r'(\d+(\.\d+)?)').firstMatch(rating)?.group(0) ?? 'N/A';
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
