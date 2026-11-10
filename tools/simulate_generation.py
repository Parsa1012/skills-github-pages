#!/usr/bin/env python3
"""Offline sanity checks for the row generator and the row pattern.

This is a faithful port of the fairness maths in GameEngine/LevelConfig/Difficulty. It runs
the generator and two virtual players (a perfect one and a reaction-limited one) so the
"is every row clearable?" question is answered by simulation instead of guesswork, and it
also reports the mix of the two row archetypes (bodies together vs. pulled wide apart).

Run: python3 tools/simulate_generation.py                  # all three presets
     python3 tools/simulate_generation.py --difficulty hard
"""

import math
import random
import sys

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
MIN_SLIVER = 14.0
BREATHER_EVERY_ROWS = 7

SPEED_TABLE = [150, 190, 230, 270, 310]
SPACING_TABLE = [320, 300, 280, 260, 240]
GAP_TABLE = [96, 92, 88, 84, 80]

# A quick swipe, used to keep the required between-row travel honest (GameEngine).
HUMAN_SWIPE_DP_PER_SECOND = 1100.0

# Mirrors Difficulty.java.
DIFFICULTIES = {
    "easy": dict(speed=0.88, spacing=1.14, gap_bonus=6.0, mismatch=0.72,
                 moving=0.55, min_window_bonus=5.0, apart=0.95, switch=0.55),
    "normal": dict(speed=1.00, spacing=1.00, gap_bonus=0.0, mismatch=1.00,
                   moving=1.00, min_window_bonus=0.0, apart=1.00, switch=0.62),
    "hard": dict(speed=1.15, spacing=0.88, gap_bonus=-6.0, mismatch=1.20,
                 moving=1.15, min_window_bonus=-4.0, apart=1.10, switch=0.72),
}
ACTIVE_NAME = "normal"
ACTIVE = DIFFICULTIES[ACTIVE_NAME]

TOGETHER = "T"
APART = "A"


def use(name):
    """Switches the simulated preset (see Difficulty.java)."""
    global ACTIVE_NAME, ACTIVE
    ACTIVE_NAME = name
    ACTIVE = DIFFICULTIES[name]


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
    return sample(SPEED_TABLE, level, 40, 520, True) * ACTIVE["speed"]


def spacing(level):
    return sample(SPACING_TABLE, level, -15, 170, False) * ACTIVE["spacing"]


def gap_width(level):
    return max(24.0, sample(GAP_TABLE, level, -3, 78, False) + ACTIVE["gap_bonus"])


def single_gap_width(level):
    return max(40.0, gap_width(level) + SINGLE_GAP_EXTRA)


def min_window():
    return max(20.0, MIN_WINDOW + ACTIVE["min_window_bonus"])


def max_mismatch(level):
    budget = gap_width(level) - min_window()
    if budget <= 0:
        return 0.0
    raw = budget * (0.35 + 0.65 * clamp01((level - 1) / 5.0))
    return min(budget, raw * ACTIVE["mismatch"])


def moving_chance(level):
    raw = 0.0 if level < 4 else min(0.28, 0.12 * (level - 3))
    return clamp(raw * ACTIVE["moving"], 0.0, 0.50)


def switch_chance(level):
    return clamp(ACTIVE["switch"] + 0.08 * clamp01((level - 1) / 8.0), 0.30, 0.85)


def max_travel(level):
    return max(WIDTH * 0.30, HUMAN_SWIPE_DP_PER_SECOND * spacing(level) / max(1.0, speed(level)))


def apart_max_offset(level):
    return WIDTH * (0.26 + 0.10 * clamp01((level - 1) / 8.0)) * ACTIVE["apart"]


