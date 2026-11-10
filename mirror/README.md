# آینه — Mirror Dash

A one-finger arcade game for Android 5.0+ (API 21). Two bodies mirrored around the middle of
the screen move together; rows of walls scroll down with asymmetric openings, and the run
ends as soon as either body touches a wall.

- **Controls:** drag anywhere on the screen — the left dot follows your finger's x, the right
  dot is always its mirror.
- **Score:** `10 × seconds survived + 5 × rows cleared`; the record is stored on the device.
- **No permissions, no ads, no internet, no third-party libraries.** ~60 KB APK.

Design notes and the reasoning behind the difficulty curve live in
[`docs/mirror/design.md`](../docs/mirror/design.md).

## Install

```bash
adb install -r dist/mirror-dash-1.0.apk     # signed release build
adb install -r dist/mirror-dash-debug.apk  # debug build, installs side by side
```

## Build

Requires JDK 17 and an Android SDK with platform 34 / build-tools 34.0.0:

```bash
gradle :mirror:assembleDebug      # mirror/build/outputs/apk/debug/mirror-debug.apk
gradle :mirror:assembleRelease    # mirror/build/outputs/apk/release/mirror-release.apk
```

CI (`.github/workflows/build-mirror-apk.yml`) builds both on every push that touches the
module, verifies the signatures with `apksigner`, and publishes the results plus
`dist/build-status.txt` back to the branch.

## Signing

Both build types are signed with the fixed development key in
[`signing/`](signing/README.md). Read that file before publishing anything: the key is public
on purpose so CI builds upgrade in place, and it must be replaced for a real release.

## Code map

| File | Responsibility |
|---|---|
| `GameActivity` | Menus, HUD, pause / game-over panels, persistence wiring |
| `GameView` | `SurfaceView`, fixed-step loop (1/60 s accumulator), touch, feedback |
| `GameEngine` | State machine, fair row generation, collision, score, particles |
| `LevelConfig` | Every tuning number (speed, spacing, gap, tolerance, sliver) |
| `ObstacleRow` | One row: gaps, wave motion, derived solid segments |
| `Renderer` | All canvas drawing, pooled paints/paths, no per-frame allocation |
| `SoundPlayer` | Two synthesised WAVs in a `SoundPool` |
| `GamePrefs` | Best score + sound preference in `SharedPreferences` |

## Tuning

Almost all balance numbers are in `LevelConfig`: the level tables (speed 150→520 dp/s,
spacing 320→170 dp, gap 96→78 dp, two-gap chance 0→70 %), the mismatch budget that controls
precision, and the moving-row chance. `tools/simulate_generation.py` re-implements the
generation maths in Python so you can check fairness/balance changes without a device:

```bash
python3 tools/simulate_generation.py
```

It verifies that no generated row is impossible, that a perfect player never dies, and prints
a survival-time snapshot for a reaction-limited virtual player.
