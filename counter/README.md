<h1 align="center">COUNTER</h1>
<p align="center"><b>Tactical top-down browser shooter</b><br />
Wave-based survival · pure HTML5 canvas · zero dependencies</p>

<p align="center">
  <a href="https://Parsa1012.github.io/skills-github-pages/counter/"><b>▶ PLAY ONLINE</b></a>
  <br /><sub>GitHub Pages must be enabled for the hosting repository (see below).</sub>
</p>

---

## What is this?

**COUNTER** is a small, fast Counter-Strike–inspired shooter that runs entirely in the
browser. You are the last counter-terrorist in a desert compound: clear each wave of
hostiles, use crates for cover, keep your magazine loaded and stay alive as long as you can.

Everything is vanilla — no frameworks, no build step, no external assets beyond the
menu/UI sounds. Just open `index.html` and play.

## Features

- **Top-down tactical combat** — mouse aim, hitscan-speed tracers, recoil, muzzle flash,
  shell casings, blood, sparks and screen shake.
- **Two weapons** — AK-12 rifle and USP-S pistol, each with its own magazine and reserve ammo.
- **Enemy AI** — hostiles chase, strafe, keep their distance, break line of sight,
  fire in bursts and get more accurate in later rounds.
- **Endless rounds** — every cleared wave is bigger, faster and more accurate. Score,
  round and personal best are tracked locally.
- **Cover matters** — bullets die on crates and walls, so peeking and repositioning works.
- **Pickups** — green crates restore health, yellow crates restock ammo.
- **Synthesised audio** — gunfire, impacts, reloads and stings are generated with
  WebAudio; menu music and UI clicks use the mp3 files in `assets/`.
- **Touch controls** — virtual stick, FIRE / RELOAD / SWAP buttons on mobile.
- **No dependencies** — 100% static files, deployable on any file host.

## Controls

| Action | Keyboard / Mouse | Touch |
| --- | --- | --- |
| Move | `W` `A` `S` `D` / arrows | left stick |
| Walk (slower) | `Shift` | — |
| Aim | mouse | drag on the right side |
| Fire | left click / hold | FIRE button |
| Reload | `R` | RELOAD button |
| Swap weapon | `1` `2` `Q` | SWAP button |
| Pause | `Esc` / `P` | — |

## Run locally

Because the game loads audio files, serve the folder over HTTP instead of opening the
file directly:

```bash
# any static server works
python3 -m http.server 8000
# then open http://localhost:8000
```

## Deploy on GitHub Pages

The repository is already set up for Pages:

1. **Settings → Pages**
2. **Source:** *Deploy from a branch*
3. **Branch:** `main` · folder `/ (root)`
4. Save — the game is live at `https://Parsa1012.github.io/skills-github-pages/counter/`

`.nojekyll` is included so static files are served as-is.

### Ship it as a standalone repository

If you want the game at its own URL (`https://Parsa1012.github.io/counter/`), create an
empty public repo named `counter` on GitHub and push this folder:

```bash
# from inside the counter/ folder
git init -b main
git add .
git commit -m "COUNTER: tactical top-down browser shooter"
git remote add origin https://github.com/Parsa1012/counter.git
git push -u origin main
```

Then enable **Settings → Pages → Deploy from a branch → main → / (root)**.

## Project structure

```
counter/
├── index.html        # markup, HUD, menus
├── css/style.css     # all styling (responsive, mobile controls)
├── js/audio.js       # WebAudio SFX engine + UI/menu sound
├── js/game.js        # game loop, map, enemies, bullets, camera, rendering
├── assets/           # menu music + UI clicks
└── .nojekyll
```

### Tuning the game

Most of the feel lives in a few constants inside `js/game.js`:

- `WEAPONS` — damage, fire rate, spread, reload time, magazine size.
- `player` — health, armour, movement speed.
- `startRound()` — enemies per wave and how many can be alive at once.
- `MAP` — the arena layout (`[x, y, width, height, "wall" | "crate"]`).

## فارسی

**کانتر** یک بازی تیراندازی تاپ‌داون در مرورگر است؛ الهام‌گرفته از کانتر استرایک.
با ماوس نشانه برو، با `WASD` حرکت کن، با کلیک شلیک کن و با `R` خشاب را پر کن.
هر مرحله موج بزرگ‌تری از دشمن‌ها می‌آید؛ جعبه‌ها و دیوارها جلوی گلوله را می‌گیرند،
پس از کاور استفاده کن.

برای اجرا محلی:

```bash
python3 -m http.server 8000
# http://localhost:8000
```

نسخهٔ آنلاین: <https://Parsa1012.github.io/counter/>

## License

MIT — see [LICENSE](LICENSE). Menu music and UI sounds were provided by the repository
owner and are not covered by the MIT license.
