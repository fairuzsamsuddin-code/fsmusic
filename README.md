# FS Music

A clean, Apple Music–inspired, **ad-free** web music player in a single `index.html`
(HTML + Tailwind CSS via CDN + vanilla JavaScript).

## Features

- **Multi-source playback.** Search checks every enabled source at once, and results appear as
  each one responds:
  | Source | What you get | Setup |
  |---|---|---|
  | **YouTube** (via [Piped](https://github.com/TeamPiped/Piped) / [Invidious](https://invidious.io)) | Full songs, no ads, no IFrame player | Needs a working server. Public ones are often blocked by YouTube, so self-hosting is the reliable option |
  | **[Internet Archive](https://archive.org/details/etree)** | Free, full-length live concerts and archival recordings | None |
  | **[Audius](https://audius.co)** | Free full tracks from independent artists | None |
  | **Previews** (iTunes Search + Deezer) | 30-second clips of almost any song, with official album art | None |
- **Fallbacks.** The Listen Now songs play from YouTube when a server responds. Otherwise they
  play as a preview or a live version, whichever you choose in Settings. When a YouTube server
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
- Lock-screen and media-key controls (Media Session API), keyboard shortcuts, playback that
  resumes after a reload, and light and dark themes.

## Run it

Open `index.html` in a browser, or serve the folder:

```sh
python3 -m http.server 8000   # then visit http://localhost:8000
```

## Notes

- Public Piped/Invidious servers are mostly blocked by YouTube as of 2026. To get full YouTube
  songs, run your own instance and add it under **Settings → YouTube Servers → Add Custom Server**.
  The instance must allow CORS.
- Search APIs are called with `fetch`. If an API doesn't allow cross-origin requests, the app
  falls back to JSONP (iTunes, Deezer, Internet Archive).
- The equalizer runs on Web Audio and needs streams served with CORS headers. If a server
  doesn't send them, the app turns the EQ off and keeps playing.
