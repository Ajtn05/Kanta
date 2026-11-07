<p align="center">
  <img src="docs/assets/kanta-icon.png" alt="Kanta app icon" width="128" height="128">
</p>

<h1 align="center">Kanta</h1>

<p align="center">Your music and lyrics, always close at hand.</p>

<p align="center"><strong>macOS 13+</strong> · <strong>Spotify &amp; Apple Music</strong> · <strong>SwiftUI</strong> · <strong>MIT License</strong></p>

Kanta is a native macOS menu-bar companion for Spotify and Apple Music. Keep a record sleeve, compact transport, synchronized subtitle, or combined player on your desktop. Open Full Lyrics when you want to browse the whole song.

## Features

- **Spotify and Apple Music support.** Follow the active desktop player automatically, or choose a source yourself. Play, pause, skip, and seek from Kanta.
- **Six player views.** Choose Artwork, Album, Compact, Lyrics Only, Combined, or a separate Full Lyrics window. Album keeps its cover clear with controls in a separate area below it.
- **Guided setup.** Choose your source, player, lyrics, appearance, and startup behavior during welcome. Run setup again from Preferences or the menu bar.
- **Synchronized lyrics.** Fetch lyrics from LRCLIB, click a timed line to seek, and adjust timing globally or for an individual song.
- **Responsive lyric windows.** Lyrics Only scales text to fit the width and reveals more lines as the window grows taller. Long lines wrap without an ellipsis. Combined keeps the title and artist centered in its player panel.
- **Full Lyrics browsing.** Drag the header to move the window, scroll through a song, and return to the current line. Close it with the close button or Escape.
- **Your preferred appearance.** Choose light, dark, or system appearance; artwork tinting; Frosted, Solid, or supported Liquid Glass backgrounds; and lyric typography, alignment, highlights, and opacity.
- **Desktop controls.** Keep windows on top, remember each layout’s position and size, enable a transparent click-through lyric overlay, set global shortcuts, or launch at login.
- **Local lyrics and caching.** Paste plain text or timestamped LRC lyrics, save song overrides, and reuse cached lyrics when offline. No account or API key is required.

## Quickstart

### Requirements

- macOS 13 Ventura or later, on Apple Silicon or Intel.
- Apple’s Command Line Tools with Swift 5.9 or newer. Install them with `xcode-select --install` if needed.
- The Spotify or Apple Music desktop app for live playback. An offline demo is also included.

Download this repository with **Code → Download ZIP**, or clone it. Open Terminal in the extracted project folder and run:

```sh
make run
```

This builds and opens Kanta. Complete the welcome setup, then start a song in Spotify or Apple Music and allow Automation access when macOS asks. Use the lyrics icon in the menu bar to choose a layout, run setup again, or open Preferences. Setup saves your choices when you select **Open My Player**; closing it preserves your previous settings.

To try the interface without a music app, build and open the offline demo:

```sh
make build
open -n dist/Kanta.app --args --demo --layout combined --full-lyrics
```

### Install locally

```sh
make install
```

This builds and signs a release bundle, installs it in `/Applications`, and launches it. Use an administrator account with write access to `/Applications`, or set `INSTALL_DIR` to an existing writable folder. Quit Kanta before updating or uninstalling. Afterwards, open Kanta from Finder or Spotlight.

For an installation in your home folder:

```sh
mkdir -p "$HOME/Applications"
make install INSTALL_DIR="$HOME/Applications"
```

### Build commands

| Command | What it does |
| --- | --- |
| `make` or `make run` | Build and open the debug app |
| `make build` | Assemble a release app at `dist/Kanta.app` |
| `make install` | Install and open the release app |
| `make uninstall` | Remove the application bundle |
| `make clean` | Remove local build and distribution output |
| `make test` | Run the SwiftPM XCTest suite |
| `make dmg` | Create `dist/Kanta.dmg` with an Applications shortcut |

## Play music

Open either desktop music app and play a song. When prompted, grant Kanta Automation access for that app. If you previously declined, use **System Settings → Privacy & Security → Automation**. Automatic source selection follows a playing app, keeps the current source if both are playing, and falls back to a paused app. Choose a specific source from the Kanta menu to pin it.

| Layout | Interaction |
| --- | --- |
| Artwork MiniPlayer | Hover to reveal controls. Double-click the sleeve to expand. |
| Album MiniPlayer | Keep a clear square cover above track information and playback controls. Use the lyrics button or double-click the cover to open Full Lyrics. |
| Compact MiniPlayer | Keep artwork, track details, and transport in a narrow strip. |
| Lyrics Only | Resize horizontally to fit the type and vertically to show more or fewer lines. Set background opacity to zero for a transparent overlay. |
| Combined MiniPlayer | Resize to adapt between a horizontal player and a stacked layout. |
| Full Lyrics | Select a timed line to seek. Scroll to browse, then choose **Current line** to resume following playback. |

Choose a layout from the menu bar or right-click any interactive player. Drag the bottom-right grip to resize. Each layout remembers its own position and size. Toggle **Lyrics Click-Through** from the menu bar to regain mouse interaction with a click-through overlay.

