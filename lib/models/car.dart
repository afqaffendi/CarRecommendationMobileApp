import 'package:cloud_firestore/cloud_firestore.dart';

class Car {
  final String brand;
  final String model;
  final String engine;
  final double price;

  final double fuelConsumption; // L/100km
  final int seats;
  final int bootSpace;
  final String safetyRating;
  final double horsepower;
  final String type;
  final int year;
  final String? imageUrl;

  Car({
    required this.brand,
    required this.model,
    required this.engine,
    required this.price,

    required this.fuelConsumption,
    required this.seats,
    required this.bootSpace,
    required this.safetyRating,
    required this.horsepower,
    required this.type,
    required this.year,
    this.imageUrl,
  });

  factory Car.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    dynamic pick(List<String> keys) {
      for (final key in keys) {
        if (data.containsKey(key) && data[key] != null) return data[key];
      }
      return null;
    }

    String parseString(List<String> keys, [String fallback = '']) {
      final value = pick(keys);
      return value?.toString() ?? fallback;
    }

    double parseDouble(List<String> keys, [double fallback = 0.0]) {
      final raw = pick(keys)?.toString();
      if (raw == null) return fallback;
      final cleaned = raw.replaceAll(',', '').replaceAll('RM', '').trim();
      return double.tryParse(cleaned) ?? fallback;
    }

    int parseInt(List<String> keys, [int fallback = 0]) {
      final value = parseDouble(keys, fallback.toDouble());
      return value.toInt();
    }

    String inferType(String model) {
      final m = model.toLowerCase();
      if (m.contains('suv') || m.contains('x50') || m.contains('x70') || m.contains('x90') || m.contains('hr-v') || m.contains('corolla cross')) return 'SUV';
      if (m.contains('mpv') || m.contains('alza') || m.contains('veloz') || m.contains('xpander') || m.contains('alphard')) return 'MPV';
      if (m.contains('hatchback') || m.contains('myvi') || m.contains('axia') || m.contains('yaris') || m.contains('iriz')) return 'Hatchback';
      if (m.contains('triton') || m.contains('canter') || m.contains('fuso') || m.contains('truck')) return 'Truck';
      if (m.contains('hiace') || m.contains('van')) return 'Van';
      return 'Sedan';
    }

    final model = parseString(['model_name', 'Model', 'model']);
    final type = parseString(['car_type', 'Type', 'type'], inferType(model));

    return Car(
      brand: parseString(['brand', 'Brand']),
      model: model,
      engine: parseString(['engine_cap', 'Engine', 'engine']),
      price: parseDouble(['price_car', 'Price (RM)', 'Price', 'price', 'priceRm']),

      fuelConsumption: parseDouble(['fuel_consumption_l_100km', 'fuelConsumption']),
      seats: parseInt(['seats', 'Seats']),
      bootSpace: parseInt(['Boot Space', 'bootSpace', 'boot_space']),
      safetyRating: parseString(['safety_rating', 'Safety Rating', 'safetyRating', 'safety_rating']),
      horsepower: parseDouble(['hp', 'Horsepower', 'horsepower']),
      type: type,
      year: parseInt(['year', 'Year'], 2024),
      imageUrl: parseString(['imageUrl', 'image_url']).isEmpty
          ? null
          : parseString(['imageUrl', 'image_url']),
    );
  }

  String get displayName => '$brand $model';

  String get fuelCategory {
    final e = engine.toLowerCase();
    if (e.contains('hybrid') || e.contains('phev') || e.contains('hev') || e.contains('e:hev') || e.contains('ehev')) {
      return 'hybrid';
    }
    if (e.contains('ev') || e.contains('electric') || e.contains('bev')) {
      return 'ev';
    }
    return 'petrol';
  }

  // Backward-compatibility getters for existing UI/services.
  String? get variant => null;

  String get key => '${brand}_${model}';

  String get usageType {
    switch (type.toLowerCase()) {
      case 'hatchback':
      case 'sedan':
        return 'city';
      case 'van':
        return 'highway';
      default:
        return 'both';
    }
  }

  String get parkingSize {
    switch (type.toLowerCase()) {
      case 'hatchback':
        return 'compact';
      case 'suv':
      case 'mpv':
      case 'truck':
      case 'van':
        return 'large';
      default:
        return 'medium';
    }
  }

  factory Car.empty() {
    return Car(
      brand: '',
      model: '',
      engine: '',
      price: 0,
      fuelConsumption: 0,
      seats: 0,
      bootSpace: 0,
      safetyRating: '',
      horsepower: 0,
      type: '',
      year: 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brand': brand,
      'model': model,
      'engine': engine,
      'price': price,
      'fuelConsumption': fuelConsumption,
      'seats': seats,
      'bootSpace': bootSpace,
      'safetyRating': safetyRating,
      'horsepower': horsepower,
      'type': type,
      'year': year,
      'imageUrl': imageUrl,
      'displayName': displayName,
      'fuelCategory': fuelCategory,
      'usageType': usageType,
      'parkingSize': parkingSize,
    };
  }
}
