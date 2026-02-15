import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import '../models/car.dart';

class CarDataLoader {
  /// Load cars from CSV file in assets
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
      return Car(
        brand: _getColumn(row, header, ['brand'], ''),
        model: _getColumn(row, header, ['model'], ''),
        price: _toDouble(_getColumn(row, header, ['price', 'price(rm)'], '0')),
        fuelEconomy: _toDouble(_getColumn(row, header, ['fueleconomy', 'fuel'], '0')),
        seats: _toInt(_getColumn(row, header, ['seats'], '5')),
        bootSpace: _toInt(_getColumn(row, header, ['bootspace', 'boot'], '400')),
        safetyRating: _toInt(_getColumn(row, header, ['safetyrating', 'safety'], '3')),
        horsepower: _toDouble(_getColumn(row, header, ['horsepower', 'hp'], '100')),
        usageType: _getColumn(row, header, ['usagetype', 'usage'], 'both'),
        parkingSize: _getColumn(row, header, ['parkingsize', 'parking'], 'medium'),
        imageUrl: _getColumnOrNull(row, header, ['imageurl', 'image']),
        variant: _getColumnOrNull(row, header, ['variant']),
      );
    }).toList();
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

