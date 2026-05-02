// Web OAuth: open the consent URL in a popup window and wait for the
// callback page (rendered server-side) to postMessage back the result.

import 'dart:async';
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'spotify_auth_platform.dart';
import 'spotify_auth_service.dart' show SpotifyAuthResult;

class _WebSpotifyAuthPlatform implements SpotifyAuthPlatform {
  @override
  Future<SpotifyAuthResult> runOAuth(String authUrl) async {
    final popup = html.window.open(
      authUrl,
      'spotify-oauth',
      'width=480,height=720',
    );
    if (popup.closed ?? false) {
      throw Exception('Popup blocked. Allow popups and retry.');
    }

    final completer = Completer<SpotifyAuthResult>();
    late final StreamSubscription<html.MessageEvent> sub;
    sub = html.window.onMessage.listen((event) {
      final data = event.data;
      if (data is! Map) return;
      if (data['type'] != 'vibzcheck-spotify-auth') return;
      final status = data['status'];
      final reason = data['reason'];
      final result = status == 'ok'
          ? SpotifyAuthResult.ok()
          : SpotifyAuthResult.error(reason?.toString() ?? 'unknown');
      if (!completer.isCompleted) completer.complete(result);
      sub.cancel();
      try {
        popup.close();
      } catch (_) {}
    });

    // Watchdog: if the user closes the popup without consenting,
    // surface a clean error rather than hanging.
    final closeTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if ((popup.closed ?? false) && !completer.isCompleted) {
        completer.complete(SpotifyAuthResult.error('popup_closed'));
        sub.cancel();
        t.cancel();
      }
    });

    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        sub.cancel();
        closeTimer.cancel();
        try {
          popup.close();
        } catch (_) {}
        return SpotifyAuthResult.error('timeout');
      },
    ).whenComplete(() => closeTimer.cancel());
  }
}

SpotifyAuthPlatform create() => _WebSpotifyAuthPlatform();
