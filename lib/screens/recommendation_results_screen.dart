import 'package:flutter/material.dart';
import '../models/car.dart';
import '../models/user_preferences.dart';
import '../services/cbf_service.dart';
import '../services/gemini_recommendation_service.dart';
import '../services/topsis_service.dart';
import '../services/ai_explanation_service.dart';
import '../services/firestore_service.dart';
import '../widgets/car_image_widget.dart';
import 'favorites_screen.dart';
import 'preference_sliders_screen.dart';
import 'admin/car_management_screen.dart';

const String _apiKey = 'AIzaSyCNGkdzg4FL06QxfmiescIJD16WBhI3GNw';

class RecommendationResultsScreen extends StatefulWidget {
  final UserPreferences preferences;

  const RecommendationResultsScreen({super.key, required this.preferences});

  @override
  State<RecommendationResultsScreen> createState() => _RecommendationResultsScreenState();
}

class _RecommendationResultsScreenState extends State<RecommendationResultsScreen> {
  List<RankedCar> _rankedCars = [];
  String _explanation = '';
  bool _isLoading = true;
  bool _isExplaining = false;
  int _totalCars = 0;
  int _filteredCount = 0;
  final FirestoreService _firestoreService = FirestoreService();
  List<Car> _favoriteCars = [];
  bool _useGemini = false;
  bool _geminiFalledBack = false;

  @override
  void initState() {
    super.initState();
    _loadAndRankCars();
  }

