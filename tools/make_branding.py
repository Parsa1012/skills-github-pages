#!/usr/bin/env python3
"""Draws the game logo and every launcher icon from code, so the artwork is exactly
centred and exactly symmetric.

The earlier logo came out of an image model: the badge was off by a couple of pixels and
the two orbs were not quite the same size, which showed up once the art was scaled down to
48 px and cropped by the launcher mask. Everything here is built from signed distance
fields in numpy, so the orbs are pixel-identical mirror copies and the centre line is the
real centre of the canvas.

Run from the repo root:  python3 tools/make_branding.py
Outputs: mirror/art/logo-v12.png (master), res/drawable-nodpi/logo.png,
         res/drawable-nodpi/ic_launcher_foreground.png, res/mipmap-*/ic_launcher[_round].png
"""

import os

import numpy as np
from PIL import Image

MASTER = 1024
ART = os.path.join("mirror", "art")

BLUE = (0x3B, 0x82, 0xF6)
RED = (0xEF, 0x44, 0x44)
BLUE_GLOW = (0x7D, 0xB4, 0xFF)
RED_GLOW = (0xFF, 0x8A, 0x8A)
# Exactly the game's night background: a flat plate cannot band, and the icon then matches
# the canvas the player actually sees.
BG = (0x0B, 0x0F, 0x1A)
RING = (0x2C, 0x3D, 0x5C)
AXIS = (0x3C, 0x4E, 0x6E)

ORB_RADIUS = 100.0
ORB_OFFSET = 180.0


def _grid(size):
    y, x = np.mgrid[0:size, 0:size].astype(np.float32)
    return x + 0.5, y + 0.5


def _rounded_rect_sdf(x, y, cx, cy, half, radius):
    qx = np.abs(x - cx) - (half - radius)
    qy = np.abs(y - cy) - (half - radius)
    outside = np.sqrt(np.maximum(qx, 0.0) ** 2 + np.maximum(qy, 0.0) ** 2)
    inside = np.minimum(np.maximum(qx, qy), 0.0)
    return outside + inside - radius


def _coverage(sdf):
    """1 px wide antialiased edge from a signed distance field."""
    return np.clip(0.5 - sdf, 0.0, 1.0)


BAYER4 = np.array([[0, 8, 2, 10],
                   [12, 4, 14, 6],
                   [3, 11, 1, 9],
                   [15, 7, 13, 5]], dtype=np.float32) / 16.0 - 0.5


def _dither(rgb, amount=1.6):
    """Ordered (Bayer) dithering, ~1.6 of an 8-bit level.

    The plate is a very dark gradient, so adjacent bands land on neighbouring palette
    entries and the eye picks the boundary out. A tiny ordered pattern breaks the bands and
    compresses far better than random noise.
    """
    h, w = rgb.shape[:2]
    tile = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w][..., None]
    return rgb + tile * amount


def _over(base_rgb, base_a, color, alpha):
    """Straight-alpha 'over' compositing with a constant colour layer."""
    a = np.clip(alpha, 0.0, 1.0)[..., None]
    ba = base_a[..., None]
    out_a = a + ba * (1.0 - a)
    out_rgb = (np.array(color, dtype=np.float32) * a
               + base_rgb * ba * (1.0 - a)) / np.maximum(out_a, 1e-6)
    return out_rgb, out_a[..., 0]


