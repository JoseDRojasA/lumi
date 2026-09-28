#!/usr/bin/env python3
"""
slice_master.py — Cut the reference painting (rig_master.png) into the 28 k_*
transparent layers the Lumi kitten rig expects, all painted IN PLACE on one
shared square canvas (so import.swift can crop + register them).

Strategy (2.5D layered puppet, motion acts on structure — see AGENTS.md):
  - The whole character is background-removed, then split into structural bands
    that map onto rig nodes, cut along low-detail seams so subtle breathing
    motion never reveals a gap:
        k_tail  : the left tail plume (separated from body by background)
        k_head  : crown tuft + ears + face + eyes + nose + cheeks (cut at neck)
        k_body  : torso + front paws (lower region)
  - Eyes stay painted inside k_head so the REST pose is pixel-identical to the
    reference. Blinking is done with fur-matched lid layers (k_lid_*) that the
    engine drops over each eye; the eye-white/iris/pupil/catchlight parts are
    tiny transparent stubs (baked into the head, but the rig needs the nodes).
  - Ear/hair/chest/paw parts are transparent stubs for the same reason.
  - Expression variants (happy/closed eyes, mouth shapes, brow) are small stubs.

Everything is emitted at the SOURCE resolution on a shared canvas so pixel
registration is exact. import.swift then crops to painted pixels + records
centers/sizes into KittenRig.json.

    python3 Tools/KittenArt/slice_master.py [master.png] [outDir]
    defaults: ~/Downloads/rig_master.png  Art/Kitten
"""
import sys, os, math
from PIL import Image, ImageDraw, ImageFilter

MASTER = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Downloads/rig_master.png")
OUT = sys.argv[2] if len(sys.argv) > 2 else "Art/Kitten"
os.makedirs(OUT, exist_ok=True)

src = Image.open(MASTER).convert("RGBA")
W, H = src.size
px = src.load()

# ---- 1. Background removal: white -> transparent, with a soft edge. ----
def bg_removed(image):
    im = image.copy()
    p = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = p[x, y]
            if a == 0:
                continue
            # distance from white
            mn = min(r, g, b)
            if r > 236 and g > 236 and b > 236:
                p[x, y] = (r, g, b, 0)
            elif r > 218 and g > 218 and b > 218:
                # soft anti-aliased rim: fade alpha by how close to white
                t = (mn - 218) / (236 - 218)
                p[x, y] = (r, g, b, int(255 * (1 - t)))
    return im

char = bg_removed(src)

def blank():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))

def save(name, img):
    img.save(os.path.join(OUT, name + ".png"))
    print("wrote", name)

# ---- 2. Character bounds (for band cuts). ----
cpx = char.load()
minx, miny, maxx, maxy = W, H, 0, 0
for y in range(H):
    for x in range(W):
        if cpx[x, y][3] > 8:
            if x < minx: minx = x
            if x > maxx: maxx = x
            if y < miny: miny = y
            if y > maxy: maxy = y

# Neck seam: narrowest row between the face (~y670) and body (~y800).
NECK = 725          # from silhouette profiling

# ---- 4. HEAD: everything from the top down to the neck seam. The bottom edge
#         is feathered and overlaps into the body a little so the neck seam is
#         hidden (head draws above body).
FEATHER = 60         # px of soft overlap below NECK
head = blank(); hd = head.load()
for y in range(0, NECK + FEATHER):
    for x in range(W):
        r, g, b, a = cpx[x, y]
        if a > 0:
            if y >= NECK:
                # ramp alpha from full at NECK to 0 at NECK+FEATHER
                t = (y - NECK) / FEATHER
                a = int(a * (1 - t))
                if a <= 0:
                    continue
            hd[x, y] = (r, g, b, a)
save("k_head", head)

# ---- 5. BODY: torso + paws + tail below the neck (tail baked in to avoid a
#         vertical cut seam; the tail merges into the body on its right side).
body = blank(); bd = body.load()
for y in range(NECK, H):
    for x in range(W):
        r, g, b, a = cpx[x, y]
        if a > 0:
            bd[x, y] = (r, g, b, a)
save("k_body", body)

# ---- 6. Eye geometry (measured from the master). ----
L_EYE = (463, 555)   # image coords (y down)
R_EYE = (769, 553)
EYE_W, EYE_H = 300, 220   # generous cover for the lid

