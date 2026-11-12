/* ============================================================
   COUNTER — Tactical Browser Ops
   A compact top-down shooter: move, aim, shoot, reload, survive.
   Plain canvas 2D + WebAudio, no dependencies.
   ============================================================ */

(function () {
  'use strict';

  /* ------------------------------------------------------------
     helpers
     ------------------------------------------------------------ */
  const TAU = Math.PI * 2;
  const rand = (a, b) => a + Math.random() * (b - a);
  const randInt = (a, b) => Math.floor(rand(a, b + 1));
  const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
  const lerp = (a, b, t) => a + (b - a) * t;
  const dist = (ax, ay, bx, by) => Math.hypot(bx - ax, by - ay);
  const pick = (arr) => arr[randInt(0, arr.length - 1)];

  /* ------------------------------------------------------------
     DOM
     ------------------------------------------------------------ */
  const $ = (id) => document.getElementById(id);
  const canvas = $('game');
  const ctx = canvas.getContext('2d');
  const mini = $('minimap');
  const mctx = mini.getContext('2d');

  const ui = {
    hud: $('hud'),
    menu: $('menu'),
    how: $('howScreen'),
    pause: $('pauseScreen'),
    over: $('overScreen'),
    banner: $('banner'),
    bannerRound: $('bannerRound'),
    bannerMsg: $('bannerMsg'),
    roundNum: $('roundNum'),
    enemiesLeft: $('enemiesLeft'),
    kills: $('kills'),
    score: $('score'),
    best: $('best'),
    healthBar: $('healthBar'),
    healthNum: $('healthNum'),
    armorBar: $('armorBar'),
    armorNum: $('armorNum'),
    weaponName: $('weaponName'),
    mag: $('mag'),
    reserve: $('reserve'),
    reloadHint: $('reloadHint'),
    reloadFill: $('reloadFill'),
    killfeed: $('killfeed'),
    damage: $('damageVignette'),
    hitMarker: $('hitMarker'),
    menuBest: $('menuBest'),
    menuRound: $('menuRound'),
    finalScore: $('finalScore'),
    finalKills: $('finalKills'),
    finalRound: $('finalRound'),
    recordNote: $('recordNote'),
    soundBtn: $('soundBtn'),
    touchUI: $('touchUI'),
    stickBase: $('stickBase'),
    stickKnob: $('stickKnob'),
    fireBtn: $('fireBtn'),
    reloadBtn: $('reloadBtn'),
    switchBtn: $('switchBtn')
  };

  /* ------------------------------------------------------------
     world / camera
     ------------------------------------------------------------ */
  const WORLD = { w: 2200, h: 1500 };
  const VIEW = { w: 1280, h: 720 };
  const cam = { x: WORLD.w / 2, y: WORLD.h / 2, shake: 0, ox: 0, oy: 0 };

  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    VIEW.w = window.innerWidth;
    VIEW.h = window.innerHeight;
    canvas.width = Math.round(VIEW.w * dpr);
    canvas.height = Math.round(VIEW.h * dpr);
    canvas.style.width = VIEW.w + 'px';
    canvas.style.height = VIEW.h + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.imageSmoothingEnabled = true;
    clampCamera(true);
  }
  window.addEventListener('resize', resize);

  function clampCamera(instant) {
    const halfW = VIEW.w / 2;
    const halfH = VIEW.h / 2;
    let tx = cam.x;
    let ty = cam.y;
    tx = WORLD.w <= VIEW.w ? WORLD.w / 2 : clamp(tx, halfW, WORLD.w - halfW);
    ty = WORLD.h <= VIEW.h ? WORLD.h / 2 : clamp(ty, halfH, WORLD.h - halfH);
    cam.x = tx;
    cam.y = ty;
    return { x: tx, y: ty };
  }

  const toWorld = (sx, sy) => ({ x: sx - VIEW.w / 2 + cam.x, y: sy - VIEW.h / 2 + cam.y });

  function onScreen(x, y) {
    const sx = x - cam.x + VIEW.w / 2;
    const sy = y - cam.y + VIEW.h / 2;
    return sx > -60 && sy > -60 && sx < VIEW.w + 60 && sy < VIEW.h + 60;
  }

  /* ------------------------------------------------------------
     map
     ------------------------------------------------------------ */
  // [x, y, w, h, kind]  kind: wall | crate
  const MAP = [
    // four corner compounds
    [300, 250, 400, 44, 'wall'],
    [300, 250, 44, 250, 'wall'],
    [1500, 250, 400, 44, 'wall'],
    [1856, 250, 44, 250, 'wall'],
    [300, 1206, 400, 44, 'wall'],
    [300, 990, 44, 260, 'wall'],
    [1500, 1206, 400, 44, 'wall'],
    [1856, 990, 44, 260, 'wall'],

    // central bunker
    [980, 600, 240, 40, 'wall'],
    [980, 860, 240, 40, 'wall'],
    [980, 600, 40, 300, 'wall'],
    [1180, 600, 40, 300, 'wall'],

    // pillars
    [560, 700, 90, 90, 'wall'],
    [1550, 700, 90, 90, 'wall'],
    [1060, 300, 80, 80, 'wall'],
    [1060, 1120, 80, 80, 'wall'],

    // crates
    [720, 420, 62, 62, 'crate'],
    [780, 470, 62, 62, 'crate'],
    [1420, 420, 62, 62, 'crate'],
    [1360, 470, 62, 62, 'crate'],
    [700, 960, 62, 62, 'crate'],
    [1460, 960, 62, 62, 'crate'],
    [880, 1080, 62, 62, 'crate'],
    [1300, 1080, 62, 62, 'crate'],
    [880, 340, 62, 62, 'crate'],
    [1300, 340, 62, 62, 'crate'],
    [200, 620, 62, 62, 'crate'],
    [1940, 620, 62, 62, 'crate'],
    [200, 860, 62, 62, 'crate'],
    [1940, 860, 62, 62, 'crate'],
    [1000, 200, 60, 60, 'crate'],
    [1140, 1240, 60, 60, 'crate']
  ];

  const walls = MAP.map((m) => ({ x: m[0], y: m[1], w: m[2], h: m[3], kind: m[4] }));

  const SPAWNS = [
    { x: 180, y: 180 }, { x: 2020, y: 180 },
    { x: 180, y: 1320 }, { x: 2020, y: 1320 },
    { x: 1100, y: 120 }, { x: 1100, y: 1380 },
    { x: 60, y: 750 }, { x: 2140, y: 750 }
  ];

  // deterministic floor speckle field
  const speckles = [];
  (function buildSpeckles() {
    let seed = 1337;
    const rnd = () => {
      seed = (seed * 16807) % 2147483647;
      return seed / 2147483647;
    };
    for (let i = 0; i < 900; i++) {
      speckles.push({
        x: rnd() * WORLD.w,
        y: rnd() * WORLD.h,
        r: 1 + rnd() * 5,
        a: 0.02 + rnd() * 0.06
      });
    }
  })();

  /* ------------------------------------------------------------
     collision helpers
     ------------------------------------------------------------ */
  function resolveCircle(ent) {
    for (let i = 0; i < walls.length; i++) {
      const w = walls[i];
      const nx = clamp(ent.x, w.x, w.x + w.w);
      const ny = clamp(ent.y, w.y, w.y + w.h);
      let dx = ent.x - nx;
      let dy = ent.y - ny;
      let d2 = dx * dx + dy * dy;
      if (d2 < ent.r * ent.r) {
        if (d2 > 0.0001) {
          const d = Math.sqrt(d2);
          ent.x = nx + (dx / d) * ent.r;
          ent.y = ny + (dy / d) * ent.r;
        } else {
          // centre inside the box — push out on the shallowest axis
          const left = ent.x - w.x;
          const right = w.x + w.w - ent.x;
          const top = ent.y - w.y;
          const bottom = w.y + w.h - ent.y;
          const m = Math.min(left, right, top, bottom);
          if (m === left) ent.x = w.x - ent.r;
          else if (m === right) ent.x = w.x + w.w + ent.r;
          else if (m === top) ent.y = w.y - ent.r;
          else ent.y = w.y + w.h + ent.r;
        }
      }
    }
    ent.x = clamp(ent.x, ent.r + 24, WORLD.w - ent.r - 24);
    ent.y = clamp(ent.y, ent.r + 24, WORLD.h - ent.r - 24);
  }

  function moveEntity(ent, dx, dy) {
    const px = ent.x;
    const py = ent.y;
    ent.x += dx;
    ent.y += dy;
    resolveCircle(ent);
    const moved = (ent.x - px) * (ent.x - px) + (ent.y - py) * (ent.y - py);
    const wanted = dx * dx + dy * dy;
    return wanted > 0.5 && moved < wanted * 0.12; // true when blocked
  }

  // Liang–Barsky: does the segment hit the rect? returns entry t (0..1) or -1
  function segmentRect(x1, y1, x2, y2, r) {
    let t0 = 0;
    let t1 = 1;
    const dx = x2 - x1;
    const dy = y2 - y1;
    const p = [-dx, dx, -dy, dy];
    const q = [x1 - r.x, r.x + r.w - x1, y1 - r.y, r.y + r.h - y1];
    for (let i = 0; i < 4; i++) {
      if (p[i] === 0) {
        if (q[i] < 0) return -1;
      } else {
        const t = q[i] / p[i];
        if (p[i] < 0) {
          if (t > t1) return -1;
          if (t > t0) t0 = t;
        } else {
          if (t < t0) return -1;
          if (t < t1) t1 = t;
        }
      }
    }
    return t0;
  }

  function wallHit(x1, y1, x2, y2) {
    let best = -1;
    for (let i = 0; i < walls.length; i++) {
      const t = segmentRect(x1, y1, x2, y2, walls[i]);
      if (t >= 0 && (best < 0 || t < best)) best = t;
    }
    return best;
  }

  function hasLOS(x1, y1, x2, y2) {
    return wallHit(x1, y1, x2, y2) < 0;
  }

  /* ------------------------------------------------------------
     state
     ------------------------------------------------------------ */
  const STATE = { MENU: 'menu', PLAY: 'play', PAUSE: 'pause', OVER: 'over' };
  let state = STATE.MENU;

  const WEAPONS = {
    rifle: {
      name: 'AK-12 RIFLE', magSize: 30, damage: 27, rate: 0.098, spread: 0.035,
      reload: 1.9, speed: 2050, auto: true, reserveStart: 120, kick: 3.4, sound: 'rifle'
    },
    pistol: {
      name: 'USP-S PISTOL', magSize: 12, damage: 26, rate: 0.19, spread: 0.028,
      reload: 1.35, speed: 1800, auto: false, reserveStart: 60, kick: 2.2, sound: 'pistol'
    }
  };

  const player = {
    x: 1100, y: 1020, r: 15, angle: -Math.PI / 2,
    hp: 100, maxHp: 100, armor: 100,
    speed: 235, walkSpeed: 130,
    slot: 'rifle',
    reloading: 0, reloadTotal: 0,
    fireCd: 0, recoil: 0, muzzle: 0, hurtFlash: 0,
    alive: true,
    ammo: {
      rifle: { mag: 30, reserve: 120 },
      pistol: { mag: 12, reserve: 60 }
    }
  };

  const game = {
    round: 1,
    score: 0,
    kills: 0,
    pending: 0,
    spawnCd: 0,
    maxAlive: 4,
    roundEnding: false,
    time: 0,
    best: Number(localStorage.getItem('counter.best') || 0),
    bestRound: Number(localStorage.getItem('counter.round') || 0)
  };

  const enemies = [];
  const bullets = [];
  const particles = [];
  const casings = [];
  const pickups = [];
  const timers = [];
  const floats = []; // floating score texts

  function later(seconds, fn) {
    timers.push({ t: seconds, fn: fn });
  }

  /* ------------------------------------------------------------
     input
     ------------------------------------------------------------ */
  const keys = Object.create(null);
  const mouse = { x: VIEW.w / 2, y: VIEW.h / 2, down: false, pressed: false };
  const stick = { active: false, dx: 0, dy: 0, id: null };
  let touchAim = null;

  window.addEventListener('keydown', (e) => {
    const k = e.key.toLowerCase();
    if ([' ', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright'].includes(k)) e.preventDefault();
    keys[k] = true;

    if (k === 'escape' || k === 'p') {
      if (state === STATE.PLAY) pauseGame();
      else if (state === STATE.PAUSE) resumeGame();
    }
    if (state === STATE.PLAY) {
      if (k === 'r') startReload();
      if (k === '1') switchWeapon('rifle');
      if (k === '2') switchWeapon('pistol');
      if (k === 'q') switchWeapon(player.slot === 'rifle' ? 'pistol' : 'rifle');
    }
    if (state === STATE.MENU && k === 'enter') startGame();
  });
  window.addEventListener('keyup', (e) => { keys[e.key.toLowerCase()] = false; });
  document.addEventListener('visibilitychange', () => {
    if (document.hidden && state === STATE.PLAY) pauseGame();
  });

  window.addEventListener('blur', () => {
    for (const k in keys) keys[k] = false;
    mouse.down = false;
    if (state === STATE.PLAY) pauseGame();
  });

  window.addEventListener('mousemove', (e) => {
    mouse.x = e.clientX;
    mouse.y = e.clientY;
  });

  window.addEventListener('mousedown', (e) => {
    if (e.button !== 0) return;
    if (state !== STATE.PLAY) return;
    mouse.down = true;
    mouse.pressed = true;
  });
  window.addEventListener('mouseup', (e) => {
    if (e.button !== 0) return;
    mouse.down = false;
  });
  window.addEventListener('contextmenu', (e) => {
    if (state === STATE.PLAY) e.preventDefault();
  });

  // touch aiming / firing on the canvas
  canvas.addEventListener('pointerdown', (e) => {
    if (e.pointerType === 'mouse' || state !== STATE.PLAY) return;
    if (e.clientX < VIEW.w * 0.42) return; // left side is the movement stick
    touchAim = { x: e.clientX, y: e.clientY, id: e.pointerId };
    mouse.down = true;
    mouse.pressed = true;
    mouse.x = e.clientX;
    mouse.y = e.clientY;
  });
  canvas.addEventListener('pointermove', (e) => {
    if (!touchAim || e.pointerId !== touchAim.id) return;
    touchAim.x = e.clientX;
    touchAim.y = e.clientY;
    mouse.x = e.clientX;
    mouse.y = e.clientY;
  });
  const endTouchAim = (e) => {
    if (!touchAim || e.pointerId !== touchAim.id) return;
    touchAim = null;
    mouse.down = false;
  };
  canvas.addEventListener('pointerup', endTouchAim);
  canvas.addEventListener('pointercancel', endTouchAim);

  /* ------------------------------------------------------------
     touch stick + buttons
     ------------------------------------------------------------ */
  const isTouch = ('ontouchstart' in window) || navigator.maxTouchPoints > 0;

  function setupTouch() {
    const base = ui.stickBase;
    const knob = ui.stickKnob;
    const maxR = 40;

    const updateStick = (e) => {
      const rect = base.getBoundingClientRect();
      const cx = rect.left + rect.width / 2;
      const cy = rect.top + rect.height / 2;
      let dx = e.clientX - cx;
      let dy = e.clientY - cy;
      const d = Math.hypot(dx, dy) || 1;
      const clamped = Math.min(d, maxR);
      dx = (dx / d) * clamped;
      dy = (dy / d) * clamped;
      knob.style.transform = 'translate(' + dx + 'px,' + dy + 'px)';
      stick.dx = dx / maxR;
      stick.dy = dy / maxR;
    };

    base.addEventListener('pointerdown', (e) => {
      e.preventDefault();
      stick.active = true;
      stick.id = e.pointerId;
      base.setPointerCapture(e.pointerId);
      updateStick(e);
    });
    base.addEventListener('pointermove', (e) => {
      if (!stick.active || e.pointerId !== stick.id) return;
      updateStick(e);
    });
    const release = (e) => {
      if (e.pointerId !== stick.id) return;
      stick.active = false;
      stick.dx = 0;
      stick.dy = 0;
      knob.style.transform = 'translate(0,0)';
    };
    base.addEventListener('pointerup', release);
    base.addEventListener('pointercancel', release);

    const hold = (btn, on, off) => {
      btn.addEventListener('pointerdown', (e) => { e.preventDefault(); on(); });
      btn.addEventListener('pointerup', (e) => { e.preventDefault(); off(); });
      btn.addEventListener('pointercancel', off);
      btn.addEventListener('pointerleave', off);
    };
    hold(ui.fireBtn, () => { mouse.down = true; mouse.pressed = true; }, () => { mouse.down = false; });
    ui.reloadBtn.addEventListener('click', startReload);
    ui.switchBtn.addEventListener('click', () => {
      switchWeapon(player.slot === 'rifle' ? 'pistol' : 'rifle');
    });
  }

  /* ------------------------------------------------------------
     HUD helpers
     ------------------------------------------------------------ */
  function setText(node, value) {
    if (node && node.textContent !== String(value)) node.textContent = value;
  }

  function hudUpdate() {
    const w = WEAPONS[player.slot];
    const a = player.ammo[player.slot];
    setText(ui.healthNum, Math.max(0, Math.round(player.hp)));
    setText(ui.armorNum, Math.max(0, Math.round(player.armor)));
    ui.healthBar.style.width = clamp((player.hp / player.maxHp) * 100, 0, 100) + '%';
    ui.healthBar.classList.toggle('low', player.hp <= 35);
    ui.armorBar.style.width = clamp((player.armor / 100) * 100, 0, 100) + '%';
    setText(ui.weaponName, w.name);
    setText(ui.mag, a.mag);
    setText(ui.reserve, a.reserve);
    setText(ui.kills, game.kills);
    setText(ui.score, game.score);
    setText(ui.best, game.best);
    setText(ui.roundNum, 'ROUND ' + game.round);
    const left = enemies.length + game.pending;
    setText(ui.enemiesLeft, left + ' LEFT');

    if (player.reloading > 0) {
      ui.reloadHint.classList.remove('hidden');
      ui.reloadFill.style.width =
        (100 * (1 - player.reloading / player.reloadTotal)).toFixed(0) + '%';
    } else {
      ui.reloadHint.classList.add('hidden');
    }
  }

  function killFeed(text, headshot) {
    const item = document.createElement('div');
    item.className = 'feed-item' + (headshot ? ' head' : '');
    item.innerHTML = text;
    ui.killfeed.appendChild(item);
    while (ui.killfeed.children.length > 5) ui.killfeed.removeChild(ui.killfeed.firstChild);
    setTimeout(() => item.remove(), 4200);
  }

  function flashDamage() {
    ui.damage.classList.add('on');
    setTimeout(() => ui.damage.classList.remove('on'), 120);
  }

  function hitMarker(kill) {
    ui.hitMarker.classList.remove('show', 'kill');
    void ui.hitMarker.offsetWidth;
    if (kill) ui.hitMarker.classList.add('kill');
    ui.hitMarker.classList.add('show');
  }

  function showBanner(round, msg) {
    ui.bannerRound.textContent = typeof round === 'number' ? round : '';
    ui.bannerMsg.textContent = msg || '';
    ui.banner.classList.remove('hidden');
    ui.banner.style.animation = 'none';
    void ui.banner.offsetWidth;
    ui.banner.style.animation = '';
    clearTimeout(showBanner._t);
    showBanner._t = setTimeout(() => ui.banner.classList.add('hidden'), 2000);
  }

  /* ------------------------------------------------------------
     fx
     ------------------------------------------------------------ */
  function spawnParticles(x, y, count, opts) {
    for (let i = 0; i < count; i++) {
      const a = rand(0, TAU);
      const sp = rand(opts.min || 30, opts.max || 220);
      particles.push({
        x: x, y: y,
        vx: Math.cos(a) * sp,
        vy: Math.sin(a) * sp,
        life: rand(opts.lifeMin || 0.2, opts.lifeMax || 0.6),
        maxLife: 0.6,
        size: rand(opts.sizeMin || 1.5, opts.sizeMax || 3.6),
        color: opts.colors ? pick(opts.colors) : '#ffcf6b',
        drag: opts.drag || 3.4,
        glow: !!opts.glow
      });
      particles[particles.length - 1].maxLife = particles[particles.length - 1].life;
    }
  }

  function impact(x, y, angle) {
    spawnParticles(x, y, 7, {
      colors: ['#ffd479', '#ff9b3d', '#d7d2c4'],
      min: 40, max: 190, lifeMin: 0.15, lifeMax: 0.4, sizeMin: 1, sizeMax: 2.6, glow: true
    });
    for (let i = 0; i < 3; i++) {
      particles.push({
        x: x, y: y, vx: Math.cos(angle + rand(-0.6, 0.6)) * rand(20, 80),
        vy: Math.sin(angle + rand(-0.6, 0.6)) * rand(20, 80),
        life: rand(0.25, 0.5), maxLife: 0.5, size: rand(3, 7),
        color: 'rgba(190,186,175,0.25)', drag: 2, glow: false
      });
    }
    if (onScreen(x, y)) Sound.hitWall();
  }

  function blood(x, y, dir) {
    spawnParticles(x, y, 11, {
      colors: ['#b81f2b', '#8c1420', '#e0454f'],
      min: 30, max: 250, lifeMin: 0.2, lifeMax: 0.65, sizeMin: 1.4, sizeMax: 3.4, drag: 4.2
    });
    for (let i = 0; i < 4; i++) {
      particles.push({
        x: x, y: y,
        vx: Math.cos(dir + rand(-0.4, 0.4)) * rand(40, 130),
        vy: Math.sin(dir + rand(-0.4, 0.4)) * rand(40, 130),
        life: rand(0.3, 0.6), maxLife: 0.6, size: rand(2, 4),
        color: '#7d1220', drag: 5, glow: false
      });
    }
  }

  function casing(x, y, angle) {
    casings.push({
      x: x, y: y,
      vx: Math.cos(angle + Math.PI / 2) * rand(50, 110) + rand(-20, 20),
      vy: Math.sin(angle + Math.PI / 2) * rand(50, 110) + rand(-20, 20),
      rot: rand(0, TAU), vr: rand(-14, 14), life: rand(2.4, 3.4)
    });
  }

  /* ------------------------------------------------------------
     weapons
     ------------------------------------------------------------ */
  function startReload() {
    if (state !== STATE.PLAY || !player.alive) return;
    const w = WEAPONS[player.slot];
    const a = player.ammo[player.slot];
    if (player.reloading > 0 || a.mag >= w.magSize || a.reserve <= 0) return;
    player.reloading = w.reload;
    player.reloadTotal = w.reload;
    Sound.reload();
  }

  function finishReload() {
    const w = WEAPONS[player.slot];
    const a = player.ammo[player.slot];
    const need = w.magSize - a.mag;
    const take = Math.min(need, a.reserve);
    a.mag += take;
    a.reserve -= take;
  }

  function switchWeapon(slot) {
    if (state !== STATE.PLAY || !player.alive || slot === player.slot) return;
    player.slot = slot;
    player.reloading = 0;
    Sound.ui('click');
  }

  function shoot() {
    const w = WEAPONS[player.slot];
    const a = player.ammo[player.slot];

    if (a.mag <= 0) {
      Sound.dryFire();
      player.fireCd = 0.22;
      startReload();
      return;
    }

    const spread = w.spread + player.recoil * 0.02 + (moving() ? 0.02 : 0);
    const angle = player.angle + rand(-spread, spread);
    const muzzleX = player.x + Math.cos(player.angle) * 24;
    const muzzleY = player.y + Math.sin(player.angle) * 24;

    bullets.push({
      x: muzzleX, y: muzzleY, px: muzzleX, py: muzzleY,
      vx: Math.cos(angle) * w.speed,
      vy: Math.sin(angle) * w.speed,
      damage: w.damage, friendly: true, life: 1.5
    });

    a.mag--;
    player.fireCd = w.rate;
    player.recoil = Math.min(6, player.recoil + 1.15);
    player.muzzle = 0.055;
    cam.shake = Math.min(9, cam.shake + 1.3);
    Sound.shoot(w.sound);
    casing(muzzleX, muzzleY, angle);

    spawnParticles(muzzleX, muzzleY, 4, {
      colors: ['#ffe9a3', '#ffb347'], min: 90, max: 260,
      lifeMin: 0.08, lifeMax: 0.2, sizeMin: 1, sizeMax: 2.4, glow: true
    });

    if (a.mag === 0) later(0.18, () => { if (state === STATE.PLAY) startReload(); });
  }

  function moving() {
    return !!(keys.w || keys.a || keys.s || keys.d || keys.arrowup ||
      keys.arrowdown || keys.arrowleft || keys.arrowright ||
      Math.abs(stick.dx) > 0.15 || Math.abs(stick.dy) > 0.15);
  }

  /* ------------------------------------------------------------
     damage
     ------------------------------------------------------------ */
  function damagePlayer(amount) {
    if (!player.alive || state !== STATE.PLAY) return;
    let dmg = amount;
    if (player.armor > 0) {
      const absorbed = Math.min(player.armor, dmg * 0.6);
      player.armor -= absorbed;
      dmg -= absorbed;
    }
    player.hp -= dmg;
    player.hurtFlash = 0.45;
    cam.shake = Math.min(14, cam.shake + 4);
    flashDamage();
    Sound.hurt();
    if (player.hp <= 0) {
      player.hp = 0;
      player.alive = false;
      gameOver();
    }
  }

  /* ------------------------------------------------------------
     enemies
     ------------------------------------------------------------ */
  function spawnEnemy() {
    // spawn away from the player, but not on the far side of the map
    const candidates = SPAWNS.filter(function (s) {
      return dist(s.x, s.y, player.x, player.y) > 620;
    });
    let best;
    if (candidates.length) {
      best = pick(candidates);
    } else {
      best = SPAWNS[0];
      let bestD = -1;
      for (let i = 0; i < SPAWNS.length; i++) {
        const d = dist(SPAWNS[i].x, SPAWNS[i].y, player.x, player.y);
        if (d > bestD) { bestD = d; best = SPAWNS[i]; }
      }
    }
    const tier = Math.min(4, Math.floor((game.round - 1) / 2));
    enemies.push({
      x: best.x + rand(-24, 24),
      y: best.y + rand(-24, 24),
      r: 15,
      hp: 100 + tier * 12,
      maxHp: 100 + tier * 12,
      angle: Math.atan2(player.y - best.y, player.x - best.x),
      speed: 92 + tier * 7,
      fireCd: rand(0.7, 1.8),
      accuracy: clamp(0.17 - game.round * 0.012, 0.06, 0.17),
      burst: 0,
      burstCd: 0,
      strafe: Math.random() < 0.5 ? 1 : -1,
      strafeCd: rand(1, 2.6),
      stuck: 0,
      avoid: 0,
      avoidDir: 1,
      flash: 0,
      walkPhase: rand(0, TAU),
      dead: false
    });
    spawnParticles(best.x, best.y, 10, {
      colors: ['#c9c0a8', '#8d866f'], min: 20, max: 90,
      lifeMin: 0.3, lifeMax: 0.7, sizeMin: 2, sizeMax: 5
    });
  }

  function enemyShoot(e) {
    const range = clamp(dist(e.x, e.y, player.x, player.y) / 620, 0.55, 1.5);
    const spread = e.accuracy * range;
    const angle = Math.atan2(player.y - e.y, player.x - e.x) + rand(-spread, spread);
    const mx = e.x + Math.cos(angle) * 24;
    const my = e.y + Math.sin(angle) * 24;
    bullets.push({
      x: mx, y: my, px: mx, py: my,
      vx: Math.cos(angle) * 1250,
      vy: Math.sin(angle) * 1250,
      damage: rand(7, 11), friendly: false, life: 1.6
    });
    e.flash = 0.06;
    const pan = clamp((e.x - player.x) / 900, -1, 1);
    Sound.enemyShoot(pan);
    spawnParticles(mx, my, 3, {
      colors: ['#ffd479', '#ff8b3d'], min: 60, max: 160,
      lifeMin: 0.06, lifeMax: 0.16, sizeMin: 1, sizeMax: 2, glow: true
    });
  }

  function killEnemy(e) {
    e.dead = true;
    game.kills++;
    const gain = 100 + (game.round - 1) * 15;
    game.score += gain;
    blood(e.x, e.y, Math.atan2(e.y - player.y, e.x - player.x));
    spawnParticles(e.x, e.y, 8, {
      colors: ['#c9c0a8', '#6a6353'], min: 20, max: 120,
      lifeMin: 0.3, lifeMax: 0.8, sizeMin: 2, sizeMax: 5
    });
    Sound.kill();
    hitMarker(true);
    floats.push({ x: e.x, y: e.y - 18, life: 0.9, text: '+' + gain });

    const roll = Math.random();
    if (roll < 0.22) dropPickup(e.x, e.y, 'health');
    else if (roll < 0.55) dropPickup(e.x, e.y, 'ammo');

    killFeed('YOU <b>›</b> HOSTILE', Math.random() < 0.25);
  }

  function dropPickup(x, y, type) {
    pickups.push({ x: x, y: y, type: type, bob: rand(0, TAU), life: 22 });
  }

  function updateEnemies(dt) {
    for (let i = enemies.length - 1; i >= 0; i--) {
      const e = enemies[i];
      if (e.dead) { enemies.splice(i, 1); continue; }

      e.flash = Math.max(0, e.flash - dt);
      e.walkPhase += dt * 8;

      const d = dist(e.x, e.y, player.x, player.y);
      const los = hasLOS(e.x, e.y, player.x, player.y);
      const aim = Math.atan2(player.y - e.y, player.x - e.x);
      e.angle = lerp(e.angle, aim, Math.min(1, dt * 8));

      let dx = 0;
      let dy = 0;

      if (player.alive) {
        if (los && d < 640) {
          // in the fight: keep mid range and strafe
          const toward = d > 380 ? 1 : d < 210 ? -1 : 0;
          dx = Math.cos(aim) * toward + Math.cos(aim + Math.PI / 2) * e.strafe * 0.85;
          dy = Math.sin(aim) * toward + Math.sin(aim + Math.PI / 2) * e.strafe * 0.85;
          e.strafeCd -= dt;
          if (e.strafeCd <= 0) { e.strafe *= -1; e.strafeCd = rand(0.9, 2.2); }

          e.fireCd -= dt;
          if (e.fireCd <= 0 && los) {
            enemyShoot(e);
            if (Math.random() < 0.3) {
              e.burst = 2;
              e.burstCd = 0.13;
            }
            e.fireCd = rand(1.0, 1.8) + (e.burst > 0 ? 0 : 0.15);
          }
          if (e.burst > 0) {
            e.burstCd -= dt;
            if (e.burstCd <= 0) {
              enemyShoot(e);
              e.burst--;
              e.burstCd = 0.14;
            }
          }
        } else {
          dx = Math.cos(aim);
          dy = Math.sin(aim);
          e.fireCd = Math.max(e.fireCd, 0.35);
        }
      } else {
        dx = Math.cos(e.angle) * 0.2;
        dy = Math.sin(e.angle) * 0.2;
      }

      // avoid clumping
      for (let j = 0; j < enemies.length; j++) {
        if (j === i) continue;
        const o = enemies[j];
        const od = dist(e.x, e.y, o.x, o.y);
        if (od < 54 && od > 0.001) {
          dx += ((e.x - o.x) / od) * 0.9;
          dy += ((e.y - o.y) / od) * 0.9;
        }
      }

      // unstick from walls
      if (e.avoid > 0) {
        e.avoid -= dt;
        const a2 = e.angle + (Math.PI / 2) * e.avoidDir;
        dx = Math.cos(a2);
        dy = Math.sin(a2);
      }

      const len = Math.hypot(dx, dy) || 1;
      const speed = e.speed * (e.burst > 0 ? 0.55 : 1);
      const blocked = moveEntity(e, (dx / len) * speed * dt, (dy / len) * speed * dt);
      if (blocked) {
        e.stuck += dt;
        if (e.stuck > 0.12 && e.avoid <= 0) {
          e.avoid = rand(0.35, 0.75);
          e.avoidDir = Math.random() < 0.5 ? 1 : -1;
          e.stuck = 0;
        }
      } else {
        e.stuck = 0;
      }
    }
  }

  /* ------------------------------------------------------------
     bullets
     ------------------------------------------------------------ */
  function updateBullets(dt) {
    for (let i = bullets.length - 1; i >= 0; i--) {
      const b = bullets[i];
      b.life -= dt;
      if (b.life <= 0) { bullets.splice(i, 1); continue; }

      const travel = Math.hypot(b.vx, b.vy) * dt;
      const steps = Math.max(1, Math.ceil(travel / 10));
      const sx = (b.vx * dt) / steps;
      const sy = (b.vy * dt) / steps;
      let dead = false;

      b.px = b.x;
      b.py = b.y;

      for (let s = 0; s < steps && !dead; s++) {
        const nx = b.x + sx;
        const ny = b.y + sy;
        const impactT = wallHit(b.x, b.y, nx, ny);

        if (impactT >= 0) {
          const hx = b.x + (nx - b.x) * impactT;
          const hy = b.y + (ny - b.y) * impactT;
          impact(hx, hy, Math.atan2(-b.vy, -b.vx));
          dead = true;
          break;
        }

        if (b.friendly) {
          for (let j = 0; j < enemies.length; j++) {
            const e = enemies[j];
            if (e.dead) continue;
            if (dist(nx, ny, e.x, e.y) < e.r + 2) {
              e.hp -= b.damage;
              e.flash = 0.08;
              blood(nx, ny, Math.atan2(b.vy, b.vx));
              Sound.hitFlesh();
              hitMarker(false);
              if (e.hp <= 0) killEnemy(e);
              dead = true;
              break;
            }
          }
        } else if (player.alive && dist(nx, ny, player.x, player.y) < player.r + 2) {
          damagePlayer(b.damage);
          blood(nx, ny, Math.atan2(b.vy, b.vx));
          dead = true;
          break;
        }

        b.x = nx;
        b.y = ny;
      }

      if (dead) bullets.splice(i, 1);
    }
  }

  /* ------------------------------------------------------------
     pickups / particles / timers
     ------------------------------------------------------------ */
  function updatePickups(dt) {
    for (let i = pickups.length - 1; i >= 0; i--) {
      const p = pickups[i];
      p.bob += dt * 3;
      p.life -= dt;
      if (p.life <= 0) { pickups.splice(i, 1); continue; }
      if (player.alive && dist(p.x, p.y, player.x, player.y) < player.r + 22) {
        if (p.type === 'health') {
          player.hp = Math.min(player.maxHp, player.hp + 30);
          floats.push({ x: p.x, y: p.y - 10, life: 0.9, text: '+30 HP' });
        } else {
          const a = player.ammo.rifle;
          a.reserve = Math.min(240, a.reserve + 40);
          player.ammo.pistol.reserve = Math.min(120, player.ammo.pistol.reserve + 18);
          floats.push({ x: p.x, y: p.y - 10, life: 0.9, text: '+40 AMMO' });
        }
        Sound.pickup();
        pickups.splice(i, 1);
      }
    }
  }

  function updateParticles(dt) {
    for (let i = particles.length - 1; i >= 0; i--) {
      const p = particles[i];
      p.life -= dt;
      if (p.life <= 0) { particles.splice(i, 1); continue; }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      const damp = 1 - Math.min(0.98, p.drag * dt);
      p.vx *= damp;
      p.vy *= damp;
    }

    for (let i = casings.length - 1; i >= 0; i--) {
      const c = casings[i];
      c.life -= dt;
      if (c.life <= 0) { casings.splice(i, 1); continue; }
      c.x += c.vx * dt;
      c.y += c.vy * dt;
      c.vx *= 1 - Math.min(0.98, 6 * dt);
      c.vy *= 1 - Math.min(0.98, 6 * dt);
      c.rot += c.vr * dt;
    }

    for (let i = floats.length - 1; i >= 0; i--) {
      const f = floats[i];
      f.life -= dt;
      f.y -= 26 * dt;
      if (f.life <= 0) floats.splice(i, 1);
    }

    for (let i = timers.length - 1; i >= 0; i--) {
      timers[i].t -= dt;
      if (timers[i].t <= 0) {
        const fn = timers[i].fn;
        timers.splice(i, 1);
        fn();
      }
    }
  }

  /* ------------------------------------------------------------
     rounds
     ------------------------------------------------------------ */
  function startRound(round) {
    game.round = round;
    game.roundEnding = false;
    game.pending = Math.min(18, 4 + (round - 1) * 2);
    game.maxAlive = Math.min(7, 3 + Math.floor(round / 2));
    game.spawnCd = 1.0;

    // resupply at the top of each round
    const r = player.ammo.rifle;
    const p = player.ammo.pistol;
    r.mag = WEAPONS.rifle.magSize;
    r.reserve = Math.max(r.reserve, 90);
    p.mag = WEAPONS.pistol.magSize;
    p.reserve = Math.max(p.reserve, 36);
    player.armor = Math.min(100, player.armor + 30);
    player.reloading = 0;

    showBanner(round, 'CLEAR THE COMPOUND · ' + game.pending + ' HOSTILES');
    Sound.roundStart();
  }

  function clearRound() {
    game.roundEnding = true;
    const bonus = 250 * game.round;
    game.score += bonus;
    player.hp = Math.min(player.maxHp, player.hp + 20);
    player.armor = Math.min(100, player.armor + 40);
    showBanner('ROUND ' + game.round + ' CLEAR', '+' + bonus + ' BONUS · NEXT WAVE IN 3');
    Sound.roundClear();
    later(3, () => {
      if (state === STATE.PLAY) startRound(game.round + 1);
    });
  }

  function updateSpawns(dt) {
    if (game.roundEnding) {
      if (game.pending === 0 && enemies.length === 0) { /* waiting on timer */ }
      return;
    }
    if (game.pending > 0) {
      game.spawnCd -= dt;
      if (game.spawnCd <= 0 && enemies.length < game.maxAlive) {
        spawnEnemy();
        game.pending--;
        game.spawnCd = Math.max(0.45, 1.7 - game.round * 0.1);
      }
    } else if (enemies.length === 0) {
      clearRound();
    }
  }

  /* ------------------------------------------------------------
     player update
     ------------------------------------------------------------ */
  function updatePlayer(dt) {
    if (!player.alive) return;

    // aim
    const mw = toWorld(mouse.x, mouse.y);
    player.angle = Math.atan2(mw.y - player.y, mw.x - player.x);

    // movement
    let dx = 0;
    let dy = 0;
    if (keys.w || keys.arrowup) dy -= 1;
    if (keys.s || keys.arrowdown) dy += 1;
    if (keys.a || keys.arrowleft) dx -= 1;
    if (keys.d || keys.arrowright) dx += 1;
    dx += stick.dx;
    dy += stick.dy;

    const len = Math.hypot(dx, dy);
    if (len > 0.001) {
      const speed = keys.shift ? player.walkSpeed : player.speed;
      const nx = dx / Math.max(1, len);
      const ny = dy / Math.max(1, len);
      moveEntity(player, nx * speed * dt, ny * speed * dt);
    }

    // camera follow
    const targetX = clamp(player.x, 0, WORLD.w);
    const targetY = clamp(player.y, 0, WORLD.h);
    cam.x = lerp(cam.x, targetX, Math.min(1, dt * 7));
    cam.y = lerp(cam.y, targetY, Math.min(1, dt * 7));
    clampCamera(false);

    // shooting
    player.fireCd -= dt;
    if (player.reloading > 0) {
      player.reloading -= dt;
      if (player.reloading <= 0) {
        player.reloading = 0;
        finishReload();
      }
    }

    const w = WEAPONS[player.slot];
    const wantsFire = w.auto ? mouse.down : mouse.pressed;
    if (wantsFire && player.fireCd <= 0 && player.reloading <= 0) shoot();
    mouse.pressed = false;

    if (touchAim) mouse.pressed = false;

    // decay
    player.recoil = Math.max(0, player.recoil - dt * 7);
    player.muzzle = Math.max(0, player.muzzle - dt);
    player.hurtFlash = Math.max(0, player.hurtFlash - dt);
  }

  /* ------------------------------------------------------------
     render
     ------------------------------------------------------------ */
  function screenX(x) { return x - cam.x + VIEW.w / 2 + cam.ox; }
  function screenY(y) { return y - cam.y + VIEW.h / 2 + cam.oy; }

  function drawFloor() {
    ctx.fillStyle = '#171a13';
    ctx.fillRect(0, 0, VIEW.w, VIEW.h);

    const tile = 100;
    const startX = Math.floor((cam.x - VIEW.w / 2) / tile) * tile;
    const startY = Math.floor((cam.y - VIEW.h / 2) / tile) * tile;

    for (let x = startX; x < cam.x + VIEW.w / 2 + tile; x += tile) {
      for (let y = startY; y < cam.y + VIEW.h / 2 + tile; y += tile) {
        const sx = screenX(x);
        const sy = screenY(y);
        const hash = ((x * 73856093) ^ (y * 19349663)) >>> 0;
        const v = hash % 5;
        ctx.fillStyle = ['#1b1f16', '#191d15', '#1d2218', '#181c14', '#1a1f16'][v];
        ctx.fillRect(sx, sy, tile + 1, tile + 1);
      }
    }

    // grid lines
    ctx.strokeStyle = 'rgba(120, 140, 90, 0.055)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (let x = startX; x < cam.x + VIEW.w / 2 + tile; x += tile) {
      const sx = Math.round(screenX(x)) + 0.5;
      ctx.moveTo(sx, 0);
      ctx.lineTo(sx, VIEW.h);
    }
    for (let y = startY; y < cam.y + VIEW.h / 2 + tile; y += tile) {
      const sy = Math.round(screenY(y)) + 0.5;
      ctx.moveTo(0, sy);
      ctx.lineTo(VIEW.w, sy);
    }
    ctx.stroke();

    // speckles / dirt
    for (let i = 0; i < speckles.length; i++) {
      const s = speckles[i];
      const sx = screenX(s.x);
      const sy = screenY(s.y);
      if (sx < -20 || sy < -20 || sx > VIEW.w + 20 || sy > VIEW.h + 20) continue;
      ctx.fillStyle = 'rgba(210, 200, 160, ' + s.a.toFixed(3) + ')';
      ctx.beginPath();
      ctx.arc(sx, sy, s.r, 0, TAU);
      ctx.fill();
    }

    // world border
    const bx = screenX(0);
    const by = screenY(0);
    ctx.strokeStyle = 'rgba(217, 255, 63, 0.16)';
    ctx.lineWidth = 3;
    ctx.strokeRect(bx + 12, by + 12, WORLD.w - 24, WORLD.h - 24);
  }

  function drawWalls() {
    for (let i = 0; i < walls.length; i++) {
      const w = walls[i];
      const x = screenX(w.x);
      const y = screenY(w.y);
      if (x + w.w < -60 || y + w.h < -60 || x > VIEW.w + 60 || y > VIEW.h + 60) continue;

      // shadow
      ctx.fillStyle = 'rgba(0,0,0,0.42)';
      ctx.fillRect(x + 9, y + 12, w.w, w.h);

      if (w.kind === 'crate') {
        ctx.fillStyle = '#4a4327';
        ctx.fillRect(x, y, w.w, w.h);
        ctx.fillStyle = '#5d5531';
        ctx.fillRect(x + 2, y + 2, w.w - 4, w.h - 7);
        ctx.strokeStyle = 'rgba(20,18,10,0.75)';
        ctx.lineWidth = 3;
        ctx.beginPath();
        ctx.moveTo(x + 6, y + 6);
        ctx.lineTo(x + w.w - 6, y + w.h - 6);
        ctx.moveTo(x + w.w - 6, y + 6);
        ctx.lineTo(x + 6, y + w.h - 6);
        ctx.stroke();
        ctx.strokeStyle = 'rgba(255, 230, 150, 0.16)';
        ctx.lineWidth = 1;
        ctx.strokeRect(x + 2.5, y + 2.5, w.w - 5, w.h - 7);
      } else {
        ctx.fillStyle = '#2a2f26';
        ctx.fillRect(x, y, w.w, w.h);
        // top face highlight
        ctx.fillStyle = '#353c2e';
        ctx.fillRect(x, y, w.w, Math.min(10, w.h));
        ctx.fillStyle = 'rgba(0,0,0,0.25)';
        ctx.fillRect(x, y + w.h - 5, w.w, 5);
        ctx.strokeStyle = 'rgba(140, 160, 110, 0.14)';
        ctx.lineWidth = 1;
        ctx.strokeRect(x + 0.5, y + 0.5, w.w - 1, w.h - 1);
      }
    }
  }

  function drawPickups() {
    for (let i = 0; i < pickups.length; i++) {
      const p = pickups[i];
      const x = screenX(p.x);
      const y = screenY(p.y) + Math.sin(p.bob) * 3;
      const glow = p.type === 'health' ? 'rgba(127, 227, 107, 0.35)' : 'rgba(255, 193, 66, 0.35)';
      const core = p.type === 'health' ? '#8fe86f' : '#ffc142';

      ctx.save();
      ctx.translate(x, y);

      ctx.beginPath();
      ctx.arc(0, 0, 26, 0, TAU);
      const g = ctx.createRadialGradient(0, 0, 2, 0, 0, 26);
      g.addColorStop(0, glow);
      g.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = g;
      ctx.fill();

      ctx.fillStyle = 'rgba(8, 12, 8, 0.9)';
      ctx.fillRect(-13, -13, 26, 26);
      ctx.strokeStyle = core;
      ctx.lineWidth = 2;
      ctx.strokeRect(-13, -13, 26, 26);
      ctx.fillStyle = core;
      if (p.type === 'health') {
        ctx.fillRect(-3, -8, 6, 16);
        ctx.fillRect(-8, -3, 16, 6);
      } else {
        ctx.fillRect(-7, -2, 5, 10);
        ctx.fillRect(-1, -2, 5, 10);
        ctx.fillRect(5, -2, 5, 10);
      }
      ctx.restore();
    }
  }

  function drawBullets() {
    for (let i = 0; i < bullets.length; i++) {
      const b = bullets[i];
      const x = screenX(b.x);
      const y = screenY(b.y);
      const px = screenX(b.px);
      const py = screenY(b.py);

      ctx.strokeStyle = b.friendly ? 'rgba(255, 241, 190, 0.95)' : 'rgba(255, 150, 110, 0.9)';
      ctx.lineWidth = b.friendly ? 2.2 : 2;
      ctx.beginPath();
      ctx.moveTo(px, py);
      ctx.lineTo(x, y);
      ctx.stroke();

      ctx.fillStyle = b.friendly ? '#fffbe8' : '#ffd0b8';
      ctx.beginPath();
      ctx.arc(x, y, b.friendly ? 2.1 : 2, 0, TAU);
      ctx.fill();
    }
  }

  function drawParticles() {
    for (let i = 0; i < particles.length; i++) {
      const p = particles[i];
      const a = clamp(p.life / p.maxLife, 0, 1);
      ctx.globalAlpha = a;
      if (p.glow) {
        ctx.shadowBlur = 8;
        ctx.shadowColor = p.color;
      }
      ctx.fillStyle = p.color;
      ctx.fillRect(screenX(p.x) - p.size / 2, screenY(p.y) - p.size / 2, p.size, p.size);
      ctx.shadowBlur = 0;
    }
    ctx.globalAlpha = 1;

    for (let i = 0; i < casings.length; i++) {
      const c = casings[i];
      ctx.save();
      ctx.translate(screenX(c.x), screenY(c.y));
      ctx.rotate(c.rot);
      ctx.fillStyle = 'rgba(210, 170, 60, ' + clamp(c.life, 0, 1).toFixed(2) + ')';
      ctx.fillRect(-2.5, -1, 5, 2);
      ctx.restore();
    }

    for (let i = 0; i < floats.length; i++) {
      const f = floats[i];
      ctx.globalAlpha = clamp(f.life, 0, 1);
      ctx.fillStyle = '#d9ff3f';
      ctx.font = 'bold 15px ui-monospace, monospace';
      ctx.textAlign = 'center';
      ctx.fillText(f.text, screenX(f.x), screenY(f.y));
    }
    ctx.globalAlpha = 1;
    ctx.textAlign = 'left';
  }

  function drawPlayer() {
    if (!player.alive) return;
    const x = screenX(player.x);
    const y = screenY(player.y);
    const walk = moving() ? Math.sin(game.time * 12) * 2 : 0;

    // shadow
    ctx.fillStyle = 'rgba(0,0,0,0.45)';
    ctx.beginPath();
    ctx.ellipse(x + 4, y + 8, 17, 12, 0, 0, TAU);
    ctx.fill();

    ctx.save();
    ctx.translate(x, y + walk * 0.4);
    ctx.rotate(player.angle);

    // legs
    ctx.fillStyle = '#2c3440';
    ctx.fillRect(-16, -9, 12, 6);
    ctx.fillRect(-16, 3, 12, 6);

    // body
    ctx.fillStyle = player.hurtFlash > 0 ? '#ffd4cf' : '#3b4a5c';
    ctx.beginPath();
    ctx.arc(0, 0, 14, 0, TAU);
    ctx.fill();
    ctx.strokeStyle = '#22303d';
    ctx.lineWidth = 3;
    ctx.stroke();

    // vest
    ctx.fillStyle = '#28323f';
    ctx.beginPath();
    ctx.arc(-2, 0, 9, -Math.PI / 2.2, Math.PI / 2.2);
    ctx.fill();

    // helmet
    ctx.fillStyle = '#5d7387';
    ctx.beginPath();
    ctx.arc(3, 0, 8, 0, TAU);
    ctx.fill();
    ctx.fillStyle = '#8fd6ff';
    ctx.beginPath();
    ctx.arc(7, 0, 3.5, 0, TAU);
    ctx.fill();

    // weapon
    ctx.fillStyle = '#1c211d';
    ctx.fillRect(8, -4, 26, 8);
    ctx.fillStyle = '#2e3730';
    ctx.fillRect(14, -6, 10, 4);

    // muzzle flash
    if (player.muzzle > 0) {
      const a = player.muzzle / 0.055;
      ctx.globalAlpha = a;
      ctx.fillStyle = '#fff3b0';
      ctx.beginPath();
      ctx.moveTo(34, 0);
      ctx.lineTo(50, -7);
      ctx.lineTo(44, 0);
      ctx.lineTo(50, 7);
      ctx.closePath();
      ctx.fill();
      ctx.globalAlpha = 1;
    }

    ctx.restore();
  }

  function drawEnemies() {
    for (let i = 0; i < enemies.length; i++) {
      const e = enemies[i];
      const x = screenX(e.x);
      const y = screenY(e.y);

      ctx.fillStyle = 'rgba(0,0,0,0.45)';
      ctx.beginPath();
      ctx.ellipse(x + 4, y + 8, 17, 12, 0, 0, TAU);
      ctx.fill();

      ctx.save();
      ctx.translate(x, y);
      ctx.rotate(e.angle);

      const bob = Math.sin(e.walkPhase) * 1.5;
      ctx.fillStyle = '#3a3128';
      ctx.fillRect(-15, -8, 11, 5);
      ctx.fillRect(-15, 3 + bob * 0.3, 11, 5);

      ctx.fillStyle = e.flash > 0 ? '#ffd9cf' : '#8a6a45';
      ctx.beginPath();
      ctx.arc(0, 0, 14, 0, TAU);
      ctx.fill();
      ctx.strokeStyle = '#4c3623';
      ctx.lineWidth = 3;
      ctx.stroke();

      ctx.fillStyle = '#5c4730';
      ctx.beginPath();
      ctx.arc(-2, 0, 9, -Math.PI / 2.2, Math.PI / 2.2);
      ctx.fill();

      // head + bandana
      ctx.fillStyle = '#a57f52';
      ctx.beginPath();
      ctx.arc(4, 0, 7.5, 0, TAU);
      ctx.fill();
      ctx.fillStyle = '#b8433a';
      ctx.fillRect(-1, -7.5, 7, 15);

      // weapon
      ctx.fillStyle = '#191d18';
      ctx.fillRect(10, -4, 24, 7);

      if (e.flash > 0) {
        ctx.fillStyle = '#ffd479';
        ctx.beginPath();
        ctx.moveTo(34, 0);
        ctx.lineTo(46, -6);
        ctx.lineTo(41, 0);
        ctx.lineTo(46, 6);
        ctx.closePath();
        ctx.fill();
      }
      ctx.restore();

      // health bar
      if (e.hp < e.maxHp) {
        const w = 34;
        ctx.fillStyle = 'rgba(0,0,0,0.6)';
        ctx.fillRect(x - w / 2, y - 25, w, 4);
        ctx.fillStyle = e.hp / e.maxHp > 0.5 ? '#8fe86f' : e.hp / e.maxHp > 0.25 ? '#ffc142' : '#ff5a4a';
        ctx.fillRect(x - w / 2, y - 25, w * (e.hp / e.maxHp), 4);
      }
    }
  }

  function drawEnemyMarkers() {
    // subtle arrow at screen edge pointing to the closest hostile
    if (!enemies.length || !player.alive) return;
    let closest = enemies[0];
    let cd = Infinity;
    for (let i = 0; i < enemies.length; i++) {
      const d = dist(enemies[i].x, enemies[i].y, player.x, player.y);
      if (d < cd) { cd = d; closest = enemies[i]; }
    }
    const sx = screenX(closest.x);
    const sy = screenY(closest.y);
    const m = 46;
    if (sx > m && sx < VIEW.w - m && sy > m && sy < VIEW.h - m) return;

    const cx = VIEW.w / 2;
    const cy = VIEW.h / 2;
    const angle = Math.atan2(sy - cy, sx - cx);
    const rx = VIEW.w / 2 - m;
    const ry = VIEW.h / 2 - m;
    const t = Math.min(
      Math.abs(rx / Math.cos(angle)) || Infinity,
      Math.abs(ry / Math.sin(angle)) || Infinity
    );
    const px = cx + Math.cos(angle) * t;
    const py = cy + Math.sin(angle) * t;

    ctx.save();
    ctx.translate(px, py);
    ctx.rotate(angle);
    ctx.fillStyle = 'rgba(255, 90, 74, 0.85)';
    ctx.beginPath();
    ctx.moveTo(9, 0);
    ctx.lineTo(-7, -7);
    ctx.lineTo(-7, 7);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  function drawReticle() {
    if (state !== STATE.PLAY) return;
    const spread = 7 + WEAPONS[player.slot].spread * 240 + player.recoil * 2.4;
    const x = mouse.x;
    const y = mouse.y;
    ctx.strokeStyle = 'rgba(217, 255, 63, 0.85)';
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.moveTo(x, y - spread - 8);
    ctx.lineTo(x, y - spread);
    ctx.moveTo(x, y + spread);
    ctx.lineTo(x, y + spread + 8);
    ctx.moveTo(x - spread - 8, y);
    ctx.lineTo(x - spread, y);
    ctx.moveTo(x + spread, y);
    ctx.lineTo(x + spread + 8, y);
    ctx.stroke();

    ctx.fillStyle = 'rgba(217, 255, 63, 0.9)';
    ctx.fillRect(x - 1, y - 1, 2, 2);
  }

  function drawVignette() {
    const g = ctx.createRadialGradient(
      VIEW.w / 2, VIEW.h / 2, Math.min(VIEW.w, VIEW.h) * 0.32,
      VIEW.w / 2, VIEW.h / 2, Math.max(VIEW.w, VIEW.h) * 0.78
    );
    g.addColorStop(0, 'rgba(0,0,0,0)');
    g.addColorStop(1, 'rgba(0,0,0,0.72)');
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, VIEW.w, VIEW.h);
  }

  function drawMinimap() {
    const w = mini.width;
    const h = mini.height;
    const sx = w / WORLD.w;
    const sy = h / WORLD.h;
    mctx.clearRect(0, 0, w, h);

    mctx.fillStyle = 'rgba(9, 13, 10, 0.9)';
    mctx.fillRect(0, 0, w, h);

    mctx.fillStyle = 'rgba(120, 140, 100, 0.5)';
    for (let i = 0; i < walls.length; i++) {
      const s = walls[i];
      mctx.fillRect(s.x * sx, s.y * sy, Math.max(2, s.w * sx), Math.max(2, s.h * sy));
    }

    for (let i = 0; i < pickups.length; i++) {
      const p = pickups[i];
      mctx.fillStyle = p.type === 'health' ? '#8fe86f' : '#ffc142';
      mctx.fillRect(p.x * sx - 1.5, p.y * sy - 1.5, 3, 3);
    }

    for (let i = 0; i < enemies.length; i++) {
      const e = enemies[i];
      mctx.fillStyle = '#ff5a4a';
      mctx.beginPath();
      mctx.arc(e.x * sx, e.y * sy, 2.6, 0, TAU);
      mctx.fill();
    }

    if (player.alive) {
      mctx.fillStyle = '#d9ff3f';
      mctx.beginPath();
      mctx.arc(player.x * sx, player.y * sy, 3.2, 0, TAU);
      mctx.fill();
      mctx.strokeStyle = 'rgba(217, 255, 63, 0.55)';
      mctx.lineWidth = 1;
      mctx.beginPath();
      mctx.moveTo(player.x * sx, player.y * sy);
      mctx.lineTo(
        player.x * sx + Math.cos(player.angle) * 9,
        player.y * sy + Math.sin(player.angle) * 9
      );
      mctx.stroke();
    }

    mctx.strokeStyle = 'rgba(217, 255, 63, 0.28)';
    mctx.lineWidth = 1;
    mctx.strokeRect(0.5, 0.5, w - 1, h - 1);
  }

  function render() {
    ctx.setTransform(
      Math.min(window.devicePixelRatio || 1, 2), 0, 0,
      Math.min(window.devicePixelRatio || 1, 2), 0, 0
    );

    if (cam.shake > 0.05) {
      cam.ox = rand(-cam.shake, cam.shake);
      cam.oy = rand(-cam.shake, cam.shake);
    } else {
      cam.ox = 0;
      cam.oy = 0;
    }

    drawFloor();
    drawPickups();
    drawEnemyMarkers();
    drawWalls();
    drawBullets();
    drawParticles();
    drawEnemies();
    drawPlayer();
    drawVignette();
    drawReticle();
    if (state === STATE.PLAY || state === STATE.PAUSE) drawMinimap();
  }

  /* ------------------------------------------------------------
     game flow
     ------------------------------------------------------------ */
  function resetWorld() {
    enemies.length = 0;
    bullets.length = 0;
    particles.length = 0;
    casings.length = 0;
    pickups.length = 0;
    timers.length = 0;
    floats.length = 0;
    ui.killfeed.innerHTML = '';

    player.x = 1100;
    player.y = 1020;
    player.hp = player.maxHp;
    player.armor = 100;
    player.alive = true;
    player.slot = 'rifle';
    player.reloading = 0;
    player.fireCd = 0;
    player.recoil = 0;
    player.muzzle = 0;
    player.ammo.rifle = { mag: WEAPONS.rifle.magSize, reserve: 120 };
    player.ammo.pistol = { mag: WEAPONS.pistol.magSize, reserve: 60 };

    cam.x = player.x;
    cam.y = player.y;
    cam.shake = 0;
    clampCamera(true);

    game.score = 0;
    game.kills = 0;
    game.round = 1;
    game.roundEnding = false;
    game.spawnCd = 0;
    game.pending = 0;
    game.best = Number(localStorage.getItem('counter.best') || 0);
    game.bestRound = Number(localStorage.getItem('counter.round') || 0);
  }

  function hideScreens() {
    ui.menu.classList.add('hidden');
    ui.how.classList.add('hidden');
    ui.pause.classList.add('hidden');
    ui.over.classList.add('hidden');
  }

  function startGame() {
    Sound.init();
    Sound.ui('pop');
    Sound.stopMusic();
    resetWorld();
    hideScreens();
    ui.hud.classList.remove('hidden');
    ui.touchUI.classList.toggle('hidden', !isTouch);
    canvas.style.cursor = 'none';
    state = STATE.PLAY;
    startRound(1);
    hudUpdate();
  }

  function pauseGame() {
    if (state !== STATE.PLAY) return;
    state = STATE.PAUSE;
    ui.pause.classList.remove('hidden');
    canvas.style.cursor = 'crosshair';
  }

  function resumeGame() {
    if (state !== STATE.PAUSE) return;
    state = STATE.PLAY;
    ui.pause.classList.add('hidden');
    canvas.style.cursor = 'none';
    Sound.init();
  }

  function toMenu() {
    state = STATE.MENU;
    hideScreens();
    ui.menu.classList.remove('hidden');
    ui.hud.classList.add('hidden');
    ui.touchUI.classList.add('hidden');
    canvas.style.cursor = 'crosshair';
    ui.menuBest.textContent = game.best;
    ui.menuRound.textContent = game.bestRound;
    Sound.startMusic();
    ui.damage.classList.remove('on');
  }

  function gameOver() {
    state = STATE.OVER;
    Sound.stopMusic();
    Sound.gameOver();
    ui.hud.classList.add('hidden');
    ui.touchUI.classList.add('hidden');
    canvas.style.cursor = 'crosshair';

    const isRecord = game.score > game.best;
    if (isRecord) {
      game.best = game.score;
      localStorage.setItem('counter.best', String(game.best));
    }
    if (game.round > game.bestRound) {
      game.bestRound = game.round;
      localStorage.setItem('counter.round', String(game.bestRound));
    }

    ui.finalScore.textContent = game.score;
    ui.finalKills.textContent = game.kills;
    ui.finalRound.textContent = game.round;
    ui.recordNote.classList.toggle('hidden', !isRecord);
    ui.over.classList.remove('hidden');

    cam.shake = 0;
    blood(player.x, player.y, rand(0, TAU));
  }

  /* ------------------------------------------------------------
     main loop
     ------------------------------------------------------------ */
  let last = performance.now();

  function frame(now) {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;

    if (state === STATE.PLAY) {
      game.time += dt;
      updatePlayer(dt);
      updateEnemies(dt);
      updateBullets(dt);
      updatePickups(dt);
      updateParticles(dt);
      updateSpawns(dt);
      hudUpdate();
    } else if (state === STATE.OVER) {
      updateParticles(dt);
    }

    cam.shake = Math.max(0, cam.shake - dt * 26);
    render();
    requestAnimationFrame(frame);
  }

  /* ------------------------------------------------------------
     menus & buttons
     ------------------------------------------------------------ */
  function wire(btn, fn) {
    btn.addEventListener('click', fn);
    btn.addEventListener('mouseenter', () => Sound.ui('hover'));
  }

  wire($('playBtn'), startGame);
  wire($('howBtn'), () => {
    Sound.ui('click');
    ui.menu.classList.add('hidden');
    ui.how.classList.remove('hidden');
  });
  wire($('backBtn'), () => {
    Sound.ui('click');
    ui.how.classList.add('hidden');
    ui.menu.classList.remove('hidden');
  });
  wire($('soundBtn'), () => {
    const on = !Sound.isEnabled();
    Sound.setEnabled(on);
    ui.soundBtn.textContent = 'SOUND: ' + (on ? 'ON' : 'OFF');
    ui.soundBtn.setAttribute('aria-pressed', String(on));
    if (on) { Sound.init(); Sound.ui('click'); }
  });
  wire($('resumeBtn'), () => { Sound.ui('click'); resumeGame(); });
  wire($('restartBtn'), () => { Sound.ui('pop'); startGame(); });
  wire($('quitBtn'), () => { Sound.ui('click'); resetWorld(); toMenu(); });
  wire($('retryBtn'), startGame);
  wire($('menuBtn'), () => { Sound.ui('click'); resetWorld(); toMenu(); });

  // first gesture: unlock audio + start menu music
  const unlockAudio = () => {
    Sound.init();
    Sound.startMusic();
    window.removeEventListener('pointerdown', unlockAudio);
    window.removeEventListener('keydown', unlockAudio);
  };
  window.addEventListener('pointerdown', unlockAudio);
  window.addEventListener('keydown', unlockAudio);

  /* ------------------------------------------------------------
     boot
     ------------------------------------------------------------ */
  resize();
  setupTouch();
  if (isTouch) ui.touchUI.classList.add('hidden');
  ui.menuBest.textContent = game.best;
  ui.menuRound.textContent = game.bestRound;
  ui.best.textContent = game.best;
  resetWorld();
  hudUpdate();
  requestAnimationFrame(frame);
})();
