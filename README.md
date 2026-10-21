# FS Music

A clean, Apple Music–inspired, **ad-free** web music player in a single `index.html`
(HTML + Tailwind CSS via CDN + vanilla JavaScript).

## Features

- **Ad-free YouTube audio.** Doesn't use the YouTube IFrame player. Search and audio-only
  streams (`.m4a` / `.webm`) come from public [Piped](https://github.com/TeamPiped/Piped)
  and [Invidious](https://invidious.io) API instances, played through an HTML5 `Audio()` element.
- **Automatic failover.** Each request tries the healthiest server first. Servers that fail or
  rate-limit go on a short cooldown, and the app switches to the next one. If every built-in
  server fails, it fetches the public instance directories once and retries. Errors show up as
  short toasts.
- **Search** by song, artist or album, with a "Top Result" card, a Songs / All Videos filter
  and recent searches.
- **Smart Autoplay (radio).** Uses each track's related-videos list to build an endless station.
  It filters out mixes, full albums, duplicates and long videos, and limits how often one artist
  repeats.
- **Up Next queue.** Play Now, Play Next, Add to Up Next, Start Station, remove songs and jump
  to any song.
- **Now Playing.** Large artwork over a blurred backdrop, a seek bar, transport controls and
  volume. It's a swipe-down sheet on mobile and a fixed side panel on desktop.
- **Settings** (hamburger menu): audio quality, AAC vs Opus, Autoplay, provider and server
  choice, server testing and discovery, custom instances, and a 6-band equalizer with presets.
- Lock-screen and media-key controls (Media Session API), keyboard shortcuts, playback that
  resumes after a reload, and light and dark themes.

## Run it

Open `index.html` in a browser, or serve the folder:

```sh
python3 -m http.server 8000   # then visit http://localhost:8000
```

## Notes

- Public Piped/Invidious instances change often. If playback stalls, open
  **Settings → Music Source** and use *Test Servers*, *Find More Servers*, or add your own instance.
- The equalizer runs on Web Audio and needs streams served with CORS headers. If a server
  doesn't send them, the app turns the EQ off and keeps playing.
