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

## نسخهٔ ۱٫۵ — ظاهر و کنترل صدا

در تنظیمات، «جلوه‌های صوتی» و «موسیقی» دو گزینهٔ مستقل دارند و هرکدام جدا ذخیره می‌شوند. در نخستین اجرای نسخهٔ جدید، هر دو وضعیت قبلی صدا را به ارث می‌برند؛ سپس تغییر یکی روی دیگری اثر ندارد. موسیقی منو و بازی همچنان به‌صورت تکراری پخش می‌شوند. پس‌زمینهٔ منو و صفحهٔ بازی، در هر دو تم روز و شب، و لوگوی بازی و آیکون نصب تازه شده‌اند؛ دکمه‌های گوشهٔ منو زیر هم قرار گرفته‌اند. فایل اصلی تصاویر در `mirror/art` و ابزار تولید خروجی‌ها در `tools/make_v15_assets.py` است. شناسه و کلید امضا تغییر نکرده و versionCode به ۶ افزایش یافته است.

## نسخهٔ ۱٫۶ — فاز اول متعادل‌سازی

ردیف‌های تک‌سوراخ فضای کافی برای عبور دو گوی بدون چسبیدن دارند. محاسبهٔ شکاف‌های متحرک اکنون تغییر فضای مشترک دو گوی را در تمام دامنهٔ حرکت لحاظ می‌کند. محدودیت حرکت بین ردیف‌ها زمان آزاد پس از عبور از دیوار و مقداری زمان واکنش را در نظر می‌گیرد؛ سقف سرعت و حداقل فاصلهٔ ردیف‌ها نیز اصلاح شده‌اند. هر سه درجه، رکوردها، زبان‌ها، موسیقی و گزینه‌های صدا حفظ می‌شوند.

برای بررسی هندسهٔ مولد واقعی جاوا در اندازه‌ها، تراکم‌ها، سختی‌ها و سطح‌های مختلف `tools/test_engine.sh` را با JDK اجرا کنید. `python3 tools/simulate_generation.py` نیز شبیه‌سازی تقریبی انجام می‌دهد؛ این آزمون‌ها جای تست لمسی با افراد و گوشی‌های واقعی را نمی‌گیرند.

## نسخهٔ ۱٫۷ — فاز سوم: آمار، ظاهر و صدا

- در تنظیمات، «آمار بازی» برای هر درجهٔ سختی جداگانه امتیاز رکورد، تعداد بازی‌های تمام‌شده، مجموع و بیشترین ردیف، بهترین زمان و بالاترین سطح را نشان می‌دهد. فقط بازی‌هایی که به پایان رسیده‌اند از نسخهٔ ۱٫۷ شمرده می‌شوند؛ داده‌های آماری قدیمی موجود نبودند و از صفر شروع می‌شوند، ولی رکوردهای قبلی حذف نمی‌شوند. زمان توقف شمرده نمی‌شود.
- «ظاهرهای بازشدنی» شامل سه طرح گوی و سه پس‌زمینهٔ بازی است. طرح نخست آزاد است؛ طرح‌های دوم و سوم با رکورد ۱۵۰ و ۴۰۰ امتیاز در هر یک از درجات باز می‌شوند. رکوردهای موجود نیز برای باز شدن حساب می‌شوند. انتخاب‌ها ذخیره می‌شوند و تنها جنبهٔ ظاهری دارند؛ رنگ آبی و قرمز و برخوردها تغییر نمی‌کنند.
- بلندی موسیقی و جلوه‌ها از صفر تا صد به‌صورت مستقل قابل تنظیم و ذخیره است؛ کلیدهای خاموش/روشن جداگانه نیز باقی مانده‌اند. تنظیمات، آمار و مجموعه به چهار زبان بازی هستند.
- این نسخه فقط فاز سوم است؛ حالت‌های مرحله‌ای و تمرینی فاز دوم اضافه نشده‌اند. شناسه و کلید امضا ثابت و versionCode برابر ۸ است.

