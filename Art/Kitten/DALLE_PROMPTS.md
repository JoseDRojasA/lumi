# Lumi Kitten — DALL·E prompts for the layered rig (Path B)

Goal: produce the **28 transparent `k_*` part layers** that
`Tools/KittenArt/import.swift` turns into `app/LumiKitten.atlas` + `app/KittenRig.json`,
which `KittenNodeFactory` assembles into an animated puppet (breathing, head tilt,
blink, ear/tail rotation, expression swaps).

This keeps ALL procedural animation. The cost is registration work: DALL·E draws the
parts, you place each on one shared transparent canvas at the mapped position.

---

## Hard rules from the code (read once — they change what you generate)

1. **Only LEFT versions of mirrored parts exist as art.** The engine draws the right
   ear, right cheek, and right brow by horizontally flipping the left one. So you
   **do NOT generate**: right ear, right cheek/blush, right brow. Files needed are
   `k_ear_left`, `k_blush_left`, `k_brow_left` only.
2. **Eyes are stacked layers, not one drawing.** Each eye = white base + iris + pupil
   + big catchlight + small catchlight + lid, composited by the engine. The **iris,
   pupil, and catchlights are painted once** (in the left eye) and reused for the
   right, so generate a single iris, single pupil, single big + small catchlight.
3. **Eye whites and lids are per-side** (`_left` / `_right`) but symmetric — draw the
   left, flip in an editor for the right. Same for the happy/closed eye overlays.
4. **Catchlights are the same on both eyes** (light from one direction) — don't mirror
   them; iris/pupil offsets are mirrored by the engine automatically.
5. **Every layer is the same square canvas, transparent, hard alpha edge.** Recommended
   **2048×2048**. The importer fails if a layer isn't square or differs in size.
6. **Under-paint occluded parts fully** (see `references/occlusion_guide.png`):
   - `k_head` = a **complete furry head with NO face features and NO ears**.
   - `k_body` = a **whole body** even under where the chest ruff sits.
   - `k_ear_left` and `k_tail` include their **full base** that tucks under the head/body.
7. **Three parts rotate** and need pivots supplied separately in `Art/Kitten/pivots.json`
   (not drawn): `k_head`, `k_ear_left`, `k_tail`.

The character (see `references/hero.png`): fluffy chibi kitten, pastel lavender-white
fur, pink inner ears + cheek blush, oversized amber-brown eyes, tiny pink nose, big
upswept crown tuft, Disney/Pixar soft-plush 3D render.

---

## Workflow

1. Paste the **setup** message into ChatGPT.
2. Generate the **hero** (identity anchor).
3. Generate each **part prompt** below. DALL·E returns transparent PNGs.
4. In an editor, place each part on a 2048×2048 transparent canvas at the center in
   `TARGET_LAYOUT`, export as `k_<name>.png` into `Art/Kitten/`.
5. Write `Art/Kitten/pivots.json`.
6. Run the importer, build, verify.

> Tip: keep the hero image attached / referenced on every part request so fur texture,
> hue and lighting match. Mismatched lighting is what creates seams after reassembly.

---

## Setup message (paste once)

```
You are helping me generate isolated character parts as transparent PNGs with DALL·E.
Keep the SAME character identity, palette, lighting direction, and rendering style
across every image. Character: adorable fluffy chibi kitten, Disney/Pixar soft-plush
3D render, pastel lavender-white fur, subtle pink inner ears and cheek blush,
oversized round amber-brown eyes, tiny pink nose, big upswept fluffy crown tuft, soft
volumetric fur, gentle top-down key light, soft ambient occlusion. Front-facing,
symmetrical. Every image: transparent background, no ground shadow, no props, no text,
square 1:1, the part centered as I describe. When I say "same kitten" reuse this exact
design. Confirm and wait.
```

## Hero (identity anchor)

```
Same kitten. Full body sitting upright, front view, symmetrical, centered. Complete
character: head, two ears (lavender outside, pink inside), fluffy crown tuft, blushed
cheeks, two big amber eyes with white catchlights, pink nose, small closed smile,
fluffy chest ruff, rounded body, two front paws, one big fluffy curled tail to the
left. Transparent background. 1:1 square.
```

---

## Part prompts (28 files → 25 prompts, thanks to mirroring)

Append to each: `Transparent background, centered, same style/scale/lighting as the
hero, 1:1 square, no text, no extra parts.`

### Base & body

```
k_shadow   → Only a soft flat horizontal oval contact shadow, semi-transparent soft
             gray, blurred edge. No character.

k_body     → Only the kitten's rounded fluffy body/torso and haunches. NO head, NO
             ears, NO tail, NO front paws, NO chest ruff. Paint the COMPLETE body
             silhouette including the area the chest ruff will later cover.

k_chest    → Only the fluffy chest ruff/mane tuft that sits in front of the lower
             body. Nothing else.

k_paw_left → Only the LEFT front paw, isolated, as seen in the sitting pose.
k_paw_right→ Only the RIGHT front paw, isolated, as seen in the sitting pose.

k_tail     → Only the big fluffy curled tail, isolated. Paint the FULL tail including
             its root/base (the base extends toward where it tucks under the body).
```

### Head & face (LEFT-only where noted)

