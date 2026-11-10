#!/usr/bin/env python3
"""Offline sanity checks for the Mirror row generator.

This is a faithful port of the fairness maths in GameEngine/LevelConfig. It runs the
generator and two virtual players (a perfect one and a reaction-limited one) so the
"is every row clearable?" question is answered by simulation instead of guesswork.

Run: python3 tools/simulate_generation.py
"""

import math
import random

# --- geometry (dp) -----------------------------------------------------------
WIDTH = 360.0
HEIGHT = 780.0
PLAYER_RADIUS = 16.0
PLAYER_Y = HEIGHT - 150.0
COLLISION_FORGIVENESS = 0.85
ROW_HEIGHT = 28.0
EDGE_MARGIN = 6.0
MIN_WINDOW = 34.0
MOVING_MIN_WINDOW = 44.0
WAVE_AMPLITUDE = 22.0
WAVE_PERIOD = 2.4
SINGLE_GAP_EXTRA = 46.0
BREATHER_EVERY_ROWS = 7

SPEED_TABLE = [150, 190, 230, 270, 310]
SPACING_TABLE = [320, 300, 280, 260, 240]
GAP_TABLE = [96, 92, 88, 84, 80]
TWO_GAP_TABLE = [0.0, 0.10, 0.20, 0.35, 0.50]


def clamp(v, lo, hi):
    return lo if v < lo else (hi if v > hi else v)


def clamp01(v):
    return 0.0 if v < 0 else (1.0 if v > 1 else v)


def sample(table, level, per_level, bound, cap):
    if level <= 1:
        value = table[0]
    elif level >= len(table):
        value = table[-1] + per_level * (level - len(table))
    else:
        i = int(math.floor(level)) - 1
        frac = level - (i + 1)
        value = table[i] + (table[i + 1] - table[i]) * frac
    return min(value, bound) if cap else max(value, bound)


def speed(level):
    return sample(SPEED_TABLE, level, 40, 520, True)


def spacing(level):
    return sample(SPACING_TABLE, level, -15, 170, False)


def gap_width(level):
    return sample(GAP_TABLE, level, -3, 78, False)


def two_gap_chance(level):
    return sample(TWO_GAP_TABLE, level, 0.05, 0.70, True)


def max_mismatch(level):
    budget = gap_width(level) - MIN_WINDOW
    return 0.0 if budget <= 0 else budget * (0.35 + 0.65 * clamp01((level - 1) / 5.0))


def max_jump(level):
    return WIDTH * (0.34 + 0.28 * clamp01((level - 1) / 5.0))


def moving_chance(level):
    return 0.0 if level < 4 else min(0.28, 0.12 * (level - 3))


class Row:
    def __init__(self, y=-ROW_HEIGHT):
        self.y = y
        self.height = ROW_HEIGHT
        self.gaps = []          # list of (center, width)
        self.window_center = 0.0
        self.window_width = 0.0
        self.wave = False
        self.wave_amp = 0.0
        self.wave_phase = 0.0
        self.offset = 0.0
        self.scored = False

    def segments(self):
        gaps = sorted(((c + self.offset, w) for c, w in self.gaps))
        out = []
        cursor = 0.0
        for center, width in gaps:
            left = clamp(center - width / 2, 0, WIDTH)
            right = clamp(center + width / 2, 0, WIDTH)
            if left > cursor:
                out.append((cursor, left))
            cursor = max(cursor, right)
        if cursor < WIDTH:
            out.append((cursor, WIDTH))
        return out