## نسخهٔ ۱٫۸ — فاز چهارم: تنوع و پرداخت

- موانع تازهٔ «شکاف باز و بسته‌شونده» در نوع یک‌شکاف و دوشکاف، پس از چند سطح ظاهر می‌شوند. دامنهٔ آن‌ها محدود است تا در تنگ‌ترین حالت هم فضای امن حفظ شود. فلش‌ها نشان‌دهندهٔ شکاف لغزنده و دو خط نشانهٔ شکاف باز و بسته‌شونده هستند.
- سه افکت صوتی ارائه‌شده توسط کاربر به‌ترتیب برای انتخاب‌ها، باز شدن منوها و باز شدن ظاهرها به کار رفته‌اند؛ از همان کلید و بلندی جلوه‌های صوتی پیروی می‌کنند و موسیقی مستقل مانده است. افکت‌ها بر اساس نام فایل و کاربرد رابط انتخاب شده‌اند.
- هنگام رسیدن به رکورد بازکنندهٔ ظاهر، پیام نشان داده می‌شود. وضعیت نوع ردیف در شروع بازی تازه بازنشانی می‌شود. منو در صفحهٔ کوتاه و با متن بزرگ قابل پیمایش است و ناحیهٔ آیکون‌های گوشه را اشغال نمی‌کند.
- حالت مرحله‌ای و تمرینی اضافه نشده‌اند. محتوای صوتی آفلاین است و شناسه و کلید امضا تغییر نکرده‌اند (versionCode برابر ۹).

## نسخهٔ ۱٫۹ — حالت‌های تازه و دسترس‌پذیری

- حالت تمرین بی‌پایان است؛ برخورد مشخص می‌شود ولی باعث پایان بازی نمی‌شود. هر مانع در هر عبور یک بار برخورد گزارش می‌کند. برای خروج از دکمهٔ توقف استفاده کنید.
- پنج مرحله با هدف ۱۵، ۲۰، ۲۵، ۳۰ و ۳۵ ردیف وجود دارد. با تکمیل هر مرحله، مرحلهٔ بعد در دستگاه باز می‌شود. مرحله‌ها از سطح دشواری بالاتری شروع می‌شوند و درجهٔ سختی تنظیم‌شده نیز اعمال می‌شود.
- آمار و رکورد حالت بی‌پایان با تمرین و مراحل تغییر نمی‌کنند. داده‌های قبلی و شناسهٔ برنامه حفظ شده‌اند.
- محل برخورد با علامت مشخص می‌شود و در صفحهٔ پایان نام توپ برخوردکننده نمایش داده می‌شود.
- تنظیمات کاهش جلوه‌ها، ضخیم‌تر کردن نشانه‌های موانع متحرک و حساسیت حرکت (۵۰ تا ۱۵۰ درصد) ذخیره می‌شوند. حساسیت با منحنی حرکت تنظیم می‌شود و همچنان تمام عرض میدان قابل دستیابی است.
- این نسخه چالش آفلاین ندارد. برای اجرای آزمون‌های منطق از `sh tools/test_engine.sh` استفاده کنید. آزمون دستگاه واقعی و بررسی نصب روی نسخهٔ ۱٫۸ همچنان لازم است.
- versionCode به ۱۰ رسیده است. پروژه همچنان از کلید توسعهٔ نسخه‌های قبلی استفاده می‌کند؛ این کلید عمومی است و برای انتشار امن در فروشگاه مناسب نیست.

## نسخهٔ ۱٫۹٫۱ — نقشهٔ مراحل و جشن پیروزی