```
k_head       → Only the bare head base: a complete fuzzy lavender-white head/face
               shape, front view. NO ears, NO crown tuft, NO eyes, NO nose, NO mouth,
               NO cheek blush. Just the smooth furry head other features layer onto.

k_ear_left   → Only the LEFT pointed ear (lavender fur outside, soft pink inside),
               isolated. Paint the FULL ear including its base. (Right ear is this
               mirrored — do NOT generate a right ear.)

k_hair       → Only the crown tuft / upswept cowlick of fur from the top of the head,
               isolated.

k_brow_left  → Only ONE left eyebrow: a short soft fur brow stroke, isolated.
               (Right brow is this mirrored — do NOT generate.)

k_blush_left → Only ONE left cheek blush: a soft translucent pink oval, isolated.
               (Right cheek is this mirrored — do NOT generate.)

k_nose       → Only the small pink triangular kitten nose, isolated.
```

### Mouths (swapped by the engine; same anchor)

```
k_mouth_neutral → Only a tiny neutral soft cat mouth (gentle line / small "w").
k_mouth_smile   → Only a small happy upturned smile.
k_mouth_o       → Only a small round surprised open "O" mouth.
k_mouth_sad     → Only a small downturned sad mouth.
```

### Eyes — open (stacked layers; draw the LEFT eye, mirror for right)

The engine composites these. Generate each element **on its own**, large and centered:

```
k_eye_white_left → Only ONE eyeball base: the white sclera shape of a big round
                   kitten eye, no iris/pupil. (Right = mirror; you can flip in editor
                   and save as k_eye_white_right, OR generate it the same way.)
k_iris           → Only ONE round amber-brown iris disc, soft radial shading. Nothing
                   else. (Reused for both eyes.)
k_pupil          → Only ONE round dark pupil disc. (Reused for both eyes.)
k_catchlight_big → Only ONE small solid white circular highlight dot. (Reused; NOT
                   mirrored.)
k_catchlight_small → Only ONE tiny solid white circular highlight dot. (Reused; NOT
                   mirrored.)
k_lid_left       → Only ONE upper eyelid: a fur-colored shape that can drop to cover
                   the eye for blinking, sized to fully cover the eye. (Right = mirror.)
```

Produce `k_eye_white_right` and `k_lid_right` by horizontally flipping the left ones
in your editor (fastest and guarantees symmetry).

### Eyes — expression overlays (per side; draw left, mirror for right)

```
k_eye_happy_left   → Only ONE happy closed eye: an upward "^" curved arc. (→ mirror
                     for k_eye_happy_right.)
k_eye_closed_left  → Only ONE relaxed/sleepy closed eye: a gentle downward lash line.
                     (→ mirror for k_eye_closed_right.)
```

### Full file checklist (28)

```
k_shadow  k_tail  k_body  k_chest  k_paw_left  k_paw_right
k_head  k_ear_left  k_hair  k_brow_left  k_blush_left  k_nose
k_mouth_neutral  k_mouth_smile  k_mouth_o  k_mouth_sad
k_eye_white_left  k_eye_white_right  k_iris  k_pupil
k_catchlight_big  k_catchlight_small  k_lid_left  k_lid_right
k_eye_happy_left  k_eye_happy_right  k_eye_closed_left  k_eye_closed_right
```

---

## TARGET_LAYOUT — where to place each part (from current `app/KittenRig.json`)

Canvas = 1024 design points → export at 2048 px (×2). Centers are normalized, **y up**
(0 bottom, 1 top). Pixel position on a 2048 canvas = `x*2048` from left, `(1-y)*2048`
from top. Sizes are a scale guide — the importer re-crops to painted pixels, so exact
placement (center) matters more than exact size.

| File | center x | center y | ~w×h (pt) |
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
| k_mouth_neutral | 0.500 | 0.473 | 71×22 |
| k_mouth_smile | 0.500 | 0.462 | 72×41 |
| k_mouth_o | 0.500 | 0.465 | 32×38 |
| k_mouth_sad | 0.500 | 0.465 | 59×23 |

Placement anchor is each part's **center**, except the three pivoted parts, whose
placement the importer derives from the pivot — just paint them where they belong
relative to the hero and set the pivot below.

### `Art/Kitten/pivots.json` (rotating parts; 1024-pt canvas space, y up)

```json
{
  "k_head": [512, 470],
  "k_ear_left": [382, 900],
  "k_tail": [670, 350]
}
```

- `k_head` → base of the neck (head tilts here).
- `k_ear_left` → the ear base where it meets the head.
- `k_tail` → the tail root where it tucks into the body.

Importer fails if a pivot is outside its part's painted pixels — a useful check.

---

## Import & verify

```sh
swift Tools/KittenArt/import.swift Art/Kitten app/LumiKitten.atlas app/KittenRig.json
```

Then build the `app` scheme and confirm: kitten breathes (chest/head), blinks (lids
fade), ears + tail + head rotate around their pivots, and no seams appear. Expression
swaps (mouths, happy/closed eyes, brows) are exposed via `PetRig.faceParts`.

## Troubleshooting

- **Missing-texture crash on launch** → a `k_*` file is absent or misnamed; the rig
  requires all 28 in `KittenRigLayout.requiredPartNames`.
- **Seam / halo at a part edge** → lighting mismatch or soft alpha; regenerate that
  part against the hero and harden the cutout edge.
- **Gap when head tilts / body breathes** → an occluded part wasn't under-painted far
  enough; extend the head/body/ear/tail base.
- **Right eye/ear/cheek looks wrong** → remember right ear/cheek/brow are engine
  mirrors of the left; right eye white/lid should be a clean horizontal flip of left.
- **"must be square" / size error from importer** → re-export that layer at exactly
  2048×2048.
- **Pivot outside part** → adjust the value in `pivots.json` or extend the part art.
```