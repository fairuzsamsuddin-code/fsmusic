# FS Music

A clean, Apple Music–inspired, **ad-free** web music player in a single `index.html`
(HTML + Tailwind CSS via CDN + vanilla JavaScript).

## Features

- **Multi-source playback.** Search checks every enabled source at once, and results appear as
  each one responds:
  | Source | What you get | Setup |
  |---|---|---|
  | **YouTube, embedded player** (default) | Full songs through YouTube's official player. YouTube may show ads, and playback stops when the phone locks | None. Songs are matched to videos through Wikidata (free); an optional free [YouTube Data API key](https://developers.google.com/youtube/v3/getting-started) unlocks full YouTube search |
  | **YouTube, your own server** ([Piped](https://github.com/TeamPiped/Piped) / [Invidious](https://invidious.io)) | Full songs, ad-free audio-only, plays with the screen locked | Self-hosted instance |
  | **[Internet Archive](https://archive.org/details/etree)** | Free, full-length live concerts and archival recordings | None |
  | **[Audius](https://audius.co)** | Free full tracks from independent artists | None |
  | **Previews** (iTunes Search + Deezer) | 30-second clips of almost any song, with official album art | None |
- **Full songs from YouTube.** Songs from the iTunes/Deezer catalog play in full through YouTube
  whenever a matching video is found. If none is found, or the video can't be embedded, the
  30-second preview plays instead.
- **[SponsorBlock](https://sponsor.ajay.app).** Skips non-music intros, skits and outros in music
  videos.
- **Fallbacks.** If no YouTube video plays, the Listen Now songs play as a preview or a live
  version, whichever you choose in Settings. When a YouTube server
  fails or rate-limits, the app tries the next one. If all of them fail, YouTube pauses for a few
  minutes so the other sources stay fast.
- **Search** by song, artist or album. Results show a Top Result and one section per source,
  with All / YouTube / Previews / Live Archive / Audius filters and recent searches.
- **Smart Autoplay (radio).** YouTube uses related videos and Previews use Deezer artist radio.
  Internet Archive continues the concert and then plays another show by the same artist. Audius
  picks trending tracks in the same genre. Mixes, duplicates and stage banter are filtered out.
- **Up Next queue.** Play Now, Play Next, Add to Up Next, Start Station, remove songs and jump
  to any song.
- **Now Playing.** Large artwork over a blurred backdrop, with a label showing where the audio
  comes from. It's a swipe-down sheet on mobile and a fixed side panel on desktop.
- **Settings** (hamburger menu): source toggles, audio quality, AAC vs Opus, Autoplay, YouTube
  server choice, testing and discovery, custom servers, and a 6-band equalizer with presets.
- **Home Screen app.** Includes a web app manifest and icons, so saving it to your phone's
  Home Screen gives a proper app icon. Replace the PNGs in `icons/` to change it.
- Lock-screen and media-key controls (Media Session API), keyboard shortcuts, playback that
  resumes after a reload, and light and dark themes.

## Run it

Open `index.html` in a browser, or serve the folder:

```sh
python3 -m http.server 8000   # then visit http://localhost:8000
```

## Your own YouTube server (optional)

For ad-free YouTube playback that keeps going when the phone is locked, run a free Invidious
server on Oracle Cloud's Always Free tier. The steps work from an iPhone, and the guide comes
with a one-line installer:

- Guide: [`server/`](server/index.html) (live at `/server/` on the GitHub Pages site)
- Installer: [`server/install.sh`](server/install.sh), which sets up Invidious, Invidious Companion
  and PostgreSQL with Docker, adds a Cloudflare quick tunnel for HTTPS, plus helper commands
  (`fsmusic-url`, `fsmusic-update`, `fsmusic-logs`) and a weekly auto-update

## Notes

- Public Piped/Invidious servers are mostly blocked by YouTube as of 2026. To get full YouTube
  songs, run your own instance and add it under **Settings → YouTube Servers → Add Custom Server**.
  The instance must allow CORS.
- Search APIs are called with `fetch`. If an API doesn't allow cross-origin requests, the app
  falls back to JSONP (iTunes, Deezer, Internet Archive).
- The equalizer runs on Web Audio and needs streams served with CORS headers. If a server
  doesn't send them, the app turns the EQ off and keeps playing.
