import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/car.dart';
import '../models/user_preferences.dart';
import 'topsis_service.dart';

const _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
const _groqModel = 'llama-3.1-8b-instant';

class AIExplanationService {
  final String apiKey;

  AIExplanationService({required this.apiKey});

  Future<String> explainRecommendations({
    required List<RankedCar> rankedCars,
    required UserPreferences prefs,
    required int totalCarsBeforeFilter,
  }) async {
    if (rankedCars.isEmpty) {
      return 'No cars match your criteria. Try adjusting your budget or preferences.';
    }

    final topCars = rankedCars.take(3).toList();
    final prompt = _buildPrompt(topCars, prefs, totalCarsBeforeFilter);

    try {
      final response = await http.post(
        Uri.parse(_groqUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _groqModel,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a helpful car recommendation expert for Malaysian buyers. Be concise and friendly.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.5,
          'max_tokens': 400,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['choices']?[0]?['message']?['content'] as String? ??
            _generateFallbackExplanation(topCars, prefs);
      }
      return _generateFallbackExplanation(topCars, prefs);
    } catch (e) {
      return _generateFallbackExplanation(topCars, prefs);
    }
  }

  String _buildPrompt(List<RankedCar> topCars, UserPreferences prefs, int totalCars) {
    final carDetails = topCars.map((rc) {
      final c = rc.car;
      return '- ${c.displayName}: RM${c.price.toStringAsFixed(0)}, '
          '${c.fuelConsumption}L/100km, Safety: ${c.safetyRating}, Score: ${(rc.score * 100).toStringAsFixed(1)}%';
    }).join('\n');

    return '''
Explain why these cars were recommended for this Malaysian buyer.

Preferences:
- Budget: ${prefs.hasBudgetConstraint ? 'RM${prefs.budget.toStringAsFixed(0)}' : 'Open budget'}
- Usage: ${prefs.usageType} driving
- Car type: ${prefs.carType}, Fuel: ${prefs.fuelType}
- Priorities: Price ${(prefs.priceWeight * 100).toInt()}%, Fuel ${(prefs.fuelConsumptionWeight * 100).toInt()}%, Safety ${(prefs.safetyWeight * 100).toInt()}%

Top picks from $totalCars cars:
$carDetails

Write 2-3 short paragraphs explaining why each car suits them and which is the best overall pick. Use Malaysian context (MYR, local driving conditions).''';
  }

  String _generateFallbackExplanation(List<RankedCar> topCars, UserPreferences prefs) {
    final buffer = StringBuffer('Based on your preferences, here are the top recommendations:\n\n');
    for (final rc in topCars) {
      final c = rc.car;
      buffer.writeln('#${rc.rank} ${c.displayName}');
      buffer.writeln('Price: RM${c.price.toStringAsFixed(0)} | Fuel: ${c.fuelConsumption}L/100km | Safety: ${c.safetyRating} | Score: ${(rc.score * 100).toStringAsFixed(1)}%\n');
    }
    buffer.writeln(prefs.hasBudgetConstraint
        ? 'Selected within your budget of RM${prefs.budget.toStringAsFixed(0)}.'
        : 'Selected based on your preferences without a strict budget.');
    return buffer.toString();
  }

  Future<String> explainSingleCar({
    required Car car,
    required UserPreferences prefs,
    required int rank,
  }) async {
    final prompt = '''
You are a Malaysian car recommendation expert. In 2-3 sentences, explain specifically why the ${car.displayName} suits this buyer.

Buyer:
- Budget: ${prefs.hasBudgetConstraint ? 'RM${prefs.budget.toStringAsFixed(0)}' : 'Open budget'}
- Usage: ${prefs.usageType}
- Priorities: Price ${(prefs.priceWeight * 100).toInt()}%, Fuel ${(prefs.fuelConsumptionWeight * 100).toInt()}%, Safety ${(prefs.safetyWeight * 100).toInt()}%

Car (Rank #$rank):
- ${car.displayName} — RM${car.price.toStringAsFixed(0)}
- Engine: ${car.engine}, Transmission: ${car.transmission}
- Fuel: ${car.fuelConsumption}L/100km (${car.fuelCategory})
- Safety: ${car.safetyRating}, Seats: ${car.seats}, Power: ${car.horsepower.toStringAsFixed(0)}hp
- Type: ${car.type}

Be specific about why this car matches their priorities. Mention Malaysia context if relevant.''';

    try {
      final response = await http.post(
        Uri.parse(_groqUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _groqModel,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a concise car advisor for Malaysian buyers. Give personalized, specific explanations in 2-3 sentences only.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.6,
          'max_tokens': 150,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['choices']?[0]?['message']?['content'] as String? ??
            _fallbackSingleCar(car, prefs, rank);
      }
      return _fallbackSingleCar(car, prefs, rank);
    } catch (e) {
      return _fallbackSingleCar(car, prefs, rank);
    }
  }

  String _fallbackSingleCar(Car car, UserPreferences prefs, int rank) {
    final reasons = <String>[];
    if (prefs.hasBudgetConstraint && car.price <= prefs.budget) {
      reasons.add('fits within your budget of RM${prefs.budget.toStringAsFixed(0)}');
    }
    if (car.fuelConsumption > 0 && car.fuelConsumption < 7) {
      reasons.add('excellent fuel economy at ${car.fuelConsumption}L/100km');
    }
    final safetyNum = double.tryParse(
        RegExp(r'(\d+(\.\d+)?)').firstMatch(car.safetyRating)?.group(0) ?? '');
    if (safetyNum != null && safetyNum >= 4) {
      reasons.add('strong safety rating of ${car.safetyRating}');
    }
    if (reasons.isEmpty) reasons.add('a solid overall value for Malaysian buyers');
    return 'The ${car.displayName} ranks #$rank and ${reasons.join(', ')}.';
  }

  Future<String> compareCars(Car car1, Car car2, UserPreferences prefs) async {
    final prompt = '''
Compare these two cars for a Malaysian buyer:

${car1.displayName}: RM${car1.price.toStringAsFixed(0)}, ${car1.fuelConsumption}L/100km, Safety: ${car1.safetyRating}, ${car1.usageType} use
${car2.displayName}: RM${car2.price.toStringAsFixed(0)}, ${car2.fuelConsumption}L/100km, Safety: ${car2.safetyRating}, ${car2.usageType} use

User priorities: Price ${(prefs.priceWeight * 100).toInt()}%, Fuel ${(prefs.fuelConsumptionWeight * 100).toInt()}%, Safety ${(prefs.safetyWeight * 100).toInt()}%

Briefly compare and recommend which is better for this buyer.''';

    try {
      final response = await http.post(
        Uri.parse(_groqUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _groqModel,
          'messages': [{'role': 'user', 'content': prompt}],
          'temperature': 0.5,
          'max_tokens': 300,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['choices']?[0]?['message']?['content'] as String? ?? 'Unable to compare cars.';
      }
      return 'Unable to compare cars.';
    } catch (e) {
      return 'Error comparing cars: $e';
    }
  }
}
