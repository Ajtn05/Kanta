# Contributing to Kanta

Run `make test` and `make build` before submitting a change. Prefer tests using the mock provider or a stubbed URL session. Playback providers use the apps’ public AppleScript dictionaries, so verify changes with the affected desktop player.

## Manual checks

1. In a fresh build, open Kanta with neither music app running. Verify onboarding, the empty state, and that neither music app opens. Start Spotify, then Apple Music in separate checks. Grant Automation and verify track changes, artwork, skip, pause, resume, and both kinds of seeking. Check the denied-permission state with a test bundle identifier.
2. Switch through the four mini-player layouts and Full Lyrics. Shrink each window from its native edges and bottom-right grip, and verify both dimensions stop at the documented minimum. Check the Artwork hover controls at its minimum size and switch Combined between Automatic, Horizontal, and Vertical. Test narrow and tall Combined sizes, mouse and keyboard controls, and both appearance modes. Verify the Full Lyrics view follows the track until you scroll and resumes only when you choose **Current line**.
3. Check an unmatched song, an instrumental song, and a plain-text response. In Combined, verify **No live lyrics** stays in the playback area for plain text and disappears for timed lyrics. Check Compact and Fill available space in both Combined arrangements, including resizing and reopening Preferences. Try a local override and removal. Simulate offline access with one cached song and one uncached song, then try **Search Again** after reconnecting.
4. Move windows between displays, detach and reconnect one display, and reopen Kanta. Check saved window frames, Spaces, always-on-top, click-through recovery from the menu bar, and a full-screen Space. Try VoiceOver and Reduce Motion.
5. Record a shortcut and use it with another app frontmost. Enable Launch at Login from the installed app, check Login Items, and verify it after a test login. Restore the prior preference after testing.
6. Run `make install`, verify the signed app opens, quit, then run `make uninstall`. Verify local settings and lyrics are present after reinstalling. To test only the bundle copy and removal, use a temporary directory with `INSTALL_DIR` and `OPEN_AFTER_INSTALL=0`.

When a check depends on a particular macOS release, player version, display setup, or track type, include those details in the test result.