Windows stop shrinking at a usable minimum: Artwork 240 × 240, Album 280 × 440, Compact 360 × 96, Lyrics Only 280 × 88, Combined 380 × 280 (520 points wide when set to Horizontal), and Full Lyrics 400 × 380 points. Saved windows smaller than these limits expand when reopened.

Use **Find or Paste Lyrics…** to retry LRCLIB or save a local copy of plain or timestamped lyrics. In **Adjust Synchronization**, positive offsets make lines appear earlier and negative offsets make them appear later. Track offsets are saved separately from the global offset. In Preferences, set global shortcuts, choose a theme, adjust type and opacity, and enable menu-bar lyrics or Launch at Login.

Choose Frosted, Solid, or Liquid Glass in Appearance. Liquid Glass uses the native effect on macOS 26 and later with a supported build toolchain, and falls back to Frosted on earlier systems. Turn off **Seek when clicking lyrics** in Lyrics preferences to keep lyric clicks from moving playback. Lyrics Only keeps at least 16 points of horizontal padding and 12 points of vertical padding, with a minimum window of 280 × 88 points. Long live lines shrink to readable type, then wrap if necessary. In **Lyrics → Combined MiniPlayer**, choose **Compact** for a small preview with a set line count, or **Fill available space** to use your chosen font size and fit more lines as the window grows.

Live lyrics are always preferred. Enable **Show plain lyrics when live lyrics are unavailable** in Lyrics preferences to keep an untimed fallback. A small clock marks unsynced lyrics in Combined, Lyrics Only, and Full Lyrics; scroll to read them at your own pace. Turn the option off to show **Live lyrics unavailable** instead. Drag the Full Lyrics header to move that window; its close button or Escape hides it.

## Privacy and storage

Kanta sends song title, artist, and, when available, album and duration to [LRCLIB](https://lrclib.net/docs). For Spotify cover art, it downloads the HTTPS image URL reported by Spotify. Apple Music cover art comes from Music’s scripting interface when available.

Cached artwork and lyrics are stored under `~/Library/Caches/Kanta`. Local lyrics overrides are stored under `~/Library/Application Support/Kanta`. Preferences and window frames use macOS UserDefaults. Uninstalling removes the app bundle and preserves these data. Kanta uses no telemetry, accounts, tracking, API keys, or uploads of local lyrics or files.

## Development and verification

```text
Sources/Kanta/
  App/         Application lifecycle, menu bar, hotkeys, playback coordination
  Models/      Playback snapshots and source selection
  Players/     AppleScript providers, artwork cache, offline demo provider
  Lyrics/      LRC parsing, matching, network client, cache and overrides
  Windows/     Floating panels and display-aware placement
  Views/       Six layouts, shared controls, guided setup and lyrics editor
  Settings/    Preferences interface and persistence
  Utilities/   Local file storage
Tests/         XCTest fixtures and integration checks with a mock player
Bundling/      Info.plist and Apple Events entitlement
Resources/     App icon
scripts/       Bundle, install, DMG, and icon generation
```

For an offline UI check, launch the bundled demo after building.

```sh
open -n dist/Kanta.app --args --demo --layout combined --full-lyrics
```

The demo has synthetic music, original artwork and lyrics, and simulated transport controls. Valid mini-player layout names are `artwork`, `album`, `compact`, `lyrics`, and `combined`. Add `--setup` to walk through welcome configuration in the demo without changing saved preferences.

The tests cover script compilation, mock provider transitions, interpolation, LRC parsing, synchronization offsets, lyrics matching, offline behavior, caches, settings, layout selection, and window placement. See [CONTRIBUTING.md](CONTRIBUTING.md) for the manual test checklist.

## Platform behavior

Spotify and Music expose different scripting features. Some Apple Music tracks expose metadata without usable artwork. Kanta uses a built-in cover in that case. LRCLIB availability and timing vary by recording, and conservative matching can leave a track unmatched. A plain-text response can be read in Full Lyrics. macOS controls whether auxiliary windows can appear above a given full-screen Space and whether login items require approval.

## Signing and distribution

Local builds use an ad-hoc signature. The default bundle identifier is `com.kanta.miniplayer`. Keep a consistent installation path and identifier across builds to help macOS retain Automation consent. macOS can ask again after a rebuild or signing identity change.

For public distribution, set a bundle ID you control, your LRCLIB project URL, and a Developer ID Application identity. The build enables the hardened runtime when given a signing identity. `UNIVERSAL=1` builds both architectures.

```sh
make dmg UNIVERSAL=1 BUNDLE_ID=com.example.kanta \
  PROJECT_URL=https://example.com/kanta \
  SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
xcrun notarytool submit dist/Kanta.dmg --keychain-profile KantaNotary --wait
xcrun stapler staple dist/Kanta.dmg
xcrun stapler validate dist/Kanta.dmg
```

Before publishing, replace the example values, configure a notarization profile, and verify the stapled DMG on a second Mac.

## Acknowledgments

Kanta takes inspiration from [Apple Music MiniPlayer](https://support.apple.com/guide/music/use-music-miniplayer-mus71d7dcfce/mac), [lrclrclrc](https://github.com/jtanudjaja/lrclrclrc), and [SpotifyLyrics](https://github.com/denyherianto/SpotifyLyrics). The two reference repositories use MIT licenses. Kanta’s implementation and assets were written independently.

Kanta is available under the [MIT License](LICENSE).
