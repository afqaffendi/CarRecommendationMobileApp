import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/car.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Car>> getCars() async {
    try {
      const candidateCollections = ['malaysia_cars', 'Cars', 'carlist'];

      for (final collectionName in candidateCollections) {
        final snapshot = await _db.collection(collectionName).get();
        if (snapshot.docs.isNotEmpty) {
          final cars = snapshot.docs.map((doc) => Car.fromFirestore(doc)).toList();
          print('Loaded ${cars.length} cars from Firestore collection: $collectionName');
          return cars;
        }
      }

      print('No car documents found in Firestore collections: cars, Cars, carlist');
      return [];
    } on FirebaseException catch (e) {
      print('Firestore error [${e.code}]: ${e.message}');
      return [];
    } catch (e) {
      print('Error fetching cars: $e');
      return [];
    }
  }
}

