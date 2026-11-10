# هم‌زاد — Mirror Dash

A one-finger arcade game for Android 5.0+ (API 21). Two bodies mirrored around the middle of
the screen move together; rows of walls scroll down with asymmetric openings, and the run
ends as soon as either body touches a wall.

- **Controls:** drag anywhere on the screen — the left dot follows your finger's x, the right
  dot is always its mirror.
- **Score:** `10 × seconds survived + 5 × rows cleared`; the record is stored on the device.
- **Settings:** three difficulty presets (آسان / متوسط / دشوار), day and night palettes,
  sound on/off. Everything is remembered between launches.
- **No permissions, no ads, no internet, no third-party libraries.** ~90 KB APK.

Design notes and the reasoning behind the difficulty curve live in
[`docs/mirror/design.md`](../docs/mirror/design.md).

## Install

```bash
adb install -r dist/mirror-dash-1.1.apk     # signed release build
adb install -r dist/mirror-dash-debug.apk  # debug build, installs side by side
```

`1.1` installs **over** `1.0` without uninstalling: the application id
(`io.github.parsa1012.mirrordash`), the signing key and the prefs file are unchanged, and
`versionCode` only goes up (1 → 2). Keep it that way — changing any of those breaks in-place
updates.

## Build

Requires JDK 17 and an Android SDK with platform 34 / build-tools 34.0.0:

```bash
gradle :mirror:assembleDebug      # mirror/build/outputs/apk/debug/mirror-debug.apk
gradle :mirror:assembleRelease    # mirror/build/outputs/apk/release/mirror-release.apk
```

CI (`.github/workflows/build-mirror-apk.yml`) builds both on every push that touches the
module, verifies the signatures with `apksigner`, attaches the APKs to the `v1.1` GitHub
release, and publishes the results plus `dist/build-status.txt` back to the branch.

## Signing

Both build types are signed with the fixed development key in
[`signing/`](signing/README.md). Read that file before publishing anything: the key is public
on purpose so CI builds upgrade in place, and it must be replaced for a real release.

## Assets

| Asset | Notes |
|---|---|
| `assets/fonts/Vazirmatn-{Regular,Bold}.ttf` | Vazirmatn 33.0.3, subsetted with `fontTools` to ASCII + Persian letters + Persian digits + ZWNJ (~46 KB each). OFL licence next to them. Loaded with `Typeface.createFromAsset`, which is why `build.gradle` sets `noCompress 'ttf'`. |
| `res/drawable-nodpi/logo.png` | Menu logo, 384 px, derived from `art/logo-source.png`. |
| `res/drawable-nodpi/ic_launcher_foreground.png` | Adaptive-icon foreground (432 px). |
| `res/mipmap-*/ic_launcher.png` | Legacy launcher icons 48–192 px for API 21–25. |

## Code map

| File | Responsibility |
|---|---|
| `GameActivity` | Menu (logo), settings page, HUD, pause / game-over panels, theme switch, persistence |
| `GameView` | `SurfaceView`, fixed-step loop (1/60 s accumulator), touch, feedback |
| `GameEngine` | State machine, fair row generation, difficulty-aware tuning, collision, score, particles |
| `LevelConfig` | The base tuning curves (speed, spacing, gap, tolerance, sliver) |
| `Difficulty` | Multipliers/offsets applied on top of `LevelConfig` for the three presets |
| `Theme` | Night and day palettes, shared by the canvas and the Android views |
| `ObstacleRow` | One row: gaps, wave motion, derived solid segments |
| `Renderer` | All canvas drawing, pooled paints/paths, glow sprites, bundled Vazirmatn typefaces |
| `SoundPlayer` | Two synthesised WAVs in a `SoundPool` |
| `GamePrefs` | Best score, sound, day/night and difficulty in `SharedPreferences` |

## Tuning

Almost all balance numbers are in `LevelConfig`: the level tables (speed 150→520 dp/s,
spacing 320→170 dp, gap 96→78 dp, two-gap chance 0→70 %), the mismatch budget that controls
precision, and the moving-row chance. `Difficulty` scales those curves:

| Preset | Speed | Spacing | Gap | Mismatch | Two-gap | Moving | Jump |
|---|---|---|---|---|---|---|---|
| آسان | ×0.85 | ×1.15 | +8 dp | ×0.55 | ×0.65 | ×0.50 | ×1.10 |
| متوسط | ×1.00 | ×1.00 | 0 | ×1.00 | ×1.00 | ×1.00 | ×1.00 |
| دشوار | ×1.15 | ×0.88 | −6 dp | ×1.25 | ×1.35 | ×1.15 | ×0.86 |

`tools/simulate_generation.py` re-implements the generation maths in Python so you can check
fairness/balance changes without a device:

```bash
python3 tools/simulate_generation.py                     # all three presets
python3 tools/simulate_generation.py --difficulty hard
```

It verifies that no generated row is impossible at the selected preset, that a perfect player
never dies, and prints a survival snapshot for a reaction-limited virtual player.
