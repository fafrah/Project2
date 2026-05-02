import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/session.dart';

class SessionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _sessions =>
      _db.collection('sessions');

  Future<Session> createSession({
    required String hostUid,
    required String hostUsername,
    required String name,
  }) async {
    final code = _generateJoinCode();
    final ref = _sessions.doc();

    final session = Session(
      id: ref.id,
      hostUid: hostUid,
      name: name,
      joinCode: code,
      createdAt: DateTime.now(),
      isActive: true,
      currentTrack: null,
      memberCount: 1,
    );

    final batch = _db.batch();
    batch.set(ref, session.toMap());
    batch.set(ref.collection('members').doc(hostUid), {
      'username': hostUsername,
      'joinedAt': Timestamp.now(),
      'role': 'host',
    });
    await batch.commit();

    return session;
  }

  Future<Session> joinSessionByCode({
    required String code,
    required String uid,
    required String username,
  }) async {
    final query = await _sessions
        .where('joinCode', isEqualTo: code.toUpperCase())
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('No active session found for code "$code"');
    }

    final doc = query.docs.first;
    final memberRef = doc.reference.collection('members').doc(uid);

    await _db.runTransaction((tx) async {
      final memberSnap = await tx.get(memberRef);
      if (!memberSnap.exists) {
        tx.set(memberRef, {
          'username': username,
          'joinedAt': Timestamp.now(),
          'role': 'member',
        });
        tx.update(doc.reference, {'memberCount': FieldValue.increment(1)});
      }
    });

    final fresh = await doc.reference.get();
    return Session.fromDoc(fresh);
  }

  Future<void> leaveSession({
    required String sessionId,
    required String uid,
  }) async {
    final ref = _sessions.doc(sessionId);
    final memberRef = ref.collection('members').doc(uid);

    await _db.runTransaction((tx) async {
      final memberSnap = await tx.get(memberRef);
      if (!memberSnap.exists) return;
      tx.delete(memberRef);
      tx.update(ref, {'memberCount': FieldValue.increment(-1)});
    });
  }

  Stream<Session> streamSession(String sessionId) {
    return _sessions
        .doc(sessionId)
        .snapshots()
        .where((s) => s.exists)
        .map(Session.fromDoc);
  }

  Stream<List<Map<String, dynamic>>> streamMembers(String sessionId) {
    return _sessions
        .doc(sessionId)
        .collection('members')
        .orderBy('joinedAt')
        .snapshots()
        .map(
          (qs) => qs.docs
              .map((d) => {'uid': d.id, ...d.data()})
              .toList(growable: false),
        );
  }

  String _generateJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
