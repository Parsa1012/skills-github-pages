#!/usr/bin/env python3
"""Renders preview mocks of the v1.1 overlay UI (menu + settings).

These are not screenshots from a device: they recreate the same layout numbers and the
same Theme palette with Pillow + the real Vazirmatn font, so text fitting and contrast can
be reviewed without an emulator. Run from the repo root:

    python3 tools/mock_ui_v11.py
"""

import math
import os

import arabic_reshaper
from bidi.algorithm import get_display
from PIL import Image, ImageDraw, ImageFont

SCALE = 2  # 360x640 dp canvas, drawn at 2x
W, H = 360 * SCALE, 640 * SCALE

FONT_DIR = os.environ.get("VAZIR_DIR", "/tmp/vazir/package/fonts/ttf")
FONT_REG = os.path.join(FONT_DIR, "Vazirmatn-Regular.ttf")
FONT_BOLD = os.path.join(FONT_DIR, "Vazirmatn-Bold.ttf")

NIGHT = dict(bg="#0B0F1A", grid="#141C2B", axis="#2B3A55",
             text="#E6EDF3", text2="#9AA6B8", muted="#6E7681",
             primary="#22D3EE", primary_text="#08121F",
             secondary="#1B2430", secondary_text="#E6EDF3",
             panel="#161B22", stroke="#233047", pink="#F472B6")
DAY = dict(bg="#F2F5FB", grid="#E1E8F4", axis="#C0CDE2",
           text="#0F172A", text2="#475569", muted="#7A8699",
           primary="#0EA5E9", primary_text="#FFFFFF",
           secondary="#E7EEF9", secondary_text="#0F172A",
           panel="#FFFFFF", stroke="#D3DDEE", pink="#DB2777")


def fa(text):
    return get_display(arabic_reshaper.reshape(text))


def font(size_dp, bold=False):
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, int(size_dp * SCALE))


def text(draw, xy, s, size, color, bold=False, anchor="mm"):
    draw.text(xy, fa(s), font=font(size, bold), fill=color, anchor=anchor)


def dashed_line(draw, x1, y, x2, color, dash=14, gap=22, width=2):
    x = x1
    while x < x2:
        draw.line([(x, y), (min(x + dash, x2), y)], fill=color, width=width)
        x += dash + gap


def dashed_vertical(draw, x, y1, y2, color, dash=14, gap=22, width=2):
    y = y1
    while y < y2:
        draw.line([(x, y), (x, min(y + dash, y2))], fill=color, width=width)
        y += dash + gap