- منوی اصلی دو کارت بزرگ بی‌پایان و مرحله‌ای دارد؛ تمرین و تنظیمات زیر آن‌ها هستند.
- صفحهٔ مستقل مراحل همهٔ پنج مرحله را نشان می‌دهد؛ مراحل قفل‌شده انتخاب نمی‌شوند. با پیروزی هر مرحله، مرحلهٔ بعد باز می‌شود و بازشدن‌های نسخهٔ ۱٫۹ حفظ می‌شوند.
- پس از آخرین مانع، خط پایان شطرنجی وارد صفحه می‌شود؛ عبور از خط (نه فقط عبور از مانع آخر) مرحله را تمام می‌کند. برخورد قبل از عبور همچنان باعث باخت است و بعد از آخرین مانع، مانع تازه‌ای تولید نمی‌شود.
- پنجرهٔ پیروزی با عنوان رنگی، امتیاز، تعداد ردیف، زمان و درجهٔ سختی، دکمهٔ مرحلهٔ بعد و جشن کاغذرنگی نمایش داده می‌شود. گزینهٔ کاهش جلوه‌ها جشن متحرک را غیرفعال می‌کند.
- صفحهٔ نتیجه و انتخاب مرحله قابل پیمایش‌اند. آزمون‌های `tools/test_engine.sh` همهٔ پنج مرحله را در سه درجه تا خط پایان، ترتیب برخورد و بازشدن‌ها بررسی می‌کنند. تست تعاملی روی گوشی همچنان ضروری است.
- `versionCode` برابر ۱۱ است و شناسه و کلید توسعهٔ نسخهٔ ۱٫۹ حفظ شده‌اند.

## نسخهٔ ۱٫۹٫۲ — محیط‌های مرحله‌ای و قدرت‌ها

- مرحلهٔ اول ظاهر اصلی را حفظ می‌کند؛ مرحله‌های ۲ تا ۵ به‌ترتیب پس‌زمینه و موسیقی آفلاین بیابانی، شهری، فانتزی و فضایی دارند. تصویرها برای خوانایی تیره شده‌اند و لبه و علامت موانع در تم روز نیز روشن باقی می‌مانند.
- قدرت‌ها فقط در حالت مرحله‌ای هستند و هرکدام در هر بار بازی یک‌بار استفاده می‌شوند: سپر از مرحلهٔ ۱، کندی چهارثانیه‌ای از مرحلهٔ ۲، و راهنمای چهارثانیه‌ای از مرحلهٔ ۳. سپر یک برخورد را جذب می‌کند؛ همان مانع بلافاصله دوباره ضربه نمی‌زند، اما برخورد بعدی کشنده است.
- کندی، حرکت دیوار و حرکت شکاف‌ها را کند می‌کند، نه حرکت انگشت یا شمارش زمان. توقف بازی، زمان قدرت‌ها را نیز متوقف می‌کند. رکورد و آمار بی‌پایان همچنان جداست و به قدرت‌ها دسترسی ندارد.
- راهنما بر اساس فضای مشترک فعلی دو گوی و شعاع مرئی آن‌هاست؛ حرکت آیندهٔ مانع را پیش‌بینی نمی‌کند. نزدیک شدن مانع متحرک با خط روشن و ثابت مشخص می‌شود. صفحهٔ شکست برخورد هم‌زمان هر دو گوی را نیز مشخص می‌کند.
- آزمون‌ها رفتار یک‌بارمصرف، سپر و برخورد بعدی، توقّف تایمر، هندسهٔ برخورد، راهنمای موانع متحرک و حفظ قفل‌ها را بررسی می‌کنند. آزمون تعاملی و شنیداری روی دستگاه واقعی همچنان لازم است.
- نسخه با `versionCode` برابر ۱۲ و همان شناسه و امضای نسخهٔ پیشین ساخته می‌شود.

## نسخهٔ ۱٫۹٫۳ — گوی‌های قدرت و مراحل دشوارتر

