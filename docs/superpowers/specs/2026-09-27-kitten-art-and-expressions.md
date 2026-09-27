# Pastel Kitten: art spec and expression plan

Goal: replace the procedural placeholder look with one hand-painted "hero" character (the pastel kitten reference sheet) that breathes, moves organically and shows emotions. Random variety is reduced to color and small proportion changes.

## 1. How the art must be made

### Workflow (important)

Separately generated parts almost never line up or share a style. Do this instead:

1. Make **one master painting**: the kitten, front view, sitting, neutral face, on a **2048 × 2048** transparent canvas. Pose and proportions as in the sheet's main image, but facing straight at the viewer (the sheet's main pose is 3/4).
2. Split it into the layers below in an editor (Procreate, Photoshop, Krita, Affinity).
3. **Paint hidden areas**: every layer must be complete where other layers cover it (fur under the ears, head bottom under nothing but body top under the head, body behind the tail, eye sockets under the eyes). When parts move, those areas become visible.
4. Export **every layer as a full-canvas 2048 × 2048 PNG**, in place (do not crop or move). A small import tool (see §3, phase 1) crops each layer, finds its position and writes the atlas and layout. You never place anything by hand.

### Style rules

- Full color, painted exactly as it should appear. The app shows these unchanged (no grey tint layer).
- Soft top-left key light, same on every layer.
- No drop shadows or glows baked in; the app draws the ground shadow.
- Clean, soft alpha edges. Fur tufts may be wispy but not semi-transparent haze across the whole part.
- Leave about 10 % empty margin around ears, tail and hair tuft so they can bend without clipping.
- Only paint the **left** version of mirrored parts (left ear, left eyebrow). The app mirrors them.

## 2. Layer list

Sizes are approximate size inside the 2048 canvas; the import tool measures the real bounds. File names are what the import tool expects.

### Body and head (neutral pose)

| File | Part | Approx. size | Notes |
|---|---|---|---|
| `k_shadow.png` | Ground shadow | — | Keep the stand-in one unless you want a custom shadow |
| `k_tail.png` | Tail | 600 × 720 | Big fluffy plume, root at lower-left of the tail, curling up on the kitten's left. Drawn separately, fully painted where the body covers it |
| `k_body.png` | Body | 880 × 760 | Sitting body without paws, head, chest fluff. Top continues ~15 % under where the head sits |
| `k_chest.png` | Chest fluff | 560 × 400 | Lighter fluffy bib |
| `k_paw_left.png` | Left front paw | 300 × 200 | Separate from the right one (walk cycle later) |
| `k_paw_right.png` | Right front paw | 300 × 200 | |
| `k_head.png` | Head | 1160 × 1000 | Head with cheek fluff, **no** eyes, brows, nose, mouth, blush, hair tuft or ears. Paint the eye sockets as plain fur |
| `k_ear_left.png` | Left ear | 420 × 560 | Pink inner ear, fluffy inner tufts. Base extends ~20 % under the head |
| `k_hair.png` | Hair tuft | 480 × 340 | The wild spiky tuft on top |

### Face (neutral)

| File | Part | Approx. size | Notes |
|---|---|---|---|
| `k_eye_white_left.png` / `_right` | Eye white + dark outline | 300 × 320 each | Both eyes painted (light direction differs, so no mirroring) |
| `k_iris.png` | Iris | 250 × 250 | Warm amber-brown, radial detail, no pupil, no highlight |
| `k_pupil.png` | Pupil | 150 × 160 | Near-black, soft edge |
| `k_catchlight_big.png` | Main highlight | 90 × 90 | Pure white |
| `k_catchlight_small.png` | Small highlight | 40 × 40 | Pure white |
| `k_lid_left.png` / `_right` | Upper eyelid | 320 × 220 | Fur-colored, covers the whole eye when fully lowered. Slides down for blinks and sleepy looks |
| `k_brow_left.png` | Eyebrow | 140 × 50 | Soft lavender arc |
| `k_nose.png` | Nose | 90 × 70 | Pink rounded triangle |
| `k_blush_left.png` | Blush | 240 × 160 | Soft pink, transparent edges (the app fades it for emotions) |

