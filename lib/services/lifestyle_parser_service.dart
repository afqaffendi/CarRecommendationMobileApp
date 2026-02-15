import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/user_preferences.dart';

const String _apiKey = 'AIzaSyCNGkdzg4FL06QxfmiescIJD16WBhI3GNw';

/// AI-powered lifestyle input parser
/// Understands ANY natural language and extracts car preferences
class LifestyleParserService {
  late final GenerativeModel _model;

  LifestyleParserService() {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
    );
  }

  /// Parse ANY free-form input into structured preferences
  /// AI will interpret whatever the user says and make reasonable assumptions
  Future<ParsedLifestyle> parseLifestyleInput(String userInput) async {
    final prompt = '''
You are an intelligent car recommendation assistant in Malaysia. Your job is to understand what the user wants and extract car buying preferences from ANY input they give you.

User said: "$userInput"

IMPORTANT: You must ALWAYS extract preferences, even if the input is vague, short, or unusual. Make intelligent assumptions based on context clues. Never say you cannot understand.

Interpret the user's words creatively:
- "cheap" / "murah" / "budget" / "jimat" / "affordable" → lower budget, price is important
- "save petrol" / "fuel" / "jimat minyak" / "ekonomi" → fuel economy is important
- "safe" / "family" / "keselamatan" / "anak-anak" / "kids" → safety is important
- "KL" / "city" / "bandar" / "traffic" / "jam" / "commute" / "kerja" → city usage
- "balik kampung" / "highway" / "jalan jauh" / "outstation" / "travel" → highway usage
- "condo" / "apartment" / "tight" / "sempit" / "small parking" → compact parking
- "landed" / "rumah" / "big" / "besar" / "spacious" → large parking
- Numbers like "50k", "80,000", "100 ribu", "RM70k" → budget amount
- "student" / "pelajar" / "fresh grad" / "first car" → lower budget, fuel efficient
- "family" / "keluarga" / "5 orang" / "anak" → safety important, more seats
- "sporty" / "fast" / "laju" / "power" → performance preference
- "SUV" / "sedan" / "hatchback" → body type preference

If user mentions specific car brands or models, note them in detectedNeeds.
If input is very short or vague, use sensible Malaysian middle-class defaults.

Return a JSON object:
{
  "budget": <number in MYR - extract from text or estimate: student=50000, average=100000, comfortable=150000>,
  "usageType": "<city|highway|both>",
  "parkingSpace": "<compact|medium|large>",
  "priceImportance": <0.0-1.0>,
  "fuelImportance": <0.0-1.0>,
  "safetyImportance": <0.0-1.0>,
  "detectedNeeds": ["<list ALL things you detected from their input>"],
  "summary": "<friendly summary in English of what they're looking for>",
  "confidence": "<high|medium|low> - how confident you are in understanding them"
}

Examples:
- "nak kereta" → budget: 80000, both usage, medium parking, balanced priorities
- "murah je" → budget: 50000, city usage, compact parking, price very important
- "SUV untuk family" → budget: 120000, both usage, medium parking, safety important
- "kerja KL everyday" → budget: 80000, city usage, compact parking, fuel important

Return ONLY valid JSON, no explanation.
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final jsonText = response.text ?? '{}';
      
      // Clean up response (remove markdown code blocks if present)
      final cleanJson = jsonText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      
      final parsed = json.decode(cleanJson) as Map<String, dynamic>;
      
      return ParsedLifestyle(
        budget: (parsed['budget'] as num?)?.toDouble() ?? 80000,
        usageType: parsed['usageType'] as String? ?? 'both',
        parkingSpace: parsed['parkingSpace'] as String? ?? 'medium',
        priceImportance: (parsed['priceImportance'] as num?)?.toDouble() ?? 0.5,
        fuelImportance: (parsed['fuelImportance'] as num?)?.toDouble() ?? 0.5,
        safetyImportance: (parsed['safetyImportance'] as num?)?.toDouble() ?? 0.5,
        detectedNeeds: (parsed['detectedNeeds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? ['General car search'],
        summary: parsed['summary'] as String? ?? 'Looking for a suitable car in Malaysia',
        confidence: parsed['confidence'] as String? ?? 'medium',
        rawInput: userInput,
      );
    } catch (e) {
      // Even on error, return reasonable defaults based on simple keyword detection
      return _fallbackParse(userInput);
    }
  }

  /// Fallback parser using simple keyword detection
  /// This ensures we ALWAYS return something useful
  ParsedLifestyle _fallbackParse(String input) {
    final lower = input.toLowerCase();
    
    // Budget detection
    double budget = 80000;
    final budgetMatch = RegExp(r'(\d+)\s*k|rm\s*(\d+)|(\d{5,})').firstMatch(lower);
    if (budgetMatch != null) {
      final match = budgetMatch.group(1) ?? budgetMatch.group(2) ?? budgetMatch.group(3);
      if (match != null) {
        final num = double.tryParse(match) ?? 80;
        budget = num < 1000 ? num * 1000 : num;
      }
    }
    if (lower.contains('cheap') || lower.contains('murah') || lower.contains('student')) {
      budget = budget > 60000 ? 60000 : budget;
    }
    
    // Usage type detection
    String usageType = 'both';
    if (lower.contains('city') || lower.contains('kl') || lower.contains('traffic') || 
        lower.contains('bandar') || lower.contains('commute')) {
      usageType = 'city';
    } else if (lower.contains('highway') || lower.contains('kampung') || 
               lower.contains('outstation') || lower.contains('travel')) {
      usageType = 'highway';
    }
    
    // Parking detection
    String parking = 'medium';
    if (lower.contains('condo') || lower.contains('apartment') || 
        lower.contains('tight') || lower.contains('sempit')) {
      parking = 'compact';
    } else if (lower.contains('landed') || lower.contains('big') || 
               lower.contains('besar') || lower.contains('spacious')) {
      parking = 'large';
    }
    
    // Priorities
    double price = 0.5, fuel = 0.5, safety = 0.5;
    if (lower.contains('cheap') || lower.contains('murah') || lower.contains('budget') || 
        lower.contains('jimat') || lower.contains('affordable')) {
      price = 0.9;
    }
    if (lower.contains('fuel') || lower.contains('petrol') || lower.contains('minyak') || 
        lower.contains('economy') || lower.contains('efficient')) {
      fuel = 0.9;
    }
    if (lower.contains('safe') || lower.contains('family') || lower.contains('keluarga') || 
        lower.contains('anak') || lower.contains('kid')) {
      safety = 0.9;
    }
    
    // Detect needs from keywords
    List<String> needs = [];
    if (lower.contains('suv')) needs.add('SUV preference');
    if (lower.contains('sedan')) needs.add('Sedan preference');
    if (lower.contains('family')) needs.add('Family car');
    if (lower.contains('first car')) needs.add('First-time buyer');
    if (lower.contains('proton')) needs.add('Proton brand interest');
    if (lower.contains('perodua')) needs.add('Perodua brand interest');
    if (lower.contains('honda')) needs.add('Honda brand interest');
    if (lower.contains('toyota')) needs.add('Toyota brand interest');
    if (needs.isEmpty) needs.add('General car search');
    
    return ParsedLifestyle(
      budget: budget,
      usageType: usageType,
      parkingSpace: parking,
      priceImportance: price,
      fuelImportance: fuel,
      safetyImportance: safety,
      detectedNeeds: needs,
      summary: 'Based on your input, looking for a car around RM${budget.toStringAsFixed(0)}',
      confidence: 'medium',
      rawInput: input,
    );
  }

  /// Convert parsed lifestyle to UserPreferences
  UserPreferences toUserPreferences(ParsedLifestyle parsed) {
    return UserPreferences(
      budget: parsed.budget,
      usageType: parsed.usageType,
      parkingSpace: parsed.parkingSpace,
      priceWeight: parsed.priceImportance,
      fuelEconomyWeight: parsed.fuelImportance,
      safetyWeight: parsed.safetyImportance,
    );
  }
}

/// Structured result from lifestyle parsing
class ParsedLifestyle {
  final double budget;
  final String usageType;
  final String parkingSpace;
  final double priceImportance;
  final double fuelImportance;
  final double safetyImportance;
  final List<String> detectedNeeds;
  final String summary;
  final String confidence;
  final String rawInput;

  ParsedLifestyle({
    required this.budget,
    required this.usageType,
    required this.parkingSpace,
    required this.priceImportance,
    required this.fuelImportance,
    required this.safetyImportance,
    required this.detectedNeeds,
    required this.summary,
    required this.confidence,
    required this.rawInput,
  });
}
