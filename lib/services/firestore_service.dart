import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/car.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Remembers which collection had data so we skip the probe on subsequent calls.
  static String? _knownCollection;

  Future<List<Car>> getCars() async {
    try {
      // Fast path: we already know which collection has data.
      if (_knownCollection != null) {
        final snapshot = await _db.collection(_knownCollection!).get();
        if (snapshot.docs.isNotEmpty) {
          return snapshot.docs.map((doc) => Car.fromFirestore(doc)).toList();
        }
        // Collection was deleted or emptied — fall through to full probe.
        _knownCollection = null;
      }

      // Probe all candidate collections simultaneously.
      const candidateCollections = ['malaysia_cars', 'Cars', 'carlist'];
      final snapshots = await Future.wait(
        candidateCollections.map((name) => _db.collection(name).get()),
      );

      for (int i = 0; i < snapshots.length; i++) {
        final snapshot = snapshots[i];
        if (snapshot.docs.isNotEmpty) {
          _knownCollection = candidateCollections[i];
          print('Loaded ${snapshot.docs.length} cars from "$_knownCollection"');
          return snapshot.docs.map((doc) => Car.fromFirestore(doc)).toList();
        }
      }

      print('No car documents found in any Firestore collection.');
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

