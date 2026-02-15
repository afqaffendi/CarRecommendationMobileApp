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
    final matrix = _buildNormalizedMatrix(cars);

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
  /// Criteria: [price (cost), fuelEconomy (cost), safety (benefit)]
  static List<List<double>> _buildNormalizedMatrix(List<Car> cars) {
    // Extract raw values
    final prices = cars.map((c) => c.price).toList();
    final fuels = cars.map((c) => c.fuelEconomy).toList();
    final safeties = cars.map((c) => c.safetyRating.toDouble()).toList();

    // Calculate normalization denominators (root of sum of squares)
    final priceNorm = sqrt(prices.map((p) => p * p).reduce((a, b) => a + b));
    final fuelNorm = sqrt(fuels.map((f) => f * f).reduce((a, b) => a + b));
    final safetyNorm = sqrt(safeties.map((s) => s * s).reduce((a, b) => a + b));

    // Build normalized matrix
    final matrix = <List<double>>[];
    for (int i = 0; i < cars.length; i++) {
      matrix.add([
        prices[i] / priceNorm,
        fuels[i] / fuelNorm,
        safeties[i] / safetyNorm,
      ]);
    }

    return matrix;
  }

  /// Normalize weights to sum to 1
  static Map<String, double> _normalizeWeights(Map<String, double> weights) {
    final total = weights.values.reduce((a, b) => a + b);
    if (total == 0) {
      return {'price': 0.33, 'fuelEconomy': 0.33, 'safety': 0.34};
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
      weights['fuelEconomy'] ?? 0.33,
      weights['safety'] ?? 0.34,
    ];

    return matrix.map((row) {
      return [row[0] * w[0], row[1] * w[1], row[2] * w[2]];
    }).toList();
  }

  /// Get ideal best solution
  /// Price: min (cost criterion), FuelEconomy: min (cost), Safety: max (benefit)
  static List<double> _getIdealBest(List<List<double>> matrix) {
    double minPrice = double.infinity;
    double minFuel = double.infinity;
    double maxSafety = double.negativeInfinity;

    for (final row in matrix) {
      if (row[0] < minPrice) minPrice = row[0];
      if (row[1] < minFuel) minFuel = row[1];
      if (row[2] > maxSafety) maxSafety = row[2];
    }

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
