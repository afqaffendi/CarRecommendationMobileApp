import 'package:hive/hive.dart';

part 'car.g.dart'; // This will be generated

@HiveType(typeId: 0)
class Car extends HiveObject {
  @HiveField(0) final String brand;
  @HiveField(1) final String model;
  @HiveField(2) final double price;
  @HiveField(3) final double fuelEconomy; // L/100km
  @HiveField(4) final int seats;
  @HiveField(5) final int bootSpace;
  @HiveField(6) final int safetyRating;
  @HiveField(7) final double horsepower;

  Car({
    required this.brand, required this.model, required this.price,
    required this.fuelEconomy, required this.seats, required this.bootSpace,
    required this.safetyRating, required this.horsepower
  });
}