import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {setGlobalOptions} from "firebase-functions/v2";

import {
  searchTracks,
  getTrack,
  getAudioFeatures,
  getAudioFeaturesBatch,
  getRecommendations,
} from "./spotify";
import {spotifyAuthFactory} from "./spotifyAuth";
import {hostQueueAdd, hostPlay, hostNowPlaying} from "./spotifyHost";

initializeApp();

const SPOTIFY_CLIENT_ID = defineSecret("SPOTIFY_CLIENT_ID");
const SPOTIFY_CLIENT_SECRET = defineSecret("SPOTIFY_CLIENT_SECRET");

// Project-specific — must match what's registered in the Spotify
// dashboard. The `vibzche-6ecc7` Firebase project lives in us-central1.
const OAUTH_CALLBACK =
  "https://us-central1-vibzche-6ecc7.cloudfunctions.net/spotifyAuthCallback";

setGlobalOptions({region: "us-central1", maxInstances: 10});

function requireAuth(auth: unknown): asserts auth is {uid: string} {
  if (!auth || typeof (auth as {uid?: unknown}).uid !== "string") {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
}

function creds() {
  return {
    clientId: SPOTIFY_CLIENT_ID.value(),
    clientSecret: SPOTIFY_CLIENT_SECRET.value(),
  };
}

export const spotifySearch = onCall(
  {secrets: [SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET]},
  async (request) => {
    requireAuth(request.auth);
    const q = String(request.data?.q ?? "").trim();
    if (!q) throw new HttpsError("invalid-argument", "Missing query.");
    const limit = Math.min(Math.max(Number(request.data?.limit ?? 20), 1), 50);
    return searchTracks(q, limit, creds());
  },
);

export const spotifyGetTrack = onCall(
  {secrets: [SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET]},
  async (request) => {
    requireAuth(request.auth);
    const trackId = String(request.data?.trackId ?? "").trim();
    if (!trackId) throw new HttpsError("invalid-argument", "Missing trackId.");
    return getTrack(trackId, creds());
  },
);

export const spotifyAudioFeatures = onCall(
  {secrets: [SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET]},
  async (request) => {
    requireAuth(request.auth);
    const trackId = String(request.data?.trackId ?? "").trim();
    if (!trackId) throw new HttpsError("invalid-argument", "Missing trackId.");
    return getAudioFeatures(trackId, creds());
  },
);

/**
 * Recommends tracks tuned to the room's averaged audio features.
 * Reads up to ~50 queue items, fetches their audio features in one
 * batch call, averages energy/valence/danceability/tempo, then asks
 * Spotify for recommendations seeded by the top-voted tracks.
 */
export const spotifyRecommend = onCall(
  {secrets: [SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET]},
  async (request) => {
    requireAuth(request.auth);
    const sessionId = String(request.data?.sessionId ?? "").trim();
    if (!sessionId) {
      throw new HttpsError("invalid-argument", "Missing sessionId.");
    }
    const limit = Math.min(Math.max(Number(request.data?.limit ?? 10), 1), 30);

    const db = getFirestore();
    const queueSnap = await db
      .collection("sessions")
      .doc(sessionId)
      .collection("queue")
      .orderBy("voteScore", "desc")
      .limit(50)
      .get();

    if (queueSnap.empty) {
      throw new HttpsError(
        "failed-precondition",
        "Add at least one track to get recommendations.",
      );
    }

    const trackIds = queueSnap.docs
      .map((d) => d.get("trackId") as string | undefined)
      .filter((id): id is string => !!id && !id.startsWith("mock-"));

    if (trackIds.length === 0) {
      throw new HttpsError(
        "failed-precondition",
        "Add real Spotify tracks (mock entries don't count).",
      );
    }

    const features = await getAudioFeaturesBatch(trackIds, creds());
    const avg = features.length
      ? {
        energy: mean(features.map((f) => f.energy)),
        valence: mean(features.map((f) => f.valence)),
        danceability: mean(features.map((f) => f.danceability)),
        tempo: mean(features.map((f) => f.tempo)),
      }
      : undefined;

    const seeds = trackIds.slice(0, 5);
    return getRecommendations(
      {
        seedTracks: seeds,
        targetEnergy: avg?.energy,
        targetValence: avg?.valence,
        targetDanceability: avg?.danceability,
        targetTempo: avg?.tempo,
        limit,
      },
      creds(),
    );
  },
);

function mean(xs: number[]): number {
  return xs.reduce((a, b) => a + b, 0) / xs.length;
}

// ---------------- Host OAuth + playback control ----------------

const auth = spotifyAuthFactory({
  clientId: SPOTIFY_CLIENT_ID,
  clientSecret: SPOTIFY_CLIENT_SECRET,
  callbackUrl: OAUTH_CALLBACK,
});
export const spotifyAuthStart = auth.spotifyAuthStart;
export const spotifyAuthCallback = auth.spotifyAuthCallback;

export const spotifyHostQueueAdd = onCall(
  {secrets: [SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET]},
  async (request) => {
    requireAuth(request.auth);
    const trackId = String(request.data?.trackId ?? "").trim();
    if (!trackId) throw new HttpsError("invalid-argument", "Missing trackId.");
    await hostQueueAdd(request.auth.uid, trackId, creds());
    return {ok: true};
  },
);

export const spotifyHostPlay = onCall(
  {secrets: [SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET]},
  async (request) => {
    requireAuth(request.auth);
    const trackId = String(request.data?.trackId ?? "").trim();
    if (!trackId) throw new HttpsError("invalid-argument", "Missing trackId.");
    await hostPlay(request.auth.uid, trackId, creds());
    return {ok: true};
  },
);

export const spotifyHostNowPlaying = onCall(
  {secrets: [SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET]},
  async (request) => {
    requireAuth(request.auth);
    return hostNowPlaying(request.auth.uid, creds());
  },
);
