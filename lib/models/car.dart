import 'package:hive/hive.dart';

part 'car.g.dart';

@HiveType(typeId: 0)
class Car extends HiveObject {
  @HiveField(0) final String brand;
  @HiveField(1) final String model;
  @HiveField(2) final double price;           // MYR
  @HiveField(3) final double fuelEconomy;     // L/100km
  @HiveField(4) final int seats;
  @HiveField(5) final int bootSpace;          // Liters
  @HiveField(6) final int safetyRating;       // 1-5
  @HiveField(7) final double horsepower;
  @HiveField(8) final String usageType;       // city, highway, both
  @HiveField(9) final String parkingSize;     // compact, medium, large
  @HiveField(10) final String? imageUrl;
  @HiveField(11) final String? variant;

  Car({
    required this.brand,
    required this.model,
    required this.price,
    required this.fuelEconomy,
    required this.seats,
    required this.bootSpace,
    required this.safetyRating,
    required this.horsepower,
    required this.usageType,
    required this.parkingSize,
    this.imageUrl,
    this.variant,
  });

  String get displayName => '$brand $model${variant != null ? ' $variant' : ''}';
}