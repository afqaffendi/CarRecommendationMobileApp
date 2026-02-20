import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import '../models/car.dart';

class CarDataLoader {
  /// Load cars from CSV file in assets
  /// Supports flexible CSV formats with intelligent data inference
  /// Current format: Source,Brand,Model,Price (RM),Engine,Year,Fuel Economy,Seats,Boot Space,Safety Rating,Maintenance Cost,Horsepower,TOPSIS Score,Rank
  static Future<List<Car>> loadFromAsset(String assetPath) async {
    final csvString = await rootBundle.loadString(assetPath);
    return _parseCsv(csvString);
  }

  /// Parse CSV string into Car objects
  /// Expected columns: Brand,Model,Price,FuelEconomy,Seats,BootSpace,SafetyRating,Horsepower,UsageType,ParkingSize,ImageUrl,Variant
  static List<Car> _parseCsv(String csvString) {
    final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
    
    if (rows.isEmpty) return [];

    // Get header to determine column indices
    final header = rows.first.map((e) => e.toString().toLowerCase().replaceAll(' ', '')).toList();
    final dataRows = rows.skip(1);

    return dataRows.map((row) {
      final brand = _getColumn(row, header, ['brand'], '');
      final model = _getColumn(row, header, ['model'], '');
      final price = _toDouble(_getColumn(row, header, ['price', 'price(rm)'], '0'));
      final seats = _toInt(_getColumn(row, header, ['seats'], '5'));
      final horsepower = _toDouble(_getColumn(row, header, ['horsepower', 'hp'], '100'));
      
      return Car(
        brand: brand,
        model: model,
        price: price,
        fuelEconomy: _toDouble(_getColumn(row, header, ['fueleconomy', 'fuel', 'fueleconomy'], '0')),
        seats: seats,
        bootSpace: _toInt(_getColumn(row, header, ['bootspace', 'boot', 'bootspace'], '400')),
        safetyRating: _toInt(_getColumn(row, header, ['safetyrating', 'safety', 'safetyrating'], '3')),
        horsepower: horsepower,
        usageType: _getColumn(row, header, ['usagetype', 'usage'], _inferUsageType(brand, model, seats, horsepower)),
        parkingSize: _getColumn(row, header, ['parkingsize', 'parking'], _inferParkingSize(brand, model, seats)),
        imageUrl: _getColumnOrNull(row, header, ['imageurl', 'image']),
        variant: _getColumnOrNull(row, header, ['variant']),
      );
    }).toList();
  }

  /// Intelligently infer usage type based on car characteristics
  static String _inferUsageType(String brand, String model, int seats, double horsepower) {
    final brandLower = brand.toLowerCase();
    final modelLower = model.toLowerCase();
    
    // Commercial/work vehicles
    if (modelLower.contains('hiace') || modelLower.contains('panel') || 
        modelLower.contains('van') || modelLower.contains('truck')) {
      return 'both'; // Work vehicles used for both city and highway
    }
    
    // City cars (small, efficient)
    if (['perodua', 'proton'].contains(brandLower) && 
        (modelLower.contains('axia') || modelLower.contains('bezza') || modelLower.contains('myvi') ||
         horsepower < 80 || (seats <= 5 && horsepower < 120))) {
      return 'city';
    }
    
    // Highway/performance cars
    if (horsepower > 200 || modelLower.contains('seal') || 
        brandLower == 'byd' && modelLower.contains('seal')) {
      return 'highway';
    }
    
    // Family cars and SUVs - typically used for both city and highway
    if (seats >= 7 || modelLower.contains('suv') || modelLower.contains('m6') ||
        modelLower.contains('atto')) {
      return 'both';
    }
    
    return 'both'; // Default for mixed usage
  }

  /// Intelligently infer parking size needed based on car characteristics
  static String _inferParkingSize(String brand, String model, int seats) {
    final brandLower = brand.toLowerCase();
    final modelLower = model.toLowerCase();
    
    // Large vehicles
    if (modelLower.contains('hiace') || seats >= 7 || 
        modelLower.contains('suv') || modelLower.contains('m6')) {
      return 'large';
    }
    
    // Compact cars
    if (['perodua'].contains(brandLower) && 
        (modelLower.contains('axia') || modelLower.contains('myvi'))) {
      return 'compact';
    }
    
    // EVs tend to be more compact due to battery placement
    if (brandLower == 'byd' && (modelLower.contains('atto') || modelLower.contains('seal'))) {
      return 'medium';
    }
    
    return 'medium'; // Default for most sedans and family cars
  }

  static String _getColumn(List<dynamic> row, List<String> header, List<String> possibleNames, String defaultValue) {
    for (final name in possibleNames) {
      final index = header.indexOf(name);
      if (index >= 0 && index < row.length) {
        final value = row[index].toString().trim();
        if (value.isNotEmpty) return value;
      }
    }
    return defaultValue;
  }

  static String? _getColumnOrNull(List<dynamic> row, List<String> header, List<String> possibleNames) {
    for (final name in possibleNames) {
      final index = header.indexOf(name);
      if (index >= 0 && index < row.length) {
        final value = row[index].toString().trim();
        if (value.isNotEmpty) return value;
      }
    }
    return null;
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}

