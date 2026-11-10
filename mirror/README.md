# هم‌زاد — Mirror Dash

A one-finger arcade game for Android 5.0+ (API 21). Two bodies mirrored around the middle of
the screen move together; rows of walls scroll down with asymmetric openings, and the run
ends as soon as either body touches a wall.

- **Controls:** drag anywhere on the screen — the blue body follows your finger's x, the red
  body is always its mirror.
- **Row pattern:** rows alternate between *together* (one shared opening, both bodies on the
  axis) and *apart* (two openings near the edges, bodies pulled wide). The pattern switches
  randomly, never repeats more than twice, and gives the player a breather every seven rows.
- **Score:** `10 × seconds survived + 5 × rows cleared`; the record is stored on the device.
- **Settings:** three difficulty presets (آسان / متوسط / دشوار), day and night palettes,
  sound on/off. Everything is remembered between launches.
- **No permissions, no ads, no internet, no third-party libraries.** ~340 KB APK.

Design notes, the fairness maths and the measured balance live in
[`docs/mirror/design.md`](../docs/mirror/design.md).

## Install

```bash
adb install -r dist/mirror-dash-1.2.apk     # signed release build
adb install -r dist/mirror-dash-debug.apk  # debug build, installs side by side
```

`1.2` installs **over** `1.0` and `1.1` without uninstalling: the application id
(`io.github.parsa1012.mirrordash`), the signing key and the prefs file are unchanged, and
`versionCode` only goes up (1 → 2 → 3). Keep it that way — changing any of those breaks
in-place updates.

## Build

Requires JDK 17 and an Android SDK with platform 34 / build-tools 34.0.0:

```bash
gradle :mirror:assembleDebug      # mirror/build/outputs/apk/debug/mirror-debug.apk
gradle :mirror:assembleRelease    # mirror/build/outputs/apk/release/mirror-release.apk
```

CI (`.github/workflows/build-mirror-apk.yml`) builds both on every push that touches the
module, verifies the signatures with `apksigner`, attaches the APKs to the `v1.2` GitHub
release, and publishes the results plus `dist/build-status.txt` back to the branch.

## Assets

| Asset | Notes |
|---|---|
| `assets/fonts/Vazirmatn-{Regular,Bold}.ttf` | Vazirmatn 33.0.3, subsetted with `fontTools` to ASCII + Persian letters + Persian digits + ZWNJ (~46 KB each). OFL licence next to them. Loaded with `Typeface.createFromAsset`, which is why `build.gradle` sets `noCompress 'ttf'`. |
| `art/logo-v12.png` | 1024 px master, drawn from signed distance fields by `tools/make_branding.py`. |
| `res/drawable-nodpi/logo.png` | Menu logo, 384 px. |
| `res/drawable-nodpi/ic_launcher_foreground.png` | Adaptive-icon foreground; the art is kept inside the 66 dp safe zone so no launcher mask clips an orb. |
| `res/mipmap-*/ic_launcher{,_round}.png` | Legacy launcher icons (48–192 px) for API 21–25 and for launchers that ask for a round icon. |

Re-generate every icon after changing the brand:

```bash
python3 tools/make_branding.py     # also prints the mirror-symmetry report
```

## Code map

| File | Responsibility |
|---|---|
| `GameActivity` | Menu (logo), settings page, HUD, pause / game-over panels, theme switch, persistence. Built entirely in code, pinned to RTL. |
| `GameView` | `SurfaceView`, fixed-step loop (1/60 s accumulator), hardware canvas, touch, feedback |
| `GameEngine` | State machine, together/apart row pattern, fairness/reachability, collision, score, particles |
| `LevelConfig` | The base tuning curves (speed, spacing, gap, tolerance, sliver) |
| `Difficulty` | Multipliers/offsets on top of `LevelConfig`, plus the pattern switch chance |
| `Theme` | Night and day palettes, shared by the canvas and the Android views |
| `ObstacleRow` | One row: gaps, wave motion, derived solid segments |
| `Renderer` | Canvas drawing, cached background bitmap, pooled paints/paths, glow sprites, Vazirmatn typefaces |
| `SoundPlayer` | Two synthesised WAVs in a `SoundPool` |
| `GamePrefs` | Best score, sound, day/night and difficulty in `SharedPreferences` |

## Performance notes

