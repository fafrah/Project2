/**
 * Authorization-Code OAuth flow for the *host* of a room.
 *
 * Flow:
 *   1. Client calls `spotifyAuthStart` → gets back the Spotify
 *      consent URL with `state = <uid>:<random>`. Opens it in a browser.
 *   2. Spotify redirects to `spotifyAuthCallback?code=...&state=...`.
 *   3. Callback exchanges the code for {access, refresh} tokens and
 *      stores them in Firestore at `spotifyTokens/{uid}` (server-only —
 *      Firestore rules forbid client reads).
 *   4. Callback then 302s back to `vibzcheck://spotify-callback?status=ok`
 *      so the Flutter app deep link picks it up.
 *
 * The refresh token is long-lived; access tokens expire in ~1h. All
 * server-side calls go through `getValidAccessToken(uid)` which
 * refreshes on demand.
 */

import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {randomBytes} from "crypto";

const HOST_SCOPES = [
  "user-read-playback-state",
  "user-modify-playback-state",
  "user-read-currently-playing",
  "streaming",
  "user-read-email",
  "user-read-private",
].join(" ");

const APP_REDIRECT = "vibzcheck://spotify-callback";

export function spotifyAuthFactory(opts: {
  clientId: ReturnType<typeof defineSecret>;
  clientSecret: ReturnType<typeof defineSecret>;
  callbackUrl: string;
}) {
  const {clientId, clientSecret, callbackUrl} = opts;

  const spotifyAuthStart = onCall(
    {secrets: [clientId]},
    async (request) => {
      const auth = request.auth;
      if (!auth?.uid) {
        throw new HttpsError("unauthenticated", "Sign in required.");
      }
      // Platform tag travels through Spotify's `state` round-trip so
      // the callback knows whether to deep-link back into a mobile app
      // or render an HTML page that posts back to the opener tab.
      const platform = request.data?.platform === "web" ? "web" : "mobile";
      const nonce = randomBytes(8).toString("hex");
      const state = `${auth.uid}:${nonce}:${platform}`;

      // Persist the nonce so the callback can verify the round-trip.
      await getFirestore()
        .collection("spotifyAuthState")
        .doc(auth.uid)
        .set({nonce, createdAt: Timestamp.now()});

      const url = new URL("https://accounts.spotify.com/authorize");
      url.searchParams.set("response_type", "code");
      url.searchParams.set("client_id", clientId.value());
      url.searchParams.set("scope", HOST_SCOPES);
      url.searchParams.set("redirect_uri", callbackUrl);
      url.searchParams.set("state", state);
      url.searchParams.set("show_dialog", "false");

      return {authUrl: url.toString()};
    },
  );

  const spotifyAuthCallback = onRequest(
    {secrets: [clientId, clientSecret]},
    async (req, res) => {
      const code = String(req.query.code ?? "");
      const state = String(req.query.state ?? "");
      const err = String(req.query.error ?? "");

      // Defaults if state is malformed (we still need to terminate
      // gracefully on the right platform).
      const stateParts = state.split(":");
      const platform: "web" | "mobile" =
        stateParts[2] === "web" ? "web" : "mobile";

      const finish = (status: "ok" | "error", reason?: string) => {
        if (platform === "web") {
          res.set("Content-Type", "text/html; charset=utf-8");
          res.send(webResultPage(status, reason));
        } else {
          const u = new URL(APP_REDIRECT);
          u.searchParams.set("status", status);
          if (reason) u.searchParams.set("reason", reason);
          res.redirect(u.toString());
        }
      };

      if (err) {
        finish("error", err);
        return;
      }
      if (!code || stateParts.length < 2) {
        finish("error", "bad_request");
        return;
      }

      const [uid, nonce] = stateParts;
      const stateRef = getFirestore().collection("spotifyAuthState").doc(uid);
      const stateSnap = await stateRef.get();
      if (!stateSnap.exists || stateSnap.data()?.nonce !== nonce) {
        finish("error", "state_mismatch");
        return;
      }
      await stateRef.delete();

      const basic = Buffer.from(
        `${clientId.value()}:${clientSecret.value()}`,
      ).toString("base64");

      const tokenRes = await fetch("https://accounts.spotify.com/api/token", {
        method: "POST",
        headers: {
          "Authorization": `Basic ${basic}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({
          grant_type: "authorization_code",
          code,
          redirect_uri: callbackUrl,
        }).toString(),
      });

      if (!tokenRes.ok) {
        const body = await tokenRes.text();
        console.error("Token exchange failed", tokenRes.status, body);
        finish("error", "token_exchange");
        return;
      }

      const tokens = (await tokenRes.json()) as {
        access_token: string;
        refresh_token: string;
        expires_in: number;
        scope: string;
      };

      const db = getFirestore();
      await Promise.all([
        db.collection("spotifyTokens").doc(uid).set({
          accessToken: tokens.access_token,
          refreshToken: tokens.refresh_token,
          expiresAt: Timestamp.fromMillis(Date.now() + tokens.expires_in * 1000),
          scope: tokens.scope,
          updatedAt: Timestamp.now(),
        }),
        // Public flag the client reads to know whether the user is
        // already connected. Tokens themselves stay server-only.
        db.collection("users").doc(uid).set(
          {spotifyConnected: true, spotifyConnectedAt: Timestamp.now()},
          {merge: true},
        ),
      ]);

      finish("ok");
    },
  );

  return {spotifyAuthStart, spotifyAuthCallback};
}

/**
 * Self-closing HTML page that posts the result back to the opener
 * window via postMessage and then closes itself. Falls back to a
 * "you can close this tab" message if popup-blocking or a missing
 * opener prevents the message from being sent.
 */
function webResultPage(status: "ok" | "error", reason?: string): string {
  const payload = JSON.stringify({
    type: "vibzcheck-spotify-auth",
    status,
    reason: reason ?? null,
  });
  const heading = status === "ok" ? "Spotify connected" : "Spotify connect failed";
  const body = status === "ok"
    ? "You can close this tab."
    : `Reason: ${reason ?? "unknown"}. You can close this tab and try again.`;
  return `<!doctype html>
<html><head><meta charset="utf-8"><title>${heading}</title>
<style>
  body{font-family:-apple-system,Segoe UI,Roboto,sans-serif;background:#0f0f14;color:#fff;
       display:flex;align-items:center;justify-content:center;height:100vh;margin:0;text-align:center;padding:24px;}
  .card{max-width:360px}
  h1{font-size:20px;margin:0 0 8px}
  p{color:#a0a0b0;font-size:14px;line-height:1.5}
</style></head>
<body><div class="card"><h1>${heading}</h1><p>${body}</p></div>
<script>
(function(){
  var msg = ${payload};
  try { if (window.opener) window.opener.postMessage(msg, "*"); } catch(_) {}
  setTimeout(function(){ try { window.close(); } catch(_) {} }, 600);
})();
</script>
</body></html>`;
}

/**
 * Returns a valid access token for `uid`, refreshing if needed.
 * Throws HttpsError if the user has never connected.
 */
export async function getValidAccessToken(
  uid: string,
  creds: {clientId: string; clientSecret: string},
): Promise<string> {
  const ref = getFirestore().collection("spotifyTokens").doc(uid);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError(
      "failed-precondition",
      "Host has not connected Spotify yet.",
    );
  }
  const data = snap.data()!;
  const expiresAt = (data.expiresAt as Timestamp).toMillis();
  if (expiresAt > Date.now() + 30_000) {
    return data.accessToken as string;
  }

  // Refresh.
  const basic = Buffer.from(
    `${creds.clientId}:${creds.clientSecret}`,
  ).toString("base64");
  const res = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: {
      "Authorization": `Basic ${basic}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: data.refreshToken as string,
    }).toString(),
  });
  if (!res.ok) {
    const body = await res.text();
    console.error("Refresh failed", res.status, body);
    throw new HttpsError("unauthenticated", "Spotify refresh failed.");
  }
  const json = (await res.json()) as {
    access_token: string;
    expires_in: number;
    refresh_token?: string;
  };
  await ref.update({
    accessToken: json.access_token,
    expiresAt: Timestamp.fromMillis(Date.now() + json.expires_in * 1000),
    ...(json.refresh_token ? {refreshToken: json.refresh_token} : {}),
    updatedAt: Timestamp.now(),
  });
  return json.access_token;
}
