/**
 * Host-only Spotify Web API actions: queue a track on the host's
 * active device, start playback, read currently-playing.
 *
 * All require an OAuth'd host (token in `spotifyTokens/{uid}`) and
 * Spotify Premium. The "active device" must already exist — the user
 * has to start playing something on Spotify once, otherwise the API
 * returns 404 NO_ACTIVE_DEVICE.
 */

import {getValidAccessToken} from "./spotifyAuth";
import {HttpsError} from "firebase-functions/v2/https";

const API = "https://api.spotify.com/v1";

async function spotifyFetch(
  uid: string,
  creds: {clientId: string; clientSecret: string},
  init: {method: string; path: string; body?: unknown; query?: Record<string, string>},
): Promise<Response> {
  const token = await getValidAccessToken(uid, creds);
  const url = new URL(`${API}${init.path}`);
  for (const [k, v] of Object.entries(init.query ?? {})) {
    if (v !== undefined && v !== "") url.searchParams.set(k, v);
  }
  return fetch(url.toString(), {
    method: init.method,
    headers: {
      "Authorization": `Bearer ${token}`,
      ...(init.body ? {"Content-Type": "application/json"} : {}),
    },
    body: init.body ? JSON.stringify(init.body) : undefined,
  });
}

function mapSpotifyError(status: number, body: string): never {
  if (status === 401) {
    throw new HttpsError("unauthenticated", "Spotify session expired — reconnect.");
  }
  if (status === 403) {
    throw new HttpsError("permission-denied", "Spotify Premium required for playback control.");
  }
  if (status === 404) {
    throw new HttpsError(
      "failed-precondition",
      "No active Spotify device. Open Spotify on your phone and play any track once.",
    );
  }
  if (status === 429) {
    throw new HttpsError("resource-exhausted", "Spotify rate limit hit.");
  }
  throw new HttpsError("internal", `Spotify ${status}: ${body}`);
}

/**
 * Adds a Spotify track URI to the host's queue (the actual Spotify
 * client queue, not Firestore).
 */
export async function hostQueueAdd(
  uid: string,
  trackId: string,
  creds: {clientId: string; clientSecret: string},
): Promise<void> {
  const res = await spotifyFetch(uid, creds, {
    method: "POST",
    path: "/me/player/queue",
    query: {uri: `spotify:track:${trackId}`},
  });
  if (!res.ok) mapSpotifyError(res.status, await res.text());
}

/**
 * Starts playback of a specific track on the host's active device.
 * Use this for "play next now" semantics; `hostQueueAdd` only appends.
 */
export async function hostPlay(
  uid: string,
  trackId: string,
  creds: {clientId: string; clientSecret: string},
): Promise<void> {
  const res = await spotifyFetch(uid, creds, {
    method: "PUT",
    path: "/me/player/play",
    body: {uris: [`spotify:track:${trackId}`]},
  });
  if (!res.ok && res.status !== 204) {
    mapSpotifyError(res.status, await res.text());
  }
}

export interface NowPlayingSnapshot {
  isPlaying: boolean;
  trackId: string | null;
  trackName: string | null;
  artist: string | null;
  albumArt: string | null;
  progressMs: number;
  durationMs: number;
}

export async function hostNowPlaying(
  uid: string,
  creds: {clientId: string; clientSecret: string},
): Promise<NowPlayingSnapshot> {
  const res = await spotifyFetch(uid, creds, {
    method: "GET",
    path: "/me/player/currently-playing",
  });
  if (res.status === 204) {
    return {
      isPlaying: false,
      trackId: null,
      trackName: null,
      artist: null,
      albumArt: null,
      progressMs: 0,
      durationMs: 0,
    };
  }
  if (!res.ok) mapSpotifyError(res.status, await res.text());

  const json = (await res.json()) as {
    is_playing: boolean;
    progress_ms: number;
    item: {
      id: string;
      name: string;
      duration_ms: number;
      artists: {name: string}[];
      album: {images: {url: string; width: number}[]};
    } | null;
  };
  const item = json.item;
  return {
    isPlaying: !!json.is_playing,
    trackId: item?.id ?? null,
    trackName: item?.name ?? null,
    artist: item ? item.artists.map((a) => a.name).join(", ") : null,
    albumArt: item?.album?.images?.[0]?.url ?? null,
    progressMs: json.progress_ms ?? 0,
    durationMs: item?.duration_ms ?? 0,
  };
}