- `SurfaceHolder.lockHardwareCanvas()` on API 26+: rows are paths and bodies are scaled
  bitmaps, both far cheaper on the GPU.
- The grid and the dashed axis are baked once into an `RGB_565` bitmap and blitted per frame
  (one draw instead of ~30 lines). The dashes live in that bitmap because hardware canvases
  ignore `PathEffect` on lines.
- The loop thread runs at `THREAD_PRIORITY_DISPLAY`, steps at a fixed 1/60 s and paces itself
  on a 60 Hz deadline grid, so 90/120 Hz devices behave identically.
- Nothing is painted while the game is paused, apart from the transition frame.

## Tuning

Almost all balance numbers are in `LevelConfig`: the level tables (speed 150→520 dp/s,
spacing 320→170 dp, gap 96→78 dp), the mismatch budget that controls precision, and the
moving-row chance. `Difficulty` scales those curves and also decides how eagerly the row
pattern flips:

| Preset | Speed | Spacing | Gap | Mismatch | Moving | Min window | Apart band | Switch chance |
|---|---|---|---|---|---|---|---|---|
| آسان | ×0.88 | ×1.14 | +6 dp | ×0.72 | ×0.55 | +5 dp | ×0.95 | 0.55 |
| متوسط | ×1.00 | ×1.00 | 0 | ×1.00 | ×1.00 | 0 | ×1.00 | 0.62 |
| دشوار | ×1.15 | ×0.88 | −6 dp | ×1.20 | ×1.15 | −4 dp | ×1.10 | 0.72 |

`tools/simulate_generation.py` re-implements the generation maths in Python so you can check
fairness/balance changes without a device:

```bash
python3 tools/simulate_generation.py                     # all three presets
python3 tools/simulate_generation.py --difficulty hard
```

It verifies that no generated row is impossible at the selected preset, that the required
travel between consecutive rows stays swiped-reachable, that the pattern really alternates,
and prints survival snapshots for a reaction-limited virtual player.

## Previews

`tools/mock_ui.py` recreates the menu, the settings page and a gameplay frame with the real
layout numbers, palette and row geometry (Pillow + Vazirmatn), for reviewing changes without
a device:

```bash
python3 tools/mock_ui.py    # docs/mirror/preview-v12-*.png
```

## نسخهٔ ۱٫۳ — توپهای همزاد

سه سطح آسان، متوسط و دشوار رکورد مستقل دارند. رکورد قدیمی که سطحش مشخص نیست، در داده‌های قبلی باقی می‌ماند و به هیچ سطحی نسبت داده نمی‌شود؛ رکوردهای جداگانه از صفر شروع می‌شوند. در منوی اصلی دکمهٔ `i` راهنما، `A` انتخاب زبان فارسی، انگلیسی، عربی و اسپانیایی، و `@` اطلاعات سازنده را باز می‌کند. سرعت و شتاب پیشرفت نسبت به نسخهٔ قبل بیشتر است و گوی‌ها سایه‌روشن آینه‌ای دارند. زبان انتخاب‌شده ذخیره می‌شود.

نسخهٔ انتشار با همان شناسه و کلید قبلی و versionCode برابر ۴ امضا شده است؛ نسخهٔ انتشار را می‌توان روی نسخه‌های قبلی انتشار نصب کرد. نسخهٔ debug شناسهٔ متفاوت دارد و جایگزین نسخهٔ انتشار نیست.

## نسخهٔ ۱٫۴ — موسیقی

«Parsa Ahmadi - آرپژ.mp3» موسیقی منو و تنظیمات، و «موسیقی در حال بازی.mp3» موسیقی بازی است. هر آهنگ در زمان پخش خود به‌صورت پیوسته تکرار می‌شود. موسیقی بازی هنگام توقف، پایان بازی یا خروج از برنامه قطع/متوقف می‌شود و در ادامهٔ بازی از محل توقف ادامه می‌یابد؛ بازگشت به منو موسیقی منو را شروع می‌کند. کلید صدای تنظیمات هم موسیقی و هم جلوه‌های صوتی را کنترل می‌کند. هنگام وقفهٔ صوتی برنامه‌های دیگر، موسیقی متوقف می‌شود. فایل‌های صوتی همراه برنامه هستند و به اینترنت نیازی نیست. شناسه و کلید امضا ثابت مانده‌اند و versionCode به ۵ رسیده است.
