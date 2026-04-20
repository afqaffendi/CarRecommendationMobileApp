class UserPreferences {
  // Lifestyle inputs
  double budget;              // Max budget in MYR
  String usageType;           // city, highway, both
  String parkingSpace;        // compact, medium, large

  // Preference weights (0.0 - 1.0)
  double priceWeight;
  double fuelEconomyWeight;
  double safetyWeight;

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

  // For export/import functionality
  Map<String, dynamic> toMap() => {
    'budget': budget,
    'usageType': usageType,
    'parkingSpace': parkingSpace,
    'priceWeight': priceWeight,
    'fuelEconomyWeight': fuelEconomyWeight,
    'safetyWeight': safetyWeight,
  };

  factory UserPreferences.fromMap(Map<String, dynamic> map) => UserPreferences(
    budget: map['budget']?.toDouble() ?? 100000,
    usageType: map['usageType'] ?? 'both',
    parkingSpace: map['parkingSpace'] ?? 'medium',
    priceWeight: map['priceWeight']?.toDouble() ?? 0.5,
    fuelEconomyWeight: map['fuelEconomyWeight']?.toDouble() ?? 0.5,
    safetyWeight: map['safetyWeight']?.toDouble() ?? 0.5,
  );
}
