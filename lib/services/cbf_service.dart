import '../models/car.dart';
import '../models/user_preferences.dart';

/// Content-Based Filtering (CBF) Module - Stage 1
/// Filters cars based on hard constraints from user lifestyle inputs
class CBFService {
  /// Filter cars based on user lifestyle constraints
  /// Returns cars that match: budget, usage type, car type, and fuel type
  static List<Car> filterCars(List<Car> allCars, UserPreferences prefs) {
    return allCars.where((car) {
      // Budget constraint (hard filter)
      if (prefs.hasBudgetConstraint && car.price > prefs.budget) return false;

      // Usage type compatibility
      if (!_isUsageCompatible(car.usageType, prefs.usageType)) return false;

      // Car type compatibility
      if (!_isCarTypeCompatible(car.type, prefs.carType)) return false;

      // Fuel type compatibility
      if (!_isFuelTypeCompatible(car.fuelCategory, prefs.fuelType)) return false;

      return true;
    }).toList();
  }

  /// Check if car's usage type matches user preference
  static bool _isUsageCompatible(String carUsage, String userUsage) {
    if (userUsage == 'both') return true;
    if (carUsage == 'both') return true;
    return carUsage == userUsage;
  }

  /// Check if car body type matches user preference
  static bool _isCarTypeCompatible(String carType, String preferredType) {
    if (preferredType == 'any') return true;
    return carType.toLowerCase() == preferredType.toLowerCase();
  }

  /// Check if fuel category matches user preference
  static bool _isFuelTypeCompatible(String carFuelType, String preferredFuelType) {
    if (preferredFuelType == 'any') return true;
    return carFuelType.toLowerCase() == preferredFuelType.toLowerCase();
  }

  /// Get filter summary for explanation
  static Map<String, dynamic> getFilterSummary(
    List<Car> allCars,
    List<Car> filteredCars,
    UserPreferences prefs,
  ) {
    return {
      'totalCars': allCars.length,
      'filteredCars': filteredCars.length,
      'removedCount': allCars.length - filteredCars.length,
      'criteria': {
        'maxBudget': prefs.budget,
        'usageType': prefs.usageType,
        'carType': prefs.carType,
        'fuelType': prefs.fuelType,
      },
    };
  }

  /// Build step-by-step diagnostics when strict filtering returns no cars.
  static Map<String, dynamic> getNoMatchDiagnostics(List<Car> allCars, UserPreferences prefs) {
    final afterBudget = prefs.hasBudgetConstraint
      ? allCars.where((c) => c.price <= prefs.budget).toList()
      : List<Car>.from(allCars);
    final afterUsage = afterBudget
        .where((c) => _isUsageCompatible(c.usageType, prefs.usageType))
        .toList();
    final afterType = afterUsage
        .where((c) => _isCarTypeCompatible(c.type, prefs.carType))
        .toList();
    final afterFuel = afterType
        .where((c) => _isFuelTypeCompatible(c.fuelCategory, prefs.fuelType))
        .toList();

    final preferredFuel = prefs.fuelType.toLowerCase();
    final preferredType = prefs.carType.toLowerCase();

    final fuelAcrossAll = preferredFuel == 'any'
        ? allCars.length
        : allCars.where((c) => c.fuelCategory.toLowerCase() == preferredFuel).length;
    final typeAcrossAll = preferredType == 'any'
        ? allCars.length
        : allCars.where((c) => c.type.toLowerCase() == preferredType).length;

    double? minPriceForPreferredFuel;
    if (prefs.hasBudgetConstraint && preferredFuel != 'any') {
      final fuelCars = allCars
          .where((c) => c.fuelCategory.toLowerCase() == preferredFuel)
          .toList();
      if (fuelCars.isNotEmpty) {
        minPriceForPreferredFuel = fuelCars
            .map((c) => c.price)
            .reduce((a, b) => a < b ? a : b);
      }
    }

    return {
      'totalCars': allCars.length,
      'afterBudget': afterBudget.length,
      'afterUsage': afterUsage.length,
      'afterType': afterType.length,
      'afterFuel': afterFuel.length,
      'fuelAcrossAll': fuelAcrossAll,
      'typeAcrossAll': typeAcrossAll,
      'minPriceForPreferredFuel': minPriceForPreferredFuel,
      'prefs': {
        'budget': prefs.budget,
        'hasBudgetConstraint': prefs.hasBudgetConstraint,
        'usageType': prefs.usageType,
        'carType': prefs.carType,
        'fuelType': prefs.fuelType,
      },
    };
  }
}