class Generator:
    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.last_window_center = -1.0
        self.rows_since_breather = 0
        self.log = []

    # -- helpers ------------------------------------------------------------
    def try_single_gap(self, row, level):
        gw = gap_width(level) + SINGLE_GAP_EXTRA
        if gw >= WIDTH - 2 * EDGE_MARGIN:
            return False
        max_offset = max(0.0, (gw - MIN_WINDOW) / 2)
        window_center = WIDTH / 2
        anchor = window_center if self.last_window_center < 0 else self.last_window_center
        if abs(window_center - anchor) > max_jump(level):
            return False
        for _ in range(48):
            center = window_center + self.rng.uniform(-1, 1) * max_offset
            window_width = gw - abs(2 * center - WIDTH)
            if window_width < MIN_WINDOW:
                continue
            row.gaps = [(center, gw)]
            row.window_center = window_center
            row.window_width = window_width
            return True
        return False

    def try_two_gaps(self, row, level):
        gw = gap_width(level)
        inset = gw / 2 + EDGE_MARGIN + WAVE_AMPLITUDE
        if inset * 2 >= WIDTH:
            return False
        mismatch = min(max_mismatch(level), gw - MIN_WINDOW)
        for _ in range(48):
            first = inset + self.rng.random() * (WIDTH - 2 * inset)
            error = self.rng.uniform(-1, 1) * mismatch
            second = WIDTH - first + error
            if not (inset <= second <= WIDTH - inset):
                continue
            window_width = gw - abs(error)
            if window_width < MIN_WINDOW:
                continue
            window_center = first - error / 2
            anchor = WIDTH / 2 if self.last_window_center < 0 else self.last_window_center
            if abs(window_center - anchor) > max_jump(level):
                continue
            row.gaps = [(first, gw), (second, gw)]
            row.window_center = window_center
            row.window_width = window_width
            if window_width >= MOVING_MIN_WINDOW and self.rng.random() < moving_chance(level):
                row.wave = True
                row.wave_amp = WAVE_AMPLITUDE
                row.wave_phase = self.rng.random() * 6.2831855
            return True
        return False

    def try_easy_mirror(self, row, level):
        gw = gap_width(level)
        half = gw / 2 + EDGE_MARGIN
        if half * 2 >= WIDTH:
            return False
        anchor = WIDTH / 2 if self.last_window_center < 0 else self.last_window_center
        center = clamp(anchor, half, WIDTH - half)
        row.gaps = [(center, gw), (WIDTH - center, gw)]
        row.window_center = center
        row.window_width = gw
        return True

    def build_fallback(self, row, level):
        gw = gap_width(level) + SINGLE_GAP_EXTRA
        half = min(gw / 2, WIDTH / 2)
        anchor = WIDTH / 2 if self.last_window_center < 0 else self.last_window_center
        center = clamp(anchor, half, WIDTH - half)
        row.gaps = [(center, gw), (WIDTH - center, gw)]
        row.window_center = center
        row.window_width = gw

    def spawn(self, level):
        row = Row()
        breather = self.rows_since_breather >= BREATHER_EVERY_ROWS or self.last_window_center < 0
        wants_two = (not breather) and self.rng.random() < two_gap_chance(level)

        if breather:
            built = self.try_single_gap(row, level) or self.try_easy_mirror(row, level)
            self.rows_since_breather = 0
        elif wants_two:
            built = self.try_two_gaps(row, level)
        else:
            built = self.try_single_gap(row, level) or self.try_two_gaps(row, level)

        if not built and not self.try_easy_mirror(row, level):
            self.build_fallback(row, level)
        if not breather:
            self.rows_since_breather += 1

        self.last_window_center = row.window_center
        self.log.append((level, row.window_center, row.window_width, row.wave))
        return row


def circle_hits_rect(cx, cy, radius, left, top, right, bottom):
    nx = clamp(cx, left, right)
    ny = clamp(cy, top, bottom)
    dx, dy = cx - nx, cy - ny
    return dx * dx + dy * dy <= radius * radius


def window_is_inside_screen(center, width):
    return center - width / 2 >= 0 - 0.5 and center + width / 2 <= WIDTH + 0.5


# --- test 1: generator invariants -------------------------------------------
def check_generator(rows_per_level=400, levels=range(1, 13)):
    gen = Generator(seed=7)
    bad_window = 0
    bad_jump = 0
    previous = None
    for level in levels:
        for _ in range(rows_per_level):
            row = gen.spawn(float(level))
            if row.window_width + 1e-6 < MIN_WINDOW:
                bad_window += 1
            if not window_is_inside_screen(row.window_center, row.window_width):
                bad_window += 1
            if previous is not None and abs(row.window_center - previous.window_center) > max_jump(level) + 1e-3:
                bad_jump += 1
            previous = row
    total = rows_per_level * len(list(levels))
    print(f"[generator] rows={total} bad_window={bad_window} bad_jump={bad_jump}")
    return bad_window == 0 and bad_jump == 0


