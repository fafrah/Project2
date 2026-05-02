import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  Future<void> createUser({required String uid, required String email}) async {
    await _users.doc(uid).set({
      'email': email,
      'username': email.split('@')[0],
      'createdAt': Timestamp.now(),
    });
  }

  Future<AppUser?> getUser(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    return AppUser.fromMap(uid, snap.data()!);
  }

  Stream<AppUser?> streamUser(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AppUser.fromMap(uid, snap.data()!);
    });
  }

  Future<void> setCurrentSession(String uid, String? sessionId) async {
    await _users.doc(uid).update({'currentSessionId': sessionId});
  }
}
