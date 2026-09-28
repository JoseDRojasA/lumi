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
from PIL import Image, ImageDraw, ImageFilter, ImageChops

MASTER = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/Downloads/rig_master.png")
OUT = sys.argv[2] if len(sys.argv) > 2 else "Art/Kitten"
os.makedirs(OUT, exist_ok=True)

src = Image.open(MASTER).convert("RGBA")
W, H = src.size
px = src.load()

# ---- 1. Background removal: white -> transparent, with a soft edge. ----
#   Only near-white pixels CONNECTED TO THE IMAGE BORDER are background. The
#   kitten's own fur highlights are also near-white; keying those out punched
#   holes that looked fine on the phone's light background but showed as dark
#   streaks on the watch's dark background.
def bg_removed(image):
    """The master already has a real transparent background, so keep its alpha.

    (Keying near-white to transparent used to punch holes in the kitten's white
    fur highlights: invisible on the phone's light backdrop, dark streaks on the
    watch's dark one.) The only paper left in the master is a few enclosed warm
    cream pockets (ear gap, tail curl); remove those: large connected regions of
    warm (r >> b) near-white, with a soft rim. Fur is cool lavender (b >= r).
    """
    from collections import deque
    im = image.copy()
    p = im.load()
    w, h = im.size
    # The lit right side of the fur is ALSO warm cream, so only look inside the
    # two known enclosed pockets of the master (left ear gap, tail curl).
    POCKETS = [(280, 100, 430, 250), (250, 760, 440, 960)]
    def cream(x, y):
        if not any(x0 <= x < x1 and y0 <= y < y1 for x0, y0, x1, y1 in POCKETS):
            return False
        r, g, b, a = p[x, y]
        return a > 0 and r > 222 and g > 205 and r - b >= 5
    seen = bytearray(w * h)
    pocket = Image.new("L", (w, h), 0); pk = pocket.load()
    for sy in range(h):
        for sx in range(w):
            if seen[sy * w + sx] or not cream(sx, sy):
                continue
            comp = []; q = deque([(sx, sy)]); seen[sy * w + sx] = 1
            while q:
                x, y = q.popleft(); comp.append((x, y))
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and cream(nx, ny):
                        seen[ny * w + nx] = 1; q.append((nx, ny))
            if len(comp) > 300:
                for x, y in comp:
                    pk[x, y] = 255
    soft = pocket.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.5))
    sp = soft.load()
    for y in range(h):
        for x in range(w):
            v = sp[x, y]
            if v:
                r, g, b, a = p[x, y]
                p[x, y] = (r, g, b, int(a * (255 - v) / 255))
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

