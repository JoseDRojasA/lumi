# Lumi Kitten — Build the LumiKitten atlas (upload this file to ChatGPT)

You are producing art assets for a SpriteKit **layered puppet rig**. Read this whole
file, then generate the parts and **assemble the final folder with code**, and give me
a downloadable **zip**. Attached alongside this file are reference images
(`hero.png`, `rig_master.png`, `occlusion_guide.png`, `expr_sheet.png`,
`motion_*.png`) — match that exact character.

## The character

Adorable fluffy chibi kitten, Disney/Pixar soft-plush 3D render. Pastel lavender-white
fur, subtle pink inner ears and cheek blush, oversized round amber-brown eyes, tiny
pink nose, big upswept fluffy crown tuft, soft volumetric fur, gentle top-down key
light, soft ambient occlusion, front-facing and symmetrical. Match the attached
`hero.png` for identity, palette, and lighting on every part.

## What I need (critical — this is a LAYERED rig, not full-body frames)

I need **28 individual body-part PNGs**, each a single part on a **transparent**
background, that a rig composites and animates (breathing, blinking, head tilt,
ear/tail rotation, expression swaps). Do **NOT** give me whole-cat frames — I need
separated parts.

### Hard rules

1. **Mirrored parts are drawn once (LEFT only).** The engine makes the right ear,
   right cheek, and right brow by flipping the left. Generate only `k_ear_left`,
   `k_blush_left`, `k_brow_left`. Do NOT generate right ear/cheek/brow.
2. **Eyes are separate stacked layers**, not one eye drawing: white sclera, iris,
   pupil, big catchlight, small catchlight, eyelid. The **iris, pupil, and both
   catchlights are single images reused for both eyes** — generate one of each.
3. **Eye whites, lids, and expression eye overlays are per-side but symmetric** —
   generate the LEFT one, then produce the RIGHT by horizontally flipping it in code.
4. **Catchlights are NOT mirrored** (light comes from one side on both eyes).
5. **Under-paint occluded parts fully** (see `occlusion_guide.png`):
   - `k_head` = a COMPLETE furry head with NO ears and NO face features.
   - `k_body` = a WHOLE body, including the area the chest ruff covers.
   - `k_ear_left` and `k_tail` include their full base that tucks under head/body.
6. **The tiny geometric parts must be clean shapes, not furry blobs**: `k_iris` and
   `k_pupil` are smooth circles, `k_catchlight_big`/`k_catchlight_small` are solid
   white circles, `k_shadow` is a soft gray oval. If DALL·E adds fur/detail to these,
   draw them procedurally with code (PIL) instead.
7. Every final file is a **2048×2048 transparent PNG**, same size for all, named
   exactly `k_<name>.png` (see checklist). Hard alpha edges.

## The 28 files

```
k_shadow  k_tail  k_body  k_chest  k_paw_left  k_paw_right
k_head  k_ear_left  k_hair  k_brow_left  k_blush_left  k_nose
k_mouth_neutral  k_mouth_smile  k_mouth_o  k_mouth_sad
k_eye_white_left  k_eye_white_right  k_iris  k_pupil
k_catchlight_big  k_catchlight_small  k_lid_left  k_lid_right
k_eye_happy_left  k_eye_happy_right  k_eye_closed_left  k_eye_closed_right
```

## Per-part content

Base & body:
- `k_shadow` — soft flat semi-transparent gray horizontal oval, blurred edge, no character.
- `k_body` — rounded fluffy body/torso + haunches only. No head, ears, tail, paws, or ruff. Complete silhouette including under the ruff.
- `k_chest` — fluffy chest ruff/mane tuft only.
- `k_paw_left` / `k_paw_right` — one front paw each, as in the sitting pose.
- `k_tail` — big fluffy curled tail only, including its full root/base.

Head & face:
- `k_head` — bare complete fuzzy head/face shape. No ears, crown tuft, eyes, nose, mouth, or blush.
- `k_ear_left` — left pointed ear (lavender outside, pink inside), full base. (Right = mirror.)
- `k_hair` — upswept crown tuft of fur only.
- `k_brow_left` — one short soft fur eyebrow. (Right = mirror.)
- `k_blush_left` — one soft translucent pink cheek oval. (Right = mirror.)
- `k_nose` — small pink triangular nose only.

