import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/car.dart';
import '../models/user_preferences.dart';
import 'cbf_service.dart';

class GeminiRecommendationService {
  final String apiKey;
  static const String _modelName = 'gemini-2.0-flash';
  static const int _maxCandidates = 30;

  GeminiRecommendationService({required this.apiKey});

  Future<List<Car>> getRecommendations({
    required UserPreferences preferences,
    required List<Car> allCars,
  }) async {
    // Stage 1: Use CBF to narrow down to relevant candidates.
    // This keeps the prompt small and focused so Gemini can reason well.
    List<Car> candidates = CBFService.filterCars(allCars, preferences);

    // If CBF filtered everything out (strict budget/type), fall back to
    // a budget-only pre-filter so Gemini still has something to work with.
    if (candidates.isEmpty) {
      candidates = preferences.hasBudgetConstraint
          ? allCars.where((c) => c.price <= preferences.budget * 1.2).toList()
          : allCars;
    }

    // Sort by price proximity to budget — most relevant first — then cap.
    candidates = _sortByRelevance(candidates, preferences);
    if (candidates.length > _maxCandidates) {
      candidates = candidates.sublist(0, _maxCandidates);
    }

    if (candidates.isEmpty) {
      print('GeminiRec: No candidates to send to Gemini.');
      return [];
    }

    final model = GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        responseMimeType: 'application/json',
      ),
    );

    // Build a compact candidate list: only fields Gemini needs for reasoning.
    final candidateData = candidates.map((car) => {
      'brand': car.brand,
      'model': car.model,
      'price': car.price,
      'type': car.type,
      'fuelCategory': car.fuelCategory,
      'fuelConsumption': car.fuelConsumption,
      'seats': car.seats,
      'safetyRating': car.safetyRating,
      'horsepower': car.horsepower,
      'usageType': car.usageType,
    }).toList();

    final prompt = _buildPrompt(preferences, candidateData);

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final jsonText = response.text;

      if (jsonText == null || jsonText.isEmpty) {
        print('GeminiRec: Empty response from model.');
        return [];
      }

      // Strip any stray markdown code fences
      final cleaned = jsonText
          .replaceAll(RegExp(r'```json\s*', caseSensitive: false), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final Map<String, dynamic> parsed = jsonDecode(cleaned);
      final rawList = parsed['recommendations'] as List? ?? [];

      if (rawList.isEmpty) {
        print('GeminiRec: Model returned 0 recommendations.');
        return [];
      }

      // Each item is {"brand": "...", "model": "..."} — match against candidates.
      final result = <Car>[];
      for (final item in rawList) {
        Car? car;
        if (item is Map<String, dynamic>) {
          car = _findByBrandModel(
            item['brand']?.toString() ?? '',
            item['model']?.toString() ?? '',
            candidates,
          );
        } else if (item is String) {
          // Fallback: Gemini returned plain strings despite instructions
          car = _findByDisplayName(item, candidates);
        }

        if (car != null && !result.any((c) => c.key == car!.key)) {
          result.add(car);
        } else if (car == null) {
          print('GeminiRec: No match for item: $item');
        }
      }

      return result;
    } catch (e) {
      print('GeminiRec: Error calling Gemini API: $e');
      return [];
    }
  }

  /// Sort candidates so the most relevant appear first (budget-proximity + type match).
  List<Car> _sortByRelevance(List<Car> cars, UserPreferences prefs) {
    return List<Car>.from(cars)..sort((a, b) {
      // Prefer cars whose price is close to (but not over) budget
      final double targetPrice = prefs.hasBudgetConstraint
          ? prefs.budget
          : (cars.isEmpty ? 100000 : cars.map((c) => c.price).reduce((x, y) => x + y) / cars.length);
      final double diffA = (a.price - targetPrice).abs();
      final double diffB = (b.price - targetPrice).abs();
      return diffA.compareTo(diffB);
    });
  }

  /// Match by brand and model separately (more robust than displayName).
  Car? _findByBrandModel(String brand, String model, List<Car> cars) {
    final lb = brand.toLowerCase().trim();
    final lm = model.toLowerCase().trim();

    // 1. Exact brand + exact model
    for (final car in cars) {
      if (car.brand.toLowerCase() == lb && car.model.toLowerCase() == lm) {
        return car;
      }
    }

    // 2. Exact brand + model contains
    for (final car in cars) {
      if (car.brand.toLowerCase() == lb &&
          (car.model.toLowerCase().contains(lm) || lm.contains(car.model.toLowerCase()))) {
        return car;
      }
    }

    // 3. Brand contains + model contains
    for (final car in cars) {
      if (car.brand.toLowerCase().contains(lb) &&
          car.model.toLowerCase().contains(lm)) {
        return car;
      }
    }

    // 4. Fall back to displayName fuzzy match
    return _findByDisplayName('$brand $model', cars);
  }

  /// Fuzzy displayName matching as last resort.
  Car? _findByDisplayName(String name, List<Car> cars) {
    final lname = name.toLowerCase().trim();

    for (final car in cars) {
      if (car.displayName.toLowerCase() == lname) return car;
    }
    for (final car in cars) {
      final cname = car.displayName.toLowerCase();
      if (lname.contains(cname) || cname.contains(lname)) return car;
    }
    final parts = lname.split(RegExp(r'\s+'));
    for (final car in cars) {
      final carParts = car.displayName.toLowerCase().split(RegExp(r'\s+'));
      if (parts.where((p) => carParts.contains(p)).length >= 2) return car;
    }
    return null;
  }

  String _buildPrompt(
    UserPreferences prefs,
    List<Map<String, dynamic>> candidateData,
  ) {
    final hasOriginal = prefs.originalInput.isNotEmpty;
    final originalSection = hasOriginal
        ? '''
User's exact words (in their own language — English, Malay, or mix):
"${prefs.originalInput}"

Use this to understand their true intent, tone, and priorities.
'''
        : '';

    return """
You are a car recommendation expert for Malaysian buyers. Your job is to select the best cars from the list below that match what the user wants.

$originalSection
Structured preferences (parsed from the user's input):
- Budget: ${prefs.hasBudgetConstraint ? 'Up to RM ${prefs.budget.toStringAsFixed(0)}' : 'No strict budget'}
- Car Type: ${prefs.carType}
- Usage: ${prefs.usageType}
- Fuel Type: ${prefs.fuelType}
- Priority weights (0.0–1.0):
  - Price importance: ${prefs.priceWeight}
  - Fuel economy importance: ${prefs.fuelConsumptionWeight}
  - Safety importance: ${prefs.safetyWeight}
  - Performance: ${prefs.performance}
  - Comfort: ${prefs.comfort}
  - Practicality: ${prefs.practicality}
  - Style: ${prefs.style}

Available cars (select ONLY from this list):
${jsonEncode(candidateData)}

Instructions:
1. Read the user's words (if provided) to understand their real needs beyond the structured fields.
2. Select up to 10 cars from the list above that best match the user's needs.
3. Order them from best match to least.
4. Budget is a strong guide but you may slightly exceed it for an outstanding match.
5. You MUST use the exact "brand" and "model" values from the list above — do not invent or rename cars.

Return ONLY valid JSON in this exact format:
{
  "recommendations": [
    {"brand": "exact brand from list", "model": "exact model from list"},
    {"brand": "exact brand from list", "model": "exact model from list"}
  ]
}
""";
  }
}
