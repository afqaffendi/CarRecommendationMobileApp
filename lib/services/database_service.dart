import '../models/car.dart';
import '../models/user_preferences.dart';
import 'firestore_service.dart';

class DatabaseService {
  static final FirestoreService _firestore = FirestoreService();

  static final List<Car> _cachedCars = [];
  static final Set<String> _favoriteKeys = <String>{};
  static final List<String> _searchHistory = <String>[];
  static UserPreferences _preferences = UserPreferences();
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  /// Marks the service ready without blocking on a network fetch.
  static void initializeSync() {
    _isInitialized = true;
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await refreshCarsFromFirestore();
  }

  static Future<void> refreshCarsFromFirestore() async {
    try {
      final cars = await _firestore.getCars();
      _cachedCars
        ..clear()
        ..addAll(cars);
    } catch (_) {
      // Keep app running with current cache if network fails.
    }
  }

  static Future<void> cacheCars(List<Car> cars) async {
    _cachedCars
      ..clear()
      ..addAll(cars);
  }

  static List<Car> getCachedCars() => List<Car>.unmodifiable(_cachedCars);

  static bool hasCachedCars() => _cachedCars.isNotEmpty;

  static List<Car> getAllCars() => getCachedCars();

  static String carKeyFromCar(Car car) => '${car.brand}_${car.model}';

  static Car? getCarByKey(String key) {
    for (final car in _cachedCars) {
      if (carKeyFromCar(car) == key) return car;
    }
    return null;
  }

  static Future<void> updateCar(dynamic key, Car updatedCar) async {
    final resolvedKey = key?.toString() ?? carKeyFromCar(updatedCar);
    final index = _cachedCars.indexWhere((car) => carKeyFromCar(car) == resolvedKey);
    if (index >= 0) {
      _cachedCars[index] = updatedCar;
    } else {
      _cachedCars.add(updatedCar);
    }
  }

  static List<Car> searchCars(String query) {
    final q = query.toLowerCase();
    return _cachedCars.where((car) {
      return car.brand.toLowerCase().contains(q) ||
          car.model.toLowerCase().contains(q) ||
          car.type.toLowerCase().contains(q);
    }).toList();
  }

  static Future<void> savePreferences(UserPreferences prefs) async {
    _preferences = prefs;
  }

  static UserPreferences getPreferences() => _preferences;

  static bool hasPreferences() => true;

  static Future<void> addSearchHistory(String searchQuery) async {
    _searchHistory.insert(0, searchQuery);
    if (_searchHistory.length > 50) {
      _searchHistory.removeRange(50, _searchHistory.length);
    }
  }

  static List<String> getSearchHistory() => List<String>.unmodifiable(_searchHistory);

  static Future<void> clearSearchHistory() async {
    _searchHistory.clear();
  }

  static Future<void> addToFavorites(String carKey) async {
    _favoriteKeys.add(carKey);
  }

  static Future<void> removeFromFavorites(String carKey) async {
    _favoriteKeys.remove(carKey);
  }

  static bool isFavorite(String carKey) => _favoriteKeys.contains(carKey);

  static List<String> getFavoriteCarKeys() => _favoriteKeys.toList(growable: false);

  static List<Car> getFavoriteCars() {
    return _favoriteKeys
        .map(getCarByKey)
        .whereType<Car>()
        .toList(growable: false);
  }
}

