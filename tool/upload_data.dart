import 'dart:io';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:car_recommendation_app/firebase_options.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  final collection = firestore.collection('malaysia_cars');

  final input = File('../assets/cars.csv').openRead();
  final fields = await input
      .transform(utf8.decoder)
      .transform(const CsvToListConverter())
      .toList();

  final headers = fields[0];
  for (var i = 1; i < fields.length; i++) {
    final values = fields[i];
    final carData = <String, dynamic>{};
    for (var j = 0; j < headers.length; j++) {
      carData[headers[j]] = values[j];
    }

    try {
      await collection.add(carData);
      print('Uploaded car: ${carData['make']} ${carData['model']}');
    } catch (e) {
      print('Error uploading car: ${carData['make']} ${carData['model']} - $e');
    }
  }

  print('Data upload complete!');
}
