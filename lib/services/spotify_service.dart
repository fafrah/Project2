import 'package:cloud_functions/cloud_functions.dart';
import '../models/track.dart';

/// Wraps the Cloud Function callables that proxy the Spotify Web API.
/// All methods require a signed-in Firebase user.
class SpotifyService {
  final FirebaseFunctions _fns;

  SpotifyService({FirebaseFunctions? functions})
      : _fns =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<List<Track>> search(String query, {int limit = 20}) async {
    final res = await _fns.httpsCallable('spotifySearch').call({
      'q': query,
      'limit': limit,
    });
    final list = (res.data as List).cast<Map<Object?, Object?>>();
    return list
        .map((m) => Track.fromMap(_normalize(m)))
        .toList(growable: false);
  }

  Future<Track> getTrack(String trackId) async {
    final res = await _fns.httpsCallable('spotifyGetTrack').call({
      'trackId': trackId,
    });
    return Track.fromMap(_normalize(res.data as Map<Object?, Object?>));
  }

  Future<Map<String, dynamic>> getAudioFeatures(String trackId) async {
    final res = await _fns.httpsCallable('spotifyAudioFeatures').call({
      'trackId': trackId,
    });
    return _normalize(res.data as Map<Object?, Object?>);
  }

  Future<List<Track>> recommend({
    required String sessionId,
    int limit = 10,
  }) async {
    final res = await _fns.httpsCallable('spotifyRecommend').call({
      'sessionId': sessionId,
      'limit': limit,
    });
    final list = (res.data as List).cast<Map<Object?, Object?>>();
    return list
        .map((m) => Track.fromMap(_normalize(m)))
        .toList(growable: false);
  }

  /// Cloud Functions returns `Map<Object?, Object?>` on iOS/Android — coerce
  /// to `Map<String, dynamic>` so existing fromMap parsers work.
  Map<String, dynamic> _normalize(Map<Object?, Object?> raw) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
}
