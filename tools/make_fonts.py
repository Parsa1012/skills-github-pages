#!/usr/bin/env python3
"""Builds the bundled Vazirmatn subsets.

One family covers all four in-game languages: Vazirmatn ships Latin (Inter-derived) and
full Arabic/Persian coverage, so Persian, English, Arabic and Spanish share the same
metrics and the same look instead of falling back to the system font per script.

The subset keeps exactly what the interface needs: ASCII + Latin-1 (Spanish accents and
inverted punctuation), the Arabic block (letters, harakat, tatweel), Arabic punctuation and
digits, the Persian-only letters, Persian digits, the zero-width joiners used in Persian
typography, and a few general punctuation marks.

Run from the repo root (needs network the first time):

    python3 tools/make_fonts.py
"""

import io
import os
import subprocess
import sys
import tarfile
import urllib.request

NPM_TARBALL = "https://registry.npmjs.org/vazirmatn/-/vazirmatn-33.0.3.tgz"
CACHE = "/tmp/package/fonts/ttf"
OUT = "mirror/src/main/assets/fonts"

UNICODES = ",".join([
    "U+0020-007E",   # ASCII
    "U+00A0-00FF",   # Latin-1 supplement: Spanish accents, ¿ ¡ « »
    "U+060C",        # Arabic comma
    "U+061B",        # Arabic semicolon
    "U+061F",        # Arabic question mark
    "U+0621-064A",   # Arabic letters
    "U+064B-0652",   # harakat
    "U+0660-066D",   # Arabic-Indic digits + punctuation
    "U+0670-06D3",   # extended Arabic (Persian letters included)
    "U+06F0-06F9",   # Persian digits
    "U+200C-200F",   # ZWNJ, ZWJ, LRM, RLM
    "U+2010-2015",   # hyphens and dashes
    "U+2018-201D",   # curly quotes
    "U+2022",        # bullet
    "U+2026",        # ellipsis
])


def ensure_source():
    if os.path.isdir(CACHE):
        return
    print("downloading Vazirmatn from npm ...")
    with urllib.request.urlopen(NPM_TARBALL, timeout=60) as response:
        payload = response.read()
    with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as tar:
        for member in tar.getmembers():
            if member.name.endswith(".ttf") or member.name.endswith("OFL.txt"):
                tar.extract(member, path="/tmp")


def main():
    ensure_source()
    os.makedirs(OUT, exist_ok=True)
    for weight in ("Regular", "Bold"):
        src = os.path.join(CACHE, f"Vazirmatn-{weight}.ttf")
        dst = os.path.join(OUT, f"Vazirmatn-{weight}.ttf")
        subprocess.run([
            sys.executable, "-m", "fontTools.subset", src,
            f"--unicodes={UNICODES}",
            "--layout-features=*",
            "--no-hinting",
            "--name-IDs=1,2,3,4,6",
            "--drop-tables+=DSIG,FFTM",
            f"--output-file={dst}",
        ], check=True)
        print(f"{dst} {os.path.getsize(dst)} B")

    licence = os.path.join("/tmp/package", "OFL.txt")
    if os.path.exists(licence):
        with open(licence, "rb") as src, open(os.path.join(OUT, "OFL.txt"), "wb") as dst:
            dst.write(src.read())

    # Prove the four languages are actually covered by the shipped file.
    from fontTools.ttLib import TTFont
    cmap = TTFont(os.path.join(OUT, "Vazirmatn-Regular.ttf")).getBestCmap()
    checks = {
        "persian": "توپ‌های هم‌زاد رکورد آسان",
        "arabic": "كرات التوأم؟ رقْم",
        "english": "Twin Balls — record",
        "spanish": "Bolas Gemelas ¿récord? ¡sí!",
    }
    for name, sample in checks.items():
        missing = [ch for ch in sample if ch not in " \n" and ord(ch) not in cmap]
        print(f"  {name}: missing {missing}")


if __name__ == "__main__":
    main()
