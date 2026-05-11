class UserPreferences {
  // Lifestyle inputs
  double budget;              // Max budget in MYR
  bool hasBudgetConstraint;   // Apply budget as hard filter only if true
  String usageType;           // city, highway, both
  String carType;             // any, sedan, suv, mpv, hatchback, truck, van
  String fuelType;            // any, petrol, ev, hybrid

  // The raw text the user typed — preserved so Gemini can understand original intent
  String originalInput;

  // Preference weights (0.0 - 1.0)
  double priceWeight;
  double fuelConsumptionWeight;
  double safetyWeight;
  double performance;
  double comfort;
  double safety;
  double practicality;
  double style;

  UserPreferences({
    this.budget = 100000,
    this.hasBudgetConstraint = true,
    this.usageType = 'both',
    this.carType = 'any',
    this.fuelType = 'any',
    this.originalInput = '',
    this.priceWeight = 0.5,
    this.fuelConsumptionWeight = 0.5,
    this.safetyWeight = 0.5,
    this.performance = 0.5,
    this.comfort = 0.5,
    this.safety = 0.5,
    this.practicality = 0.5,
    this.style = 0.5,
  });

  Map<String, double> get weights => {
    'price': priceWeight,
    'fuelConsumption': fuelConsumptionWeight,
    'safety': safetyWeight,
  };

  // For export/import functionality
  Map<String, dynamic> toMap() => {
    'budget': budget,
    'hasBudgetConstraint': hasBudgetConstraint,
    'usageType': usageType,
    'carType': carType,
    'fuelType': fuelType,
    'originalInput': originalInput,
    'priceWeight': priceWeight,
    'fuelConsumptionWeight': fuelConsumptionWeight,
    'safetyWeight': safetyWeight,
    'performance': performance,
    'comfort': comfort,
    'safety': safety,
    'practicality': practicality,
    'style': style,
  };

  factory UserPreferences.fromMap(Map<String, dynamic> map) => UserPreferences(
    budget: map['budget']?.toDouble() ?? 100000,
    hasBudgetConstraint: map['hasBudgetConstraint'] == null
        ? true
        : map['hasBudgetConstraint'] == true,
    usageType: map['usageType'] ?? 'both',
    carType: map['carType'] ?? _legacyParkingToType(map['parkingSpace']?.toString()),
    fuelType: map['fuelType'] ?? 'any',
    originalInput: map['originalInput']?.toString() ?? '',
    priceWeight: map['priceWeight']?.toDouble() ?? 0.5,
    fuelConsumptionWeight: map['fuelConsumptionWeight']?.toDouble() ?? 0.5,
    safetyWeight: map['safetyWeight']?.toDouble() ?? 0.5,
    performance: map['performance']?.toDouble() ?? 0.5,
    comfort: map['comfort']?.toDouble() ?? 0.5,
    safety: map['safety']?.toDouble() ?? 0.5,
    practicality: map['practicality']?.toDouble() ?? 0.5,
    style: map['style']?.toDouble() ?? 0.5,
  );

  static String _legacyParkingToType(String? parkingSpace) {
    switch (parkingSpace) {
      case 'compact':
        return 'hatchback';
      case 'large':
        return 'suv';
      default:
        return 'any';
    }
  }
}