class Row:
    def __init__(self):
        self.y = -ROW_HEIGHT
        self.height = ROW_HEIGHT
        self.gaps = []          # list of (centre, width)
        self.window_center = 0.0
        self.window_width = 0.0
        self.wave = False
        self.wave_amp = 0.0
        self.wave_phase = 0.0
        self.offset = 0.0
        self.scored = False
        self.mode = TOGETHER

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
        self.last_spread = None
        self.spread_run = 0
        self.modes = []

    # -- helpers ------------------------------------------------------------
    def next_spread(self, level):
        if self.last_spread is None:
            return APART if self.rng.random() < 0.5 else TOGETHER
        opposite = TOGETHER if self.last_spread == APART else APART
        if self.spread_run >= 2:
            return opposite
        return opposite if self.rng.random() < switch_chance(level) else self.last_spread

    def try_together(self, row, level):
        gw = single_gap_width(level)
        if gw >= WIDTH - 2 * EDGE_MARGIN:
            return False
        max_offset = max(0.0, (gw - min_window()) / 2)
        max_offset = min(max_offset, max(0.0, WIDTH / 2 - gw / 2 - MIN_SLIVER))
        for _ in range(48):
            center = WIDTH / 2 + self.rng.uniform(-1, 1) * max_offset
            window_width = gw - abs(2 * center - WIDTH)
            if window_width < min_window():
                continue
            row.gaps = [(center, gw)]
            row.window_center = WIDTH / 2
            row.window_width = window_width
            return True
        return False

    def try_apart(self, row, level):
        gw = gap_width(level)
        half = WIDTH / 2
        min_offset = max((gw + MIN_SLIVER) / 2, WIDTH * 0.16)
        max_offset = apart_max_offset(level)
        if max_offset <= min_offset:
            return False
        mismatch = max_mismatch(level)
        anchor = half if self.last_window_center < 0 else self.last_window_center
        travel = max_travel(level)
        edge = gw / 2 + EDGE_MARGIN
        for _ in range(48):
            side = 1.0 if self.rng.random() < 0.5 else -1.0
            reachable = (anchor + travel - half) if side > 0 else (half - anchor + travel)
            limit = min(max_offset, reachable)
            if limit < min_offset:
                continue
            bias = math.sqrt(self.rng.random())
            offset = min_offset + (limit - min_offset) * bias
            window_center = half + side * offset
            error = self.rng.uniform(-1, 1) * mismatch
            first = window_center + error / 2
            second = WIDTH - window_center + error / 2
            if not (edge <= first <= WIDTH - edge and edge <= second <= WIDTH - edge):
                continue
            if abs(first - second) - gw < MIN_SLIVER:
                continue
            window_width = gw - abs(error)
            if window_width < min_window():
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
        half = gw / 2 + EDGE_MARGIN + MIN_SLIVER
        if half * 2 >= WIDTH:
            return False
        anchor = WIDTH / 2 if self.last_window_center < 0 else self.last_window_center
        center = clamp(anchor, half, WIDTH - half)
        row.gaps = [(center, gw), (WIDTH - center, gw)]
        row.window_center = center
        row.window_width = gw
        return True

    def build_fallback(self, row, level):
        gw = single_gap_width(level)
        half = min(gw / 2 + MIN_SLIVER, WIDTH / 2)
        anchor = WIDTH / 2 if self.last_window_center < 0 else self.last_window_center
        center = clamp(anchor, half, WIDTH - half)
        row.gaps = [(center, gw), (WIDTH - center, gw)]
        row.window_center = center
        row.window_width = gw

    def spawn(self, level):
        row = Row()
        breather = self.rows_since_breather >= BREATHER_EVERY_ROWS or self.last_window_center < 0
        wanted = TOGETHER if breather else self.next_spread(level)

        if wanted == APART:
            built = self.try_apart(row, level) or self.try_together(row, level)
        else:
            built = self.try_together(row, level) or self.try_apart(row, level)
        if not built and not self.try_easy_mirror(row, level):
            self.build_fallback(row, level)

        mode = APART if len(row.gaps) > 1 else TOGETHER
        row.mode = mode
        self.spread_run = self.spread_run + 1 if mode == self.last_spread else 1
        self.last_spread = mode
        self.modes.append(mode)

        if breather:
            self.rows_since_breather = 0
        else:
            self.rows_since_breather += 1

        self.last_window_center = row.window_center
        return row


def circle_hits_rect(cx, cy, radius, left, top, right, bottom):
    nx = clamp(cx, left, right)
    ny = clamp(cy, top, bottom)
    dx, dy = cx - nx, cy - ny
    return dx * dx + dy * dy <= radius * radius


def window_is_inside_screen(center, width):
    return center - width / 2 >= -0.5 and center + width / 2 <= WIDTH + 0.5