### Expression layers

Painted on the same canvas, in place, over the neutral face.

| File | Used for | Notes |
|---|---|---|
| `k_eye_happy_left.png` / `_right` | Happy, wink | Closed "^" eye line, lashes optional |
| `k_eye_closed_left.png` / `_right` | Sleepy, sleep | Relaxed closed curve "‿" |
| `k_mouth_neutral.png` | Normal | Small cat "ω" mouth |
| `k_mouth_smile.png` | Happy | Open smile with small tongue |
| `k_mouth_o.png` | Surprised | Small round open mouth |
| `k_mouth_sad.png` | Sad | Small downturned mouth |
| `k_tear_left.png` | Sad (optional) | Glossy tear-well highlight on the lower lid |

Brow angle, lid height, pupil size, blush strength, ear angle and head tilt are animated by the app, so they need no extra art.

Iris, pupil and both catchlights are painted once, in the **left** eye. The right eye reuses them: iris and pupil mirrored, catchlights not (same light direction).

### Delivering and importing

Put the layers in `Art/Kitten/` (stand-ins live there now) together with `pivots.json`, which gives the tail root, ear base and neck in 1024-point canvas coordinates, y up:

```json
{ "k_head": [512, 420], "k_ear_left": [370, 745], "k_tail": [640, 240] }
```

Then run:

```sh
swift Tools/KittenArt/import.swift          # Art/Kitten → app/LumiKitten.atlas + app/KittenRig.json
swift Tools/KittenArt/make-standins.swift   # regenerate the stand-in layers (overwrites Art/Kitten)
```

### Image-generator prompts (for the master painting)

Base prompt:

> Cute chibi kitten character, front view, sitting upright, facing the viewer, symmetrical, pale lavender fluffy fur, lighter cream-lavender chest fluff, large pink-lined pointed ears, wild spiky tuft of hair on top of the head, big round glossy amber-brown eyes with large white highlights, small pink nose, soft pink blush cheeks, big fluffy curled tail, soft painterly 2D illustration, soft top-left lighting, clean edges, plain transparent background, no shadow, no text, game character sprite

Expression prompts: same base plus "closed happy eyes, open smile with small tongue" / "surprised, wide eyes, small round open mouth" / "sleepy, eyes closed, relaxed" / "sad, worried eyebrows, small frown". Use these as painting references for the expression layers; the layers themselves still have to be painted onto the master so they line up.

## 3. Rendering plan

Each phase ends with passing package tests and a visual review sheet.

1. **Hero art import.** `Tools/KittenImport`: reads the full-canvas layers, crops each to its alpha bounds, writes `LumiKitten.atlas` (iPhone at 1024 design points with @2x pixels; Watch downscaled) and `KittenRig.json` (part centers, sizes, pivot points for ear base, tail root and neck). Pre-colored sprites (`colorBlendFactor = 0`).
2. **Hero rig.** A `KittenNodeFactory` building a `PetRig` from `KittenRig.json`: separate paws, eyelids that slide (not fade), brows, swappable mouth and closed-eye sprites. Ears, tail and head rotate around their pivots, not their centers. Existing breathing, blink, gaze, ear twitch and weight-shift controllers keep working through the same rig nodes.
3. **Expressions.** A `PetExpression` enum (`normal, happy, surprised, wink, sleepy, sad`) mapped to a pose: lid height, brow angle and offset, mouth sprite, closed-eye sprites, pupil scale, blush alpha, ear angle, head tilt. Transitions blend over ~0.25 s through a new expression channel in `PetMotionComposer`. Blinks stay on top of any expression.
4. **Organic bending.** `SKWarpGeometryGrid` deformation for tail wag, ear flicks and a soft body squash that follows the breathing curve.
5. **Hooking it up.** How the app picks the kitten instead of a random Lumi: either the preset button, or a new `character` field in `PetConfiguration`. The field changes the stored format and needs a format-version bump, so it is a separate decision. Colors can later be varied with a hue-shift shader instead of tinting.
6. **Later.** Poses for walk, jump and sleep, with extra art for paws, body and tail.

Phases 2–4 can be built and tested with rough stand-in layers before the final art is ready.
