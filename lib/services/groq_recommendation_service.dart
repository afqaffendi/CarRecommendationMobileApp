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

  // All known brands for matching against user input
  static const List<String> _knownBrands = [
    'audi', 'bmw', 'mercedes', 'volkswagen', 'toyota', 'honda',
    'hyundai', 'kia', 'mazda', 'ford', 'proton', 'perodua', 'nissan',
    'mitsubishi', 'suzuki', 'volvo', 'lexus', 'porsche', 'tesla',
    'subaru', 'isuzu', 'chery', 'geely', 'byd', 'mg', 'peugeot',
  ];

  GroqRecommendationService({required this.apiKey});

  String _extractBrandFromInput(String input) {
    final lower = input.toLowerCase();
    for (final brand in _knownBrands) {
      if (RegExp('\\b${RegExp.escape(brand)}\\b').hasMatch(lower)) return brand;
    }
    return '';
  }

  /// Returns the model keyword if the user mentioned a specific car model
  /// that exists in the database. Checks longest model names first to prefer
  /// specific matches (e.g. "Vios 1.5 E") over partial ones (e.g. "Vios").
  String _extractModelFromInput(String input, List<Car> allCars) {
    final lower = input.toLowerCase();

    final candidates = <String>{};
    for (final car in allCars) {
      candidates.add(car.model.toLowerCase().trim());
      final firstWord = car.model.toLowerCase().split(RegExp(r'[\s\-]+')).first;
      if (firstWord.length >= 3) candidates.add(firstWord);
    }

    final sorted = candidates.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final keyword in sorted) {
      if (keyword.length < 3) continue;
      final pattern = RegExp(
        '(?<![a-zA-Z0-9])${RegExp.escape(keyword)}(?![a-zA-Z0-9])',
        caseSensitive: false,
      );
      if (pattern.hasMatch(lower)) return keyword;
    }
    return '';
  }

  bool _detectShowAll(String input) {
    final lower = input.toLowerCase();
    return RegExp(r'\b(semua|all|semuanya|kesemua|show all|tunjuk semua)\b').hasMatch(lower);
  }

  bool _brandMatches(Car car, String brand) {
    final carBrand = car.brand.toLowerCase();
    if (brand == 'mercedes') return carBrand.contains('mercedes');
    if (brand == 'volkswagen') return carBrand.contains('volkswagen') || carBrand.contains('vw');
    return carBrand.contains(brand) || brand.contains(carBrand);
  }

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

    // Extract brand intent from original text (ground truth beats parsed preference)
    final rawBrand = _extractBrandFromInput(preferences.originalInput);
    final detectedBrand = rawBrand.isNotEmpty ? rawBrand : preferences.preferredBrand;
    final showAll = _detectShowAll(preferences.originalInput) || preferences.showAll;

    // When user says "semua [brand]" — return all matching cars directly, no AI needed
    if (detectedBrand.isNotEmpty && showAll) {
      final brandCars = allCars.where((c) => _brandMatches(c, detectedBrand)).toList();
      if (brandCars.isEmpty) {
        lastError = 'No ${detectedBrand.toUpperCase()} cars found in the database.';
        return [];
      }
      final result = preferences.hasBudgetConstraint
          ? brandCars.where((c) => c.price <= preferences.budget).toList()
          : brandCars;
      final finalList = result.isNotEmpty ? result : brandCars;
      finalList.sort((a, b) => a.price.compareTo(b.price));
      return finalList;
    }

    // Specific model mentioned — return matching cars directly, no AI needed.
    // Primary: Groq-parsed preferredModel. Secondary: regex scan of raw input.
    final detectedModel = preferences.preferredModel.isNotEmpty
        ? preferences.preferredModel
        : _extractModelFromInput(preferences.originalInput, allCars);
    if (detectedModel.isNotEmpty) {
      var modelCars = allCars
          .where((c) => c.model.toLowerCase().contains(detectedModel))
          .toList();
      if (modelCars.isEmpty) {
        lastError = 'No cars matching "$detectedModel" found in the database.';
        return [];
      }
      if (preferences.hasBudgetConstraint) {
        final budgetFiltered = modelCars.where((c) => c.price <= preferences.budget).toList();
        if (budgetFiltered.isNotEmpty) modelCars = budgetFiltered;
      }
      modelCars.sort((a, b) => a.price.compareTo(b.price));
      return modelCars;
    }

    // Stage 1: Candidate selection
    List<Car> candidates;

    if (detectedBrand.isNotEmpty) {
      // Brand-specific search — bypass CBF relevance sort that would bury brand cars
      candidates = allCars.where((c) => _brandMatches(c, detectedBrand)).toList();
      // Apply fuel type hard filter even in brand path
      candidates = _applyStrictFuelFilter(candidates, preferences.fuelType);
      if (preferences.hasBudgetConstraint) {
        final budgetFiltered = candidates.where((c) => c.price <= preferences.budget).toList();
        if (budgetFiltered.isNotEmpty) candidates = budgetFiltered;
      }
      if (candidates.isEmpty) {
        lastError = 'No ${detectedBrand.toUpperCase()} cars found matching your constraints.';
        return [];
      }
    } else {
      // Standard CBF pre-filter — keeps prompt small and focused.
      candidates = CBFService.filterCars(allCars, preferences);
      if (candidates.isEmpty) {
        // Fallback: relax budget slightly but KEEP fuel type strict
        final fuelFiltered = _applyStrictFuelFilter(allCars, preferences.fuelType);
        candidates = preferences.hasBudgetConstraint
            ? fuelFiltered.where((c) => c.price <= preferences.budget * 1.2).toList()
            : fuelFiltered;
      }
      candidates = _sortByRelevance(candidates, preferences);
      if (candidates.length > _maxCandidates) {
        candidates = candidates.sublist(0, _maxCandidates);
      }
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

    final systemPrompt = _buildSystemPrompt(detectedBrand);
    final userPrompt = _buildUserPrompt(preferences, candidateData, detectedBrand);

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

      // Final guards: enforce fuel type and budget cap regardless of what Groq picked.
      final fuelFiltered = _applyStrictFuelFilter(result, preferences.fuelType);
      return _applyStrictBudgetFilter(fuelFiltered, preferences);
    } catch (e) {
      lastError = 'API error: $e';
      print('GroqRec: $lastError');
      return [];
    }
  }

  /// Hard fuel-type filter — 'any' passes everything, otherwise requires exact match.
  List<Car> _applyStrictFuelFilter(List<Car> cars, String fuelType) {
    if (fuelType == 'any') return cars;
    return cars
        .where((c) => c.fuelCategory.toLowerCase() == fuelType.toLowerCase())
        .toList();
  }

  /// Hard budget filter — only applied when the user has set a budget constraint.
  List<Car> _applyStrictBudgetFilter(List<Car> cars, UserPreferences prefs) {
    if (!prefs.hasBudgetConstraint) return cars;
    return cars.where((c) => c.price <= prefs.budget).toList();
  }

  String _safetyLabel(double weight) {
    if (weight >= 0.8) return '5-star NCAP rated cars only';
    if (weight >= 0.6) return 'prefer 4–5 star NCAP rated cars';
    if (weight >= 0.3) return 'prefer 4+ star rated cars';
    return 'any safety rating';
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

  String _buildSystemPrompt(String detectedBrand) {
    final brandRule = detectedBrand.isNotEmpty
        ? ' The user specifically wants ${detectedBrand.toUpperCase()} brand cars — only recommend cars of this brand.'
        : '';
    return 'You are a car recommendation expert for Malaysian buyers. '
        'You understand both Malay and English.$brandRule '
        'Always respond with valid JSON only. No explanations, no markdown.';
  }

  String _buildUserPrompt(
    UserPreferences prefs,
    List<Map<String, dynamic>> candidateData,
    String detectedBrand,
  ) {
    final contextSection = prefs.originalInput.isNotEmpty
        ? 'Background context (for understanding intent only): "${prefs.originalInput}"\n\n'
        : '';

    final brandNote = detectedBrand.isNotEmpty
        ? '\nIMPORTANT: Only recommend ${detectedBrand.toUpperCase()} cars from the list below.\n'
        : '';

    final budgetLine = prefs.hasBudgetConstraint
        ? 'HARD CAP RM ${prefs.budget.toStringAsFixed(0)} — do not recommend any car above this price'
        : 'No strict budget limit';

    return """${contextSection}FINAL USER PREFERENCES (these override anything in the background context above):
- Budget: $budgetLine
- Car Type: ${prefs.carType}
- Usage: ${prefs.usageType}
- Fuel Type: ${prefs.fuelType} — only recommend cars of this fuel type
- Safety priority: ${_safetyLabel(prefs.safetyWeight)}
- Fuel economy priority: ${prefs.fuelType == 'ev' ? 'N/A (electric)' : (prefs.fuelConsumptionWeight >= 0.7 ? 'high — prefer low L/100km' : prefs.fuelConsumptionWeight <= 0.3 ? 'low' : 'moderate')}

Select the best cars for this user from the list below.$brandNote

Available cars (use ONLY exact brand and model values from this list):
${jsonEncode(candidateData)}

Return JSON:
{"recommendations": [{"brand": "exact value", "model": "exact value"}, ...]}

Pick up to 10 best matches, ordered best to least.""";
  }
}
