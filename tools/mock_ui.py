#!/usr/bin/env python3
"""Renders preview mocks of the v1.2 UI and of the new row pattern.

These are not screenshots from a device: they recreate the same layout numbers, the same
Theme palette and the same row geometry with Pillow + the real Vazirmatn font, so text
fitting, contrast and the "together / apart" rhythm can be reviewed without an emulator.

Run from the repo root:  python3 tools/mock_ui.py
"""

import math
import os

import arabic_reshaper
from bidi.algorithm import get_display
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

SCALE = 2  # 360x640 dp canvas, drawn at 2x
W, H = 360 * SCALE, 640 * SCALE

FONT_DIR = os.environ.get("VAZIR_DIR", "/tmp/vazir/package/fonts/ttf")
FONT_REG = os.path.join(FONT_DIR, "Vazirmatn-Regular.ttf")
FONT_BOLD = os.path.join(FONT_DIR, "Vazirmatn-Bold.ttf")

NIGHT = dict(bg="#0B0F1A", grid="#141C2B", axis="#2B3A55", row="#16233C", edge="#2F81F7",
             text="#E6EDF3", text2="#9AA6B8", muted="#71809A",
             primary="#3B82F6", primary_text="#FFFFFF",
             secondary="#1B2430", secondary_text="#E6EDF3",
             panel="#161B22", stroke="#233047", chip="#1E2836",
             blue="#3B82F6", red="#EF4444")
DAY = dict(bg="#F2F5FB", grid="#E3EAF5", axis="#C0CDE2", row="#C9D8EF", edge="#2563EB",
           text="#0F172A", text2="#475569", muted="#6B7A93",
           primary="#2563EB", primary_text="#FFFFFF",
           secondary="#E7EEF9", secondary_text="#0F172A",
           panel="#FFFFFF", stroke="#D3DDEE", chip="#EDF2FB",
           blue="#2563EB", red="#DC2626")


def fa(text):
    return get_display(arabic_reshaper.reshape(text))


def font(size_dp, bold=False):
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, int(size_dp * SCALE))


def text(draw, xy, s, size, color, bold=False, anchor="mm"):
    draw.text(xy, fa(s), font=font(size, bold), fill=color, anchor=anchor)