def sample_fur(cx, cy, dy):
    # average a small patch of forehead fur above the eye
    rs = gs = bs = n = 0
    for yy in range(cy + dy - 8, cy + dy + 8):
        for xx in range(cx - 20, cx + 20):
            r, g, b, a = cpx[xx, yy]
            if a > 200:
                rs += r; gs += g; bs += b; n += 1
    if n == 0:
        return (200, 182, 224, 255)
    return (rs // n, gs // n, bs // n, 255)

fur_L = sample_fur(*L_EYE, -150)
fur_R = sample_fur(*R_EYE, -150)
# The right eye's forehead sample can pick up the pink ear; force both lids to
# a shared lavender fur tone (average of the two, biased to the lavender left).
def lav(c):  # is this a lavender (blue-ish) tone, not pink?
    return c[2] >= c[0]
if not lav(fur_R):
    fur_R = fur_L
if not lav(fur_L):
    fur_L = fur_R
print("fur L", fur_L, "fur R", fur_R)

# ---- 7. LIDS: a fur-colored rounded rect that covers the eye when opaque. ----
def make_lid(center, fur):
    lid = blank()
    d = ImageDraw.Draw(lid)
    cx, cy = center
    x0, y0 = cx - EYE_W // 2, cy - EYE_H // 2
    x1, y1 = cx + EYE_W // 2, cy + EYE_H // 2
    d.rounded_rectangle([x0, y0, x1, y1], radius=EYE_H // 2, fill=fur)
    lid = lid.filter(ImageFilter.GaussianBlur(6))
    return lid

save("k_lid_left", make_lid(L_EYE, fur_L))
save("k_lid_right", make_lid(R_EYE, fur_R))

# ---- 8. Closed-eye overlays (a soft down-curved lash line for expressions). ----
def make_closed(center, fur, happy):
    im = blank()
    d = ImageDraw.Draw(im)
    cx, cy = center
    w = EYE_W // 2 - 20
    dark = (60, 45, 55, 255)
    if happy:   # upward curve (^_^)
        pts = [(cx - w, cy + 12), (cx, cy - 22), (cx + w, cy + 12)]
    else:       # gentle downward closed line
        pts = [(cx - w, cy - 6), (cx, cy + 16), (cx + w, cy - 6)]
    d.line(pts, fill=dark, width=12, joint="curve")
    return im

save("k_eye_happy_left", make_closed(L_EYE, fur_L, True))
save("k_eye_happy_right", make_closed(R_EYE, fur_R, True))
save("k_eye_closed_left", make_closed(L_EYE, fur_L, False))
save("k_eye_closed_right", make_closed(R_EYE, fur_R, False))

# ---- 9. Tiny transparent stubs for parts already baked into head/body. ----
# import.swift crops to painted pixels, so a stub needs a few opaque px placed
# where the part conceptually lives (keeps the rig registration sane).
def stub(name, center, size=(8, 8), color=None):
    im = blank()
    d = ImageDraw.Draw(im)
    cx, cy = center
    # Sample the master's local color so a residual stub pixel is on-model,
    # at very low alpha so it is imperceptible under the baked-in head/body.
    if color is None:
        r, g, b, a = cpx[min(W - 1, max(0, cx)), min(H - 1, max(0, cy))]
        color = (r, g, b, 6)
    d.rectangle([cx - size[0] // 2, cy - size[1] // 2,
                 cx + size[0] // 2, cy + size[1] // 2], fill=color)
    save(name, im)

# eyes: whites/iris/pupil/catchlights are baked into head -> stubs at eye centers
stub("k_eye_white_left", L_EYE, (200, 160))
stub("k_eye_white_right", R_EYE, (200, 160))
stub("k_iris", (L_EYE[0], L_EYE[1]), (120, 120))
stub("k_pupil", (L_EYE[0], L_EYE[1]), (70, 80))
stub("k_catchlight_big", (L_EYE[0] - 30, L_EYE[1] - 30), (40, 40))
stub("k_catchlight_small", (L_EYE[0] + 20, L_EYE[1] + 10), (20, 20))
# brows, nose, blush, hair, chest, ear, paws, shadow, mouths: baked in -> stubs
stub("k_brow_left", (L_EYE[0], L_EYE[1] - 120), (100, 30))
stub("k_nose", (616, 620), (48, 30))
stub("k_blush_left", (360, 640), (120, 70))
stub("k_hair", (610, 140), (180, 120))
stub("k_chest", (610, 950), (240, 200))
stub("k_ear_left", (300, 260), (170, 260))
stub("k_paw_left", (500, 1170), (120, 80))
stub("k_paw_right", (720, 1170), (120, 80))
# tail is baked into k_body; a stub keeps the rig node (no independent sway)
stub("k_tail", (260, 950), (60, 200))

# shadow: a soft dark ellipse under the paws
shadow = blank()
sd = ImageDraw.Draw(shadow)
sd.ellipse([minx + 40, maxy - 40, maxx - 40, maxy + 30], fill=(40, 30, 50, 90))
shadow = shadow.filter(ImageFilter.GaussianBlur(10))
save("k_shadow", shadow)

# mouths: small dark shapes near the muzzle (neutral is a soft smile)
def make_mouth(name, kind):
    im = blank()
    d = ImageDraw.Draw(im)
    cx, cy = 616, 690
    dark = (120, 70, 80, 230)
    if kind == "neutral":
        d.arc([cx - 34, cy - 20, cx + 34, cy + 20], 20, 160, fill=dark, width=8)
    elif kind == "smile":
        d.arc([cx - 40, cy - 26, cx + 40, cy + 26], 15, 165, fill=dark, width=9)
    elif kind == "o":
        d.ellipse([cx - 16, cy - 20, cx + 16, cy + 20], fill=dark)
    elif kind == "sad":
        d.arc([cx - 34, cy + 6, cx + 34, cy + 46], 200, 340, fill=dark, width=8)
    save(name, im)

make_mouth("k_mouth_smile", "smile")
make_mouth("k_mouth_o", "o")
make_mouth("k_mouth_sad", "sad")
# neutral mouth is already painted into the head -> transparent stub
stub("k_mouth_neutral", (616, 690), (59, 20))

# ---- 10. Pivots (design space is 1024, y UP). ----
# image y-down -> design y-up: dy = 1024 * (1 - y/H); dx = 1024 * x/W
def to_design(x, y):
    return [round(1024 * x / W), round(1024 * (1 - y / H))]

import json
pivots = {
    "k_head": to_design((minx + maxx) / 2, NECK - 10),   # pivot at the neck
    "k_ear_left": to_design(300, 300),
}
with open(os.path.join(OUT, "pivots.json"), "w") as f:
    json.dump(pivots, f, indent=2)
print("pivots", pivots)
print("DONE. canvas", W, "x", H, "char bounds", minx, miny, maxx, maxy)
