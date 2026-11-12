# Counterstrike Arena (Offline 2.5D Low-Poly Arcade Arena)

پروژه مستقل و آفلاین بازی **2.5D Low-Poly** با موتور **Godot 4** برای پلتفرم **Android** و بهینه‌سازی‌شده برای **Samsung Galaxy A32**.

> **وضعیت فعلی: فاز ۱ — اسکلت پروژه، زیرساخت آفلاین و صحنه تست دوربین سبک BombSquad**

---

## ویژگی‌های کلیدی معماری (فاز ۱)

- **استقلال کامل در پوشه `counterstrike-game/`:** بدون وابستگی به اینترنت، API خارجی یا فایل‌های بیرون پوشه پروژه در زمان اجرا.
- **رابط کاربری کامل فارسی (RTL) و فونت استاندارد:** مجهز به فونت آزاد **Vazirmatn** (`assets/fonts/Vazirmatn-Regular.ttf` و `Vazirmatn-Bold.ttf`) و تم پیش‌فرض فارسی (`assets/ui/persian_theme.tres`).
- **صداگذاری و موسیقی منوی اصلی:** استفاده از فایل‌های صوتی داخلی (`assets/audio/main_menu.mp3`، `ui_click.mp3`، `ui_menu.mp3`، `ui_pop.mp3`) با مدیریت کامل قطع/وصل در منوی تنظیمات.
- **رندرر موبایل:** `GL Compatibility` (`gl_compatibility`) برای پایداری بالا روی پردازنده گرافیکی **Mali-G52 MC2** (Galaxy A32).
- **هدف نرخ فریم:** پیش‌فرض **30 FPS پایدار** (`application/run/max_fps=30`) همراه با گزینه بررسی **60 FPS** در منوی تنظیمات و صحنه تست.
- **طراحی گیم‌پلی آرکید و خیالی:**
  - رقابت تیمی با **ربات‌های بازی آفلاین** (`ArenaBotProfile`)
  - **پرتابه‌های انرژی تخیلی** (`EnergyBlasterData`)
  - **موانع، کاورها و مناطق قابل تصرف** (`ArenaModeConfig` — Zone Control & Score Rush)
  - بدون شبیه‌سازی سلاح‌ها یا مواد انفجاری واقعی.

---

## طراحی دوربین سبک BombSquad (Angled Top-Down / Bird's-Eye)

دوربین از طریق `ArenaCameraRig` (`scenes/camera/arena_camera_rig.tscn`) پیاده‌سازی شده است:
- **نمای سه‌بعدی از بالا و مورب:** زاویه پیش‌فرض **`57.5°`** (در بازه `55°–60°`) و فاصله **`19.5 m`** با `FOV = 44°`.
- **بدون چرخش آزاد ۳۶۰ درجه:** محور افقی (Yaw) قفل است تا کنترل لمسی دو‌جوی‌استیک و خوانایی نقشه روی موبایل کاملاً یکنواخت بماند.
- **تعقیب نرم بازیکن (Smooth Follow):** با میرایی مستقل از نرخ فریم و محدودسازی مرزهای زمین (`use_arena_bounds`).
- **قابل تنظیم از Project Settings در Godot 4:**
  بخش `[arena_camera]` در `project.godot`:
  - `arena_camera/pitch_degrees` (`57.5`)
  - `arena_camera/yaw_degrees` (`0.0`)
  - `arena_camera/distance` (`19.5`)
  - `arena_camera/fov_degrees` (`44.0`)
  - `arena_camera/follow_smoothness` (`6.5`)
  - `arena_camera/look_ahead_distance` (`1.25`)
  - `arena_camera/allow_free_rotation` (`false`)

---

## ساختار پوشه‌ها

```text
counterstrike-game/
├── project.godot                     # فایل اصلی پروژه Godot 4 (Compatibility + 30 FPS + arena_camera)
├── export_presets.cfg                # تنظیمات خروجی Android (arm64-v8a، آفلاین بدون دسترسی اینترنت)
├── icon.svg                          # آیکون برداری بازی
├── .gitignore                        # مسدودسازی .godot/، builds/، *.apk و کلیدهای امضا
├── assets/                           # دارایی‌های آینده (فاز ۲ تا ۶)
├── data/
│   ├── camera/default_bombsquad_camera.tres
│   ├── bots/  blasters/  maps/  modes/
├── scenes/
│   ├── main/boot.tscn                # نقطه شروع بازی
│   ├── ui/main_menu.tscn             # منوی اصلی و تنظیمات FPS/کیفیت (با Safe Area موبایل)
│   ├── camera/arena_camera_rig.tscn  # ریگ دوربین 2.5D سبک BombSquad
│   └── test/camera_angle_test.tscn   # صحنه آزمایشی فاز ۱ برای بررسی زاویه، فاصله و کارایی
└── scripts/
    ├── autoload/                     # EventBus, SaveManager, AudioManager, PoolManager, GameManager
    ├── camera/                       # ArenaCameraRig
    ├── core/                         # CameraConfig, EnergyBlasterData, ArenaBotProfile, ArenaModeConfig
    ├── test/                         # CameraAngleTest, PatrolProxy
    └── ui/                           # BootScreen, MainMenu
```

---

## نحوه باز کردن و آزمایش در Godot 4

1. **Godot 4.3+** را باز کنید و گزینه **Import** را بزنید.
2. فایل `counterstrike-game/project.godot` را انتخاب کنید.
3. پروژه را اجرا کنید (**F5**) یا مستقیم صحنه تست را باز کنید:
   - `res://scenes/main/boot.tscn` (منوی اصلی -> دکمه **Launch Camera Angle Test**)
   - یا مستقیماً `res://scenes/test/camera_angle_test.tscn`
4. در صحنه تست می‌توانید زوایای `55°`، `57.5°`، `60°`، فاصله دوربین، وضعیت `30 / 60 FPS` و تعداد `Draw Calls / Primitives` را به صورت زنده بررسی کنید.
5. برای خروجی گرفتن APK روی Galaxy A32، پس از نصب Android Export Templates در Godot 4 از Preset آماده **`Android`** (`arm64-v8a`) استفاده کنید. (خروجی‌ها در پوشه `builds/` ساخته شده و وارد Git نمی‌شوند.)

---

## نقشه راه مراحل بعدی

- **فاز ۲:** کنترل لمسی دوتایی (Twin-Stick) و کنترلر حرکت کاراکتر 2.5D روی زمین با برخورد فیزیکی.
- **فاز ۳:** سیستم پرتابه‌های انرژی تخیلی، Object Pooling و سپر/انرژی کاراکترها.
- **فاز ۴:** نقشه تاکتیکی اول + NavMesh + هوش مصنوعی آفلاین ربات‌های بازی.
- **فاز ۵:** چرخه کامل راندها، تصرف مناطق (Zone A / Zone B)، امتیازدهی و فروشگاه ارتقای آرکید.
- **فاز ۶:** افکت‌های صوتی مستقل و پروفایلینگ نهایی روی Samsung Galaxy A32.
