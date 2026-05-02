/**
 * Thin Spotify Web API client using the Client-Credentials flow.
 *
 * The token is cached in module scope, so a warm function instance
 * reuses it until ~30s before expiry. Cold instances pay one extra
 * request to /api/token.
 */

const TOKEN_URL = "https://accounts.spotify.com/api/token";
const API_BASE = "https://api.spotify.com/v1";

interface CachedToken {
  accessToken: string;
  expiresAt: number; // epoch ms
}

let cached: CachedToken | null = null;

async function getAccessToken(
  clientId: string,
  clientSecret: string,
): Promise<string> {
  const now = Date.now();
  if (cached && cached.expiresAt > now + 30_000) return cached.accessToken;

  const basic = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: {
      "Authorization": `Basic ${basic}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });

  if (!res.ok) {
    throw new Error(`Spotify token request failed: ${res.status}`);
  }
  const json = (await res.json()) as {
    access_token: string;
    expires_in: number;
  };
  cached = {
    accessToken: json.access_token,
    expiresAt: now + json.expires_in * 1000,
  };
  return cached.accessToken;
}

async function spotifyGet<T>(
  path: string,
  params: Record<string, string | number | undefined>,
  clientId: string,
  clientSecret: string,
): Promise<T> {
  const token = await getAccessToken(clientId, clientSecret);
  const url = new URL(`${API_BASE}${path}`);
  for (const [k, v] of Object.entries(params)) {
    if (v !== undefined && v !== null && v !== "") {
      url.searchParams.set(k, String(v));
    }
  }
  const res = await fetch(url.toString(), {
    headers: {Authorization: `Bearer ${token}`},
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Spotify ${path} failed (${res.status}): ${body}`);
  }
  return (await res.json()) as T;
}

// ---------------- Trimmed shapes for the client ----------------

export interface ClientTrack {
  id: string;
  name: string;
  artist: string;
  albumArt: string | null;
  previewUrl: string | null;
  durationMs: number;
}

export interface AudioFeatures {
  id: string;
  danceability: number;
  energy: number;
  valence: number;
  tempo: number;
  acousticness: number;
  instrumentalness: number;
}

interface SpotifyTrack {
  id: string;
  name: string;
  duration_ms: number;
  preview_url: string | null;
  artists: {name: string}[];
  album: {images: {url: string; width: number; height: number}[]};
}

function trim(t: SpotifyTrack): ClientTrack {
  const art = t.album?.images ?? [];
  // Pick a mid-size image when available, fall back to the first.
  const img = art.find((i) => (i.width ?? 0) <= 320) ?? art[0];
  return {
    id: t.id,
    name: t.name,
    artist: (t.artists ?? []).map((a) => a.name).join(", "),
    albumArt: img?.url ?? null,
    previewUrl: t.preview_url,
    durationMs: t.duration_ms,
  };
}

// ---------------- Public API ----------------

export async function searchTracks(
  q: string,
  limit: number,
  creds: {clientId: string; clientSecret: string},
): Promise<ClientTrack[]> {
  const data = await spotifyGet<{tracks: {items: SpotifyTrack[]}}>(
    "/search",
    {q, type: "track", limit},
    creds.clientId,
    creds.clientSecret,
  );
  return (data.tracks?.items ?? []).map(trim);
}

export async function getTrack(
  trackId: string,
  creds: {clientId: string; clientSecret: string},
): Promise<ClientTrack> {
  const data = await spotifyGet<SpotifyTrack>(
    `/tracks/${encodeURIComponent(trackId)}`,
    {},
    creds.clientId,
    creds.clientSecret,
  );
  return trim(data);
}

export async function getAudioFeatures(
  trackId: string,
  creds: {clientId: string; clientSecret: string},
): Promise<AudioFeatures> {
  return spotifyGet<AudioFeatures>(
    `/audio-features/${encodeURIComponent(trackId)}`,
    {},
    creds.clientId,
    creds.clientSecret,
  );
}

export async function getAudioFeaturesBatch(
  trackIds: string[],
  creds: {clientId: string; clientSecret: string},
): Promise<AudioFeatures[]> {
  if (trackIds.length === 0) return [];
  // Spotify caps the batch endpoint at 100 ids.
  const ids = trackIds.slice(0, 100).join(",");
  const data = await spotifyGet<{audio_features: (AudioFeatures | null)[]}>(
    "/audio-features",
    {ids},
    creds.clientId,
    creds.clientSecret,
  );
  return (data.audio_features ?? []).filter(
    (f): f is AudioFeatures => f != null,
  );
}

export async function getRecommendations(
  params: {
    seedTracks: string[];
    targetEnergy?: number;
    targetValence?: number;
    targetDanceability?: number;
    targetTempo?: number;
    limit: number;
  },
  creds: {clientId: string; clientSecret: string},
): Promise<ClientTrack[]> {
  const seeds = params.seedTracks.slice(0, 5).join(",");
  const data = await spotifyGet<{tracks: SpotifyTrack[]}>(
    "/recommendations",
    {
      seed_tracks: seeds,
      limit: params.limit,
      target_energy: params.targetEnergy,
      target_valence: params.targetValence,
      target_danceability: params.targetDanceability,
      target_tempo: params.targetTempo,
    },
    creds.clientId,
    creds.clientSecret,
  );
  return (data.tracks ?? []).map(trim);
}
