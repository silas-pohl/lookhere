# Lookhere

A macOS menu-bar app that turns your cursor into a hand-drawn pointer on a
stick. Every click **taps** the screen with a clack and a comic burst, so
people watching your screen share always know where to look. Rattle off a
few clicks and it gets more and more excited.

All the art, motion and sound here are original:
- a hand-drawn classic cartoon glove and Fishy, a goldfish that pokes with its lips (Bézier paths, like an SVG illustration)
- animated tap bursts: impact ring, speed lines, starburst and confetti
- synthesized tap sounds: Clack (default), Knock, Boop, Pop, Squeak and Boing

## Install

With Homebrew (builds from source on your Mac, about a minute):

```bash
brew install silas-pohl/tap/lookhere
open "$(brew --prefix)/opt/lookhere/Lookhere.app"
```

Or build it yourself:

```bash
make run          # build build/Lookhere.app and launch it
make install      # or copy it to /Applications and launch it
```

You need the Xcode Command Line Tools (Swift 5.9+) and macOS 14 or later.
Click the glove icon in the menu bar to open the comic-style settings panel. It
opens by itself on first launch.

| Shortcut | Action |
|---|---|
| ⌃⌥L | Turn Lookhere on or off |
| ⌃⌥H | Hands-off Mode: clicks only poke and never reach apps; the keyboard still works |

Hands-off Mode needs **Accessibility** permission. Lookhere prompts you the
first time; grant it, then press ⌃⌥H again. Every new build has a new ad-hoc
signature, so macOS may forget the permission after an update. If so, remove
Lookhere under System Settings → Privacy & Security → Accessibility and add it again.
While Hands-off Mode is on, clicks on the menu-bar icon still go through, so you
can always switch it off with the mouse.

## Settings (menu-bar panel)

- **Pointer**:
  - Style: glove, arrow or Fishy.
  - Glove colour: white, sunny, cherry, bubblegum, mint or sky.
  - Stick colour, or no stick.
  - Size: Small to Huge.
- **Tap**:
  - Mood: *Mellow*, *Friendly*, *Peppy*, *Rowdy* or *Unhinged*. Clicking in quick succession builds energy, and the bursts escalate from a ring to speed lines to a popping starburst with confetti.
  - Bursts on or off.
  - Sound on or off: pick Clack (default), Knock, Boop, Pop, Squeak, Boing or your own file, plus volume.
- **General**: Hands-off Mode, hide the system cursor, launch at login, Quit.

## Screen sharing tips

- Share or record the **entire screen**. Window capture leaves overlays out.
- The tap sound plays as system audio. To let others hear it:
  - Zoom: tick "Share sound".
  - Meet: tick "Also share system audio".

## Development

```bash
swift build && .build/debug/Lookhere                          # run unbundled
.build/debug/Lookhere --preview /tmp/art.png                  # all art on one sheet
.build/debug/Lookhere --simulate                              # print the engine's response to clicks
.build/debug/Lookhere --export-sounds /tmp/sounds             # write the built-in sounds as WAVs
.build/debug/Lookhere --settings-snapshot /tmp/settings.png   # panel render
```

| File | Role |
|---|---|
| `Engine.swift` | Spring-based lean and poke, click energy (pure logic) |
| `GloveArt.swift` / `FishArt.swift` | Hand-drawn glove and fish, authored as SVG path data |
| `Effects.swift` | Animated tap bursts, driven by the frame loop |
| `HandDrawing.swift` | The arrow pointer |
| `Art.swift` | Rasterises the pointer, finds the fingertip hotspot, draws stick and flashes |
| `Overlay.swift` | Click-through overlay window per display (Core Animation) |
| `Lookhere.swift` | 120 Hz frame loop, input, wiring |
| `Sounds.swift` | Synthesized tap sounds and playback |
| `System.swift` | Cursor hiding, Hands-off Mode event tap, hotkeys |
| `SettingsView.swift` / `Theme.swift` / `Stage.swift` | Comic-style menu-bar panel, its controls and the animated header |
| `AppDelegate.swift` | Status item and panel window |
| `Showcase.swift` | Previews, menu-bar icon, app icon |

## Support

Lookhere is free and open source under the MIT license. If it livened up your
calls and you'd like to say thanks, there's a **Tip jar ♥** button in the panel
(and a Sponsor button on GitHub). No pressure — it stays free either way.

## Releasing (maintainers)

1. Bump `CFBundleShortVersionString` in `Resources/Info.plist` and tag `vX.Y.Z`.
2. Update `url` and `sha256` in `packaging/homebrew/lookhere.rb`
   (`curl -L <tag tarball> | shasum -a 256`) and copy it to the `homebrew-tap` repo as `Formula/lookhere.rb`.
3. To show the tip jar, set `LHSupportURL` in `Resources/Info.plist` and fill in `.github/FUNDING.yml`.
