import 'package:cloud_firestore/cloud_firestore.dart';

class VoteService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Atomically applies a vote. [value] must be -1, 0, or 1.
  /// 0 clears any existing vote. The queue item's denormalized
  /// voteScore is incremented by (newValue - oldValue) in the same
  /// transaction so concurrent voters can't desync the score.
  Future<void> castVote({
    required String sessionId,
    required String queueItemId,
    required String uid,
    required int value,
  }) async {
    assert(value == -1 || value == 0 || value == 1);

    final itemRef = _db
        .collection('sessions')
        .doc(sessionId)
        .collection('queue')
        .doc(queueItemId);
    final voteRef = itemRef.collection('votes').doc(uid);

    await _db.runTransaction((tx) async {
      final itemSnap = await tx.get(itemRef);
      if (!itemSnap.exists) {
        throw Exception('Queue item no longer exists');
      }
      final voteSnap = await tx.get(voteRef);
      final oldValue = voteSnap.exists
          ? (voteSnap.data()?['value'] as int? ?? 0)
          : 0;
      final delta = value - oldValue;
      if (delta == 0 && voteSnap.exists) return;

      if (value == 0) {
        if (voteSnap.exists) tx.delete(voteRef);
      } else {
        tx.set(voteRef, {'value': value, 'votedAt': Timestamp.now()});
      }
      if (delta != 0) {
        tx.update(itemRef, {'voteScore': FieldValue.increment(delta)});
      }
    });
  }

  Stream<int?> streamMyVote({
    required String sessionId,
    required String queueItemId,
    required String uid,
  }) {
    return _db
        .collection('sessions')
        .doc(sessionId)
        .collection('queue')
        .doc(queueItemId)
        .collection('votes')
        .doc(uid)
        .snapshots()
        .map((s) => s.exists ? (s.data()?['value'] as int?) : null);
  }
}