- مراحل ۳، ۴ و ۵ نسبت به منحنی قبلی به‌ترتیب ۶٪، ۱۲٪ و ۱۸٪ سرعت بیشتری دارند. درجهٔ سختی انتخابی همچنان اثر دارد. محاسبهٔ فاصلهٔ قابل‌دستیابی بین موانع از سرعت جدید استفاده می‌کند.
- دکمه‌های قدرت حذف شده‌اند. در حالت مرحله‌ای گوی‌های کوچک زرد و اختیاری در فاصلهٔ میان موانع حرکت می‌کنند؛ برخورد هر یک از توپ‌ها با گوی آن را جمع می‌کند. در هر اجرا هر نوع موجود حداکثر یک‌بار ظاهر می‌شود و گرفتن آن اجباری نیست. گوی‌ها هندسهٔ موانع را تغییر نمی‌دهند.
- علامت دایره: سپر از مرحلهٔ ۱؛ ساعت‌شنی: کندی از مرحلهٔ ۲؛ لوزی: راهنمای مسیر فعلی از مرحلهٔ ۳. هر قدرت پس از جمع‌کردن سه ثانیه فعال می‌ماند و نشانگر دور آن کاهش می‌یابد. سپر در این سه ثانیه از برخوردها محافظت می‌کند. راهنما وضعیت فعلی شکاف را نشان می‌دهد و حرکت آینده را پیش‌بینی نمی‌کند.
- تایمرها هنگام توقف بازی متوقف می‌شوند. راهنما، سپر و کندی در حالت بی‌پایان موجود نیستند. رکوردهای قبلی و پیشرفت مراحل حفظ می‌شوند.
- آزمون واقعی مولد، هندسه و دسترسی میان ردیف‌ها را برای مراحل سریع‌تر، پنج سطح محاسباتی، سه درجه، پنج عرض و سه تراکم بررسی می‌کند؛ همچنین جمع‌آوری با هر توپ، عبور سریع، پایان زمان قدرت، برخورد هم‌زمان و بازنشانی بررسی می‌شوند. این آزمون‌ها جای آزمایش لمسی و بالانس با بازیکن واقعی را نمی‌گیرند.

## نسخهٔ ۱٫۹٫۴ — سکه و ظاهر

موسیقی منو با فایل جدید جایگزین شد. گوی‌های قدرت حذف شده‌اند؛ در حالت مرحله‌ای پس از هر چهار مانع سکه‌ای اختیاری ظاهر می‌شود. هر سکه هنگام جمع‌آوری فوراً در دستگاه ذخیره می‌شود، حتی در صورت باخت یا خروج. فروشگاه «ظاهر» در منوی اصلی چهار ترکیب رنگ دارد (رایگان، ۵، ۱۰ و ۱۵ سکه). خریدها و رنگ انتخابی ذخیره می‌شوند و انتخاب دوباره هزینه ندارد. طرح‌های قدیمی و رکوردها حفظ می‌شوند. صدای پیروزی و جمع‌آوری سکه از تنظیمات جلوه‌های صوتی پیروی می‌کنند؛ کاهش جلوه‌ها ذرات و تزئینات را محدود می‌کند. امضای نسخهٔ انتشار همان کلید توسعه‌ای قبلی و versionCode برابر ۱۴ است.

## نسخهٔ ۱٫۹٫۵ — فروشگاه و اقتصاد تازه

پنجاه ظاهر جدید به چهار ظاهر قبلی اضافه شد: ده حیوان در سه رنگ، شش توپ ورزشی در دو رنگ، و هشت ظاهر ویژهٔ ستاره‌ای دنباله‌دار. سکه‌های مراحل تازه در فاصله‌های تصادفی ۵ تا ۸ مانع ظاهر می‌شوند. در مرحله‌ای که قبلاً برنده شده‌اید سکه‌ای در مسیر نیست و فقط با پیروزی دوباره دقیقاً سه سکه جایزه می‌گیرید؛ شکست جایزه ندارد. برای هر خرید تازه، هم موجودی و هم رکورد حالت بی‌پایان در درجهٔ مشخص‌شده لازم است. خریدهای قبلی حتی پس از افزایش قیمت و شرط رکورد باقی می‌مانند. کاهش جلوه‌ها دنباله را پنهان می‌کند و شکل/برخورد توپ‌ها تغییر مکانیکی ندارد.