# ---- 6. Eye geometry (measured from the master, image coords y-down). ----
# Per-eye painted bounding boxes (iris + eyeball), with a small margin.
MARGIN = 10
EYE_BBOX = {
    "left":  (326 - MARGIN, 461 - MARGIN, 602 + MARGIN, 651 + MARGIN),
    "right": (638 - MARGIN, 455 - MARGIN, 903 + MARGIN, 653 + MARGIN),
}
EYE_CENTER = {
    "left":  ((326 + 602) // 2, (461 + 651) // 2),   # (464, 556)
    "right": ((638 + 903) // 2, (455 + 653) // 2),    # (770, 554)
}

def sample_fur_ring(box):
    """Average fur color just OUTSIDE the eye box (the socket surround)."""
    x0, y0, x1, y1 = box
    rs = gs = bs = n = 0
    for x in range(x0, x1):
        for yy in (y0 - 12, y1 + 12):
            if 0 <= yy < H:
                r, g, b, a = cpx[x, yy]
                if a > 180 and b >= r - 10:   # prefer lavender, skip pink/dark
                    rs += r; gs += g; bs += b; n += 1
    if n == 0:
        return (205, 188, 236, 255)
    return (rs // n, gs // n, bs // n, 255)

fur = {side: sample_fur_ring(EYE_BBOX[side]) for side in ("left", "right")}
print("socket fur", fur)

# ---- 6a. OPEN-EYE SPRITES: cut the painted eye straight out of the reference.
for side in ("left", "right"):
    x0, y0, x1, y1 = EYE_BBOX[side]
    eye = blank(); ed = eye.load()
    for y in range(max(0, y0), min(H, y1)):
        for x in range(max(0, x0), min(W, x1)):
            r, g, b, a = cpx[x, y]
            if a > 0:
                ed[x, y] = (r, g, b, a)
    save(f"k_eye_open_{side}", eye)

# ---- 6b. Re-cut the HEAD with the eye sockets FILLED with fur, so nothing dark
#          shows behind the (separately layered) open/closed eye sprites.
head_fill = head.copy(); hf = head_fill.load()
for side in ("left", "right"):
    x0, y0, x1, y1 = EYE_BBOX[side]
    fr, fg, fb, _ = fur[side]
    cx, cy = EYE_CENTER[side]
    rx, ry = (x1 - x0) / 2, (y1 - y0) / 2
    for y in range(max(0, y0), min(H, y1)):
        for x in range(max(0, x0), min(W, x1)):
            # elliptical socket, feathered at the rim
            nx = (x - cx) / rx; ny = (y - cy) / ry
            d2 = nx * nx + ny * ny
            if d2 <= 1.15:
                t = max(0.0, min(1.0, (1.15 - d2) / 0.30))
                orr, org, orb, ora = hf[x, y]
                nr = int(fr * t + orr * (1 - t))
                ng = int(fg * t + org * (1 - t))
                nb = int(fb * t + orb * (1 - t))
                hf[x, y] = (nr, ng, nb, max(ora, int(255 * t)))
save("k_head", head_fill)

# ---- 7. CLOSED-EYE SPRITES: a reference-styled soft lid that fully covers the
#         socket. Fur-colored dome + a soft downward-curved dark lash line, sized
#         The lid is a fur "curtain" the width of the eye whose BOTTOM edge is a
#         soft eyelid margin (curve + lash). At rest the engine parks it above the
#         eye; a blink slides it straight down inside an eye-shaped crop mask, so
#         the eye stays open underneath and the lid progressively covers it —
#         exactly like a real eyelid closing. See BlinkLidNode.
LID_TRAVEL = 1.18   # lid height as a fraction of eye height (extra so it fully covers)

def make_lid(side):
    """Fur eyelid curtain, drawn at the eye position; bottom edge = lid margin."""
    x0, y0, x1, y1 = EYE_BBOX[side]
    w = x1 - x0; h = y1 - y0
    cx, cy = EYE_CENTER[side]
    fr, fg, fb, _ = fur[side]
    # CLOSED pose: the curtain covers the whole socket and its leading edge
    # (lid margin) sits at the BOTTOM of the eye, bowed downward like a real
    # upper lid. The engine parks it one travel higher when the eye is open.
    bow = int(h * 0.22)                      # how much the margin bows down
    top = y0 - 12                            # just above the socket
    bot = y1 - 10                            # margin lands inside the eye bottom
    lw, lh = (x1 + 6) - (x0 - 6), bot - top

    # Fur body from the REAL painted forehead fur just above this eye, stretched
    # to lid height so the lid carries the same texture/lighting as the head.
    src = char.crop((x0 - 6, max(0, y0 - int(h * 0.55)), x1 + 6, y0 - 6)).convert("RGBA")
    # Flatten onto the socket fur colour (transparent pixels would turn black),
    # then replace anything much darker than fur (painted brows, stray strands)
    # with fur so only soft fur grain remains.
    base = Image.new("RGBA", src.size, (fr, fg, fb, 255))
    base.alpha_composite(src)
    bp = base.load(); fl = (fr + fg + fb) / 3
    for yy in range(base.height):
        for xx in range(base.width):
            r_, g_, b_, _ = bp[xx, yy]
            if (r_ + g_ + b_) / 3 < fl - 18:
                bp[xx, yy] = (fr, fg, fb, 255)
    fur_tex = base.resize((lw, lh), Image.BICUBIC).filter(ImageFilter.GaussianBlur(1.2))

    # Rounded-lid shading: slightly darker toward the margin (lid curving under).
    shade = Image.new("L", (lw, lh), 0)
    sd = ImageDraw.Draw(shade)
    for i in range(lh):
        t = i / max(1, lh - 1)
        sd.line([(0, i), (lw, i)], fill=int(70 * max(0.0, t - 0.45) / 0.55))
    dark = Image.new("RGBA", (lw, lh), (max(0, fr - 60), max(0, fg - 66), max(0, fb - 50), 255))
    fur_tex = Image.composite(dark, fur_tex, shade)

    im = blank()
    im.paste(fur_tex, (x0 - 6, top))

    # Lash line tracing the bowed margin — composited ON TOP (never overwrite).
    lash_layer = blank(); d2 = ImageDraw.Draw(lash_layer)
    lash = (74, 54, 66, 255)
    d2.arc([x0 + int(w * 0.04), bot - 2 * bow, x1 - int(w * 0.04), bot - 2],
           start=15, end=165, fill=lash, width=max(6, h // 22))
    outer = x0 + int(w * 0.08) if side == "left" else x1 - int(w * 0.08)
    flick = -13 if side == "left" else 13
    d2.line([(outer, bot - bow - 4), (outer + flick, bot - bow + 12)], fill=lash, width=max(4, h // 34))
    lash_layer = lash_layer.filter(ImageFilter.GaussianBlur(0.8))
    im.alpha_composite(lash_layer)

    # Shape: rectangle + bowed bottom; lightly anti-aliased edge, fully opaque inside.
    mask = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mask)
    md.rectangle([x0 - 6, top, x1 + 6, bot - bow], fill=255)
    md.ellipse([x0 - 6, bot - 2 * bow, x1 + 6, bot + 2], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(1.5))
    r, g, b, a = im.split()
    a = ImageChops.multiply(a, mask)
    return Image.merge("RGBA", (r, g, b, a))

def make_eye_mask(side):
    """Opaque eye-shaped ellipse: the SKCropNode mask that clips the sliding lid
    to the eye so it never spills onto the fur."""
    x0, y0, x1, y1 = EYE_BBOX[side]
    cx, cy = EYE_CENTER[side]
    rx, ry = (x1 - x0) / 2 + 2, (y1 - y0) / 2 + 2
    im = blank(); d = ImageDraw.Draw(im)
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(255, 255, 255, 255))
    return im.filter(ImageFilter.GaussianBlur(6))

save("k_lid_left", make_lid("left"))
save("k_lid_right", make_lid("right"))
save("k_eye_mask_left", make_eye_mask("left"))
save("k_eye_mask_right", make_eye_mask("right"))

# ---- 8. Expression eye overlays (happy ^_^ and a plain closed line), hidden at
#         rest and shown only by expression triggers. Positioned at eye centers.
def make_expression(side, happy):
    cx, cy = EYE_CENTER[side]
    x0, y0, x1, y1 = EYE_BBOX[side]
    w = (x1 - x0) // 2 - 20
    im = blank()
    d = ImageDraw.Draw(im)
    dark = (60, 45, 55, 255)
    if happy:   # upward curve (^_^)
        pts = [(cx - w, cy + 12), (cx, cy - 22), (cx + w, cy + 12)]
    else:       # gentle downward closed line
        pts = [(cx - w, cy - 6), (cx, cy + 16), (cx + w, cy - 6)]
    d.line(pts, fill=dark, width=12, joint="curve")
    return im

save("k_eye_happy_left", make_expression("left", True))
save("k_eye_happy_right", make_expression("right", True))
save("k_eye_closed_left", make_expression("left", False))
save("k_eye_closed_right", make_expression("right", False))

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

L_EYE = EYE_CENTER["left"]
R_EYE = EYE_CENTER["right"]
# eye-white/iris/pupil/catchlights now live in the k_eye_open_* sprites -> stubs
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
