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

import base64
import hashlib
import hmac
import io
import os
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

NPM_TARBALL = "https://registry.npmjs.org/vazirmatn/-/vazirmatn-33.0.3.tgz"
EXPECTED_SHA512 = "fbjNc0CMjazZpIegWzz9OHGzI1APFboT+x7ZecXlUCtDe/nkyx7gtCTZnWS/+eeXG7fbfXymCPKJI8EsnM3iqw=="
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


def ensure_source(directory):
    """Download a pinned archive; only read three regular files, never extract paths/links."""
    print("downloading pinned Vazirmatn from npm ...")
    with urllib.request.urlopen(NPM_TARBALL, timeout=60) as response:
        payload = response.read(20 * 1024 * 1024 + 1)
    if len(payload) > 20 * 1024 * 1024 or not hmac.compare_digest(
            base64.b64encode(hashlib.sha512(payload).digest()).decode("ascii"), EXPECTED_SHA512):
        raise ValueError("Font archive failed size or SHA-512 verification")
    wanted = {
        "package/fonts/ttf/Vazirmatn-Regular.ttf": "Vazirmatn-Regular.ttf",
        "package/fonts/ttf/Vazirmatn-Bold.ttf": "Vazirmatn-Bold.ttf",
        "package/OFL.txt": "OFL.txt",
    }
    with tarfile.open(fileobj=io.BytesIO(payload), mode="r:gz") as tar:
        for name, output in wanted.items():
            entries = [member for member in tar.getmembers() if member.name == name]
            if len(entries) != 1 or not entries[0].isfile() or entries[0].size > 10 * 1024 * 1024:
                raise ValueError("Invalid or missing font archive member: " + name)
            with tar.extractfile(entries[0]) as source, open(os.path.join(directory, output), "wb") as dest:
                dest.write(source.read())


def main():
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="mirror-font-") as source:
        ensure_source(source)
        for weight in ("Regular", "Bold"):
            src = os.path.join(source, f"Vazirmatn-{weight}.ttf")
            dst = os.path.join(OUT, f"Vazirmatn-{weight}.ttf")
            subprocess.run([
                sys.executable, "-m", "fontTools.subset", src,
                f"--unicodes={UNICODES}",
                "--layout-features=*", "--no-hinting", "--name-IDs=1,2,3,4,6",
                "--drop-tables+=DSIG,FFTM", f"--output-file={dst}",
            ], check=True)
            print(f"{dst} {os.path.getsize(dst)} B")
        with open(os.path.join(source, "OFL.txt"), "rb") as src, open(os.path.join(OUT, "OFL.txt"), "wb") as dst:
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
