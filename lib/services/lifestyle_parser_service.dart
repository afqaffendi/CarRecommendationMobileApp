import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/user_preferences.dart';

String get _groqKey => dotenv.env['GROQ_API_KEY'] ?? '';
const _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
const _groqModel = 'llama-3.1-8b-instant';

class LifestyleParserService {
  static final Map<RegExp, String> _slangRules = {
    RegExp(r'\bnk\b', caseSensitive: false): 'nak',
    RegExp(r'\bxnak\b', caseSensitive: false): 'tak nak',
    RegExp(r'\btaknak\b', caseSensitive: false): 'tak nak',
    RegExp(r'\bx\b', caseSensitive: false): 'tak',
    RegExp(r'\btk\b', caseSensitive: false): 'tak',
    RegExp(r'\bxtau\b', caseSensitive: false): 'tak tahu',
    RegExp(r'\bkereta2\b', caseSensitive: false): 'kereta',
    RegExp(r'\bkete\b', caseSensitive: false): 'kereta',
    RegExp(r'\bketa\b', caseSensitive: false): 'kereta',
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
    RegExp(r'\bbrp\b', caseSensitive: false): 'berapa',
    RegExp(r'\bpegi\b', caseSensitive: false): 'pergi',
    RegExp(r'\bgak\b', caseSensitive: false): 'juga',
    RegExp(r'\bjgk\b', caseSensitive: false): 'juga',
    RegExp(r'\bjgn\b', caseSensitive: false): 'jangan',
    RegExp(r'\bslalu\b', caseSensitive: false): 'selalu',
    RegExp(r'\bskrg\b', caseSensitive: false): 'sekarang',
    RegExp(r'\bsbb\b', caseSensitive: false): 'sebab',
    RegExp(r'\bdh\b', caseSensitive: false): 'dah',
    RegExp(r'\blg\b', caseSensitive: false): 'lagi',
    RegExp(r'\byg\b', caseSensitive: false): 'yang',
    RegExp(r'\bblh\b', caseSensitive: false): 'boleh',
    RegExp(r'\bbwh\b', caseSensitive: false): 'bawah',
    RegExp(r'\bdlm\b', caseSensitive: false): 'dalam',
    RegExp(r'\bkrn\b', caseSensitive: false): 'kerana',
    RegExp(r'\bsmua\b', caseSensitive: false): 'semua',
    RegExp(r'\bkalo\b', caseSensitive: false): 'kalau',
    RegExp(r'\bklu\b', caseSensitive: false): 'kalau',
    RegExp(r'\brm\s*(\d+)k\b', caseSensitive: false): r'RM $1 000',
    RegExp(r'\b(\d+)\s*ribu\b', caseSensitive: false): r'$1 000',
    RegExp(r'\b(\d+)\s*rb\b', caseSensitive: false): r'$1 000',
  };

