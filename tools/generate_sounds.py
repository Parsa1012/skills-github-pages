#!/usr/bin/env python3
"""Generates the two tiny sounds the game ships with.

Both are synthesised from scratch (no third-party samples) so the APK stays tiny and
the repository stays licence-clean:

  tick.wav   ~70 ms bright blip played when a row is cleared
  crash.wav  ~430 ms low thud + noise burst played on impact

Run: python3 tools/generate_sounds.py
"""

import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
OUT_DIR = Path(__file__).resolve().parent.parent / "mirror" / "src" / "main" / "res" / "raw"


def write_wav(path, samples):
    clipped = [max(-1.0, min(1.0, s)) for s in samples]
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(b"".join(struct.pack("<h", int(s * 32000)) for s in clipped))
    print(f"wrote {path.name}: {len(clipped) / RATE * 1000:.0f} ms, {path.stat().st_size} bytes")


def tick(seconds=0.07):
    n = int(RATE * seconds)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-t / 0.016)
        attack = min(1.0, t / 0.002)
        # A bright two-tone blip: 1180 Hz plus a quiet octave, slight downward glide.
        freq = 1180.0 - 260.0 * (t / seconds)
        tone = math.sin(2 * math.pi * freq * t)
        shimmer = 0.25 * math.sin(2 * math.pi * freq * 2 * t)
        out.append(0.46 * env * attack * (tone + shimmer))
    # Fade the tail so the file never ends on a click.
    fade = int(RATE * 0.008)
    for i in range(fade):
        out[n - 1 - i] *= i / fade
    return out


def crash(seconds=0.43):
    random.seed(7)
    n = int(RATE * seconds)
    out = []
    low = 0.0
    for i in range(n):
        t = i / RATE
        # Body: a fast downward sweep from 190 Hz to 55 Hz.
        sweep = 55.0 + (190.0 - 55.0) * math.exp(-t / 0.09)
        body = math.sin(2 * math.pi * sweep * t) * math.exp(-t / 0.13)
        # Noise: one-pole low-passed white noise for a "crunch" instead of hiss.
        low += (random.uniform(-1.0, 1.0) - low) * 0.22
        crunch = low * math.exp(-t / 0.055) * 0.9
        attack = min(1.0, t / 0.004)
        out.append(0.72 * attack * (body * 0.9 + crunch))
    fade = int(RATE * 0.02)
    for i in range(fade):
        out[n - 1 - i] *= i / fade
    return out


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    write_wav(OUT_DIR / "tick.wav", tick())
    write_wav(OUT_DIR / "crash.wav", crash())


if __name__ == "__main__":
    main()