def rgb(hex_color):
    value = hex_color.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def rounded(draw, box, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def background(palette, overlay_alpha=0.0):
    img = Image.new("RGBA", (W, H), palette["bg"])
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    step = 48 * SCALE
    for x in range(-step, W + step, step):
        d.line([(x, 0), (x, H)], fill=palette["grid"], width=SCALE)
    for y in range(-step, H + step, step):
        d.line([(0, y), (W, y)], fill=palette["grid"], width=SCALE)
    y = 0
    while y < H:
        d.line([(W // 2, y), (W // 2, min(y + 14, H))], fill=palette["axis"], width=2)
        y += 36
    img.alpha_composite(layer)
    if overlay_alpha > 0:
        veil = Image.new("RGBA", (W, H),
                         Image.new("RGBA", (1, 1), palette["bg"]).getpixel((0, 0))[:3]
                         + (int(255 * overlay_alpha),))
        img.alpha_composite(veil)
    return img


def button(img, box, caption, size_dp, palette, primary, bold=True):
    d = ImageDraw.Draw(img)
    fill = palette["primary"] if primary else palette["secondary"]
    rounded(d, box, 14 * SCALE, fill=fill, outline=None if primary else palette["stroke"],
            width=SCALE)
    color = palette["primary_text"] if primary else palette["secondary_text"]
    text(d, ((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), caption, size_dp, color, bold=bold)


def menu_mock(path):
    p = NIGHT
    img = background(p, overlay_alpha=0.95)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    logo = Image.open("mirror/src/main/res/drawable-nodpi/logo.png").convert("RGBA")
    logo_size = 104 * SCALE
    logo = logo.resize((logo_size, logo_size), Image.LANCZOS)
    layer.alpha_composite(logo, (W // 2 - logo_size // 2, 16 * SCALE))

    y = 16 * SCALE + logo_size + 14 * SCALE
    text(d, (W // 2, y), "هم‌زاد", 34, p["text"], bold=True, anchor="ma")
    y += 46 * SCALE
    text(d, (W // 2, y), "یک انگشت، دو نیمه", 14, p["blue"], anchor="ma")
    y += 30 * SCALE
    text(d, (W // 2, y), "رکورد  120", 14, p["red"], bold=True, anchor="ma")
    y += 26 * SCALE
    text(d, (W // 2, y), "سختی: متوسط", 12, p["muted"], anchor="ma")
    y += 26 * SCALE

    button(layer, [28 * SCALE, y, W - 28 * SCALE, y + 27 * SCALE], "شروع", 16, p, True)
    y += 27 * SCALE + 10 * SCALE
    button(layer, [28 * SCALE, y, W - 28 * SCALE, y + 25 * SCALE], "تنظیمات", 15, p, False,
           bold=False)
    y += 25 * SCALE + 16 * SCALE
    text(d, (W // 2, y), "انگشت را بکشید تا هر دو دایره با هم حرکت کنند.", 12, p["muted"],
         anchor="ma")
    text(d, (W // 2, y + 20 * SCALE), "اگر یکی از آن‌ها بمیرد، بازی تمام است.", 12, p["muted"],
         anchor="ma")

    bbox = layer.getbbox()
    offset = int((H - (bbox[3] - bbox[1])) / 2) - bbox[1]
    img.alpha_composite(layer, (0, offset))
    img.convert("RGB").save(path, optimize=True)
    return path


def chip_row(img, p, left, right, y, height, captions, selected_index,
             size_dp=15, gap=8, rtl=True):
    order = list(range(len(captions)))
    if rtl:
        order = order[::-1]
    count = len(captions)
    cw = (right - left - gap * SCALE * (count - 1)) / count
    d = ImageDraw.Draw(img)
    for slot, index in enumerate(order):
        x1 = left + slot * (cw + gap * SCALE)
        box = [x1, y, x1 + cw, y + height]
        selected = index == selected_index
        rounded(d, box, 13 * SCALE,
                fill=p["primary"] if selected else p["chip"],
                outline=p["primary"] if selected else p["stroke"], width=SCALE)
        text(d, ((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), captions[index], size_dp,
             p["primary_text"] if selected else p["text2"], bold=selected)


def settings_mock(path):
    p = DAY
    img = background(p, overlay_alpha=0.95)
    d = ImageDraw.Draw(img)

    card_w = 320 * SCALE
    left = (W - card_w) // 2
    right = left + card_w
    top = 42 * SCALE
    height = 404 * SCALE
    rounded(d, [left, top, right, top + height], 22 * SCALE, fill=p["panel"],
            outline=p["stroke"], width=SCALE)

    inner_l, inner_r = left + 20 * SCALE, right - 20 * SCALE
    y = top + 20 * SCALE
    text(d, (W // 2, y + 12 * SCALE), "تنظیمات", 20, p["text"], bold=True)
    y += 46 * SCALE

    for label, captions, selected in (
            ("درجه سختی", ["آسان", "متوسط", "دشوار"], 1),
            ("حالت نمایش", ["شب", "روز"], 1),
            ("صدا", ["روشن", "خاموش"], 0)):
        text(d, (W // 2, y + 7 * SCALE), label, 12, p["muted"])
        y += 22 * SCALE
        chip_row(img, p, inner_l, inner_r, y, 46 * SCALE, captions, selected)
        y += 46 * SCALE + 16 * SCALE

    y += 6 * SCALE
    button(img, [inner_l, y, inner_r, y + 50 * SCALE], "بازگشت", 16, p, True)
    y += 50 * SCALE + 14 * SCALE
    text(d, (W // 2, y + 5 * SCALE), "تنظیمات به‌صورت خودکار ذخیره می‌شود", 11, p["muted"])

    img.convert("RGB").save(path, optimize=True)
    return path


def draw_row(img, p, top, height, gaps):
    """One wall with its openings punched out, matching ObstacleRow.segments() and the
    even-odd carving the renderer does (pill-shaped openings, hairline edge)."""
    mask = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, top, W - 1, top + height], 6 * SCALE, fill=255)
    for center, width in gaps:
        md.rounded_rectangle([center - width / 2, top, center + width / 2, top + height],
                             height / 2, fill=0)

    img.paste(Image.new("RGBA", (W, H), p["row"]), (0, 0), mask)
    edge = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(3)))
    img.paste(Image.new("RGBA", (W, H), p["edge"]), (0, 0), edge)


def ball(img, p, x, y, radius, color):
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gr = radius * 3
    gd.ellipse([x - gr, y - gr, x + gr, y + gr], fill=rgb(color) + (110,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(radius * 0.9)))
    d = ImageDraw.Draw(img)
    d.ellipse([x - radius, y - radius, x + radius, y + radius], fill=rgb(color))
    d.ellipse([x - radius, y - radius, x + radius, y + radius],
              outline=(255, 255, 255, 120), width=SCALE)


def gameplay_mock(path):
    p = NIGHT
    img = background(p)
    radius = 16 * SCALE
    row_h = 28 * SCALE
    player_y = 470 * SCALE

    # Together -> apart -> together -> apart, the rhythm the new generator produces.
    draw_row(img, p, 210 * SCALE, row_h, [(180 * SCALE, 104 * SCALE)])
    draw_row(img, p, 330 * SCALE, row_h, [(72 * SCALE, 88 * SCALE), (288 * SCALE, 88 * SCALE)])
    draw_row(img, p, 440 * SCALE, row_h, [(168 * SCALE, 100 * SCALE)])
    draw_row(img, p, player_y - row_h / 2, row_h,
             [(72 * SCALE, 88 * SCALE), (288 * SCALE, 88 * SCALE)])

    ball(img, p, 72 * SCALE, player_y, radius, p["blue"])
    ball(img, p, 288 * SCALE, player_y, radius, p["red"])

    d = ImageDraw.Draw(img)
    text(d, (W // 2, 74 * SCALE), "120", 36, p["text"], bold=True)
    text(d, (22 * SCALE, 34 * SCALE), "رکورد  120", 13, p["muted"], anchor="lm")
    rounded(d, [W - 62 * SCALE, 20 * SCALE, W - 22 * SCALE, 46 * SCALE], 10 * SCALE,
            fill=p["chip"], outline=p["stroke"], width=SCALE)
    text(d, (W - 42 * SCALE, 33 * SCALE), "II", 14, p["text2"], bold=True)

    img.convert("RGB").save(path, optimize=True)
    return path


if __name__ == "__main__":
    os.makedirs("docs/mirror", exist_ok=True)
    print(menu_mock("docs/mirror/preview-v12-menu.png"))
    print(settings_mock("docs/mirror/preview-v12-settings.png"))
    print(gameplay_mock("docs/mirror/preview-v12-gameplay.png"))
