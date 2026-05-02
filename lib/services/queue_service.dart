import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/queue_item.dart';
import '../models/track.dart';

class QueueService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _queueRef(String sessionId) =>
      _db.collection('sessions').doc(sessionId).collection('queue');

  Future<QueueItem> addToQueue({
    required String sessionId,
    required Track track,
    required String addedBy,
  }) async {
    final ref = _queueRef(sessionId).doc();
    final item = QueueItem(
      id: ref.id,
      trackId: track.id,
      trackName: track.name,
      artist: track.artist,
      albumArt: track.albumArt,
      previewUrl: track.previewUrl,
      durationMs: track.durationMs,
      addedBy: addedBy,
      addedAt: DateTime.now(),
      voteScore: 0,
      tags: const [],
    );
    await ref.set(item.toMap());
    return item;
  }

  Future<void> removeFromQueue({
    required String sessionId,
    required String queueItemId,
  }) async {
    await _queueRef(sessionId).doc(queueItemId).delete();
  }

  Stream<List<QueueItem>> streamQueue(String sessionId) {
    return _queueRef(sessionId)
        .orderBy('voteScore', descending: true)
        .orderBy('addedAt')
        .snapshots()
        .map(
          (qs) => qs.docs.map(QueueItem.fromDoc).toList(growable: false),
        );
  }
}
