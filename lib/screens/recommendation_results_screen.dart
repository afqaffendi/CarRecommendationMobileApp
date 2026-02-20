import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/car.dart';
import '../models/user_preferences.dart';
import '../services/car_data_loader.dart';
import '../services/cbf_service.dart';
import '../services/topsis_service.dart';
import '../services/ai_explanation_service.dart';
import '../services/database_service.dart';
import '../widgets/car_image_widget.dart';
import 'favorites_screen.dart';

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
        allCars = await CarDataLoader.loadFromAsset('assets/cars.csv');
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

  Future<void> _toggleFavorite(Car car) async {
    final carKey = '${car.brand}_${car.model}_${car.variant ?? 'base'}';
    try {
      if (DatabaseService.isFavorite(carKey)) {
        await DatabaseService.removeFromFavorites(carKey);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Removed ${car.displayName} from favorites',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        await DatabaseService.addToFavorites(carKey);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Added ${car.displayName} to favorites',
                style: GoogleFonts.inter(),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      setState(() {}); // Refresh to update favorite icons
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating favorites: $e', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Your Perfect Car',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoritesScreen(),
                ),
              );
            },
            tooltip: 'My Favorites',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAndRankCars,
            tooltip: 'Refresh',
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
                    style: GoogleFonts.inter(
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
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
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Try adjusting your budget or preferences\nto discover more options',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.black54,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
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
                  style: GoogleFonts.inter(
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
              style: GoogleFonts.poppins(
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
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
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
        border: Border.all(color: Colors.black.withOpacity(0.1)),
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
                style: GoogleFonts.poppins(
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
                  style: GoogleFonts.inter(
                    color: Colors.black54,
                    fontSize: 15,
                  ),
                )
              : Text(
                  _explanation,
                  style: GoogleFonts.inter(
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
    final carKey = '${car.brand}_${car.model}_${car.variant ?? 'base'}';
    final isFavorited = DatabaseService.isFavorite(carKey);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTopPick ? Colors.black : Colors.black.withOpacity(0.1),
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
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'RM ${car.price.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
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
                _buildSpecChip(Icons.local_gas_station_rounded, '${car.fuelEconomy}L/100km'),
                _buildSpecChip(Icons.shield_rounded, '${car.safetyRating}/5'),
                _buildSpecChip(Icons.people_rounded, '${car.seats} seats'),
                _buildSpecChip(Icons.route_rounded, car.usageType),
                _buildSpecChip(Icons.local_parking_rounded, car.parkingSize),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: rank == 1 ? Colors.black : Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        '#$rank',
        style: GoogleFonts.poppins(
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
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_up_rounded, size: 16),
          const SizedBox(width: 4),
          Text(
            '${(score * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.montserrat(
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
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
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