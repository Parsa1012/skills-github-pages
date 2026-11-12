/* ============================================================
   COUNTER — audio engine
   All weapon / gameplay sounds are synthesised with WebAudio so the
   game needs no extra asset downloads. Menu music and UI clicks use
   the mp3 files in /assets.
   ============================================================ */

const Sound = (function () {
  let ctx = null;
  let master = null;
  let noiseBuffer = null;
  let enabled = true;
  let musicStarted = false;

  const music = new Audio('assets/main-menu.mp3');
  music.loop = true;
  music.volume = 0.32;
  music.preload = 'auto';

  const ui = {
    click: new Audio('assets/ui-click.mp3'),
    hover: new Audio('assets/ui-hover.mp3'),
    pop: new Audio('assets/ui-pop.mp3')
  };
  Object.keys(ui).forEach(function (k) {
    ui[k].volume = k === 'hover' ? 0.18 : 0.35;
    ui[k].preload = 'auto';
  });

  function ensureContext() {
    if (ctx) return ctx;
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = 0.55;
    master.connect(ctx.destination);

    // 1 second of white noise, reused by every noisy sound
    const len = Math.floor(ctx.sampleRate * 1);
    noiseBuffer = ctx.createBuffer(1, len, ctx.sampleRate);
    const data = noiseBuffer.getChannelData(0);
    for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
    return ctx;
  }

  function now() { return ctx.currentTime; }

  function noise(opts) {
    if (!enabled || !ctx) return;
    const t = now() + (opts.delay || 0);
    const src = ctx.createBufferSource();
    src.buffer = noiseBuffer;
    src.loop = true;
    src.playbackRate.value = opts.rate || 1;

    const filter = ctx.createBiquadFilter();
    filter.type = opts.type || 'bandpass';
    filter.frequency.value = opts.freq || 1200;
    filter.Q.value = opts.q || 1;

    const gain = ctx.createGain();
    const peak = (opts.gain === undefined ? 0.5 : opts.gain);
    const dur = opts.dur || 0.15;
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(Math.max(0.0002, peak), t + (opts.attack || 0.004));
    gain.gain.exponentialRampToValueAtTime(0.0001, t + dur);

    src.connect(filter);
    filter.connect(gain);
    if (opts.pan !== undefined && ctx.createStereoPanner) {
      const panner = ctx.createStereoPanner();
      panner.pan.value = Math.max(-1, Math.min(1, opts.pan));
      gain.connect(panner);
      panner.connect(master);
    } else {
      gain.connect(master);
    }
    src.start(t);
    src.stop(t + dur + 0.05);
  }

  function tone(opts) {
    if (!enabled || !ctx) return;
    const t = now() + (opts.delay || 0);
    const osc = ctx.createOscillator();
    osc.type = opts.wave || 'sine';
    osc.frequency.setValueAtTime(opts.freq || 440, t);
    if (opts.to) osc.frequency.exponentialRampToValueAtTime(Math.max(20, opts.to), t + (opts.dur || 0.2));

    const gain = ctx.createGain();
    const peak = (opts.gain === undefined ? 0.25 : opts.gain);
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(Math.max(0.0002, peak), t + 0.008);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + (opts.dur || 0.2));

    osc.connect(gain);
    gain.connect(master);
    osc.start(t);
    osc.stop(t + (opts.dur || 0.2) + 0.05);
  }

  const api = {
    init: function () {
      ensureContext();
      if (ctx && ctx.state === 'suspended') ctx.resume();
    },

    setEnabled: function (on) {
      enabled = on;
      if (!on) {
        music.pause();
      } else if (musicStarted) {
        music.play().catch(function () {});
      }
    },

    isEnabled: function () { return enabled; },

    /* ---------- music ---------- */
    startMusic: function () {
      if (!enabled) return;
      musicStarted = true;
      music.play().catch(function () {
        // autoplay blocked — retried on the next user gesture
      });
    },
    stopMusic: function () {
      music.pause();
    },
    duckMusic: function (ducked) {
      music.volume = ducked ? 0.08 : 0.32;
    },

    /* ---------- UI ---------- */
    ui: function (name) {
      if (!enabled) return;
      const el = ui[name] || ui.click;
      try {
        const clone = el.cloneNode(true);
        clone.volume = el.volume;
        clone.play().catch(function () {});
      } catch (e) { /* ignore */ }
    },

    /* ---------- weapons ---------- */
    shoot: function (weapon) {
      if (!ctx) return;
      if (weapon === 'pistol') {
        noise({ freq: 1700, q: 0.7, gain: 0.45, dur: 0.12 });
        tone({ wave: 'square', freq: 210, to: 60, gain: 0.22, dur: 0.1 });
      } else {
        noise({ freq: 1100, q: 0.6, gain: 0.6, dur: 0.16 });
        noise({ freq: 260, q: 0.9, gain: 0.4, dur: 0.24, type: 'lowpass' });
        tone({ wave: 'sawtooth', freq: 160, to: 42, gain: 0.28, dur: 0.16 });
      }
    },

    enemyShoot: function (pan) {
      if (!ctx) return;
      noise({ freq: 900, q: 0.7, gain: 0.2, dur: 0.13, pan: pan });
      tone({ wave: 'square', freq: 150, to: 48, gain: 0.1, dur: 0.1 });
    },

    dryFire: function () {
      if (!ctx) return;
      noise({ freq: 2600, q: 3, gain: 0.18, dur: 0.05, type: 'highpass' });
    },

    reload: function () {
      if (!ctx) return;
      noise({ freq: 3200, q: 4, gain: 0.16, dur: 0.05, type: 'highpass' });
      noise({ freq: 1400, q: 2, gain: 0.14, dur: 0.07, delay: 0.16 });
      noise({ freq: 2200, q: 3, gain: 0.18, dur: 0.06, delay: 0.46 });
      tone({ wave: 'square', freq: 320, to: 180, gain: 0.08, dur: 0.06, delay: 0.46 });
    },

    /* ---------- impacts ---------- */
    hitFlesh: function () {
      if (!ctx) return;
      noise({ freq: 320, q: 1.1, gain: 0.34, dur: 0.1, type: 'lowpass' });
    },
    hitWall: function () {
      if (!ctx) return;
      noise({ freq: 4200, q: 2, gain: 0.13, dur: 0.06, type: 'highpass' });
    },
    hurt: function () {
      if (!ctx) return;
      tone({ wave: 'sine', freq: 130, to: 44, gain: 0.34, dur: 0.3 });
      noise({ freq: 700, q: 0.8, gain: 0.2, dur: 0.22 });
    },
    kill: function () {
      tone({ wave: 'triangle', freq: 880, gain: 0.18, dur: 0.07 });
      tone({ wave: 'triangle', freq: 1320, gain: 0.16, dur: 0.1, delay: 0.07 });
    },
    pickup: function () {
      tone({ wave: 'sine', freq: 520, to: 900, gain: 0.18, dur: 0.14 });
    },
    roundStart: function () {
      tone({ wave: 'square', freq: 300, gain: 0.12, dur: 0.1 });
      tone({ wave: 'square', freq: 450, gain: 0.12, dur: 0.12, delay: 0.13 });
      tone({ wave: 'square', freq: 600, gain: 0.12, dur: 0.16, delay: 0.27 });
    },
    roundClear: function () {
      tone({ wave: 'triangle', freq: 523, gain: 0.16, dur: 0.14 });
      tone({ wave: 'triangle', freq: 659, gain: 0.16, dur: 0.14, delay: 0.14 });
      tone({ wave: 'triangle', freq: 784, gain: 0.18, dur: 0.28, delay: 0.28 });
    },
    gameOver: function () {
      tone({ wave: 'sawtooth', freq: 220, to: 70, gain: 0.22, dur: 0.9 });
      noise({ freq: 300, q: 0.6, gain: 0.16, dur: 0.8, type: 'lowpass' });
    }
  };

  // Resume audio on the first interaction (browser autoplay rules)
  ['pointerdown', 'keydown', 'touchstart'].forEach(function (evt) {
    window.addEventListener(evt, function once() {
      api.init();
      window.removeEventListener(evt, once);
    }, { once: true, passive: true });
  });

  return api;
})();
