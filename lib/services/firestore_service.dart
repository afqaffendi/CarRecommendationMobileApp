import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/car.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<Car>> getCars() async {
    try {
      QuerySnapshot snapshot = await _db.collection('cars').get();
      List<Car> cars = snapshot.docs.map((doc) => Car.fromFirestore(doc)).toList();
      return cars;
    } catch (e) {
      print('Error fetching cars: $e');
      return [];
    }
  }
}
