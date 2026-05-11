import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/car.dart';
import '../models/user_preferences.dart';
import 'cbf_service.dart';

/// Uses the Groq API (free tier, no billing required) as a reliable
/// alternative to Gemini for AI-powered car recommendations.
/// Get a free key at console.groq.com
class GroqRecommendationService {
  final String apiKey;
  static const String _apiUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.1-8b-instant';
  static const int _maxCandidates = 30;

  static String lastError = '';

  GroqRecommendationService({required this.apiKey});

  Future<List<Car>> getRecommendations({
    required UserPreferences preferences,
    required List<Car> allCars,
  }) async {
    lastError = '';

    if (apiKey.isEmpty) {
      lastError = 'GROQ_API_KEY is missing from .env — get a free key at console.groq.com';
      print('GroqRec: $lastError');
      return [];
    }

    // Stage 1: CBF pre-filter — keeps prompt small and focused.
    List<Car> candidates = CBFService.filterCars(allCars, preferences);
    if (candidates.isEmpty) {
      candidates = preferences.hasBudgetConstraint
          ? allCars.where((c) => c.price <= preferences.budget * 1.2).toList()
          : allCars;
    }

    candidates = _sortByRelevance(candidates, preferences);
    if (candidates.length > _maxCandidates) {
      candidates = candidates.sublist(0, _maxCandidates);
    }

    if (candidates.isEmpty) {
      lastError = 'No candidate cars found after filtering.';
      return [];
    }

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
    }).toList();

    final systemPrompt = _buildSystemPrompt();
    final userPrompt = _buildUserPrompt(preferences, candidateData);

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.1,
          'max_tokens': 1024,
        }),
      );

      if (response.statusCode != 200) {
        lastError = 'Groq API error ${response.statusCode}: ${response.body}';
        print('GroqRec: $lastError');
        return [];
      }

      final body = jsonDecode(response.body);
      final rawText = body['choices']?[0]?['message']?['content'] as String?;

      if (rawText == null || rawText.trim().isEmpty) {
        lastError = 'Groq returned an empty response.';
        return [];
      }

      final Map<String, dynamic> parsed = jsonDecode(rawText);
      final rawList = parsed['recommendations'] as List? ?? [];

      if (rawList.isEmpty) {
        lastError = 'Groq returned an empty recommendations list.';
        return [];
      }

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
          car = _findByDisplayName(item, candidates);
        }
        if (car != null && !result.any((c) => c.key == car!.key)) {
          result.add(car);
        }
      }

      if (result.isEmpty) {
        lastError = 'Groq responded but no car names matched the dataset.';
        print('GroqRec: $lastError\nGroq said: $rawText');
      }

      return result;
    } catch (e) {
      lastError = 'API error: $e';
      print('GroqRec: $lastError');
      return [];
    }
  }

  List<Car> _sortByRelevance(List<Car> cars, UserPreferences prefs) {
    return List<Car>.from(cars)..sort((a, b) {
      final target = prefs.hasBudgetConstraint
          ? prefs.budget
          : cars.map((c) => c.price).reduce((x, y) => x + y) / cars.length;
      return (a.price - target).abs().compareTo((b.price - target).abs());
    });
  }

  Car? _findByBrandModel(String brand, String model, List<Car> cars) {
    final lb = brand.toLowerCase().trim();
    final lm = model.toLowerCase().trim();
    for (final car in cars) {
      if (car.brand.toLowerCase() == lb && car.model.toLowerCase() == lm) return car;
    }
    for (final car in cars) {
      if (car.brand.toLowerCase() == lb &&
          (car.model.toLowerCase().contains(lm) || lm.contains(car.model.toLowerCase()))) {
        return car;
      }
    }
    for (final car in cars) {
      if (car.brand.toLowerCase().contains(lb) && car.model.toLowerCase().contains(lm)) {
        return car;
      }
    }
    return _findByDisplayName('$brand $model', cars);
  }

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

  String _buildSystemPrompt() {
    return 'You are a car recommendation expert for Malaysian buyers. '
        'Always respond with valid JSON only. No explanations, no markdown.';
  }

  String _buildUserPrompt(
    UserPreferences prefs,
    List<Map<String, dynamic>> candidateData,
  ) {
    final originalSection = prefs.originalInput.isNotEmpty
        ? 'User\'s exact words: "${prefs.originalInput}"\n\n'
        : '';

    return """${originalSection}Select the best cars for this user from the list below.

User preferences:
- Budget: ${prefs.hasBudgetConstraint ? 'Up to RM ${prefs.budget.toStringAsFixed(0)}' : 'No strict budget'}
- Car Type: ${prefs.carType}
- Usage: ${prefs.usageType}
- Fuel Type: ${prefs.fuelType}
- Priorities (0.0–1.0): Price=${prefs.priceWeight}, FuelEconomy=${prefs.fuelConsumptionWeight}, Safety=${prefs.safetyWeight}, Performance=${prefs.performance}, Comfort=${prefs.comfort}

Available cars (use ONLY exact brand and model values from this list):
${jsonEncode(candidateData)}

Return JSON:
{"recommendations": [{"brand": "exact value", "model": "exact value"}, ...]}

Pick up to 10 best matches, ordered best to least.""";
  }
}