# --- test 1: generator invariants --------------------------------------------
def check_generator(rows_per_level=400, levels=range(1, 13)):
    gen = Generator(seed=7)
    bad_window = 0
    bad_sliver = 0
    unreachable = 0
    previous = None
    runs = []
    current_run = 0
    last_mode = None
    for level in levels:
        for _ in range(rows_per_level):
            row = gen.spawn(float(level))
            if row.window_width + 1e-6 < min_window():
                bad_window += 1
            if not window_is_inside_screen(row.window_center, row.window_width):
                bad_window += 1
            if len(row.gaps) == 2 and abs(row.gaps[0][0] - row.gaps[1][0]) - row.gaps[0][1] < MIN_SLIVER - 0.5:
                bad_sliver += 1
            if previous is not None:
                travel = abs(row.window_center - previous.window_center)
                if travel > max_travel(level) + 0.5:
                    unreachable += 1
            if row.mode == last_mode:
                current_run += 1
            else:
                if last_mode is not None:
                    runs.append(current_run)
                current_run = 1
                last_mode = row.mode
            previous = row

    modes = gen.modes
    apart_rate = modes.count(APART) / len(modes)
    switches = sum(1 for a, b in zip(modes, modes[1:]) if a != b)
    switch_rate = switches / (len(modes) - 1)
    longest = max(runs) if runs else 1
    print(f"[generator] rows={len(modes)} bad_window={bad_window} bad_sliver={bad_sliver} "
          f"unreachable={unreachable}")
    print(f"[pattern] apart={apart_rate * 100:.1f}% switches={switch_rate * 100:.1f}% "
          f"longest_run={longest}")
    return (bad_window == 0 and bad_sliver == 0 and unreachable == 0
            and 0.32 <= apart_rate <= 0.62 and switch_rate >= 0.50 and longest <= 3)


# --- test 2/3: simulated runs ------------------------------------------------
def simulate(seed, skill, max_seconds=600.0, log=False,
             reaction=0.22, sight=340.0, vmax_human=760.0):
    """skill: 'perfect' teleports into the safe window; 'human' has a sight range,
    a reaction delay and a lateral speed limit."""
    gen = Generator(seed)
    dt = 1.0 / 60.0
    rows = []
    distance_since_spawn = spacing(1) - speed(1) * 0.6
    rows_cleared = 0
    elapsed = 0.0
    x = WIDTH * 0.3
    vmax = 4000.0 if skill == "perfect" else vmax_human
    radius = PLAYER_RADIUS * COLLISION_FORGIVENESS
    scheduled = {}          # id(row) -> time the player will know its position
    known_target = WIDTH * 0.5

    while elapsed < max_seconds:
        elapsed += dt
        level = 1 + rows_cleared / 8.0
        sp = speed(level)
        spc = spacing(level)

        if skill == "perfect":
            relevant = [r for r in rows if r.y <= PLAYER_Y + PLAYER_RADIUS]
            if relevant:
                nearest = max(relevant, key=lambda r: r.y)
                target = nearest.window_center + nearest.offset
            else:
                target = WIDTH / 2
        else:
            live = [r for r in rows if r.y + r.height >= PLAYER_Y - sight
                    and r.y <= PLAYER_Y + PLAYER_RADIUS]
            if live:
                nearest = max(live, key=lambda r: r.y)
                if id(nearest) not in scheduled:
                    scheduled[id(nearest)] = elapsed + reaction
            for key in list(scheduled):
                if scheduled[key] <= elapsed:
                    del scheduled[key]
                    known_target = nearest.window_center + nearest.offset if live else WIDTH / 2
            target = known_target
        target = clamp(target, PLAYER_RADIUS, WIDTH - PLAYER_RADIUS)

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


def run_preset(name):
    use(name)
    print(f"===== difficulty: {name} =====")
    generator_ok = check_generator()
    playable_ok = check_playability()
    print(f"RESULT[{name}]:", "PASS" if generator_ok and playable_ok else "FAIL")
    return generator_ok and playable_ok


if __name__ == "__main__":
    requested = None
    args = sys.argv[1:]
    for i, arg in enumerate(args):
        if arg == "--difficulty" and i + 1 < len(args):
            requested = args[i + 1]
        elif arg.startswith("--difficulty="):
            requested = arg.split("=", 1)[1]
    presets = [requested] if requested else ["easy", "normal", "hard"]
    for preset in presets:
        if preset not in DIFFICULTIES:
            raise SystemExit(f"unknown difficulty: {preset}")
    ok = True
    for preset in presets:
        ok = run_preset(preset) and ok
    print("RESULT:", "PASS" if ok else "FAIL")
