import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/car.dart';

class SearchLogService {
  static final _db = FirebaseFirestore.instance;
  static const _collection = 'carSearchStats';

  static Future<void> logTopResults(List<Car> cars) async {
    final top = cars.take(5).toList();
    final batch = _db.batch();
    for (final car in top) {
      final docId = '${car.brand}_${car.model}'
          .replaceAll(' ', '_')
          .toLowerCase();
      final ref = _db.collection(_collection).doc(docId);
      batch.set(ref, {
        'brand': car.brand,
        'model': car.model,
        'displayName': car.displayName,
        'type': car.type,
        'price': car.price,
        'count': FieldValue.increment(1),
        'lastSearched': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  static Future<List<Map<String, dynamic>>> getTopSearchedCars(
      {int limit = 10}) async {
    try {
      final snap = await _db
          .collection(_collection)
          .orderBy('count', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }
}
