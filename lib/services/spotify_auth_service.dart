import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'spotify_auth_platform.dart';

/// Drives the host's Spotify OAuth round-trip.
///
/// Mobile: opens the consent URL in the system browser, then waits for
/// a `vibzcheck://spotify-callback?status=ok` deep link.
/// Web:    opens the consent URL in a popup window, then waits for a
/// `window.postMessage` from the redirected page (rendered by the
/// Cloud Function callback).
///
/// Connection status itself is mirrored on `users/{uid}.spotifyConnected`
/// (server writes via the OAuth callback function), so the UI listens
/// directly to the user doc — this service only needs to drive the
/// flow.
class SpotifyAuthService {
  final FirebaseFunctions _fns;
  final SpotifyAuthPlatform _platform;

  SpotifyAuthService({
    FirebaseFunctions? functions,
    SpotifyAuthPlatform? platform,
  })  : _fns =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
        _platform = platform ?? createSpotifyAuthPlatform();

  Future<SpotifyAuthResult> connect() async {
    final res = await _fns.httpsCallable('spotifyAuthStart').call({
      'platform': kIsWeb ? 'web' : 'mobile',
    });
    final authUrl = (res.data as Map)['authUrl'] as String;
    return _platform.runOAuth(authUrl);
  }

  Stream<bool> connectedStream(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) => s.data()?['spotifyConnected'] as bool? ?? false);
  }
}

class SpotifyAuthResult {
  final bool ok;
  final String? reason;
  SpotifyAuthResult._(this.ok, this.reason);
  factory SpotifyAuthResult.ok() => SpotifyAuthResult._(true, null);
  factory SpotifyAuthResult.error(String reason) =>
      SpotifyAuthResult._(false, reason);
}
