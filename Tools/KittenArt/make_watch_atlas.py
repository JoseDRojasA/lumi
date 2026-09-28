#!/usr/bin/env python3
"""Build the watch copy of the kitten atlas from the phone atlas.

The kitten is drawn ~5-7x smaller on the watch than its phone textures, and
SpriteKit minifies without mipmaps, so full-size textures alias into dark
speckles there. This pre-filters each part down (in premultiplied space, so
soft fur edges don't pick up dark fringes) and copies KittenRig.json unchanged:
sprite sizes come from the JSON, so layout is identical.

Usage (from repo root):
    python3 Tools/KittenArt/make_watch_atlas.py [scale]
"""
import os
import shutil
import sys

from PIL import Image

SCALE = float(sys.argv[1]) if len(sys.argv) > 1 else 0.33
SRC_ATLAS = "app/LumiKitten.atlas"
SRC_RIG = "app/KittenRig.json"
DST_DIR = "LumiWatch Watch App"
DST_ATLAS = os.path.join(DST_DIR, "LumiKitten.atlas")


def downscale_premultiplied(im: Image.Image, size) -> Image.Image:
    """Resize RGBA with alpha-premultiplied filtering (no dark halos)."""
    im = im.convert("RGBA")
    premul = im.convert("RGBa")
    small = premul.resize(size, Image.LANCZOS)
    return small.convert("RGBA")


def main() -> None:
    if os.path.isdir(DST_ATLAS):
        shutil.rmtree(DST_ATLAS)
    os.makedirs(DST_ATLAS)
    count = 0
    for name in sorted(os.listdir(SRC_ATLAS)):
        if not name.endswith(".png"):
            continue
        im = Image.open(os.path.join(SRC_ATLAS, name))
        size = (max(1, round(im.width * SCALE)), max(1, round(im.height * SCALE)))
        downscale_premultiplied(im, size).save(os.path.join(DST_ATLAS, name), optimize=True)
        count += 1
    shutil.copyfile(SRC_RIG, os.path.join(DST_DIR, "KittenRig.json"))
    print(f"wrote {count} watch parts at {SCALE:.2f}x to {DST_ATLAS}")


if __name__ == "__main__":
    main()
