import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/user_preferences.dart';

const String _apiKey = 'AIzaSyCNGkdzg4FL06QxfmiescIJD16WBhI3GNw';

/// AI-powered lifestyle input parser
/// Understands ANY natural language and extracts car preferences
class LifestyleParserService {
  late final GenerativeModel _model;

  static final Map<RegExp, String> _slangRules = {
    RegExp(r'\bnk\b', caseSensitive: false): 'nak',
    RegExp(r'\bx\b', caseSensitive: false): 'tak',
    RegExp(r'\btk\b', caseSensitive: false): 'tak',
    RegExp(r'\bxtau\b', caseSensitive: false): 'tak tahu',
    RegExp(r'\bkereta2\b', caseSensitive: false): 'kereta',
    RegExp(r'\bkete\b', caseSensitive: false): 'kereta',
    RegExp(r'\bbajet\b', caseSensitive: false): 'budget',
    RegExp(r'\bjimat2\b', caseSensitive: false): 'jimat',
    RegExp(r'\bminyk\b', caseSensitive: false): 'minyak',
    RegExp(r'\bminyok\b', caseSensitive: false): 'minyak',
    RegExp(r'\bpetrol\b', caseSensitive: false): 'petrol',
    RegExp(r'\bev\b', caseSensitive: false): 'ev',
    RegExp(r'\belektrik\b', caseSensitive: false): 'electric',
    RegExp(r'\bsuvs\b', caseSensitive: false): 'suv',
    RegExp(r'\bjer\b', caseSensitive: false): 'sahaja',
    RegExp(r'\bje\b', caseSensitive: false): 'sahaja',
    RegExp(r'\bpls\b', caseSensitive: false): 'please',
    RegExp(r'\bpls2\b', caseSensitive: false): 'please',
    RegExp(r'\bbrp\b', caseSensitive: false): 'berapa',
    RegExp(r'\brm\s*(\d+)k\b', caseSensitive: false): 'RM \$1 000',
  };