def background(palette, overlay_alpha=0.0):
    img = Image.new("RGBA", (W, H), palette["bg"])
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    step = 48 * SCALE
    for x in range(-step, W + step, step):
        d.line([(x, 0), (x, H)], fill=palette["grid"], width=SCALE)
    for y in range(-step, H + step, step):
        d.line([(0, y), (W, y)], fill=palette["grid"], width=SCALE)
    dashed_vertical(d, W // 2, 0, H, palette["axis"])
    img.alpha_composite(layer)
    if overlay_alpha > 0:
        veil = Image.new("RGBA", (W, H),
                         Image.new("RGBA", (1, 1), palette["bg"]).getpixel((0, 0))[:3]
                         + (int(255 * overlay_alpha),))
        img.alpha_composite(veil)
    return img


def rounded(draw, box, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def menu_mock(path):
    p = NIGHT
    img = background(p, overlay_alpha=0.95)
    # The activity centres the menu block (Gravity.CENTER); draw it on a layer and centre it.
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    logo = Image.open("mirror/src/main/res/drawable-nodpi/logo.png").convert("RGBA")
    logo_size = 104 * SCALE
    logo = logo.resize((logo_size, logo_size), Image.LANCZOS)
    layer.alpha_composite(logo, (W // 2 - logo_size // 2, int(16 * SCALE)))

    y = 16 * SCALE + logo_size
    y += 14 * SCALE
    text(d, (W // 2, y), "هم‌زاد", 34, p["text"], bold=True, anchor="ma")
    y += 46 * SCALE
    text(d, (W // 2, y), "یک انگشت، دو نیمه", 14, p["primary"], anchor="ma")
    y += 30 * SCALE
    text(d, (W // 2, y), "رکورد  120", 14, p["pink"], bold=True, anchor="ma")
    y += 26 * SCALE
    text(d, (W // 2, y), "سختی: متوسط", 12, p["muted"], anchor="ma")

    y += 26 * SCALE
    btn_h = 27 * SCALE
    rounded(d, [28 * SCALE, y, W - 28 * SCALE, y + btn_h], 14 * SCALE, fill=p["primary"])
    text(d, (W // 2, y + btn_h / 2), "شروع", 16, p["primary_text"], bold=True)

    y += btn_h + 10 * SCALE
    btn2 = 24 * SCALE
    rounded(d, [28 * SCALE, y, W - 28 * SCALE, y + btn2], 14 * SCALE,
            fill=p["secondary"], outline=p["stroke"], width=SCALE)
    text(d, (W // 2, y + btn2 / 2), "تنظیمات", 15, p["secondary_text"])

    y += btn2 + 16 * SCALE
    text(d, (W // 2, y), "انگشت را بکشید تا هر دو دایره با هم حرکت کنند.", 12, p["muted"],
         anchor="ma")
    text(d, (W // 2, y + 20 * SCALE), "اگر یکی از آن‌ها بمیرد، بازی تمام است.", 12,
         p["muted"], anchor="ma")

    bbox = layer.getbbox()
    offset = int((H - (bbox[3] - bbox[1])) / 2) - bbox[1]
    img.alpha_composite(layer, (0, offset))

    img.convert("RGB").save(path, optimize=True)
    return path


def chip(d, box, label, selected, p, size=14):
    rounded(d, box, 12 * SCALE,
            fill=p["primary"] if selected else p["secondary"],
            outline=p["primary"] if selected else p["stroke"], width=SCALE)
    cx = (box[0] + box[2]) / 2
    cy = (box[1] + box[3]) / 2
    text(d, (cx, cy), label, size,
         p["primary_text"] if selected else p["secondary_text"], bold=selected)


def settings_mock(path):
    p = DAY
    img = background(p, overlay_alpha=0.95)

    # Layout is computed first so the card can wrap its content and sit centred, which is
    # what the LinearLayout + Gravity.CENTER combination does on the device.
    label_h = 20 * SCALE
    chip_h = 44 * SCALE
    gap = 8 * SCALE
    pad_x = 22 * SCALE
    pad_y = 22 * SCALE
    section_gap = 16 * SCALE
    button_h = 48 * SCALE

    content_h = (pad_y + 26 * SCALE + 34 * SCALE
                 + (label_h + 6 * SCALE + chip_h + section_gap) * 3
                 + 6 * SCALE + button_h + pad_y)
    card_w = 312 * SCALE
    left = (W - card_w) // 2
    right = left + card_w
    top = (H - content_h) // 2
    bottom = top + content_h

    card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dc = ImageDraw.Draw(card)
    rounded(dc, [left, top, right, bottom], 22 * SCALE, fill=p["panel"],
            outline=p["stroke"], width=SCALE)
    img.alpha_composite(card)

    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    inner_l = left + pad_x
    inner_r = right - pad_x

    y = top + pad_y
    text(d, (W // 2, y + 12 * SCALE), "تنظیمات", 20, p["text"], bold=True)
    y += 26 * SCALE + 34 * SCALE

    def section(label, options, columns):
        nonlocal y
        text(d, (W // 2, y + label_h / 2), label, 13, p["muted"])
        y += label_h + 6 * SCALE
        cw = (inner_r - inner_l - gap * (columns - 1)) / columns
        for i, (caption, selected) in enumerate(options):
            x1 = inner_l + i * (cw + gap)
            chip(d, [x1, y, x1 + cw, y + chip_h], caption, selected, p)
        y += chip_h + section_gap

    section("درجه سختی", [("آسان", False), ("متوسط", True), ("دشوار", False)], 3)
    section("حالت نمایش", [("شب", False), ("روز", True)], 2)
    section("صدا", [("روشن", True), ("خاموش", False)], 2)

    y += 6 * SCALE
    rounded(d, [inner_l, y, inner_r, y + button_h], 14 * SCALE, fill=p["primary"])
    text(d, (W // 2, y + button_h / 2), "بازگشت", 16, p["primary_text"], bold=True)

    img.alpha_composite(layer)
    img.convert("RGB").save(path, optimize=True)
    return path


if __name__ == "__main__":
    os.makedirs("docs/mirror", exist_ok=True)
    print(menu_mock("docs/mirror/preview-phase5-menu-mock.png"))
    print(settings_mock("docs/mirror/preview-phase5-settings-mock.png"))
