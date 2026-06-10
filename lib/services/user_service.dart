import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  static final _db = FirebaseFirestore.instance;

  static Future<void> createUserDocument(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final doc = await ref.get();
    if (!doc.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'role': 'user',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<String> getUserRole(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      return doc.data()?['role'] as String? ?? 'user';
    } catch (_) {
      return 'user';
    }
  }

  static bool isAdmin(String role) => role == 'admin';
}