Mouths:
- `k_mouth_neutral` — tiny neutral soft mouth. `k_mouth_smile` — small upturned smile.
- `k_mouth_o` — small round surprised "O". `k_mouth_sad` — small downturned mouth.

Eyes (open), left eye then mirror for right where noted:
- `k_eye_white_left` — white sclera base of a big round eye (no iris/pupil). (`_right` = flip.)
- `k_iris` — one smooth amber-brown iris circle. `k_pupil` — one dark circle.
- `k_catchlight_big` — one solid white circle. `k_catchlight_small` — one tiny white circle.
- `k_lid_left` — one fur-colored upper eyelid covering the eye for blinks. (`_right` = flip.)

Eyes (expression overlays), left then mirror:
- `k_eye_happy_left` — happy closed upward "^" arc. (`_right` = flip.)
- `k_eye_closed_left` — relaxed/sleepy closed downward lash line. (`_right` = flip.)

## Assemble with code — placement table (do NOT eyeball this)

For each part, paste it onto a **2048×2048 fully transparent** canvas so its **center**
lands at the coordinate below. Coordinates are normalized, **y measured from the
BOTTOM (y up)**. So in pixels on a 2048 canvas:
`px_x = round(x * 2048)`, `px_y_from_top = round((1 - y) * 2048)`, then place the
part centered on that point. Scale each part so its width/height roughly matches the
`w×h` design points below (× 2 for pixels), preserving aspect ratio; exact size isn't
critical (the importer re-crops) but **center position is**.

| file | x | y | w×h (pt) |
|---|---|---|---|
| k_shadow | 0.500 | 0.117 | 470×82 |
| k_tail | 0.715 | 0.398 | 309×449 |
| k_body | 0.500 | 0.293 | 404×384 |
| k_chest | 0.500 | 0.347 | 240×234 |
| k_paw_left | 0.430 | 0.132 | 140×92 |
| k_paw_right | 0.570 | 0.132 | 140×92 |
| k_head | 0.500 | 0.586 | 618×454 |
| k_ear_left | 0.359 | 0.813 | 179×269 |
| k_hair | 0.508 | 0.867 | 184×179 |
| k_brow_left | 0.393 | 0.687 | 101×33 |
| k_blush_left | 0.327 | 0.503 | 126×75 |
| k_nose | 0.500 | 0.507 | 48×30 |
| k_eye_white_left | 0.400 | 0.576 | 167×179 |
| k_eye_white_right | 0.600 | 0.576 | 167×179 |
| k_iris | 0.402 | 0.568 | 128×128 |
| k_pupil | 0.402 | 0.566 | 72×80 |
| k_catchlight_big | 0.424 | 0.594 | 44×44 |
| k_catchlight_small | 0.383 | 0.547 | 22×22 |
| k_lid_left | 0.400 | 0.578 | 176×188 |
| k_lid_right | 0.600 | 0.578 | 176×188 |
| k_eye_happy_left | 0.400 | 0.577 | 116×48 |
| k_eye_happy_right | 0.600 | 0.577 | 116×48 |
| k_eye_closed_left | 0.400 | 0.572 | 116×34 |
| k_eye_closed_right | 0.600 | 0.572 | 116×34 |

Notes for the code step:
- Make `k_eye_white_right`, `k_lid_right`, `k_eye_happy_right`, `k_eye_closed_right`
  by horizontally flipping their `_left` source, then placing at the right-side x.
- `k_iris`, `k_pupil`, `k_catchlight_big`, `k_catchlight_small` are placed at the LEFT
  eye position only (the rig copies them to the right eye itself).
- Trim/erase any stray background so alpha edges are crisp (alpha threshold is tiny).

## Also include `pivots.json`

Create `pivots.json` in the folder with these rotating-part pivots (1024-pt canvas
space, y up):

```json
{
  "k_head": [512, 470],
  "k_ear_left": [382, 900],
  "k_tail": [670, 350]
}
```

## Deliverable

A single downloadable **`.zip`** containing a folder `Art_Kitten/` with:
- the 28 `k_*.png` files (each 2048×2048, transparent, correctly positioned), and
- `pivots.json`.

Also print a short summary listing every file and its pixel center so I can spot-check
placement. Do the positioning in code (PIL), not by eye. If any part can't be cleanly
isolated by generation, draw it procedurally instead and say which ones you did that
way.