  Future<void> _loadAndRankCars() async {
    setState(() {
      _isLoading = true;
      _geminiFalledBack = false;
    });

    try {
      List<Car> allCars = await _firestoreService.getCars();
      _totalCars = allCars.length;

      if (allCars.isEmpty) {
        setState(() {
          _rankedCars = [];
          _filteredCount = 0;
          _isLoading = false;
          _explanation =
              'No cars were fetched from Firestore. Check that your collection name is cars and Firestore rules allow reads.';
        });
        return;
      }

      if (_useGemini) {
        await _runGeminiRanking(allCars);
      } else {
        await _runClassicRanking(allCars);
      }

      setState(() => _isLoading = false);

      if (_geminiFalledBack && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gemini AI unavailable — showing Classic results'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
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

  Future<void> _runGeminiRanking(List<Car> allCars) async {
    final geminiService = GeminiRecommendationService(apiKey: _apiKey);
    final recommendedCars = await geminiService.getRecommendations(
      preferences: widget.preferences,
      allCars: allCars,
    );

    _filteredCount = allCars.length;

    if (recommendedCars.isEmpty) {
      // Fallback to Classic so the user always sees results
      _geminiFalledBack = true;
      await _runClassicRanking(allCars);
      return;
    }

    _rankedCars = List<RankedCar>.generate(recommendedCars.length, (index) {
      final car = recommendedCars[index];
      final score = 1.0 - (index / recommendedCars.length);
      return RankedCar(car: car, score: score, rank: index + 1);
    });
  }

  Future<void> _runClassicRanking(List<Car> allCars) async {
    // Stage 1: Strict CBF Filtering
    final filteredCars = CBFService.filterCars(allCars, widget.preferences);
    _filteredCount = filteredCars.length;

    if (filteredCars.isEmpty) {
      final diagnostics = CBFService.getNoMatchDiagnostics(allCars, widget.preferences);
      setState(() {
        _rankedCars = [];
        _explanation = _buildNoMatchExplanation(diagnostics);
      });
      return;
    }

    // Stage 2: TOPSIS Ranking
    final rankedCars = TopsisService.rankCars(filteredCars, widget.preferences);

    // Defensive pass: de-duplicate repeated models + limit to top 10.
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
    final hasBudgetConstraint = widget.preferences.hasBudgetConstraint;
    final usage = widget.preferences.usageType;
    final type = widget.preferences.carType;
    final fuel = widget.preferences.fuelType;

    if (hasBudgetConstraint && afterBudget == 0) {
      return 'No cars are within your budget (RM ${budget.toStringAsFixed(0)}). Try increasing budget.';
    }
    if (afterUsage == 0) {
      if (hasBudgetConstraint) {
        return 'Cars exist in your budget, but none match usage "$usage" together with your other constraints.';
      }
      return 'No cars match usage "$usage" together with your selected type/fuel constraints.';
    }
    if (afterType == 0) {
      if (type != 'any' && typeAcrossAll == 0) {
        return 'No "$type" cars exist in the current dataset.';
      }
      return 'No "$type" cars remain after budget and usage filtering.';
    }
    if (afterFuel == 0) {
      if (fuel != 'any' && fuelAcrossAll == 0) {
        return 'No "$fuel" cars exist in the current dataset.';
      }
      if (hasBudgetConstraint && fuel != 'any' && minFuelPrice != null && minFuelPrice > budget) {
        return '"$fuel" cars exist, but start from RM ${minFuelPrice.toStringAsFixed(0)}, above your budget RM ${budget.toStringAsFixed(0)}.';
      }
      return hasBudgetConstraint
          ? 'Fuel filter "$fuel" removed the remaining cars. Try fuel "any" or increase budget.'
          : 'Fuel filter "$fuel" removed the remaining cars. Try fuel "any".';
    }

    return 'No cars match your exact preferences. Try broadening one filter (usage, type, or fuel).';
  }

  Future<void> _generateExplanation() async {
    setState(() => _isExplaining = true);

    final aiService = AIExplanationService(apiKey: _apiKey);
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

  bool _isFavorite(Car car) {
    return _favoriteCars.any((favCar) => favCar.displayName == car.displayName);
  }

  Future<void> _toggleFavorite(Car car) async {
    // This is a simplified favorite toggle. A more robust solution would use user accounts and a proper database service.
    setState(() {
      if (_isFavorite(car)) {
        _favoriteCars.removeWhere((favCar) => favCar.displayName == car.displayName);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Removed ${car.displayName} from favorites',
              style: TextStyle(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        _favoriteCars.add(car);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Added ${car.displayName} to favorites',
              style: TextStyle(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your Perfect Car',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PreferenceSlidersScreen(preferences: widget.preferences)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CarManagementScreen()),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Finding your perfect car...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            )
          : _rankedCars.isEmpty
              ? _buildEmptyState()
              : _buildResultsList(),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            // Keep toggle visible so user can switch modes
            _buildRecommendationModeToggle(),
            const SizedBox(height: 32),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 60,
                color: Colors.black38,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No cars match your criteria',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Try adjusting your budget or preferences\nto discover more options',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (_explanation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _explanation,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.redAccent,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Adjust Preferences',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return CustomScrollView(
      slivers: [
        // Recommendation Mode Toggle
        SliverToBoxAdapter(
          child: _buildRecommendationModeToggle(),
        ),

        // Summary Header
        SliverToBoxAdapter(
          child: _buildSummaryHeader(),
        ),

        // AI Explanation Card
        SliverToBoxAdapter(
          child: _buildExplanationCard(),
        ),

        // Results Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Text(
              'Top ${_rankedCars.length} Recommendations',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),

        // Car Cards
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => _buildCarCard(_rankedCars[index]),
            childCount: _rankedCars.length,
          ),
        ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 32),
        ),
      ],
    );
  }

  Widget _buildRecommendationModeToggle() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Classic',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Switch(
            value: _useGemini,
            onChanged: (value) {
              setState(() {
                _useGemini = value;
              });
              _loadAndRankCars();
            },
            activeTrackColor: Colors.black,
            activeThumbColor: Colors.white,
          ),
          const Text(
            'Gemini',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
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
              label: 'Total Cars',
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white24),
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.filter_alt_rounded,
              value: '$_filteredCount',
              label: 'Filtered',
            ),
          ),
          Container(width: 1, height: 50, color: Colors.white24),
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.star_rounded,
              value: '${_rankedCars.length}',
              label: 'Ranked',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildExplanationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Explanation',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (_isExplaining)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _isExplaining
              ? Text(
                  'Analyzing your recommendations...',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                  ),
                )
              : Text(
                  _explanation,
                  style: TextStyle(
                    height: 1.6,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildCarCard(RankedCar rankedCar) {
    final car = rankedCar.car;
    final isTopPick = rankedCar.rank == 1;
    final isFavorited = _isFavorite(car);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTopPick ? Colors.black : Colors.black.withValues(alpha: 0.1),
          width: isTopPick ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header with rank, car info, and favorite button
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _buildRankBadge(rankedCar.rank),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        car.displayName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RM ${car.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _toggleFavorite(car),
                  icon: Icon(
                    isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFavorited ? Colors.red : Colors.black54,
                  ),
                  tooltip: isFavorited ? 'Remove from favorites' : 'Add to favorites',
                ),
                const SizedBox(width: 8),
                _buildScoreBadge(rankedCar.score),
              ],
            ),
          ),

          // Car Image
          _buildCarImage(car),

          // Specs Row
          Container(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSpecChip(Icons.local_gas_station_rounded, '${car.fuelConsumption}L/100km'),
                _buildSpecChip(Icons.shield_rounded, '${_getNumericSafetyRating(car.safetyRating)}/5'),
                _buildSpecChip(Icons.people_rounded, '${car.seats} seats'),
                _buildSpecChip(Icons.directions_car_rounded, car.type),
                _buildSpecChip(Icons.bolt_rounded, car.fuelCategory.toUpperCase()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getNumericSafetyRating(String rating) {
    if (rating.isEmpty) return 'N/A';
    final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(rating);
    return match?.group(0) ?? 'N/A';
  }

  Widget _buildRankBadge(int rank) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: rank == 1 ? Colors.black : Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        '#$rank',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildScoreBadge(double score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_up_rounded, size: 16),
          const SizedBox(width: 4),
          Text(
            '${(score * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarImage(Car car) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: CarImageWidget(
        car: car,
        width: double.infinity,
        height: 200,
        size: 'medium',
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
