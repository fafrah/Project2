// Mobile / desktop OAuth: open the consent URL in the system browser
// and wait for a `vibzcheck://spotify-callback?status=...` deep link.

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

import 'spotify_auth_platform.dart';
import 'spotify_auth_service.dart' show SpotifyAuthResult;

class _IoSpotifyAuthPlatform implements SpotifyAuthPlatform {
  final AppLinks _links = AppLinks();

  @override
  Future<SpotifyAuthResult> runOAuth(String authUrl) async {
    // Subscribe BEFORE launching so we never miss the redirect on a
    // fast OAuth flow with cached consent.
    final completer = Completer<SpotifyAuthResult>();
    late final StreamSubscription<Uri> sub;
    sub = _links.uriLinkStream.listen((uri) {
      if (uri.scheme != 'vibzcheck' || uri.host != 'spotify-callback') return;
      final status = uri.queryParameters['status'];
      final reason = uri.queryParameters['reason'];
      final result = status == 'ok'
          ? SpotifyAuthResult.ok()
          : SpotifyAuthResult.error(reason ?? 'unknown');
      if (!completer.isCompleted) completer.complete(result);
      sub.cancel();
    });

    final ok = await launchUrl(
      Uri.parse(authUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      sub.cancel();
      throw Exception('Could not open Spotify in browser.');
    }

    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        sub.cancel();
        return SpotifyAuthResult.error('timeout');
      },
    );
  }
}

SpotifyAuthPlatform create() => _IoSpotifyAuthPlatform();
