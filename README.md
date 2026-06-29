# Handometer

> A **pedometer for your hands** 🖐️ — Handometer tracks, **per day**, the physical
> distance your cursor travels and how many times you press each key.

- 📏 **Mouse distance** in real centimeters (move 5 cm with the mouse = 5 cm counted).
- 🏎️ **Speed** — average and peak mouse speed in km/h.
- 🖱️ **Clicks** counted per button: left, right, and middle (scroll wheel click).
- ⌨️ **Key frequency** — type "hello" → h×1, **e×1**, l×2, o×1.
- 📊 Today's dashboard + history charts.
- 💾 CSV / JSON export.
- 🔄 Automatic updates (Sparkle).

> The app UI is in **English**.

Everything stays **100% local and private**: only per-character counters are
stored — never the words you type or the order of keystrokes.

## Installation

1. Download the latest version from the [Releases page](https://github.com/jeoste/handometer/releases).
2. Unzip and drag `Handometer.app` into `/Applications`.
3. **First launch** — the app is not signed by Apple, so macOS will block it.
   **Right-click the app ▸ Open**, then confirm. (Only needed once.)
   - Terminal alternative: `xattr -dr com.apple.quarantine /Applications/Handometer.app`
4. macOS will ask for **Accessibility** permission (required to count keystrokes):
   *System Settings ▸ Privacy & Security ▸ Accessibility* → enable **Handometer**,
   then relaunch the app.

The icon appears in the **menu bar** (not the Dock). Click it to see your stats
or open the dashboard.

## Building from source

Requirements: macOS 13+ and the Swift toolchain.

```bash
./build.sh            # produces Handometer.app (default version)
VERSION=1.2.3 ./build.sh   # with a specific version
open Handometer.app
```

## How it works

- Monitoring via `NSEvent` (global + local monitors).
- Pixel → cm conversion using `CGDisplayScreenSize` (physical screen size),
  calculated per display (multi-monitor supported).
- JSON persistence in `~/Library/Application Support/Handometer/stats.json`.
- Auto-update via [Sparkle](https://sparkle-project.org) and an `appcast.xml` feed.

## Releases & updates

Every push to `main` automatically triggers the
[`.github/workflows/release.yml`](.github/workflows/release.yml) workflow: it
bumps the version number (patch), builds the app, signs the archive (Sparkle
EdDSA), publishes a [GitHub Release](https://github.com/jeoste/handometer/releases),
and updates `appcast.xml`.

Installed apps detect updates via Sparkle (menu bar → **Check for updates…**).
The feed reads `appcast.xml` on `main` and downloads the zip from the matching
GitHub Release.

> Auto-update only works with a complete `.app` bundle (built via `./build.sh` or
> downloaded from a release), not with `swift run`.

## License

[MIT](LICENSE).