  Future<ParsedLifestyle> parseLifestyleInput(String userInput) async {
    final normalizedInput = _normalizeSlang(userInput);
    final hasBudgetConstraint = _hasBudgetIntent(normalizedInput.toLowerCase());

    final prompt =
        '''You are an expert car recommendation AI for Malaysia. Extract car preferences from the user's message, which may be in Malay, English, or code-switched (Manglish/Bahasa Rojak).

User said: "$userInput"
Normalized: "$normalizedInput"

LANGUAGE CONTEXT — Malaysian expressions:
Budget: "ribu/rb/k" = thousands | "bawah/under/below" = under that amount | "dalam/sekitar/lebih kurang" = approximately | "murah/jimat/cheap/affordable" = budget-conscious | "mahal/premium/mewah/luxury/high-end/atas" = premium (200k+) | "budget ketat" = tight budget | "tak kesah harga/x kisah duit" = price not important | "sanggup bayar lebih" = willing to spend more
Usage: "kerja KL/pegi ofis/commute" = city | "balik kampung/outstation/jalan jauh/travel jauh" = highway | "bandar/shopping" = city | Klang Valley cities (KL/PJ/Subang/Shah Alam/Cheras/Klang/Putrajaya) = city commuter | "JB/Penang/Ipoh" = city
Family signals: "bini/isteri/suami/wife/husband" = family car | "anak-anak/budak/kids/children/baby" = safety priority | "keluarga/family" = 5-7 seats | "mak ayah/parents/tua" = comfort important
First buyer: "first car/kereta pertama/baru kerja/fresh grad/baru habis study/student/pelajar" = budget 50k-70k, price very important
Car types: "kete kecik/compact/small car" = hatchback | "kete besar/bigger car" = suv or mpv | "salun" = sedan | "4WD/crossover" = suv | "van keluarga" = mpv
Fuel: "jimat minyak/fuel efficient/low consumption" = fuel economy important (NOT necessarily EV) | "charge/bateri/plug in" = ev | "semi-electric/e:HEV/PHEV/mild hybrid" = hybrid | "ron95/ron97/bensin/gasoline" = petrol

Malaysian car brand context (to infer budget range):
- Perodua (Axia 40k, Bezza 45k, Myvi 55k, Ativa 65k, Alza 75k) → budget 40-90k
- Proton (Saga 40k, Iriz 55k, X50 85k, X70 110k, S70 95k) → mid 40-130k
- Toyota/Honda/Mazda → reliable Japanese 70-200k
- Hyundai/Kia → value Korean 80-180k
- BMW/Mercedes/Audi/Volvo/Lexus → premium European 200k+
- Tesla/BYD/Chery/MG → EV options 100-350k

Inference rules:
- "balik kampung selalu" → highway usage, fuel economy important
- "kerja kat KL / commute daily" → city usage
- Any mention of children/anak → safety importance 0.8+
- "first car/baru kerja/fresh grad" → budget 55000, price importance 0.9
- "mahal/luxury/premium" without number → budget 250000, price importance 0.15
- "murah/cheap/jimat" without number → budget 60000, price importance 0.9
- Brand mentioned → infer typical budget range if no explicit budget given
- showAll = true ONLY if user says "semua/all/show me everything/tunjuk semua"

Return ONLY valid JSON (no explanation, no markdown):
{
  "budget": <MYR number>,
  "usageType": "<city|highway|both>",
  "carType": "<any|sedan|suv|mpv|hatchback|truck|van>",
  "fuelType": "<any|petrol|ev|hybrid>",
  "preferredBrand": "<lowercase brand or empty string>",
  "preferredModel": "<lowercase model or empty string>",
  "showAll": <true|false>,
  "priceImportance": <0.0-1.0>,
  "fuelImportance": <0.0-1.0>,
  "safetyImportance": <0.0-1.0>,
  "detectedNeeds": ["2-4 key needs in plain English"],
  "summary": "1-2 friendly English sentences describing what they want",
  "confidence": "<high|medium|low>"
}''';

    try {
      final response = await http
          .post(
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
                  'content':
                      'You are a Malaysian car preference extractor. Respond with valid JSON only. No markdown, no explanation.',
                },
                {'role': 'user', 'content': prompt},
              ],
              'response_format': {'type': 'json_object'},
              'temperature': 0.2,
              'max_tokens': 512,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        debugPrint('LifestyleParser: Groq error ${response.statusCode}');
        return _fallbackParse(normalizedInput, rawInput: userInput);
      }

      final body = jsonDecode(response.body);
      final jsonText =
          body['choices']?[0]?['message']?['content'] as String? ?? '{}';
      final parsed = jsonDecode(jsonText) as Map<String, dynamic>;