تصاویر حیوانات، توپ‌ها و نمادهای فروشگاه از پروژهٔ [Twemoji](https://github.com/twitter/twemoji) هستند؛ طرح‌ها تحت [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) و متعلق به Twitter, Inc. و مشارکت‌کنندگان Twemoji هستند. اندازه و نحوهٔ نمایش در بازی تغییر کرده است.

## نسخهٔ ۱٫۹٫۶ — پاداش‌ها و عملکرد

نمونه‌های تکراری نه حیوان از فروشگاه حذف شدند؛ نسخه‌های قبلاً خریداری‌شده همچنان قابل انتخاب‌اند. همهٔ قیمت‌ها به ۳۰٪ مقدار قبلی (گردشده به نزدیک‌ترین سکه) و شرط رکورد هشت ظاهر ویژه به ۸۰٪ کاهش یافته است. خرید تازه با تبریک، صدا و در صورت فعال بودن جلوه‌ها، کاغذ رنگی همراه است. انتخاب مجدد خرید قبلی جایزه و صدای خرید ندارد.

مرحلهٔ یک برای هر نصب یک بار ۲۰ سکه می‌دهد؛ باز کردن مرحلهٔ بعدی هم یک بار ۲۰ سکه جایزه دارد، بدون پرداخت مجدد برای مراحل قبلاً بازشده. در تکرار مرحلهٔ ۱ و ۲ با پیروزی به‌ترتیب ۵ و ۸ سکه دریافت می‌شود؛ در تکرار مراحل ۳ تا ۵ سکه‌های پراکنده با فاصلهٔ تصادفی ۹ تا ۱۲ مانع روی مسیر قرار دارند و پاداش ثابت پایان ندارند. در بازی نخست همان فاصلهٔ تصادفی ۵ تا ۸ مانع برقرار است. ذخیرهٔ پیشرفت و جایزهٔ باز شدن در یک عملیات مشترک انجام می‌شود.

رندر ردیف‌ها به مستطیل‌های برخورد تغییر کرده و تصویر توپ با شکل و نماد آن به صورت ازپیش‌آماده کشیده می‌شود تا محاسبهٔ مسیر و برش گرافیکی در هر فریم کاهش یابد. حرکت ردیف‌های ثابت دیگر محاسبهٔ سینوسی انجام نمی‌دهد. سنجش FPS و لمس روی گوشی واقعی همچنان ضروری است.

## نسخهٔ ۱٫۹٫۷ — راهنما و توقف

ظاهر آینه‌ها به طرح پیشین با گوشه‌ها و شکاف‌های گرد بازگشت. از ردیف نهم، در بازی مرحله‌ای و بی‌پایان هر شش ردیف یک درخشش کوچک روی قسمت جامد آینه نمایش داده می‌شود؛ در حالت کاهش جلوه‌ها پنهان است و هندسه و برخورد را تغییر نمی‌دهد. راهنمای بخش‌بندی‌شده در نصب تازه نمایش داده می‌شود و با دکمهٔ i همیشه قابل باز کردن است. رنگ قاب آیتم‌های خریداری‌شده سبز، انتخاب‌شده طلایی و خریداری‌نشده خاکستری است. در منوی توقف، تنظیم بلندی و خاموش/روشن صدا و موسیقی و کاهش جلوه‌ها اضافه شده است.

تصاویر آیتم‌ها اکنون PNGهای سه‌بعدی [Fluent UI Emoji](https://github.com/microsoft/fluentui-emoji) هستند، © Microsoft Corporation، مجوز MIT در `assets/licenses/fluentui-emoji-LICENSE.txt` همراه برنامه است. تصاویر قبلی Twemoji در نسخه‌های تاریخی استفاده می‌شدند.
