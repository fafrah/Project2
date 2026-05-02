# Vibzcheck — Setup commands

Everything that has to be run by a human (or by someone with access to the Firebase project) lives here. Code-side scaffolding is already in the repo.

---

## 1. Firebase project access

The Firebase project `vibzche-6ecc7` lives on a friend's Google account. To work with it from this machine, they must add `jasnoorsandhu51@gmail.com` as **Owner**:

1. console.firebase.google.com → **vibzche-6ecc7**
2. Gear icon → **Users and permissions**
3. **Add member** → `jasnoorsandhu51@gmail.com` → role **Owner**
4. Accept the email invite.

Once accepted, on this machine:

```bash
firebase logout
firebase login
firebase use vibzche-6ecc7
```

Verify:
```bash
firebase projects:list   # vibzche-6ecc7 should appear
```

---

## 2. Upgrade to Blaze plan (required)

Cloud Functions can only call out to Spotify on the Blaze plan.

console.firebase.google.com → vibzche-6ecc7 → bottom-left **"Upgrade"** → Blaze (pay-as-you-go). Set a budget alert at $5/mo to be safe.

---

## 3. Spotify app — already created

- **Client ID**: `532fc038edc946d3b01c8bf493d18aa9`
- **Client Secret**: rotate this on the Spotify dashboard (it was leaked in chat). Edit Settings → "View client secret" → "Rotate".
- **Redirect URIs** (must be added in Spotify dashboard → Edit Settings):
  - `vibzcheck://spotify-callback`
  - `https://us-central1-vibzche-6ecc7.cloudfunctions.net/spotifyAuthCallback`

---

## 4. Set Cloud Functions secrets

The Spotify client ID + secret are stored in Google Secret Manager (the new way; `functions:config:set` is deprecated).

```bash
firebase functions:secrets:set SPOTIFY_CLIENT_ID
# paste: 532fc038edc946d3b01c8bf493d18aa9

firebase functions:secrets:set SPOTIFY_CLIENT_SECRET
# paste the (rotated) client secret
```

Confirm:
```bash
firebase functions:secrets:access SPOTIFY_CLIENT_ID
firebase functions:secrets:access SPOTIFY_CLIENT_SECRET
```

---

## 5. Flutter dependencies

Already updated in `pubspec.yaml`. Run:

```bash
flutter pub get
```

Pods for iOS:
```bash
cd ios && pod install && cd ..
```

---

## 6. URL scheme registration (deep link `vibzcheck://`)

### iOS — `ios/Runner/Info.plist`
Already added by the patch. If you ever rerun `flutterfire configure` and it overwrites, the block to keep is:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array><string>vibzcheck</string></array>
  </dict>
</array>
```

### Android — `android/app/src/main/AndroidManifest.xml`
Inside the main `<activity>` tag, an extra `<intent-filter>` was added for `vibzcheck://`. If lost, re-add:

```xml
<intent-filter android:autoVerify="false">
  <action android:name="android.intent.action.VIEW"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <category android:name="android.intent.category.BROWSABLE"/>
  <data android:scheme="vibzcheck"/>
</intent-filter>
```

---

## 7. Camera permission for QR scanning

### iOS — `ios/Runner/Info.plist`
```xml
<key>NSCameraUsageDescription</key>
<string>Used to scan room codes from a QR.</string>
```

### Android — `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.CAMERA"/>
```

---

## 8. Deploy Cloud Functions

After secrets are set:

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

The new functions are:
- `spotifyAuthStart` (callable) — returns the OAuth URL the host should open
- `spotifyAuthCallback` (HTTPS) — exchanges the code, stores tokens in Firestore
- `spotifyHostQueueAdd` (callable) — pushes a track into the host's Spotify queue
- `spotifyHostNowPlaying` (callable) — reads what the host's Spotify is currently playing
- `spotifyHostPlay` (callable) — starts playback of a specific track on host's active device

Plus the existing search/recommend/etc.

---

## 9. Firestore rules + indexes

Already in `firestore.rules` and `firestore.indexes.json`. Deploy:

```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```

---

## 10. Smoke test checklist

After everything's deployed:

1. Sign in with two test accounts (host + guest) on two devices/simulators.
2. Host: tap **Create room** → tap **Connect Spotify** → completes OAuth → returns to app with status "connected".
3. Host: starts playing any track on Spotify on their phone (Web API requires an "active device" — the Spotify app must be open and playing once).
4. Guest: scan QR or enter 6-digit code → joins room.
5. Guest: searches a track, adds to queue.
6. Both: vote on tracks. Top-voted track auto-advances or host taps Skip.
7. Verify the Spotify app on host's phone receives the queued track.

---

## Troubleshooting

**"INVALID_CLIENT" on OAuth** — redirect URI mismatch. The URI sent in the `/authorize` call must match one of the dashboard URIs **exactly** (trailing slash, http vs https, casing).

**"No active device"** when calling `spotifyHostPlay`** — host's Spotify app isn't open or playing. Tell them to start any track first; Web API can't wake a cold device.

**`PERMISSION_DENIED` from Functions** — check that the user is signed in (`request.auth` populated) and that secrets are accessible to the deployed function (re-run step 4 if needed).

**`INSUFFICIENT_CLIENT_SCOPE`** — re-run OAuth; the scopes were widened. The host needs to sign back in to grant the new scopes.
