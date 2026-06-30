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

## Code signing & the Accessibility permission

Handometer needs the **Accessibility** permission. macOS (TCC) ties that grant to
the app's code signature. An **ad-hoc** signature pins it to the exact binary
(`cdhash`), so every update looks like a *new* app — macOS re-asks for the
permission and leaves a stale entry behind.

The fix (no Apple Developer account needed): sign every release with a **stable
self-signed certificate**. The grant then keys on the certificate and survives
updates.

**One-time setup**

```bash
bash Tools/make-signing-cert.sh     # creates "Handometer Self-Signed" (10-year cert)
                                    # → backup written to ~/handometer-signing-cert.p12
```

**Make CI sign with the same certificate** (releases are built in GitHub Actions):

```bash
bash Tools/export-cert-secret.sh    # prints/copies the base64 .p12
```

Then in GitHub → *Settings ▸ Secrets and variables ▸ Actions* add:
- `SIGNING_CERT_P12_BASE64` = the base64 value
- `SIGNING_CERT_PASSWORD` = `handometer` (the `.p12` password)

> Every release **must** be signed with this same certificate. Keep the `.p12`
> backup safe — losing it means the permission resets once more on the next build.

**Migrate the currently-installed (ad-hoc) app — once:**

```bash
./build.sh release <version>        # now signed with the certificate
osascript -e 'quit app "Handometer"' 2>/dev/null || true
bash Tools/reset-accessibility.sh   # clears the stale TCC entry
open Handometer.app                 # grant Accessibility one last time
```

From then on, updates keep the permission.

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
