import 'package:hive_flutter/hive_flutter.dart';
import '../models/car.dart';
import '../models/user_preferences.dart';

class DatabaseService {
  static const String _carBoxName = 'cars';
  static const String _preferencesBoxName = 'preferences';
  static const String _preferencesKey = 'user_prefs';

  static late Box<Car> _carBox;
  static late Box<UserPreferences> _preferencesBox;

  static Future<void> initialize() async {
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
  }

  // Car data operations
  static Future<void> cacheCars(List<Car> cars) async {
    await _carBox.clear();
    for (var car in cars) {
      await _carBox.add(car);
    }
  }

  static List<Car> getCachedCars() {
    return _carBox.values.toList();
  }

  static bool hasCachedCars() {
    return _carBox.isNotEmpty;
  }

  // User preferences operations
  static Future<void> savePreferences(UserPreferences prefs) async {
    await _preferencesBox.put(_preferencesKey, prefs);
  }

  static UserPreferences getPreferences() {
    return _preferencesBox.get(_preferencesKey) ?? UserPreferences();
  }

  static Future<void> clearAll() async {
    await _carBox.clear();
    await _preferencesBox.clear();
  }
}
