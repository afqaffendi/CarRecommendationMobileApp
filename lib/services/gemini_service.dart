import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/car.dart';

class GeminiService {
  late final GenerativeModel _model;
  late ChatSession _chat;
  final List<Car> _availableCars;

  GeminiService({required String apiKey, required List<Car> availableCars})
      : _availableCars = availableCars {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      systemInstruction: Content.text(_buildSystemPrompt()),
    );
    _chat = _model.startChat();
  }

  String _buildSystemPrompt() {
    final carList = _availableCars
        .map((c) =>
            '${c.brand} ${c.model}: \$${c.price}, ${c.fuelConsumption}L/100km, '
            '${c.seats} seats, ${c.bootSpace}L boot, ${c.safetyRating}/5 safety, '
            '${c.horsepower}hp')
        .join('\n');

    return '''
You are an expert car recommendation assistant for a car dealership app.
You help users find the perfect car based on their needs, compare vehicles, 
and answer questions about available cars.

Available cars in our inventory:
$carList

Guidelines:
- Recommend cars ONLY from the available inventory above
- Consider budget, family size, fuel economy needs, safety preferences
- Be helpful, concise, and knowledgeable
- When comparing cars, highlight key differences
- If asked about cars not in inventory, suggest similar alternatives we have
''';
  }

  /// Chat-based recommendation: Send a message and get AI response
  Future<String> chat(String userMessage) async {
    try {
      final response = await _chat.sendMessage(Content.text(userMessage));
      return response.text ?? 'Sorry, I could not generate a response.';
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  /// Natural language search: Parse user query and return matching cars
  Future<List<Car>> searchCars(String naturalQuery) async {
    final prompt = '''
Based on this user query: "$naturalQuery"
Return ONLY a comma-separated list of car models that match (format: "Brand Model").
If no cars match, return "NONE".
Do not include any other text.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final result = response.text?.trim() ?? '';

      if (result == 'NONE' || result.isEmpty) return [];

      final carNames = result.split(',').map((s) => s.trim().toLowerCase());
      return _availableCars.where((car) {
        final fullName = '${car.brand} ${car.model}'.toLowerCase();
        return carNames.any((name) => fullName.contains(name) || name.contains(fullName));
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Compare multiple cars and explain differences
  Future<String> compareCars(List<Car> carsToCompare) async {
    if (carsToCompare.isEmpty) return 'No cars selected for comparison.';
    if (carsToCompare.length == 1) return 'Please select at least 2 cars to compare.';

    final carDetails = carsToCompare
        .map((c) =>
            '${c.brand} ${c.model}: \$${c.price}, ${c.fuelConsumption}L/100km, '
            '${c.seats} seats, ${c.bootSpace}L boot, ${c.safetyRating}/5 safety, '
            '${c.horsepower}hp')
        .join('\n');

    final prompt = '''
Compare these cars and provide a helpful analysis:
$carDetails

Include:
1. Best for budget
2. Best for families
3. Best fuel economy
4. Best performance
5. Overall recommendation with reasoning
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text ?? 'Could not generate comparison.';
    } catch (e) {
      return 'Error comparing cars: ${e.toString()}';
    }
  }

  /// Reset chat history
  void resetChat() {
    _chat = _model.startChat();
  }

  static Future<List<String>> getSimilarCars(Car car, List<Car> allCars) async {
    final carStrings = allCars
        .map((c) =>
            '${c.brand} ${c.model}: \$${c.price}, ${c.fuelConsumption}L/100km, '
            '${c.type}, ${c.seats} seats, ${c.engine}')
        .toList();

    return carStrings;
  }

  static Future<List<String>> getComparison(Car car1, Car car2) async {
    final carStrings = [car1, car2]
        .map((c) =>
            '${c.brand} ${c.model}: \$${c.price}, ${c.fuelConsumption}L/100km, '
            '${c.type}, ${c.seats} seats, ${c.engine}')
        .toList();

    return carStrings;
  }
}

