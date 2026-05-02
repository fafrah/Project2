// Platform façade. The conditional import below picks the IO impl
// (mobile/desktop, deep-link based) or the web impl (popup window +
// postMessage). Tests can supply a fake `SpotifyAuthPlatform`
// directly through the SpotifyAuthService constructor.

import 'spotify_auth_service.dart' show SpotifyAuthResult;

import 'spotify_auth_platform_io.dart'
    if (dart.library.html) 'spotify_auth_platform_web.dart' as impl;

abstract class SpotifyAuthPlatform {
  Future<SpotifyAuthResult> runOAuth(String authUrl);
}

SpotifyAuthPlatform createSpotifyAuthPlatform() => impl.create();
