import 'package:hive_flutter/hive_flutter.dart';
import '../models/car.dart';
import '../models/user_preferences.dart';

class DatabaseService {
  static const String _carBoxName = 'cars';
  static const String _preferencesBoxName = 'preferences';
  static const String _searchHistoryBoxName = 'search_history';
  static const String _favoriteBoxName = 'favorites';
  static const String _preferencesKey = 'user_prefs';

  static late Box<Car> _carBox;
  static late Box<UserPreferences> _preferencesBox;
  static late Box<String> _searchHistoryBox;
  static late Box<String> _favoriteBox;
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await Hive.initFlutter();
      
      // Register adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(CarAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(UserPreferencesAdapter());
      }

      // Open boxes
      _carBox = await Hive.openBox<Car>(_carBoxName);
      _preferencesBox = await Hive.openBox<UserPreferences>(_preferencesBoxName);
      _searchHistoryBox = await Hive.openBox<String>(_searchHistoryBoxName);
      _favoriteBox = await Hive.openBox<String>(_favoriteBoxName);
      
      _isInitialized = true;
      print('🗄️ Hive database initialized successfully');
    } catch (e) {
      print('❌ Error initializing Hive database: $e');
      rethrow;
    }
  }

  // Car data operations
  static Future<void> cacheCars(List<Car> cars) async {
    _ensureInitialized();
    try {
      await _carBox.clear();
      final Map<String, Car> carMap = {};
      for (var car in cars) {
        final key = '${car.brand}_${car.model}_${car.variant ?? 'base'}';
        carMap[key] = car;
      }
      await _carBox.putAll(carMap);
      print('🚗 Cached ${cars.length} cars to Hive database');
    } catch (e) {
      print('❌ Error caching cars: $e');
      rethrow;
    }
  }

  static List<Car> getCachedCars() {
    _ensureInitialized();
    return _carBox.values.toList();
  }

  static bool hasCachedCars() {
    _ensureInitialized();
    return _carBox.isNotEmpty;
  }

  static Car? getCarByKey(String key) {
    _ensureInitialized();
    return _carBox.get(key);
  }

  // Add alias for getAllCars to match image management service expectations
  static List<Car> getAllCars() {
    return getCachedCars();
  }

  // Update a car in the database
  static Future<void> updateCar(dynamic key, Car updatedCar) async {
    _ensureInitialized();
    try {
      await _carBox.put(key, updatedCar);
      print('✅ Car updated: ${updatedCar.displayName}');
    } catch (e) {
      print('❌ Error updating car: $e');
      rethrow;
    }
  }

  static List<Car> searchCars(String query) {
    _ensureInitialized();
    final searchQuery = query.toLowerCase();
    return _carBox.values.where((car) {
      return car.brand.toLowerCase().contains(searchQuery) ||
             car.model.toLowerCase().contains(searchQuery) ||
             (car.variant?.toLowerCase().contains(searchQuery) ?? false);
    }).toList();
  }

  // User preferences operations
  static Future<void> savePreferences(UserPreferences prefs) async {
    _ensureInitialized();
    try {
      await _preferencesBox.put(_preferencesKey, prefs);
      print('💾 User preferences saved to Hive');
    } catch (e) {
      print('❌ Error saving preferences: $e');
      rethrow;
    }
  }

  static UserPreferences getPreferences() {
    _ensureInitialized();
    return _preferencesBox.get(_preferencesKey) ?? UserPreferences();
  }

  static bool hasPreferences() {
    _ensureInitialized();
    return _preferencesBox.containsKey(_preferencesKey);
  }

  // Search history operations
  static Future<void> addSearchHistory(String searchQuery) async {
    _ensureInitialized();
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      await _searchHistoryBox.put(timestamp, searchQuery);
      
      // Keep only last 50 searches
      if (_searchHistoryBox.length > 50) {
        final keys = _searchHistoryBox.keys.toList()..sort();
        for (int i = 0; i < keys.length - 50; i++) {
          await _searchHistoryBox.delete(keys[i]);
        }
      }
    } catch (e) {
      print('❌ Error adding search history: $e');
    }
  }

  static List<String> getSearchHistory() {
    _ensureInitialized();
    final entries = _searchHistoryBox.toMap().entries.toList();
    entries.sort((a, b) => b.key.compareTo(a.key)); // Sort by timestamp desc
    return entries.map((e) => e.value).take(20).toList();
  }

  static Future<void> clearSearchHistory() async {
    _ensureInitialized();
    await _searchHistoryBox.clear();
  }

  // Favorites operations
  static Future<void> addToFavorites(String carKey) async {
    _ensureInitialized();
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      await _favoriteBox.put(carKey, timestamp);
      print('⭐ Added car to favorites');
    } catch (e) {
      print('❌ Error adding to favorites: $e');
    }
  }

  static Future<void> removeFromFavorites(String carKey) async {
    _ensureInitialized();
    try {
      await _favoriteBox.delete(carKey);
      print('💔 Removed car from favorites');
    } catch (e) {
      print('❌ Error removing from favorites: $e');
    }
  }

  static bool isFavorite(String carKey) {
    _ensureInitialized();
    return _favoriteBox.containsKey(carKey);
  }

  static List<String> getFavoriteCarKeys() {
    _ensureInitialized();
    return _favoriteBox.keys.cast<String>().toList();
  }

  static List<Car> getFavoriteCars() {
    _ensureInitialized();
    final favoriteKeys = getFavoriteCarKeys();
    return favoriteKeys
        .map((key) => getCarByKey(key))
        .where((car) => car != null)
        .cast<Car>()
        .toList();
  }

  // Database statistics and maintenance
  static Map<String, dynamic> getDatabaseStats() {
    _ensureInitialized();
    return {
      'totalCars': _carBox.length,
      'hasPreferences': hasPreferences(),
      'searchHistoryCount': _searchHistoryBox.length,
      'favoritesCount': _favoriteBox.length,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  static Future<void> clearAll() async {
    _ensureInitialized();
    try {
      await _carBox.clear();
      await _preferencesBox.clear();
      await _searchHistoryBox.clear();
      await _favoriteBox.clear();
      print('🧹 All Hive data cleared');
    } catch (e) {
      print('❌ Error clearing all data: $e');
      rethrow;
    }
  }

  static Future<void> compactDatabase() async {
    _ensureInitialized();
    try {
      await _carBox.compact();
      await _preferencesBox.compact();
      await _searchHistoryBox.compact();
      await _favoriteBox.compact();
      print('🗜️ Hive database compacted');
    } catch (e) {
      print('❌ Error compacting database: $e');
    }
  }

  static Future<void> closeDatabase() async {
    if (!_isInitialized) return;
    
    try {
      await _carBox.close();
      await _preferencesBox.close();
      await _searchHistoryBox.close();
      await _favoriteBox.close();
      _isInitialized = false;
      print('🔒 Hive database closed');
    } catch (e) {
      print('❌ Error closing database: $e');
    }
  }

  static void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('DatabaseService not initialized. Call initialize() first.');
    }
  }

  // Export/Import functionality
  static Map<String, dynamic> exportData() {
    _ensureInitialized();
    return {
      'cars': _carBox.values.map((car) => {
        'brand': car.brand,
        'model': car.model,
        'price': car.price,
        'fuelEconomy': car.fuelEconomy,
        'seats': car.seats,
        'bootSpace': car.bootSpace,
        'safetyRating': car.safetyRating,
        'horsepower': car.horsepower,
        'usageType': car.usageType,
        'parkingSize': car.parkingSize,
        'imageUrl': car.imageUrl,
        'variant': car.variant,
      }).toList(),
      'preferences': _preferencesBox.get(_preferencesKey)?.toMap(),
      'searchHistory': _searchHistoryBox.values.toList(),
      'favorites': _favoriteBox.keys.toList(),
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  static Future<bool> importData(Map<String, dynamic> data) async {
    _ensureInitialized();
    try {
      // Import cars
      if (data['cars'] != null) {
        await _carBox.clear();
        final List<dynamic> carsData = data['cars'];
        final cars = carsData.map((carData) => Car(
          brand: carData['brand'],
          model: carData['model'],
          price: carData['price'].toDouble(),
          fuelEconomy: carData['fuelEconomy'].toDouble(),
          seats: carData['seats'],
          bootSpace: carData['bootSpace'],
          safetyRating: carData['safetyRating'],
          horsepower: carData['horsepower'].toDouble(),
          usageType: carData['usageType'],
          parkingSize: carData['parkingSize'],
          imageUrl: carData['imageUrl'],
          variant: carData['variant'],
        )).toList();
        await cacheCars(cars);
      }

      // Import preferences
      if (data['preferences'] != null) {
        final prefsData = data['preferences'];
        final prefs = UserPreferences(
          budget: prefsData['budget'].toDouble(),
          usageType: prefsData['usageType'],
          parkingSpace: prefsData['parkingSpace'],
          priceWeight: prefsData['priceWeight'].toDouble(),
          fuelEconomyWeight: prefsData['fuelEconomyWeight'].toDouble(),
          safetyWeight: prefsData['safetyWeight'].toDouble(),
        );
        await savePreferences(prefs);
      }

      print('📥 Data imported successfully');
      return true;
    } catch (e) {
      print('❌ Error importing data: $e');
      return false;
    }
  }
}
