import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/car.dart';
import '../models/user_preferences.dart';
import 'topsis_service.dart';

/// AI Explanation Module
/// Uses Gemini to generate human-readable explanations for recommendations
class AIExplanationService {
  late final GenerativeModel _model;

  AIExplanationService({required String apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
    );
  }

  /// Generate explanation for why top cars were recommended
  Future<String> explainRecommendations({
    required List<RankedCar> rankedCars,
    required UserPreferences prefs,
    required int totalCarsBeforeFilter,
  }) async {
    if (rankedCars.isEmpty) {
      return "No cars match your criteria. Try adjusting your budget or preferences.";
    }

    final topCars = rankedCars.take(3).toList();
    final prompt = _buildExplanationPrompt(topCars, prefs, totalCarsBeforeFilter);

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? "Unable to generate explanation.";
    } catch (e) {
      return _generateFallbackExplanation(topCars, prefs);
    }
  }

  String _buildExplanationPrompt(
    List<RankedCar> topCars,
    UserPreferences prefs,
    int totalCars,
  ) {
    final carDetails = topCars.map((rc) {
      final c = rc.car;
      return '''
- ${c.displayName}: RM${c.price.toStringAsFixed(0)}, ${c.fuelEconomy}L/100km, 
  Safety: ${c.safetyRating}/5, TOPSIS Score: ${(rc.score * 100).toStringAsFixed(1)}%''';
    }).join('\n');

    return '''
You are a car recommendation expert. Explain why these cars were recommended.

User Preferences:
- Budget: RM${prefs.budget.toStringAsFixed(0)}
- Usage: ${prefs.usageType} driving
- Parking space: ${prefs.parkingSpace}
- Priority weights: Price ${(prefs.priceWeight * 100).toInt()}%, 
  Fuel Economy ${(prefs.fuelEconomyWeight * 100).toInt()}%, 
  Safety ${(prefs.safetyWeight * 100).toInt()}%

From $totalCars cars, ${topCars.length} best matches found:
$carDetails

Write a brief, friendly explanation (2-3 paragraphs) of:
1. Why each car suits the user's needs
2. Key trade-offs between the top options
3. Which car might be best for their specific situation

Be concise and practical. Use Malaysian context (MYR currency, local driving conditions).
''';
  }

  /// Fallback explanation if AI is unavailable
  String _generateFallbackExplanation(
    List<RankedCar> topCars,
    UserPreferences prefs,
  ) {
    final buffer = StringBuffer();
    buffer.writeln("Based on your preferences, here are the top recommendations:\n");

    for (final rc in topCars) {
      final c = rc.car;
      buffer.writeln("**#${rc.rank} ${c.displayName}**");
      buffer.writeln("- Price: RM${c.price.toStringAsFixed(0)}");
      buffer.writeln("- Fuel Economy: ${c.fuelEconomy}L/100km");
      buffer.writeln("- Safety Rating: ${c.safetyRating}/5 stars");
      buffer.writeln("- Match Score: ${(rc.score * 100).toStringAsFixed(1)}%\n");
    }

    buffer.writeln("These cars were selected based on your budget of RM${prefs.budget.toStringAsFixed(0)}, ");
    buffer.writeln("${prefs.usageType} driving needs, and ${prefs.parkingSpace} parking space.");

    return buffer.toString();
  }

  /// Generate comparison between two specific cars
  Future<String> compareCars(Car car1, Car car2, UserPreferences prefs) async {
    final prompt = '''
Compare these two cars for a Malaysian buyer:

Car 1: ${car1.displayName}
- Price: RM${car1.price.toStringAsFixed(0)}
- Fuel: ${car1.fuelEconomy}L/100km
- Safety: ${car1.safetyRating}/5
- Best for: ${car1.usageType} driving

Car 2: ${car2.displayName}
- Price: RM${car2.price.toStringAsFixed(0)}
- Fuel: ${car2.fuelEconomy}L/100km
- Safety: ${car2.safetyRating}/5
- Best for: ${car2.usageType} driving

User priorities: Price ${(prefs.priceWeight * 100).toInt()}%, 
Fuel ${(prefs.fuelEconomyWeight * 100).toInt()}%, Safety ${(prefs.safetyWeight * 100).toInt()}%

Provide a brief comparison highlighting which car is better for what scenario.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? "Unable to compare cars.";
    } catch (e) {
      return "Error comparing cars: $e";
    }
  }
}
