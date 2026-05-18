import 'dart:math';
import '../models/car.dart';
import '../models/user_preferences.dart';

/// TOPSIS (Technique for Order of Preference by Similarity to Ideal Solution)
/// Stage 2: Rank filtered cars using multi-criteria decision making
class TopsisService {
  /// Rank cars using TOPSIS algorithm
  /// Returns list of cars sorted by TOPSIS score (best first)
  static List<RankedCar> rankCars(List<Car> cars, UserPreferences prefs) {
    if (cars.isEmpty) return [];
    if (cars.length == 1) {
      return [RankedCar(car: cars[0], score: 1.0, rank: 1)];
    }

    // Step 1: Build decision matrix (normalized)
    final matrix = _buildNormalizedMatrix(cars, prefs);

    // Step 2: Apply weights
    final weights = _normalizeWeights(prefs.weights);
    final weightedMatrix = _applyWeights(matrix, weights);

    // Step 3: Determine ideal best and worst solutions
    final idealBest = _getIdealBest(weightedMatrix);
    final idealWorst = _getIdealWorst(weightedMatrix);

    // Step 4: Calculate distances and TOPSIS scores
    final scores = <double>[];
    for (int i = 0; i < cars.length; i++) {
      final distToBest = _euclideanDistance(weightedMatrix[i], idealBest);
      final distToWorst = _euclideanDistance(weightedMatrix[i], idealWorst);
      final score = distToWorst / (distToBest + distToWorst);
      scores.add(score);
    }

    // Step 5: Rank cars by score
    final rankedCars = <RankedCar>[];
    for (int i = 0; i < cars.length; i++) {
      rankedCars.add(RankedCar(car: cars[i], score: scores[i], rank: 0));
    }

    // Sort by score descending
    rankedCars.sort((a, b) => b.score.compareTo(a.score));

    // Assign ranks
    for (int i = 0; i < rankedCars.length; i++) {
      rankedCars[i] = RankedCar(
        car: rankedCars[i].car,
        score: rankedCars[i].score,
        rank: i + 1,
      );
    }

    return rankedCars;
  }

  /// Build normalized decision matrix
  /// Criteria: [priceDistanceToTarget (cost), fuelConsumption (cost), safety (benefit)]
  static List<List<double>> _buildNormalizedMatrix(List<Car> cars, UserPreferences prefs) {
    // Convert raw price into distance to target budget tier.
    // This keeps TOPSIS as a cost criterion while adapting to user intent:
    // - high price importance => cheaper cars preferred
    // - low price importance (e.g. premium intent) => cars nearer upper budget preferred
    final targetPriceRatio = _targetPriceRatio(prefs.priceWeight);
    final maxPriceInSet = cars
        .map((c) => c.price)
        .reduce((a, b) => a > b ? a : b);
    final budgetAnchor = (prefs.hasBudgetConstraint && prefs.budget > 0)
        ? prefs.budget
        : (maxPriceInSet > 0 ? maxPriceInSet : 1.0);
    final priceDistances = cars.map((c) {
      final ratio = (c.price / budgetAnchor).clamp(0.0, 1.0);
      return (ratio - targetPriceRatio).abs();
    }).toList();

    // Extract raw values
    final fuels = cars.map((c) => c.fuelConsumption).toList();
    final safeties = cars.map((c) => _parseSafetyRating(c.safetyRating)).toList();

    // Calculate normalization denominators (root of sum of squares)
    final priceNorm = _safeNorm(priceDistances);
    final fuelNorm = _safeNorm(fuels);
    final safetyNorm = _safeNorm(safeties);

    // Build normalized matrix
    final matrix = <List<double>>[];
    for (int i = 0; i < cars.length; i++) {
      matrix.add([
        priceDistances[i] / priceNorm,
        fuels[i] / fuelNorm,
        safeties[i] / safetyNorm,
      ]);
    }

    return matrix;
  }

  /// Parses a safety rating string (e.g., "5-star", "Not Rated") into a double.
  static double _parseSafetyRating(String rating) {
    if (rating.isEmpty || rating.toLowerCase() == 'not rated') {
      return 0.0; // Default for unrated or missing data
    }
    // Extracts the first number found in the string.
    final match = RegExp(r'(\d+(\.\d+)?)').firstMatch(rating);
    if (match != null) {
      return double.tryParse(match.group(0)!) ?? 0.0;
    }
    return 0.0;
  }

  static double _targetPriceRatio(double priceWeight) {
    // Clamp to valid range and map user cost sensitivity to a budget target ratio.
    final w = priceWeight.clamp(0.0, 1.0);
    if (w >= 0.7) return 0.20; // very price sensitive
    if (w <= 0.3) return 0.85; // premium / less price sensitive
    return 0.55; // balanced
  }

  static double _safeNorm(List<double> values) {
    final sumSquares = values.fold<double>(0.0, (sum, v) => sum + (v * v));
    final norm = sqrt(sumSquares);
    return norm == 0 ? 1.0 : norm;
  }

  /// Normalize weights to sum to 1
  static Map<String, double> _normalizeWeights(Map<String, double> weights) {
    final total = weights.values.reduce((a, b) => a + b);
    if (total == 0) {
      return {'price': 0.33, 'fuelConsumption': 0.33, 'safety': 0.34};
    }
    return weights.map((key, value) => MapEntry(key, value / total));
  }

  /// Apply weights to normalized matrix
  static List<List<double>> _applyWeights(
    List<List<double>> matrix,
    Map<String, double> weights,
  ) {
    final w = [
      weights['price'] ?? 0.33,
      weights['fuelConsumption'] ?? 0.33,
      weights['safety'] ?? 0.34,
    ];

    return matrix.map((row) {
      return [row[0] * w[0], row[1] * w[1], row[2] * w[2]];
    }).toList();
  }

  /// Get ideal best solution
  /// Price: min (cost criterion), FuelConsumption: min (cost), Safety: max (benefit)
  static List<double> _getIdealBest(List<List<double>> matrix) {
    double minPrice = double.infinity;
    double minFuel = double.infinity;
    double maxSafety = double.negativeInfinity;

    for (final row in matrix) {
      if (row[0] < minPrice) minPrice = row[0];
      // Ignore 0 values for fuel consumption when determining the ideal best
      if (row[1] > 0 && row[1] < minFuel) minFuel = row[1];
      if (row[2] > maxSafety) maxSafety = row[2];
    }

    // If no car had fuel > 0 (all-zero / EV data), treat 0 as the ideal best
    // so the fuel column doesn't inflate distances to infinity.
    if (minFuel == double.infinity) minFuel = 0.0;

    return [minPrice, minFuel, maxSafety];
  }

  /// Get ideal worst solution
  static List<double> _getIdealWorst(List<List<double>> matrix) {
    double maxPrice = double.negativeInfinity;
    double maxFuel = double.negativeInfinity;
    double minSafety = double.infinity;

    for (final row in matrix) {
      if (row[0] > maxPrice) maxPrice = row[0];
      if (row[1] > maxFuel) maxFuel = row[1];
      if (row[2] < minSafety) minSafety = row[2];
    }

    return [maxPrice, maxFuel, minSafety];
  }

  /// Calculate Euclidean distance between two vectors
  static double _euclideanDistance(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      sum += pow(a[i] - b[i], 2);
    }
    return sqrt(sum);
  }
}

/// Car with TOPSIS ranking information
class RankedCar {
  final Car car;
  final double score;  // TOPSIS score (0-1, higher is better)
  final int rank;      // 1 = best

  RankedCar({
    required this.car,
    required this.score,
    required this.rank,
  });
}

