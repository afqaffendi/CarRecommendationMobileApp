import 'package:cloud_firestore/cloud_firestore.dart';

class Car {
  final String brand;
  final String model;
  final double price;
  final double fuelEconomy;
  final int seats;
  final int bootSpace;
  final int safetyRating;
  final double horsepower;
  final String type;
  final int year;
  final String? imageUrl;

  Car({
    required this.brand,
    required this.model,
    required this.price,
    required this.fuelEconomy,
    required this.seats,
    required this.bootSpace,
    required this.safetyRating,
    required this.horsepower,
    required this.type,
    required this.year,
    this.imageUrl,
  });

  factory Car.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Car(
      brand: data['Brand'] ?? '',
      model: data['Model'] ?? '',
      price: double.tryParse(data['Price (RM)']?.toString() ?? '0.0') ?? 0.0,
      fuelEconomy: double.tryParse(data['Fuel Economy']?.toString() ?? '0.0') ?? 0.0,
      seats: int.tryParse(data['Seats']?.toString() ?? '0') ?? 0,
      bootSpace: int.tryParse(data['Boot Space']?.toString() ?? '0') ?? 0,
      safetyRating: int.tryParse(data['Safety Rating']?.toString() ?? '0') ?? 0,
      horsepower: double.tryParse(data['Horsepower']?.toString() ?? '0.0') ?? 0.0,
      type: data['Type'] ?? '',
      year: int.tryParse(data['Year']?.toString() ?? '2024') ?? 2024,
      imageUrl: data['imageUrl'], // Assuming you might add this field later
    );
  }

  String get displayName => '$brand $model';

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
}