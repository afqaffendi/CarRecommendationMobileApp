import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/car.dart';
import '../models/user_preferences.dart';
import '../services/database_service.dart';
import '../services/groq_recommendation_service.dart';
import '../services/topsis_service.dart';
import '../services/cbf_service.dart';
import '../services/ai_explanation_service.dart';
import '../services/firestore_service.dart';
import '../widgets/car_image_widget.dart';
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
  bool _isExplaining = false;
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

      _generateExplanation();
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

    _rankedCars = List<RankedCar>.generate(recommendedCars.length, (index) {
      final car = recommendedCars[index];
      final score = 1.0 - (index / recommendedCars.length);
      return RankedCar(car: car, score: score, rank: index + 1);
    });
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
      if (type != 'any' && typeAcrossAll == 0) return 'No "$type" cars exist in the dataset.';
      return 'No "$type" cars remain after budget and usage filtering.';
    }
    if (afterFuel == 0) {
      if (fuel != 'any' && fuelAcrossAll == 0) return 'No "$fuel" cars exist in the dataset.';
      if (hasBudget && fuel != 'any' && minFuelPrice != null && minFuelPrice > budget) {
        return '"$fuel" cars start from RM ${minFuelPrice.toStringAsFixed(0)}, above your budget of RM ${budget.toStringAsFixed(0)}.';
      }
      return hasBudget
          ? 'Fuel filter "$fuel" removed all remaining cars. Try "any" fuel or increase budget.'
          : 'Fuel filter "$fuel" removed all remaining cars. Try "any" fuel.';
    }
    return 'No cars match your exact preferences. Try broadening one filter.';
  }

  Future<void> _generateExplanation() async {
    setState(() => _isExplaining = true);
    final aiService = AIExplanationService(apiKey: _groqKey);
    final explanation = await aiService.explainRecommendations(
      rankedCars: _rankedCars,
      prefs: widget.preferences,
      totalCarsBeforeFilter: _totalCars,
    );
    setState(() {
      _explanation = explanation;
      _isExplaining = false;
    });
  }

  bool _isFavorite(Car car) =>
      _favoriteCars.any((f) => f.displayName == car.displayName);

  void _toggleFavorite(Car car) {
    setState(() {
      if (_isFavorite(car)) {
        _favoriteCars.removeWhere((f) => f.displayName == car.displayName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${car.displayName}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
          ),
        );
      } else {
        _favoriteCars.add(car);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${car.displayName} to favorites'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Results', style: TextStyle(fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
            tooltip: 'Favorites',
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      PreferenceSlidersScreen(preferences: widget.preferences)),
            ),
            tooltip: 'Adjust preferences',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'admin') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CarManagementScreen()),
                );
              } else if (value == 'retry') {
                _loadAndRankCars();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'retry',
                child: Row(
                  children: [
                    Icon(Icons.refresh_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Retry'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'admin',
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings, size: 18),
                    SizedBox(width: 10),
                    Text('Admin Panel'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _rankedCars.isEmpty
              ? _buildEmptyState()
              : _buildResultsList(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
          ),
          const SizedBox(height: 20),
          const Text(
            'AI is finding your best matches...',
            style: TextStyle(fontSize: 16, color: Colors.black54),
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
              color: Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.search_off_rounded, size: 48, color: Colors.black38),
          ),
          const SizedBox(height: 20),
          const Text('No matches found',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your budget or preferences.',
            style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.5),
            textAlign: TextAlign.center,
          ),
          if (_explanation.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Text(
                _explanation,
                style: const TextStyle(
                    fontSize: 13, color: Colors.black54, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Adjust Preferences',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
        SliverToBoxAdapter(child: _buildExplanationCard()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                Text(
                  'Top ${_rankedCars.length} Picks',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_aiFalledBack)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Classic fallback',
                      style:
                          TextStyle(fontSize: 11, color: Colors.orange),
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
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
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
          Container(width: 1, height: 44, color: Colors.white12),
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.auto_awesome_rounded,
              value: '${_rankedCars.length}',
              label: 'AI Picks',
            ),
          ),
          Container(width: 1, height: 44, color: Colors.white12),
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
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _buildExplanationCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
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
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              const Text('AI Explanation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              if (_isExplaining)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black)),
            ],
          ),
          const SizedBox(height: 14),
          _isExplaining
              ? const Text('Generating explanation...',
                  style: TextStyle(color: Colors.black38, fontSize: 14))
              : Text(
                  _explanation,
                  style: const TextStyle(
                      height: 1.6, fontSize: 14, color: Colors.black87),
                ),
        ],
      ),
    );
  }

  Widget _buildCarCard(RankedCar rankedCar) {
    final car = rankedCar.car;
    final isTop = rankedCar.rank == 1;
    final isFavorited = _isFavorite(car);

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTop ? Colors.black : Colors.black.withValues(alpha: 0.07),
          width: isTop ? 1.5 : 1,
        ),
        boxShadow: isTop
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with overlaid rank + score badges
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
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
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.15),
                        ],
                        stops: const [0, 0.35, 0.65, 1],
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
                          ? Colors.white
                          : Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isTop)
                          const Icon(Icons.emoji_events_rounded,
                              size: 13, color: Colors.black),
                        if (isTop) const SizedBox(width: 4),
                        Text(
                          isTop ? 'Best Pick' : '#${rankedCar.rank}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isTop ? Colors.black : Colors.white,
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
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(rankedCar.score * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'RM ${_formatPrice(car.price)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _toggleFavorite(car),
                      icon: Icon(
                        isFavorited
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFavorited ? Colors.red : Colors.black38,
                        size: 22,
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
                    _specChip(Icons.people_rounded, '${car.seats} seats'),
                    _specChip(Icons.bolt_rounded,
                        car.fuelCategory.toUpperCase()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _specChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.black45),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500)),
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
