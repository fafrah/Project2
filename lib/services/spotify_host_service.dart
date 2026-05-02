import 'package:cloud_functions/cloud_functions.dart';

/// Pushes playback commands to the *host's* Spotify account via Cloud
/// Functions. Only meaningful for the room's host; guests should never
/// hit these endpoints (server checks the auth uid against the
/// connected account).
class SpotifyHostService {
  final FirebaseFunctions _fns;

  SpotifyHostService({FirebaseFunctions? functions})
      : _fns =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Appends `trackId` to the host's Spotify queue.
  Future<void> queueAdd(String trackId) async {
    await _fns.httpsCallable('spotifyHostQueueAdd').call({'trackId': trackId});
  }

  /// Plays `trackId` immediately on the host's active device.
  Future<void> play(String trackId) async {
    await _fns.httpsCallable('spotifyHostPlay').call({'trackId': trackId});
  }

  /// Snapshot of what's currently playing on the host's account.
  /// Returns null fields if nothing is playing.
  Future<HostNowPlaying> nowPlaying() async {
    final res = await _fns.httpsCallable('spotifyHostNowPlaying').call();
    final m = (res.data as Map).cast<Object?, Object?>();
    return HostNowPlaying(
      isPlaying: m['isPlaying'] as bool? ?? false,
      trackId: m['trackId'] as String?,
      trackName: m['trackName'] as String?,
      artist: m['artist'] as String?,
      albumArt: m['albumArt'] as String?,
      progressMs: (m['progressMs'] as num?)?.toInt() ?? 0,
      durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class HostNowPlaying {
  final bool isPlaying;
  final String? trackId;
  final String? trackName;
  final String? artist;
  final String? albumArt;
  final int progressMs;
  final int durationMs;

  HostNowPlaying({
    required this.isPlaying,
    required this.trackId,
    required this.trackName,
    required this.artist,
    required this.albumArt,
    required this.progressMs,
    required this.durationMs,
  });
}
