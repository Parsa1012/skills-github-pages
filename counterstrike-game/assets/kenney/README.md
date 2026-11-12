# دارایی‌های سه‌بعدی Kenney (آماده جایگزینی)

این پوشه برای نگهداری بسته‌های مدل سه‌بعدی **Kenney** (شخصیت‌ها و قطعات محیطی با فرمت `.glb` / `.gltf` / `.tscn`) طراحی شده است:

- `assets/kenney/characters/` ← مدل‌های شخصیت‌های Kenney (مثلاً `character.glb` یا زیرپوشه بسته کاراکتر)
- `assets/kenney/environment/` ← بلوک‌ها، دیوارها، موانع و کف‌پوش‌های محیطی Kenney

## نحوه اتصال خودکار در پروژه
- صحنه بازیکن `res://scenes/entities/player_character.tscn` دارای پارامتر `kenney_character_scene` است و به محض قرار گرفتن فایل‌های Kenney، می‌توان مدل Low-Poly فعلی را با یک مدل Kenney جایگزین کرد بدون اینکه کد حرکت، دوربین یا کنترل لمسی تغییری کند.
- محیط `res://scenes/maps/arena_sector_01.tscn` به صورت ماژولار (`Floor`, `Walls`, `Cover`, `Ramps`, `Zones`) ساخته شده و آماده جایگزینی مستقیم با قطعات `kenney/environment/` است.