  LifestyleParserService() {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
    );
  }

  /// Parse ANY free-form input into structured preferences
  /// AI will interpret whatever the user says and make reasonable assumptions
  Future<ParsedLifestyle> parseLifestyleInput(String userInput) async {
    final normalizedInput = _normalizeSlang(userInput);
    final hasBudgetConstraint = _hasBudgetIntent(normalizedInput.toLowerCase());

    final prompt = '''
You are an intelligent car recommendation assistant in Malaysia. Your job is to understand what the user wants and extract car buying preferences from ANY input they give you.

User said: "$userInput"
Normalized hint: "$normalizedInput"

IMPORTANT: You must ALWAYS extract preferences, even if the input is vague, short, or unusual. Make intelligent assumptions based on context clues. Never say you cannot understand.

Interpret the user's words creatively:
- "cheap" / "murah" / "budget" / "jimat" / "affordable" → lower budget, price is important
- "mahal" / "premium" / "luxury" / "high-end" / "atas" → higher budget, price is less important
- "save petrol" / "fuel" / "jimat minyak" / "ekonomi" → fuel economy is important
- "safe" / "family" / "keselamatan" / "anak-anak" / "kids" → safety is important
- "KL" / "city" / "bandar" / "traffic" / "jam" / "commute" / "kerja" → city usage
- "balik kampung" / "highway" / "jalan jauh" / "outstation" / "travel" → highway usage
- "SUV" / "sedan" / "hatchback" / "mpv" / "truck" / "van" → preferred car type
- "EV" / "electric" / "elektrik" → prefers EV
- "petrol" / "gasoline" / "bensin" / "minyak" → prefers Petrol
- "hybrid" / "phev" / "hev" / "e:hev" / "ehev" → prefers Hybrid
- Numbers like "50k", "80,000", "100 ribu", "RM70k" → budget amount
- "student" / "pelajar" / "fresh grad" / "first car" → lower budget, fuel efficient
- "family" / "keluarga" / "5 orang" / "anak" → safety important, more seats
- "sporty" / "fast" / "laju" / "power" → performance preference

If user mentions specific car brands or models, note them in detectedNeeds.
If input is very short or vague, use sensible Malaysian middle-class defaults.

Return a JSON object:
{
  "budget": <number in MYR - extract from text or estimate: student=50000, average=100000, comfortable=150000>,
  "usageType": "<city|highway|both>",
  "carType": "<any|sedan|suv|mpv|hatchback|truck|van>",
  "fuelType": "<any|petrol|ev|hybrid>",
  "priceImportance": <0.0-1.0>,
  "fuelImportance": <0.0-1.0>,
  "safetyImportance": <0.0-1.0>,
  "detectedNeeds": ["<list ALL things you detected from their input>"],
  "summary": "<friendly summary in English of what they're looking for>",
  "confidence": "<high|medium|low> - how confident you are in understanding them"
}

Examples:
- "nak kereta" → budget: 80000, both usage, any type, balanced priorities
- "murah je" → budget: 50000, city usage, any type, price very important
- "SUV untuk family" → budget: 120000, both usage, suv, safety important
- "kerja KL everyday" → budget: 80000, city usage, hatchback/sedan, fuel important
- "nak petrol bukan EV" → fuelType: petrol
- "mahu EV" → fuelType: ev
- "nak hybrid" → fuelType: hybrid
- "kete mahal dan pakai petrol" → budget: 220000+, fuelType: petrol, priceImportance low

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
      
      final parsedLifestyle = ParsedLifestyle(
        budget: (parsed['budget'] as num?)?.toDouble() ?? 80000,
        hasBudgetConstraint: hasBudgetConstraint,
        usageType: parsed['usageType'] as String? ?? 'both',
        carType: parsed['carType'] as String? ?? 'any',
        fuelType: parsed['fuelType'] as String? ?? 'any',
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

      return _applyIntentHeuristics(parsedLifestyle, normalizedInput);
    } catch (e) {
      // Even on error, return reasonable defaults based on simple keyword detection
      return _fallbackParse(normalizedInput, rawInput: userInput);
    }
  }

  String _normalizeSlang(String input) {
    var normalized = input;
    for (final entry in _slangRules.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }

    // Normalize separators and repeated spaces.
    normalized = normalized.replaceAll(RegExp(r'[_\-\/]+'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  /// Fallback parser using simple keyword detection
  /// This ensures we ALWAYS return something useful
  ParsedLifestyle _fallbackParse(String input, {String? rawInput}) {
    final lower = input.toLowerCase();
    final hasBudgetConstraint = _hasBudgetIntent(lower);
    
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
    
    // Car type detection
    String carType = 'any';
    if (lower.contains('suv')) {
      carType = 'suv';
    } else if (lower.contains('sedan')) {
      carType = 'sedan';
    } else if (lower.contains('hatchback')) {
      carType = 'hatchback';
    } else if (lower.contains('mpv')) {
      carType = 'mpv';
    } else if (lower.contains('truck')) {
      carType = 'truck';
    } else if (lower.contains('van')) {
      carType = 'van';
    }

    // Fuel type detection (respects negation phrases like "taknak ev")
    final fuelType = _resolveFuelTypeFromText('any', lower);
    
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

    // Expensive / premium intent
    if (lower.contains('mahal') ||
        lower.contains('premium') ||
        lower.contains('luxury') ||
        lower.contains('high-end') ||
        lower.contains('atas')) {
      if (budget < 220000) budget = 220000;
      price = 0.15; // low priority on cheapness
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
      hasBudgetConstraint: hasBudgetConstraint,
      usageType: usageType,
      carType: carType,
      fuelType: fuelType,
      priceImportance: price,
      fuelImportance: fuel,
      safetyImportance: safety,
      detectedNeeds: needs,
      summary: hasBudgetConstraint
          ? 'Based on your input, looking for a car around RM${budget.toStringAsFixed(0)}'
          : 'Based on your input, no strict budget was specified',
      confidence: 'medium',
      rawInput: rawInput ?? input,
    );
  }

  ParsedLifestyle _applyIntentHeuristics(ParsedLifestyle parsed, String normalizedInput) {
    final lower = normalizedInput.toLowerCase();

    var budget = parsed.budget;
    var hasBudgetConstraint = parsed.hasBudgetConstraint;
    var priceImportance = parsed.priceImportance;
    var fuelType = _normalizeFuelType(parsed.fuelType);

    if (lower.contains('mahal') ||
        lower.contains('premium') ||
        lower.contains('luxury') ||
        lower.contains('high-end') ||
        lower.contains('atas')) {
      if (budget < 220000) budget = 220000;
      if (priceImportance > 0.2) priceImportance = 0.2;
      hasBudgetConstraint = true;
    }

    // Hard override from explicit user wording so LLM ambiguity cannot leak EV results.
    fuelType = _resolveFuelTypeFromText(fuelType, lower);

    return ParsedLifestyle(
      budget: budget,
      hasBudgetConstraint: hasBudgetConstraint,
      usageType: parsed.usageType,
      carType: parsed.carType,
      fuelType: fuelType,
      priceImportance: priceImportance,
      fuelImportance: parsed.fuelImportance,
      safetyImportance: parsed.safetyImportance,
      detectedNeeds: parsed.detectedNeeds,
      summary: parsed.summary,
      confidence: parsed.confidence,
      rawInput: parsed.rawInput,
    );
  }

  /// Convert parsed lifestyle to UserPreferences
  UserPreferences toUserPreferences(ParsedLifestyle parsed) {
    return UserPreferences(
      budget: parsed.budget,
      hasBudgetConstraint: parsed.hasBudgetConstraint,
      usageType: parsed.usageType,
      carType: parsed.carType,
      fuelType: _normalizeFuelType(parsed.fuelType),
      priceWeight: parsed.priceImportance,
      fuelConsumptionWeight: parsed.fuelImportance,
      safetyWeight: parsed.safetyImportance,
    );
  }

  String _normalizeFuelType(String? fuelType) {
    final v = (fuelType ?? '').toLowerCase().trim();
    if (v == 'petrol') return 'petrol';
    if (v == 'ev') return 'ev';
    if (v == 'hybrid') return 'hybrid';
    return 'any';
  }

  String _resolveFuelTypeFromText(String currentFuelType, String lowerInput) {
    final hasPetrol = RegExp(r'\b(petrol|gasoline|bensin|ron95|ron97|minyak)\b').hasMatch(lowerInput);
    final hasEv = RegExp(r'\b(ev|electric|elektrik)\b').hasMatch(lowerInput);
    final hasHybrid = RegExp(r'\b(hybrid|phev|hev|e:hev|ehev)\b').hasMatch(lowerInput);

    final rejectEv = RegExp(
      r'\b(tak\s*nak|taknak|x\s*nak|tak\s*mahu|takmahu|tak\s*mau|bukan|no|not)\s*(ev|electric|elektrik)\b',
    ).hasMatch(lowerInput);
    final rejectPetrol = RegExp(
      r'\b(tak\s*nak|taknak|x\s*nak|tak\s*mahu|takmahu|tak\s*mau|bukan|no|not)\s*(petrol|gasoline|bensin|ron95|ron97|minyak)\b',
    ).hasMatch(lowerInput);
    final rejectHybrid = RegExp(
      r'\b(tak\s*nak|taknak|x\s*nak|tak\s*mahu|takmahu|tak\s*mau|bukan|no|not)\s*(hybrid|phev|hev|e:hev|ehev)\b',
    ).hasMatch(lowerInput);

    if (rejectEv) {
      if (hasHybrid && !hasPetrol) return 'hybrid';
      return 'petrol';
    }
    if (rejectPetrol) {
      if (hasHybrid && !hasEv) return 'hybrid';
      return 'ev';
    }
    if (rejectHybrid) {
      if (hasEv && !hasPetrol) return 'ev';
      return 'petrol';
    }

    if (hasHybrid && !hasPetrol && !hasEv) return 'hybrid';

    if (hasPetrol && !hasEv) return 'petrol';
    if (hasEv && !hasPetrol && !hasHybrid) return 'ev';

    return _normalizeFuelType(currentFuelType);
  }

  bool _hasBudgetIntent(String lowerInput) {
    if (RegExp(r'\b(rm\s*\d+|\d+\s*k|\d+\s*ribu|\d{5,})\b').hasMatch(lowerInput)) {
      return true;
    }

    return RegExp(
      r'\b(budget|bajet|murah|cheap|affordable|jimat|mahal|premium|luxury|high-end|atas|student|pelajar|fresh\s*grad|first\s*car|bawah|under|below)\b',
    ).hasMatch(lowerInput);
  }
}

/// Structured result from lifestyle parsing
class ParsedLifestyle {
  final double budget;
  final bool hasBudgetConstraint;
  final String usageType;
  final String carType;
  final String fuelType;
  final double priceImportance;
  final double fuelImportance;
  final double safetyImportance;
  final List<String> detectedNeeds;
  final String summary;
  final String confidence;
  final String rawInput;

  ParsedLifestyle({
    required this.budget,
    required this.hasBudgetConstraint,
    required this.usageType,
    required this.carType,
    required this.fuelType,
    required this.priceImportance,
    required this.fuelImportance,
    required this.safetyImportance,
    required this.detectedNeeds,
    required this.summary,
    required this.confidence,
    required this.rawInput,
  });
}

