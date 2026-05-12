import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/user_preferences.dart';

String get _groqKey => dotenv.env['GROQ_API_KEY'] ?? '';
const _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
const _groqModel = 'llama-3.1-8b-instant';

/// AI-powered lifestyle input parser using Groq (free, no billing required).
/// Understands ANY natural language and extracts car preferences.
class LifestyleParserService {
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

  Future<ParsedLifestyle> parseLifestyleInput(String userInput) async {
    final normalizedInput = _normalizeSlang(userInput);
    final hasBudgetConstraint = _hasBudgetIntent(normalizedInput.toLowerCase());

    final prompt = '''
You are an intelligent car recommendation assistant in Malaysia. Extract car buying preferences from the user's input.

User said: "$userInput"
Normalized: "$normalizedInput"

ALWAYS extract preferences even if the input is vague. Make intelligent assumptions.

Key interpretations:
- "cheap/murah/budget/jimat/affordable" → lower budget, price important
- "mahal/premium/luxury/atas" → higher budget (220000+), price not important
- "jimat minyak/fuel economy/efficient" → fuel economy important
- "safe/family/keluarga/anak-anak/kids" → safety important
- "KL/city/bandar/traffic/commute/kerja" → city usage
- "kampung/highway/outstation/travel/jauh" → highway usage
- "SUV/sedan/hatchback/mpv/truck/van" → car type
- "EV/electric/elektrik" → ev fuel
- "petrol/minyak/ron95" → petrol fuel
- "hybrid/phev/hev" → hybrid fuel
- Numbers "50k/rm80000/100 ribu" → budget
- "student/fresh grad/first car" → budget ~50000, fuel economy important
- "family/keluarga" → safety important, more seats needed
- Brand names like "Audi", "BMW", "Mercedes", "Toyota", "Honda", "Proton", "Perodua", "Hyundai", "Kia", "Mazda", "Volkswagen", "Volvo", "Lexus", "Tesla", "BYD", "Nissan", "Mitsubishi", "Subaru", "Suzuki" → set preferredBrand
- Specific model names like "Vios", "Bezza", "Myvi", "Axia", "City", "Civic", "Saga", "X50", "Corolla", "Iriz", "Almera", "Yaris" → set preferredModel (lowercase). Also infer brand if known (e.g. "bezza" → brand "perodua", "myvi" → brand "perodua", "saga" → brand "proton").
- "semua/all/semuanya/kesemua" combined with a brand or type → showAll = true (user wants to see all options)

Return ONLY valid JSON, no other text:
{
  "budget": <number in MYR>,
  "usageType": "<city|highway|both>",
  "carType": "<any|sedan|suv|mpv|hatchback|truck|van>",
  "fuelType": "<any|petrol|ev|hybrid>",
  "preferredBrand": "<lowercase brand name or empty string>",
  "preferredModel": "<lowercase model name or empty string>",
  "showAll": <true|false>,
  "priceImportance": <0.0-1.0>,
  "fuelImportance": <0.0-1.0>,
  "safetyImportance": <0.0-1.0>,
  "detectedNeeds": ["<list of detected needs>"],
  "summary": "<friendly English summary of what they want>",
  "confidence": "<high|medium|low>"
}
''';

    try {
      final response = await http.post(
        Uri.parse(_groqUrl),
        headers: {
          'Authorization': 'Bearer $_groqKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _groqModel,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a car preference extractor. Always respond with valid JSON only.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'response_format': {'type': 'json_object'},
          'temperature': 0.2,
          'max_tokens': 512,
        }),
      );

      if (response.statusCode != 200) {
        print('LifestyleParser: Groq error ${response.statusCode}');
        return _fallbackParse(normalizedInput, rawInput: userInput);
      }

      final body = jsonDecode(response.body);
      final jsonText = body['choices']?[0]?['message']?['content'] as String? ?? '{}';
      final parsed = jsonDecode(jsonText) as Map<String, dynamic>;

      final result = ParsedLifestyle(
        budget: (parsed['budget'] as num?)?.toDouble() ?? 80000,
        hasBudgetConstraint: hasBudgetConstraint,
        usageType: parsed['usageType'] as String? ?? 'both',
        carType: parsed['carType'] as String? ?? 'any',
        fuelType: parsed['fuelType'] as String? ?? 'any',
        preferredBrand: (parsed['preferredBrand'] as String? ?? '').toLowerCase().trim(),
        preferredModel: (parsed['preferredModel'] as String? ?? '').toLowerCase().trim(),
        showAll: parsed['showAll'] == true,
        priceImportance: (parsed['priceImportance'] as num?)?.toDouble() ?? 0.5,
        fuelImportance: (parsed['fuelImportance'] as num?)?.toDouble() ?? 0.5,
        safetyImportance: (parsed['safetyImportance'] as num?)?.toDouble() ?? 0.5,
        detectedNeeds: (parsed['detectedNeeds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            ['General car search'],
        summary: parsed['summary'] as String? ?? 'Looking for a suitable car in Malaysia',
        confidence: parsed['confidence'] as String? ?? 'medium',
        rawInput: userInput,
      );

      return _applyIntentHeuristics(result, normalizedInput);
    } catch (e) {
      print('LifestyleParser: Error - $e');
      return _fallbackParse(normalizedInput, rawInput: userInput);
    }
  }

  String _normalizeSlang(String input) {
    var normalized = input;
    for (final entry in _slangRules.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    normalized = normalized.replaceAll(RegExp(r'[_\-\/]+'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }

  ParsedLifestyle _fallbackParse(String input, {String? rawInput}) {
    final lower = input.toLowerCase();
    final hasBudgetConstraint = _hasBudgetIntent(lower);

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

    String usageType = 'both';
    if (lower.contains('city') || lower.contains('kl') || lower.contains('traffic') ||
        lower.contains('bandar') || lower.contains('commute')) {
      usageType = 'city';
    } else if (lower.contains('highway') || lower.contains('kampung') ||
        lower.contains('outstation') || lower.contains('travel')) {
      usageType = 'highway';
    }

    String carType = 'any';
    if (lower.contains('suv')) {
      carType = 'suv';
    } else if (lower.contains('sedan')) carType = 'sedan';
    else if (lower.contains('hatchback')) carType = 'hatchback';
    else if (lower.contains('mpv')) carType = 'mpv';
    else if (lower.contains('truck')) carType = 'truck';
    else if (lower.contains('van')) carType = 'van';

    final fuelType = _resolveFuelTypeFromText('any', lower);

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
    if (lower.contains('mahal') || lower.contains('premium') || lower.contains('luxury') ||
        lower.contains('high-end') || lower.contains('atas')) {
      if (budget < 220000) budget = 220000;
      price = 0.15;
    }

    final detectedBrand = _extractBrandFromText(lower);
    final showAll = RegExp(r'\b(semua|all|semuanya|kesemua)\b').hasMatch(lower);

    final needs = <String>[];
    if (lower.contains('suv')) needs.add('SUV preference');
    if (lower.contains('sedan')) needs.add('Sedan preference');
    if (lower.contains('family')) needs.add('Family car');
    if (lower.contains('first car')) needs.add('First-time buyer');
    if (detectedBrand.isNotEmpty) needs.add('${_capitalizeFirst(detectedBrand)} brand');
    if (needs.isEmpty) needs.add('General car search');

    return ParsedLifestyle(
      budget: budget,
      hasBudgetConstraint: hasBudgetConstraint,
      usageType: usageType,
      carType: carType,
      fuelType: fuelType,
      preferredBrand: detectedBrand,
      preferredModel: '',
      showAll: showAll,
      priceImportance: price,
      fuelImportance: fuel,
      safetyImportance: safety,
      detectedNeeds: needs,
      summary: detectedBrand.isNotEmpty
          ? 'Looking for ${_capitalizeFirst(detectedBrand)} cars'
          : hasBudgetConstraint
              ? 'Looking for a car around RM${budget.toStringAsFixed(0)}'
              : 'Looking for a car without a strict budget',
      confidence: 'medium',
      rawInput: rawInput ?? input,
    );
  }

  String _extractBrandFromText(String lower) {
    const brands = [
      'audi', 'bmw', 'mercedes', 'volkswagen', 'toyota', 'honda',
      'hyundai', 'kia', 'mazda', 'ford', 'proton', 'perodua', 'nissan',
      'mitsubishi', 'suzuki', 'volvo', 'lexus', 'porsche', 'tesla',
      'subaru', 'isuzu', 'chery', 'geely', 'byd', 'mg', 'peugeot',
    ];
    for (final brand in brands) {
      if (RegExp('\\b${RegExp.escape(brand)}\\b').hasMatch(lower)) return brand;
    }
    return '';
  }

  String _capitalizeFirst(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  ParsedLifestyle _applyIntentHeuristics(ParsedLifestyle parsed, String normalizedInput) {
    final lower = normalizedInput.toLowerCase();

    var budget = parsed.budget;
    var hasBudgetConstraint = parsed.hasBudgetConstraint;
    var priceImportance = parsed.priceImportance;
    var fuelType = _normalizeFuelType(parsed.fuelType);

    if (lower.contains('mahal') || lower.contains('premium') || lower.contains('luxury') ||
        lower.contains('high-end') || lower.contains('atas')) {
      if (budget < 220000) budget = 220000;
      if (priceImportance > 0.2) priceImportance = 0.2;
      hasBudgetConstraint = true;
    }

    fuelType = _resolveFuelTypeFromText(fuelType, lower);

    return ParsedLifestyle(
      budget: budget,
      hasBudgetConstraint: hasBudgetConstraint,
      usageType: parsed.usageType,
      carType: parsed.carType,
      fuelType: fuelType,
      preferredBrand: parsed.preferredBrand,
      preferredModel: parsed.preferredModel,
      showAll: parsed.showAll,
      priceImportance: priceImportance,
      fuelImportance: parsed.fuelImportance,
      safetyImportance: parsed.safetyImportance,
      detectedNeeds: parsed.detectedNeeds,
      summary: parsed.summary,
      confidence: parsed.confidence,
      rawInput: parsed.rawInput,
    );
  }

  UserPreferences toUserPreferences(ParsedLifestyle parsed) {
    return UserPreferences(
      budget: parsed.budget,
      hasBudgetConstraint: parsed.hasBudgetConstraint,
      usageType: parsed.usageType,
      carType: parsed.carType,
      fuelType: _normalizeFuelType(parsed.fuelType),
      preferredBrand: parsed.preferredBrand,
      preferredModel: parsed.preferredModel,
      showAll: parsed.showAll,
      originalInput: parsed.rawInput,
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

    if (rejectEv) return (hasHybrid && !hasPetrol) ? 'hybrid' : 'petrol';
    if (rejectPetrol) return (hasHybrid && !hasEv) ? 'hybrid' : 'ev';
    if (rejectHybrid) return (hasEv && !hasPetrol) ? 'ev' : 'petrol';
    if (hasHybrid && !hasPetrol && !hasEv) return 'hybrid';
    if (hasPetrol && !hasEv) return 'petrol';
    if (hasEv && !hasPetrol && !hasHybrid) return 'ev';
    return _normalizeFuelType(currentFuelType);
  }

  bool _hasBudgetIntent(String lowerInput) {
    if (RegExp(r'\b(rm\s*\d+|\d+\s*k|\d+\s*ribu|\d{5,})\b').hasMatch(lowerInput)) return true;
    return RegExp(
      r'\b(budget|bajet|murah|cheap|affordable|jimat|mahal|premium|luxury|high-end|atas|student|pelajar|fresh\s*grad|first\s*car|bawah|under|below)\b',
    ).hasMatch(lowerInput);
  }
}

class ParsedLifestyle {
  final double budget;
  final bool hasBudgetConstraint;
  final String usageType;
  final String carType;
  final String fuelType;
  final String preferredBrand;
  final String preferredModel;
  final bool showAll;
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
    this.preferredBrand = '',
    this.preferredModel = '',
    this.showAll = false,
    required this.priceImportance,
    required this.fuelImportance,
    required this.safetyImportance,
    required this.detectedNeeds,
    required this.summary,
    required this.confidence,
    required this.rawInput,
  });
}
