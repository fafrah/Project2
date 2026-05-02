import 'package:cloud_firestore/cloud_firestore.dart';
import 'spotify_host_service.dart';

/// Host-only playback controls. Writes the room's `currentTrack`
/// snapshot, pops the played item out of the queue, and (when the
/// host has connected Spotify) tells Spotify to actually start the
/// next track on the host's active device.
///
/// Firestore is still the source of truth — guest devices render
/// progress using `currentTrack.startedAt` + local clock, identical
/// to before. The Spotify call is best-effort: a failure (no active
/// device, expired auth) shouldn't desync the room's logical clock.
class PlaybackService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SpotifyHostService _spotify;

  PlaybackService({SpotifyHostService? spotify})
      : _spotify = spotify ?? SpotifyHostService();

  DocumentReference<Map<String, dynamic>> _sessionRef(String sessionId) =>
      _db.collection('sessions').doc(sessionId);

  /// Pops the top-voted queue item and promotes it to `currentTrack`.
  /// Returns the new track's id, or null if the queue was empty.
  ///
  /// Runs as a single transaction so two hosts (or a host on two
  /// devices) can't desync the room.
  Future<String?> playNext({required String sessionId}) async {
    final sessionRef = _sessionRef(sessionId);
    final queueRef = sessionRef.collection('queue');

    final newTrackId = await _db.runTransaction<String?>((tx) async {
      // We need the highest-voted item. Firestore txns don't allow
      // queries with cursors, so we read the top item via a
      // narrowly-scoped query before the transaction starts.
      // (Reads inside a transaction must be of single docs.)
      // Workaround: read the head outside, then re-fetch inside the
      // txn to make sure it's still there.
      final head = await queueRef
          .orderBy('voteScore', descending: true)
          .orderBy('addedAt')
          .limit(1)
          .get();

      if (head.docs.isEmpty) {
        tx.update(sessionRef, {'currentTrack': null});
        return null;
      }

      final headDoc = head.docs.first;
      final freshSnap = await tx.get(headDoc.reference);
      if (!freshSnap.exists) return null;
      final data = freshSnap.data()!;

      tx.update(sessionRef, {
        'currentTrack': {
          'trackId': data['trackId'],
          'trackName': data['trackName'],
          'artist': data['artist'],
          'albumArt': data['albumArt'],
          'startedAt': Timestamp.now(),
          'durationMs': data['durationMs'],
          'addedBy': data['addedBy'],
        },
      });
      tx.delete(headDoc.reference);
      return data['trackId'] as String?;
    });

    // Best-effort Spotify hand-off. If the host hasn't connected, has
    // no active device, or auth expired, the function throws — we
    // swallow it so the room's logical clock stays advanced and the
    // host can fix Spotify out-of-band without rewinding the queue.
    if (newTrackId != null && !newTrackId.startsWith('mock-')) {
      try {
        await _spotify.play(newTrackId);
      } catch (_) {
        // Surfaced separately by the UI's "Spotify status" indicator.
      }
    }
    return newTrackId;
  }

  Future<void> stop({required String sessionId}) async {
    await _sessionRef(sessionId).update({'currentTrack': null});
  }
}
