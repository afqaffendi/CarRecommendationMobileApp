import '../models/car.dart';
import '../models/user_preferences.dart';

/// Content-Based Filtering (CBF) Module - Stage 1
/// Filters cars based on hard constraints from user lifestyle inputs
class CBFService {
  /// Filter cars based on user lifestyle constraints
  /// Returns cars that match: budget, usage type, and parking space
  static List<Car> filterCars(List<Car> allCars, UserPreferences prefs) {
    return allCars.where((car) {
      // Budget constraint (hard filter)
      if (car.price > prefs.budget) return false;

      // Usage type compatibility
      if (!_isUsageCompatible(car.usageType, prefs.usageType)) return false;

      // Parking space compatibility
      if (!_isParkingCompatible(car.parkingSize, prefs.parkingSpace)) return false;

      return true;
    }).toList();
  }

  /// Check if car's usage type matches user preference
  static bool _isUsageCompatible(String carUsage, String userUsage) {
    if (userUsage == 'both') return true;
    if (carUsage == 'both') return true;
    return carUsage == userUsage;
  }

  /// Check if car fits in user's available parking space
  /// User's space >= car's size requirement
  static bool _isParkingCompatible(String carSize, String userSpace) {
    const sizeOrder = {'compact': 1, 'medium': 2, 'large': 3};
    final carSizeValue = sizeOrder[carSize] ?? 2;
    final userSpaceValue = sizeOrder[userSpace] ?? 2;
    return carSizeValue <= userSpaceValue;
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
        'parkingSpace': prefs.parkingSpace,
      },
    };
  }
}