def render_art(size, centre, extent):
    """Orbs + dashes on a transparent canvas.

    ``extent`` is the width of the square the artwork is fitted into, in pixels; the art is
    drawn around ``centre`` so it is centred by construction.
    """
    x, y = _grid(size)
    scale = extent / 1024.0                      # artwork designed on a 1024 grid
    cx, cy = centre
    art_x = (x - (size / 2.0)) / scale + 512.0
    art_y = (y - (size / 2.0)) / scale + 512.0

    rgb = np.zeros((size, size, 3), dtype=np.float32)
    alpha = np.zeros((size, size), dtype=np.float32)

    # dashes of the mirror axis
    dash, gap, half_w = 30.0, 26.0, 4.0
    in_span = (art_y >= 250.0) & (art_y <= 774.0)
    phase = np.mod(art_y - 250.0, dash + gap) < dash
    axis = _coverage(np.abs(art_x - 512.0) - half_w) * (phase & in_span) * 0.75
    rgb, alpha = _over(rgb, alpha, AXIS, axis)

    for sign, core, glow in ((-1.0, BLUE, BLUE_GLOW), (1.0, RED, RED_GLOW)):
        ox = 512.0 + sign * ORB_OFFSET
        oy = 512.0
        d = np.sqrt((art_x - ox) ** 2 + (art_y - oy) ** 2)
        # outer bloom
        bloom = np.exp(-((d / (ORB_RADIUS * 1.80)) ** 2) * 3.0) * 0.55
        rgb, alpha = _over(rgb, alpha, glow, bloom * _coverage(d - ORB_RADIUS * 2.6))
        # body: slightly lighter towards the upper-left, like a lit sphere
        shade = np.clip(((art_x - ox) * -0.32 + (art_y - oy) * -0.32) / ORB_RADIUS, -1.0, 1.0)
        body_rgb = (np.array(core, dtype=np.float32)[None, None, :]
                    * (1.0 + 0.16 * shade[..., None]))
        body_a = _coverage(d - ORB_RADIUS)[..., None]
        base_a = alpha[..., None]
        out_a = body_a + base_a * (1.0 - body_a)
        rgb = (body_rgb * body_a + rgb * base_a * (1.0 - body_a)) / np.maximum(out_a, 1e-6)
        alpha = out_a[..., 0]
        # rim
        rim = _coverage(np.abs(d - (ORB_RADIUS - 2.0)) - 2.0) * 0.35
        rgb, alpha = _over(rgb, alpha, (255, 255, 255), rim)
        # specular
        sx, sy = ox - ORB_RADIUS * 0.30, oy - ORB_RADIUS * 0.32
        spec = np.exp(-(((art_x - sx) ** 2 + (art_y - sy) ** 2) / (2.0 * (ORB_RADIUS * 0.22) ** 2)))
        rgb, alpha = _over(rgb, alpha, (255, 255, 255), spec * 0.45 * body_a[..., 0])

    out = np.zeros((size, size, 4), dtype=np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(alpha * 255.0, 0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def render_badge(size):
    """The full app icon: rounded navy plate with the artwork on top."""
    x, y = _grid(size)
    s = size / 1024.0
    half = 512.0 * s
    radius = 210.0 * s

    sdf = _rounded_rect_sdf(x, y, size / 2.0, size / 2.0, half - 1.0, radius)
    plate = _coverage(sdf)

    rgb = np.ones((size, size, 3), dtype=np.float32) * np.array(BG, dtype=np.float32)

    # inner hairline ring
    ring = _coverage(np.abs(sdf + 9.0 * s) - 1.6 * s) * 0.8
    rgb = rgb * (1.0 - ring[..., None]) + np.array(RING, dtype=np.float32) * ring[..., None]

    art = render_art(size, (size / 2.0, size / 2.0), size)
    art_rgb = np.asarray(art, dtype=np.float32)[..., :3]
    art_a = np.asarray(art, dtype=np.float32)[..., 3] / 255.0

    out_rgb = art_rgb * art_a[..., None] + rgb * (1.0 - art_a[..., None])
    out = np.zeros((size, size, 4), dtype=np.uint8)
    out[..., :3] = np.clip(out_rgb, 0, 255).astype(np.uint8)
    out[..., 3] = np.clip(plate * 255.0, 0, 255).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def circle_crop(image):
    size = image.size[0]
    x, y = _grid(size)
    r = size / 2.0
    mask = np.clip(0.5 - (np.sqrt((x - r) ** 2 + (y - r) ** 2) - (r - 1.0)), 0.0, 1.0)
    arr = np.asarray(image, dtype=np.float32).copy()
    arr[..., 3] *= mask
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def save(image, path):
    """Writes the icon with ordered dithering applied at *final* resolution.

    Dithering has to happen after the downscale: a 4 px Bayer tile from the master turns
    into moiré once it is resampled, which is what produced the diagonal streaks in the
    first version of this artwork.
    """
    os.makedirs(os.path.dirname(path), exist_ok=True)
    arr = np.asarray(image.convert("RGBA"), dtype=np.float32)
    rgb = _dither(arr[..., :3], amount=1.1)
    arr[..., :3] = np.clip(rgb, 0, 255)
    out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    out.save(path, optimize=True)
    return os.path.getsize(path)


def symmetry_report(master):
    arr = np.asarray(master, dtype=np.int16)
    r, g, b, a = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]
    blue = (b > 120) & (b > r + 50) & (g < b) & (a > 200)
    red = (r > 120) & (r > g + 60) & (r > b + 20) & (a > 200)
    ys_b, xs_b = np.where(blue)
    ys_r, xs_r = np.where(red)
    print(f"  blue centroid  x={xs_b.mean():.2f} y={ys_b.mean():.2f} n={blue.sum()}")
    print(f"  red  centroid  x={xs_r.mean():.2f} y={ys_r.mean():.2f} n={red.sum()}")
    mid = (xs_b.mean() + xs_r.mean()) / 2.0
    print(f"  horizontal mirror error = {abs(mid - master.size[0] / 2):.2f} px, "
          f"vertical error = {abs(ys_b.mean() - ys_r.mean()):.2f} px, "
          f"size delta = {abs(blue.sum() - red.sum())} px")
    cy = (ys_b.mean() + ys_r.mean()) / 2.0
    print(f"  artwork centre y={cy:.2f} (canvas {master.size[1] / 2:.1f})")


def main():
    master = render_badge(MASTER)
    os.makedirs(ART, exist_ok=True)
    master.save(os.path.join(ART, "logo-v12.png"), optimize=True)
    symmetry_report(master)

    size = save(master.resize((384, 384), Image.LANCZOS),
                "mirror/src/main/res/drawable-nodpi/logo.png")
    print(f"  drawable-nodpi/logo.png {size} B")

    # Adaptive foreground: artwork only, kept inside the 66 dp safe zone of the 108 dp
    # canvas, so no launcher mask can clip an orb.
    foreground = render_art(432, (216, 216), 264)
    size = save(foreground, "mirror/src/main/res/drawable-nodpi/ic_launcher_foreground.png")
    print(f"  drawable-nodpi/ic_launcher_foreground.png {size} B")

    for density, px in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                        ("xxhdpi", 144), ("xxxhdpi", 192)):
        square = save(master.resize((px, px), Image.LANCZOS),
                      f"mirror/src/main/res/mipmap-{density}/ic_launcher.png")
        rounded = save(circle_crop(master).resize((px, px), Image.LANCZOS),
                       f"mirror/src/main/res/mipmap-{density}/ic_launcher_round.png")
        print(f"  mipmap-{density}: {px}px square={square} B round={rounded} B")


if __name__ == "__main__":
    main()
