# VibzCheck Cloud Functions

Spotify proxy for the VibzCheck Flutter app. All callables are auth-checked
(`request.auth` must be present) and use Spotify's Client-Credentials flow,
so users never see the client secret.

## Setup (one-time)

1. Register a Spotify app at https://developer.spotify.com/dashboard.
2. Store credentials as Firebase secrets — these are injected into the
   function runtime, never committed:

   ```sh
   firebase functions:secrets:set SPOTIFY_CLIENT_ID
   firebase functions:secrets:set SPOTIFY_CLIENT_SECRET
   ```

3. Install dependencies:

   ```sh
   cd functions
   npm install
   ```

## Develop

```sh
npm run build:watch        # background tsc
firebase emulators:start --only functions,firestore,auth
```

## Deploy

```sh
npm run deploy
```

## Callables

| Name                  | Input                                  | Returns                              |
| --------------------- | -------------------------------------- | ------------------------------------ |
| `spotifySearch`       | `{ q: string, limit?: number }`        | `Track[]`                            |
| `spotifyGetTrack`     | `{ trackId: string }`                  | `Track`                              |
| `spotifyAudioFeatures`| `{ trackId: string }`                  | Audio features                       |
| `spotifyRecommend`    | `{ sessionId: string, limit?: number }`| `Track[]` tuned to the room's vibe  |

`Track` shape: `{ id, name, artist, albumArt?, previewUrl?, durationMs }`.

The Spotify access token is cached in-process (per-instance) until ~30s
before expiry — typical cold start does one token request, then reuses.