# --- test 2/3: simulated runs ------------------------------------------------
def simulate(seed, skill, max_seconds=600.0, log=False,
             reaction=0.22, sight=340.0, vmax_human=760.0):
    """skill: 'perfect' teleports into the safe window; 'human' has a sight range,
    a reaction delay, a lateral speed limit and the same 0.08 s smoothing as the game."""
    gen = Generator(seed)
    dt = 1.0 / 60.0
    rows = []
    distance_since_spawn = spacing(1) - speed(1) * 0.6
    rows_cleared = 0
    rows_since_breather = 0
    elapsed = 0.0
    x = WIDTH * 0.3
    vmax = 1500.0 if skill == "perfect" else vmax_human   # dp/s lateral speed
    radius = PLAYER_RADIUS * COLLISION_FORGIVENESS
    pending = []          # (deliver_at, target) queue standing in for reaction time
    known_target = WIDTH * 0.5

    while elapsed < max_seconds:
        elapsed += dt
        level = 1 + rows_cleared / 8.0
        sp = speed(level)
        spc = spacing(level)

        # pick a target: centre of the safe window of the nearest not-yet-passed row
        target = gen.last_window_center if gen.last_window_center >= 0 else WIDTH / 2
        # The row that matters is the lowest one that has not passed the player band yet,
        # including the row currently crossing it.
        if skill == "perfect":
            relevant = [r for r in rows if r.y <= PLAYER_Y + PLAYER_RADIUS]
            if relevant:
                nearest = max(relevant, key=lambda r: r.y)
                target = nearest.window_center + nearest.offset
        else:
            visible = [r for r in rows if r.y + r.height >= PLAYER_Y - sight
                       and r.y <= PLAYER_Y + PLAYER_RADIUS]
            if visible:
                nearest = max(visible, key=lambda r: r.y)
                pending.append((elapsed + reaction, nearest.window_center + nearest.offset))
            while pending and pending[0][0] <= elapsed:
                known_target = pending.pop(0)[1]
            target = known_target
        target = clamp(target, PLAYER_RADIUS, WIDTH - PLAYER_RADIUS)
        if skill == "perfect":
            x = target
        else:
            dx = target - x
            step = vmax * dt
            x += clamp(dx, -step, step)
        x = clamp(x, PLAYER_RADIUS, WIDTH - PLAYER_RADIUS)

        for row in rows:
            row.y += sp * dt
            if row.wave:
                row.offset = math.sin(elapsed * 2 * math.pi / WAVE_PERIOD + row.wave_phase) * row.wave_amp
            if not row.scored and row.y > PLAYER_Y + PLAYER_RADIUS:
                row.scored = True
                rows_cleared += 1
        rows = [r for r in rows if r.y <= HEIGHT + r.height]

        distance_since_spawn += sp * dt
        if distance_since_spawn >= spc:
            distance_since_spawn = 0.0
            rows.append(gen.spawn(level))

        # collision
        for row in rows:
            top, bottom = row.y, row.y + row.height
            if bottom < PLAYER_Y - radius or top > PLAYER_Y + radius:
                continue
            for left, right in row.segments():
                if circle_hits_rect(x, PLAYER_Y, radius, left, top, right, bottom):
                    if log:
                        print(f"  death: t={elapsed:.2f}s level={level:.2f} rows={rows_cleared}")
                    return rows_cleared, elapsed
    return rows_cleared, elapsed


def check_playability():
    ok = True
    print("[perfect player] should never die (no impossible rows)")
    for seed in range(1, 6):
        cleared, t = simulate(seed, "perfect", max_seconds=120.0)
        reached_level = 1 + cleared / 8.0
        print(f"  seed={seed} rows={cleared} level={reached_level:.1f} time={t:.1f}s")
        if t < 119.9:
            ok = False
    print("[human-ish player] balance snapshot")
    results = []
    for seed in range(1, 11):
        cleared, t = simulate(seed, "human", max_seconds=180.0)
        results.append((cleared, t))
    results.sort()
    median_rows = results[len(results) // 2][0]
    print(f"  runs={len(results)} rows min/median/max = "
          f"{results[0][0]}/{median_rows}/{results[-1][0]}")
    print(f"  median level reached = {1 + median_rows / 8.0:.2f}")
    return ok


if __name__ == "__main__":
    generator_ok = check_generator()
    playable_ok = check_playability()
    print("RESULT:", "PASS" if generator_ok and playable_ok else "FAIL")
