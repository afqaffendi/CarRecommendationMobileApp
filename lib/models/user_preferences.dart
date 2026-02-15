import 'package:hive/hive.dart';

part 'user_preferences.g.dart';

@HiveType(typeId: 1)
class UserPreferences extends HiveObject {
  // Lifestyle inputs
  @HiveField(0) double budget;              // Max budget in MYR
  @HiveField(1) String usageType;           // city, highway, both
  @HiveField(2) String parkingSpace;        // compact, medium, large

  // Preference weights (0.0 - 1.0)
  @HiveField(3) double priceWeight;
  @HiveField(4) double fuelEconomyWeight;
  @HiveField(5) double safetyWeight;

  UserPreferences({
    this.budget = 100000,
    this.usageType = 'both',
    this.parkingSpace = 'medium',
    this.priceWeight = 0.5,
    this.fuelEconomyWeight = 0.5,
    this.safetyWeight = 0.5,
  });

  Map<String, double> get weights => {
    'price': priceWeight,
    'fuelEconomy': fuelEconomyWeight,
    'safety': safetyWeight,
  };
}
