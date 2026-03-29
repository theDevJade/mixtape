# mixtape

Open source music player built with Flutter. Mix YouTube, SoundCloud, Spotify playlists, and local files in the same queue.

**Platforms:** iOS · Android · macOS · Windows · Linux

---

## Screenshots

| Now Playing | Sources | Menu |
|---|---|---|
| ![Now Playing](screenshots/playingSong.png) | ![Sources](screenshots/sources.png) | ![Menu](screenshots/menu.png) |

---

## What it does

- Mix tracks from different sources in one queue
- Background playback with lock screen controls on mobile
- Discord Rich Presence on desktop, shows what you're playing in your status
- Synced lyrics from [lrclib.net](https://lrclib.net), no API key needed
- Colors adapt to album art
- Playlists and queue saved locally with SQLite
- Each source is its own plugin, easy to add new ones

---

## Sources

### Spotify

Pulls in your Spotify playlists and library. **Spotify is for playlists/metadata only.** Audio plays through another source like yt-dlp or SoundCloud. Login uses OAuth PKCE, no client secret needed.

**Setup:**
1. Make an app at [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard)
2. Add `com.mixtape://callback` as a redirect URI
3. Put your Client ID in **Settings → Sources → Spotify**

**Redirect URI setup (one-time per platform):**

- **Android** - add to `AndroidManifest.xml` inside `<activity>`:
  ```xml
  <intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="com.mixtape" android:host="callback"/>
  </intent-filter>
  ```
- **iOS / macOS** - add to `Info.plist`:
  ```xml
  <key>CFBundleURLTypes</key>
  <array><dict>
    <key>CFBundleURLSchemes</key>
    <array><string>com.mixtape</string></array>
  </dict></array>
  ```

---

### YouTube

Search and browse YouTube using the YouTube Data API v3. You can also point it at a self-hosted [Piped](https://github.com/TeamPiped/Piped) or [Invidious](https://invidious.io) instance if you don't want to hit YouTube directly.

**Setup:**
1. Enable **YouTube Data API v3** at [console.developers.google.com](https://console.developers.google.com)
2. Add your API key in **Settings → Sources → YouTube Music**
3. Optionally add a Piped/Invidious URL (e.g. `https://pipedapi.kavin.rocks`)

> For actually playing YouTube audio, pair this with yt-dlp below.

---

### yt-dlp

Uses a local `yt-dlp` binary to grab real audio stream URLs from YouTube (and [hundreds of other sites](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md)). This is how you actually play YouTube in Mixtape on desktop.

**Requirements:**
- `yt-dlp` on your `PATH` (`brew install yt-dlp`, `pip install yt-dlp`, etc.)
- Desktop only (macOS · Windows · Linux)

**Setup:**
- Optionally set a custom binary path in **Settings → Sources → yt-dlp**
- Accept the prompt on first use

---

### SoundCloud

Search, browse, and stream from SoundCloud.

**Setup:**
1. Register an app at [soundcloud.com/you/apps](https://soundcloud.com/you/apps)
2. Add your Client ID in **Settings → Sources → SoundCloud**

---

### Jamendo

Millions of tracks under Creative Commons licenses, free to stream.

**Setup:**
1. Get a free API key at [developer.jamendo.com](https://developer.jamendo.com)
2. Add your Client ID in **Settings → Sources → Jamendo**

---

### Local Files

Pick audio files from your device and play them. Nothing to set up.

---

## Discord Rich Presence

Shows your current track in your Discord status on macOS, Windows, and Linux.

**App ID:** `1487732566558773360`

> **macOS:** If presence isn't connecting, the app sandbox is probably blocking it. Disable it in `macos/Runner/DebugProfile.entitlements` and `Release.entitlements`:
> ```xml
> <key>com.apple.security.app-sandbox</key>
> <false/>
> ```

---

## Running

```bash
flutter pub get
flutter run
```

After changing models/database schema:

```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## Stack

| | |
|---|---|
| State | `flutter_riverpod` |
| Navigation | `go_router` |
| Audio | `just_audio` + `audio_service` |
| Database | `drift` (SQLite) |
| HTTP | `dio` |
| Discord | `dart_discord_presence` |
| Lyrics | [lrclib.net](https://lrclib.net) |
| OAuth | `flutter_web_auth_2` |