      final result = ParsedLifestyle(
        budget: (parsed['budget'] as num?)?.toDouble() ?? 80000,
        hasBudgetConstraint: hasBudgetConstraint,
        usageType: parsed['usageType'] as String? ?? 'both',
        carType: parsed['carType'] as String? ?? 'any',
        fuelType: parsed['fuelType'] as String? ?? 'any',
        preferredBrand:
            (parsed['preferredBrand'] as String? ?? '').toLowerCase().trim(),
        preferredModel:
            (parsed['preferredModel'] as String? ?? '').toLowerCase().trim(),
        showAll: parsed['showAll'] == true,
        priceImportance:
            (parsed['priceImportance'] as num?)?.toDouble() ?? 0.5,
        fuelImportance: (parsed['fuelImportance'] as num?)?.toDouble() ?? 0.5,
        safetyImportance:
            (parsed['safetyImportance'] as num?)?.toDouble() ?? 0.5,
        detectedNeeds: (parsed['detectedNeeds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            ['General car search'],
        summary: parsed['summary'] as String? ??
            'Looking for a suitable car in Malaysia',
        confidence: parsed['confidence'] as String? ?? 'medium',
        rawInput: userInput,
        isOffline: false,
      );

      return _applyIntentHeuristics(result, normalizedInput);
    } on SocketException catch (_) {
      debugPrint('LifestyleParser: No internet connection');
      return _fallbackParse(normalizedInput,
          rawInput: userInput, isOffline: true);
    } on TimeoutException catch (_) {
      debugPrint('LifestyleParser: Request timed out');
      return _fallbackParse(normalizedInput,
          rawInput: userInput, isOffline: true);
    } catch (e) {
      debugPrint('LifestyleParser: Error - $e');
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

  ParsedLifestyle _fallbackParse(String input,
      {String? rawInput, bool isOffline = false}) {
    final lower = input.toLowerCase();
    final hasBudgetConstraint = _hasBudgetIntent(lower);

    double budget = 80000;
    final budgetMatch =
        RegExp(r'(\d+)\s*k|rm\s*(\d+)|(\d{5,})').firstMatch(lower);
    if (budgetMatch != null) {
      final match = budgetMatch.group(1) ??
          budgetMatch.group(2) ??
          budgetMatch.group(3);
      if (match != null) {
        final num = double.tryParse(match) ?? 80;
        budget = num < 1000 ? num * 1000 : num;
      }
    }
    if (lower.contains('cheap') ||
        lower.contains('murah') ||
        lower.contains('student')) {
      budget = budget > 60000 ? 60000 : budget;
    }

    String usageType = 'both';
    if (lower.contains('city') ||
        lower.contains('kl') ||
        lower.contains('traffic') ||
        lower.contains('bandar') ||
        lower.contains('commute') ||
        lower.contains('ofis')) {
      usageType = 'city';
    } else if (lower.contains('highway') ||
        lower.contains('kampung') ||
        lower.contains('outstation') ||
        lower.contains('travel') ||
        lower.contains('jalan jauh')) {
      usageType = 'highway';
    }

    String carType = 'any';
    if (lower.contains('suv')) {
      carType = 'suv';
    } else if (lower.contains('sedan') || lower.contains('salun')) {
      carType = 'sedan';
    } else if (lower.contains('hatchback') || lower.contains('kete kecik')) {
      carType = 'hatchback';
    } else if (lower.contains('mpv') || lower.contains('van keluarga')) {
      carType = 'mpv';
    } else if (lower.contains('truck')) {
      carType = 'truck';
    } else if (lower.contains('van')) {
      carType = 'van';
    }

    final fuelType = _resolveFuelTypeFromText('any', lower);

    double price = 0.5, fuel = 0.5, safety = 0.5;
    if (lower.contains('cheap') ||
        lower.contains('murah') ||
        lower.contains('budget') ||
        lower.contains('jimat') ||
        lower.contains('affordable') ||
        lower.contains('ketat')) {
      price = 0.9;
    }
    if (lower.contains('fuel') ||
        lower.contains('petrol') ||
        lower.contains('minyak') ||
        lower.contains('economy') ||
        lower.contains('efficient') ||
        lower.contains('jimat minyak')) {
      fuel = 0.9;
    }
    if (lower.contains('safe') ||
        lower.contains('family') ||
        lower.contains('keluarga') ||
        lower.contains('anak') ||
        lower.contains('kid') ||
        lower.contains('bini') ||
        lower.contains('isteri')) {
      safety = 0.9;
    }
    if (lower.contains('fresh grad') ||
        lower.contains('baru kerja') ||
        lower.contains('first car') ||
        lower.contains('kereta pertama')) {
      if (budget > 70000) budget = 65000;
      price = 0.9;
    }
    if (lower.contains('mahal') ||
        lower.contains('premium') ||
        lower.contains('luxury') ||
        lower.contains('high-end') ||
        lower.contains('mewah') ||
        lower.contains('atas')) {
      if (budget < 220000) budget = 220000;
      price = 0.15;
    }

    final detectedBrand = _extractBrandFromText(lower);
    final showAll =
        RegExp(r'\b(semua|all|semuanya|kesemua|show everything)\b')
            .hasMatch(lower);

    final needs = <String>[];
    if (lower.contains('suv')) { needs.add('SUV preference'); }
    if (lower.contains('sedan') || lower.contains('salun')) {
      needs.add('Sedan preference');
    }
    if (lower.contains('family') || lower.contains('keluarga')) {
      needs.add('Family car');
    }
    if (lower.contains('first car') ||
        lower.contains('kereta pertama') ||
        lower.contains('fresh grad')) {
      needs.add('First-time buyer');
    }
    if (lower.contains('anak') || lower.contains('kid')) {
      needs.add('Child safety priority');
    }
    if (detectedBrand.isNotEmpty) {
      needs.add('${_capitalizeFirst(detectedBrand)} brand');
    }
    if (needs.isEmpty) { needs.add('General car search'); }

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
      isOffline: isOffline,
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

  ParsedLifestyle _applyIntentHeuristics(
      ParsedLifestyle parsed, String normalizedInput) {
    final lower = normalizedInput.toLowerCase();

    var budget = parsed.budget;
    var hasBudgetConstraint = parsed.hasBudgetConstraint;
    var priceImportance = parsed.priceImportance;
    var fuelType = _normalizeFuelType(parsed.fuelType);

    if (lower.contains('mahal') ||
        lower.contains('premium') ||
        lower.contains('luxury') ||
        lower.contains('mewah') ||
        lower.contains('high-end') ||
        lower.contains('atas')) {
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
      isOffline: parsed.isOffline,
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
    final hasPetrol =
        RegExp(r'\b(petrol|gasoline|bensin|ron95|ron97|minyak)\b')
            .hasMatch(lowerInput);
    final hasEv =
        RegExp(r'\b(ev|electric|elektrik|bateri|charge|plug.?in)\b')
            .hasMatch(lowerInput);
    final hasHybrid =
        RegExp(r'\b(hybrid|phev|hev|e:hev|ehev|mild.?hybrid|semi.?electric)\b')
            .hasMatch(lowerInput);

    final rejectEv = RegExp(
      r'\b(tak\s*nak|taknak|x\s*nak|tak\s*mahu|takmahu|tak\s*mau|bukan|no|not)\s*(ev|electric|elektrik)\b',
    ).hasMatch(lowerInput);
    final rejectPetrol = RegExp(
      r'\b(tak\s*nak|taknak|x\s*nak|tak\s*mahu|takmahu|tak\s*mau|bukan|no|not)\s*(petrol|gasoline|bensin|ron95|ron97|minyak)\b',
    ).hasMatch(lowerInput);
    final rejectHybrid = RegExp(
      r'\b(tak\s*nak|taknak|x\s*nak|tak\s*mahu|takmahu|tak\s*mau|bukan|no|not)\s*(hybrid|phev|hev)\b',
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
    if (RegExp(r'\b(rm\s*\d+|\d+\s*k|\d+\s*ribu|\d+\s*rb|\d{5,})\b')
        .hasMatch(lowerInput)) {
      return true;
    }
    return RegExp(
      r'\b(budget|bajet|murah|cheap|affordable|jimat|mahal|premium|luxury|mewah|high-end|atas|student|pelajar|fresh\s*grad|first\s*car|kereta\s*pertama|bawah|under|below|sekitar|lebih\s*kurang|around)\b',
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
  final bool isOffline;

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
    this.isOffline = false,
  });
}
