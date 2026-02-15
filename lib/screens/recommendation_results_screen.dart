import 'package:flutter/material.dart';
import '../models/car.dart';
import '../models/user_preferences.dart';
import '../services/car_data_loader.dart';
import '../services/cbf_service.dart';
import '../services/topsis_service.dart';
import '../services/ai_explanation_service.dart';
import '../services/database_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadAndRankCars();
  }

  Future<void> _loadAndRankCars() async {
    setState(() => _isLoading = true);

    try {
      // Load cars from cache or CSV
      List<Car> allCars;
      if (DatabaseService.hasCachedCars()) {
        allCars = DatabaseService.getCachedCars();
      } else {
        allCars = await CarDataLoader.loadFromAsset('assets/malaysian_cars.csv');
        await DatabaseService.cacheCars(allCars);
      }
      _totalCars = allCars.length;

      // Stage 1: CBF Filtering
      final filteredCars = CBFService.filterCars(allCars, widget.preferences);
      _filteredCount = filteredCars.length;

      // Stage 2: TOPSIS Ranking
      _rankedCars = TopsisService.rankCars(filteredCars, widget.preferences);

      setState(() => _isLoading = false);

      // Generate AI Explanation
      _generateExplanation();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _explanation = 'Error loading cars: $e';
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAndRankCars,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rankedCars.isEmpty
              ? _buildEmptyState()
              : _buildResultsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No cars match your criteria',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your budget or preferences',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context),
              child: const Text('Adjust Preferences'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return CustomScrollView(
      slivers: [
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.format_list_numbered, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Top ${_rankedCars.length} Matches',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
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
          child: SizedBox(height: 24),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.directions_car,
              value: '$_totalCars',
              label: 'Total Cars',
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white30),
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.filter_alt,
              value: '$_filteredCount',
              label: 'After CBF',
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white30),
          Expanded(
            child: _buildSummaryItem(
              icon: Icons.stars,
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
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildExplanationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              const Text(
                'AI Explanation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const Spacer(),
              if (_isExplaining)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _isExplaining
              ? const Text('Analyzing your recommendations...')
              : Text(
                  _explanation,
                  style: const TextStyle(height: 1.5),
                ),
        ],
      ),
    );
  }

  Widget _buildCarCard(RankedCar rankedCar) {
    final car = rankedCar.car;
    final isTopPick = rankedCar.rank == 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTopPick ? Colors.amber : Colors.grey.shade200,
          width: isTopPick ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Rank Badge & Title
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildRankBadge(rankedCar.rank),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        car.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'RM ${car.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildScoreBadge(rankedCar.score),
              ],
            ),
          ),

          // Specs Row
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                _buildSpecChip(Icons.local_gas_station, '${car.fuelEconomy}L/100km'),
                const SizedBox(width: 8),
                _buildSpecChip(Icons.health_and_safety, '${car.safetyRating}/5'),
                const SizedBox(width: 8),
                _buildSpecChip(Icons.event_seat, '${car.seats} seats'),
              ],
            ),
          ),

          // Tags Row
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                _buildTag(car.usageType, Icons.route),
                const SizedBox(width: 8),
                _buildTag(car.parkingSize, Icons.local_parking),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color bgColor;
    Color textColor;

    switch (rank) {
      case 1:
        bgColor = Colors.amber;
        textColor = Colors.black;
        break;
      case 2:
        bgColor = Colors.grey.shade400;
        textColor = Colors.white;
        break;
      case 3:
        bgColor = Colors.brown.shade300;
        textColor = Colors.white;
        break;
      default:
        bgColor = Colors.grey.shade200;
        textColor = Colors.black54;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '#$rank',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildScoreBadge(double score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_up, size: 16),
          const SizedBox(width: 4),
          Text(
            '${(score * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blue.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
          ),
        ],
      ),
    );
  }
}
