#!/usr/bin/env python3
"""Produce v1.5 launcher and background resources from the checked-in artwork.

Requires Pillow. The full originals are retained in mirror/art for reproducible resizing.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps

res = Path('mirror/src/main/res')
art = Path('mirror/art')
logo = Image.open(art / 'logo-v15.png').convert('RGB')
logo.resize((384, 384), Image.Resampling.LANCZOS).save(res / 'drawable-nodpi/logo.png')
foreground = Image.new('RGBA', (432, 432), (0, 0, 0, 0))
foreground.alpha_composite(logo.resize((280, 280), Image.Resampling.LANCZOS).convert('RGBA'), (76, 76))
foreground.save(res / 'drawable-nodpi/ic_launcher_foreground.png')
for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    icon = logo.resize((size, size), Image.Resampling.LANCZOS).convert('RGBA')
    for name in ('ic_launcher', 'ic_launcher_round'):
        mask = Image.new('L', (size * 4, size * 4))
        draw = ImageDraw.Draw(mask)
        bounds = (0, 0, size * 4 - 1, size * 4 - 1)
        if name.endswith('round'):
            draw.ellipse(bounds, fill=255)
        else:
            draw.rounded_rectangle(bounds, radius=int(size * 4 * .22), fill=255)
        result = icon.copy()
        result.putalpha(mask.resize((size, size), Image.Resampling.LANCZOS))
        result.save(res / ('mipmap-' + density) / (name + '.png'))
background = Image.open(art / 'background-v15.png').convert('RGB').resize((480, 854), Image.Resampling.LANCZOS)
background.save(res / 'drawable-nodpi/scene_night.jpg', quality=88, optimize=True)
day = Image.blend(Image.new('RGB', background.size, (242, 246, 252)), ImageOps.invert(background), .20)
day.save(res / 'drawable-nodpi/scene_day.jpg', quality=90, optimize=True)
