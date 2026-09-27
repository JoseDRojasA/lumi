# Lumi Kitten — ChatGPT Images Prompt Pack

An ordered, copy-ready playbook for producing the Lumi kitten's art with ChatGPT
Images (GPT Image). Work top to bottom. Each stage has a gate; do not advance
until the gate passes.

This tool cannot guarantee true transparency, exact 2048×2048 output, or
pixel-perfect alignment between layers. Every AI result must be verified and
cleaned up by a human editor. Treat AI output as a painting reference, not a
finished production asset, until you have inspected it.

---

## 1. Quick start

**Two source references (attach to almost everything):**

- **Reference A** — `/Users/joserojas/Downloads/ChatGPT Image Sep 27, 2026, 10_48_39 AM.png`
  Controls character identity, face, palette, fur, and premium painterly finish.
  This is the identity truth until a hero is approved.
- **Reference B** — `/Users/joserojas/Downloads/ChatGPT Image Sep 27, 2026, 10_50_29 AM.png`
  Controls production-friendly front-facing proportions, layered structure,
  expressions, and animation intent.

**Attachment rules**

- For the analysis and hero-candidate stages, attach **A and B**.
- Once a hero is approved, attach the **approved hero first (primary)**, then A,
  then B, on every later request. The hero becomes the identity truth; A and B
  become secondary support.

**File naming (what you save)**

| Stage | Save the accepted artifact as |
|---|---|
| Hero candidates | `hero_candidate_01.png` … `hero_candidate_06.png` |
| Refined hero | `hero_refined.png` |
| Locked hero | `hero_locked.png` (the primary identity reference from here on) |
| Frontal rig master | `rig_master.png` |
| Expression sheet | `expr_sheet.png` |
| Occlusion guide | `occlusion_guide.png` |
| Optional motion refs | `motion_walk.png`, `motion_tailwag.png`, etc. |
| Final split layers | the 28 `k_*.png` names in Section 8 |

**Output naming (what you tell ChatGPT to return)**
Ask for a single PNG on a transparent background at 2048×2048 unless a prompt
says otherwise. Rename the download yourself to the stage name above.

**Image-edit rules**

- After you pick a hero candidate, **never regenerate from scratch**. Use
  image-edit mode (attach the artifact and edit it) so identity is preserved.
- **One request at a time.** One goal per prompt. Do not batch fixes.
- **Freeze unrelated pixels** on every edit — change only the named region.
- **Return to the last accepted artifact on degradation.** If an edit damages an
  area that was already correct, discard the result, re-attach the last accepted
  artifact, and retry with a narrower instruction.

**Recommended first action:** Run the **Reference analysis** prompt (Section 4)
and do not generate any art until ChatGPT returns the written identity
specification. See Section 13.

---

## 2. Reference hierarchy

Resolve conflicts in this order (higher wins):

1. **Approved hero** (`hero_locked.png`) — once it exists, it is the final word
   on identity, face, palette, and fur.
2. **Reference A** — identity, face, palette, fur, painterly finish (identity
   truth before a hero exists).
3. **Reference B** — front-facing proportions, layered structure, expressions,
   animation intent.
4. **This document's DNA / Preserve / Never blocks** — arbiter when the images
   are ambiguous or silent.

If A and B disagree on a look, A wins on identity/finish and B wins on
proportion/pose usefulness. If the hero and A disagree, the hero wins.

---

## 3. Reusable blocks

Paste these verbatim into prompts where indicated. They encode the character so
ChatGPT cannot reinterpret it.

### Canonical character DNA

```
Canonical character DNA — a single specific recurring kitten named Lumi.
Palette: pale pearl-lavender fur, soft and luminous, not gray, not white.
Head: oversized rounded head with soft cheek tufts; head reads larger than the body.
Body: compact pear-shaped seated body; short forelegs; broad rounded paws.
Tail: large plume tail curling upward on the kitten's LEFT side.
Ears: tall pointed ears with pink-lined inner ears.
Crown: one distinctive swept, layered, spiky crown tuft rising from the top of the head.
Chest: a layered pale chest ruff.
Eyes: huge, widely spaced amber-copper eyes with near-black pupils; two fixed
white catchlights per eye — one big, one small — in matching positions.
Nose: tiny rounded pink triangular nose. Mouth: a very small cat mouth.
Cheeks: subtle warm-pink blush.
Finish: premium painterly illustration with dimensional individual fur strands
and soft rounded volume. Warm key light from the upper LEFT; restrained
cool-lavender shadow on the lower right. Reads as a hand-painted illustration,
not a photo, not a 3D render.
```

### Preserve

```
Preserve exactly: the same individual kitten identity, face, and expression
character; the pearl-lavender palette; the oversized-head-to-small-body ratio;
crown tuft shape and sweep; ear shape and pink lining; huge widely spaced
amber-copper eyes with near-black pupils and the two fixed white catchlights;
tiny pink triangular nose; small cat mouth; chest ruff; plume tail curling up on
the LEFT; broad rounded paws; painterly fur strands and soft volume;
upper-left warm key light with cool-lavender shadow.
```

### Never add or change

```
Never add or change: no accessories, no clothing, no collar, no hat; no coat
markings, stripes, spots, or patches; no whiskers; no extra, missing, or
malformed limbs or paws; no mismatched or asymmetric eyes; no scenery,
background objects, floor, or props; no text, labels, watermark, signature, or
border; no baked-in rim glow or halo; no baked-in ground/contact shadow; do not
crop any part of the kitten; no photorealism, no glossy plastic 3D look, no
toy/vinyl look, no flat outline-heavy vector look; no soft diffuse alpha haze
around the edges.
```

---

## 4. Hero lock

Goal of this stage: choose and freeze one hero image that defines the character.

### 4.1 Reference analysis — TEXT ONLY, NO IMAGE

```
Do not generate any image. Analysis only.
Attached are two reference images of the same kitten character (A: identity and
finish; B: proportions and structure). In writing, produce a precise identity
specification I can reuse as a prompt: describe palette (name the lavender tone),
head-to-body ratio, crown tuft shape, ear shape and inner-ear color, eye shape,
color, spacing, pupil, and catchlight positions, nose, mouth, chest ruff, tail
shape and which side it curls to, paw shape, fur rendering style, and the
lighting direction. List anything the two references disagree on. Do not
invent accessories, markings, or scenery. Return text only.
```

Gate/next step: read the returned spec. If it matches Section 3, proceed to 4.2.
If not, correct it in chat and re-ask before generating anything.

### 4.2 Hero candidate generation

- **Attach:** Reference A, Reference B.
- **Goal:** Generate one appealing hero portrait of this exact kitten.
- **Preserve:** Paste the **Preserve** block. Keep the character identical to A.
- **Reject if:** any item in the **Never add or change** block appears; eyes are
  mismatched; tail is on the wrong (right) side; palette drifts to gray/white.
- **Save as:** `hero_candidate_01.png` (repeat for 02–06).
- **Gate/next step:** Generate 4–6 candidates, then go to 4.3.

```
Attached: Reference A (identity and finish) and Reference B (proportions).
Generate ONE hero illustration of this exact kitten, seated, three-quarter or
gentle front view, on a fully transparent background, 2048×2048.
A slight expressive head tilt is allowed, but it must be unmistakably the same
individual kitten.

[PASTE: Canonical character DNA]

[PASTE: Preserve]

[PASTE: Never add or change]

Return one PNG with a transparent background.
```

Run this prompt 4–6 times (or ask for variations) and save each as
`hero_candidate_0N.png`.

### 4.3 Candidate critique — TEXT ONLY, NO IMAGE

```
Do not generate any image. Critique only.
Attached are hero candidates for the same kitten plus Reference A. For each
candidate, score identity match to A from 1–10 and list concrete defects: eye
symmetry and catchlight placement, tail side, crown tuft shape, palette accuracy,
paw count and shape, any stray markings, accessories, scenery, text, baked
shadow or glow, or edge haze. Recommend the single best candidate to refine and
name the exact fixes it still needs. Return text only.
```

Gate/next step: pick the winner. Save it as `hero_refined.png` and edit it in
4.4. Do not start a fresh generation.

### 4.4 Surgical candidate refinement — IMAGE EDIT

- **Attach:** `hero_refined.png` (the chosen candidate) first, then Reference A.
- **Goal:** Fix only the defects named in 4.3, nothing else.
- **Preserve:** Everything not named. Paste the **Preserve** block.
- **Reject if:** the edit changes identity, palette, or any correct area.
- **Save as:** `hero_refined.png` (overwrite once accepted).
- **Gate/next step:** When all defects are gone, go to 4.5.

```
Edit the attached hero image. Change ONLY the following and freeze every other
pixel: [DESCRIBE the specific defect(s) to fix, e.g. "the left eye catchlight is
missing — add one big and one small white catchlight matching the right eye"].
Do not alter identity, palette, pose, crown tuft, tail, or lighting.

[PASTE: Preserve]

[PASTE: Never add or change]

Return one PNG with a transparent background at the same size.
```

If the edit degrades any correct area, discard it, re-attach the previous
accepted `hero_refined.png`, and retry with a narrower instruction.

### 4.5 Final identity lock

- **Attach:** `hero_refined.png` first, then Reference A.
- **Goal:** Confirm this is the final hero; make no visual change.
- **Preserve:** All.
- **Reject if:** the model alters anything.
- **Save as:** `hero_locked.png`.
- **Gate/next step:** This is now the primary identity reference for every later
  prompt. Proceed to Section 5.

```
Do not generate any image. Confirm only.
Attached is the final hero for this kitten plus Reference A. Confirm in writing
that it satisfies the identity specification (palette, head-to-body ratio, crown
tuft, ears, eyes and catchlights, nose, mouth, chest ruff, tail on the LEFT,
paws, painterly fur, upper-left light) with no accessories, markings, scenery,
text, baked shadow/glow, or edge haze. If anything fails, list it. Return text
only.
```

Once confirmed, rename the accepted file to `hero_locked.png`.

---

## 5. Frontal rig master

Goal: a clean, level, front-facing, seated, neutral master on a 2048×2048
transparent canvas — centered, uncropped, with safe margins, no baked ground
shadow, no glow. The rig master may change **only pose and camera**; it must be
the same character as the locked hero.

### 5.1 Master generation / edit

- **Attach:** `hero_locked.png` (primary) first, then Reference A, then Reference B.
- **Goal:** Produce the frontal neutral seated master.
- **Preserve:** Identity from the hero; paste the **Preserve** block.
- **Reject if:** the character changes; the pose is not front-facing and level;
  the kitten is cropped; there is a baked shadow, glow, or edge haze.
- **Save as:** `rig_master.png`.
- **Gate/next step:** Run the side-by-side critique in 5.2.

```
Attached: the approved hero (primary identity reference), Reference A, and
Reference B. Produce the same individual kitten in a NEW pose only: seated
straight on, facing the camera directly, head level (no tilt), body centered,
neutral calm expression, eyes open, mouth in the small neutral shape.
Canvas 2048×2048, fully transparent background. Center the kitten with generous
safe margins so nothing touches the canvas edge; do not crop any part.
Change only pose and camera — the character must remain identical to the hero.

[PASTE: Canonical character DNA]

[PASTE: Preserve]

[PASTE: Never add or change]

Return one PNG, transparent background, 2048×2048, no ground shadow and no glow.
```

If you already have a near-correct master, run the same instruction as an edit on
`rig_master.png` instead of generating fresh.

### 5.2 Master critique — TEXT ONLY, NO IMAGE

```
Do not generate any image. Critique only.
Attached: the frontal master and the approved hero. Placed side by side, confirm
they are the same individual kitten. Report specifically: is the pose truly
front-facing and level; is the kitten centered and uncropped with safe margins;
are the eyes symmetric with correct catchlights; is the tail plume on the LEFT;
is the palette and upper-left lighting consistent with the hero; is the
background truly empty with no baked shadow, glow, or edge haze. List every
deviation. Return text only.
```

Gate/next step: if clean, proceed to Section 6. If not, run 5.3.

### 5.3 Master surgical repair — IMAGE EDIT

```
Edit the attached frontal master. Change ONLY this and freeze all other pixels:
[DESCRIBE the deviation from the 5.2 critique, e.g. "the head is tilted slightly
left — rotate the head to level while keeping the same face and features"].
Do not change identity, palette, or lighting. Keep the kitten centered,
uncropped, on a transparent background with safe margins.

[PASTE: Preserve]

[PASTE: Never add or change]

Return one PNG, transparent background, 2048×2048.
```

If the repair degrades a correct area, discard it and re-attach the last accepted
`rig_master.png`.

---

## 6. Production references

These are **painting references only** — visual guides for the human editor. They
are **not** production layers and are not exported directly as `k_*.png` files.

Keep fixed across all of them: identity, skull shape, eye placement, camera,
scale, key light (upper-left), and fur treatment. Only the named expression or
occlusion detail changes.

### 6.1 Occlusion / hidden-area guide

- **Attach:** `hero_locked.png` (primary), `rig_master.png`, Reference A.
- **Goal:** Show what is behind overlapping parts so the editor can paint hidden
  areas when separating layers.
- **Preserve:** Identity, camera, scale, light.
- **Reject if:** identity or camera changes.
- **Save as:** `occlusion_guide.png`.
- **Gate/next step:** Hand to the editor alongside Section 8.

```
Attached: the approved hero (primary), the frontal master, and Reference A.
Do not change the character, camera, scale, or lighting. Produce a painting
reference that shows the full, complete shape of each body part as if nothing
overlapped it: the whole head behind the ears and crown tuft, the full body
behind the chest ruff and forelegs, the complete tail behind the body, and each
paw in full. This is a reference sheet to help a human editor reconstruct hidden
areas; label parts if helpful. Same individual kitten, transparent background.
```

### 6.2 Six-expression sheet

- **Attach:** `hero_locked.png` (primary), `rig_master.png`, Reference B.
- **Goal:** One sheet of six heads showing the exact expressions.
- **Preserve:** Identity, skull, eye placement, camera, scale, light, fur.
- **Reject if:** the skull or eye placement shifts between cells; identity drifts.
- **Save as:** `expr_sheet.png`.
- **Gate/next step:** Painting reference for the expression textures in Section 8.

```
Attached: the approved hero (primary), the frontal master, and Reference B.
Produce ONE reference sheet with six front-facing heads of the same individual
kitten, in a labeled 3×2 grid, in this order:
1) normal — eyes open, small neutral mouth;
2) happy — eyes in soft happy arcs, small smile;
3) surprised — eyes wide and round, small open "o" mouth;
4) wink — kitten's LEFT eye closed in a happy arc, right eye open;
5) sleepy — both eyes nearly closed, calm mouth;
6) sad — brows raised inner, downturned small mouth.
Keep the skull shape, eye placement, camera, scale, and upper-left light
identical in every cell — only the eyes, brows, and mouth change. Same palette
and painterly fur throughout. Transparent background. This is a painting
reference, not a production layer.
```

---

## 7. Optional later-phase references

**Not required for the current layer deliverable.** These are for a later
animation phase. Do them only after Sections 5, 6, and 8 are accepted. Each is a
painting reference, not a production layer.

For every prompt below: attach `hero_locked.png` (primary), `rig_master.png`,
Reference B; preserve identity, palette, and upper-left light; keep the same
individual kitten; return a transparent PNG.

```
WALK — Show the same kitten in a gentle side-on walk cycle reference: 4 frames of
alternating short-foreleg steps, body bob subtle, tail plume trailing. Same
character, transparent background. Painting reference only. Save as motion_walk.png.
```

```
TAIL WAG — Show the same kitten seated front-on with the LEFT plume tail in 3
positions (upright, mid-sweep, far-sweep). Body and head unchanged. Painting
reference only. Save as motion_tailwag.png.
```

```
BLINK — Show the same front-facing head in 3 steps: eyes open, half-closed, fully
closed (calm lids). Eye placement fixed. Painting reference only. Save as
motion_blink.png.
```

```
HAPPY / EXCITED — Show the same kitten seated front-on, bright happy eyes, open
smile, ears perked, tail lifted. Painting reference only. Save as motion_excited.png.
```

```
SLEEP — Show the same kitten curled or seated with eyes closed and a calm face,
gentle breathing pose. Painting reference only. Save as motion_sleep.png.
```

```
JUMP — Show the same kitten mid-jump reference: 3 frames (crouch, launch, apex),
paws tucked, tail streaming. Painting reference only. Save as motion_jump.png.
```

---

## 8. Layer production (manual)

A human editor separates and repairs the layers. AI transparency and alignment
are **not** guaranteed — the editor must verify every edge and pivot.

**Rules for every layer file**

- Export a **full-canvas 2048×2048 PNG in place** (the part sits at its true
  position on the full canvas; do not trim or recenter).
- **Paint hidden areas** so each part is complete behind whatever overlaps it
  (use the occlusion guide from 6.1).
- **Clean, soft alpha edges** — no hard jaggies and no diffuse alpha haze.
- Keep **safe margins**; nothing touches the canvas edge.
- Keep **consistent upper-left key light** on every part.
- `k_shadow` is a **separate** soft contact shadow layer — it must NOT be baked
  into any other part.
- **Mirror** the left ear and left brow to make the right side: `k_ear_left` →
  right ear, `k_brow_left` → right brow (there is no `k_ear_right`/`k_brow_right`
  file; the rig mirrors them).
- **Reuse** `k_iris` and `k_pupil` for both eyes (single shared texture each).
- **Do not mirror catchlights** — `k_catchlight_big` and `k_catchlight_small`
  keep the same on-screen positions for both eyes so the gaze stays consistent.
- Set **pivots** for the rotating parts: `k_head`, `k_ear_left`, and `k_tail`
  (see `pivots.json`: head ≈ [512, 420], left ear ≈ [370, 745], tail ≈ [640, 240]).

**The 28 required layer files** (exact names, all must exist):

Base and body:
`k_shadow`, `k_tail`, `k_body`, `k_chest`, `k_paw_left`, `k_paw_right`

Head and crown:
`k_head`, `k_ear_left`, `k_hair`

Eyes (neutral, open):
`k_eye_white_left`, `k_eye_white_right`, `k_iris`, `k_pupil`,
`k_catchlight_big`, `k_catchlight_small`, `k_lid_left`, `k_lid_right`

Face detail:
`k_brow_left`, `k_nose`, `k_blush_left`

Expression eye variants:
`k_eye_happy_left`, `k_eye_happy_right`, `k_eye_closed_left`, `k_eye_closed_right`

Mouths:
`k_mouth_neutral`, `k_mouth_smile`, `k_mouth_o`, `k_mouth_sad`

**Optional, not required:** `k_tear_left` (a small tear for a sad/crying accent).
Do not create it unless a later phase explicitly asks for it. It is not part of
the 28 required files.

---

## 9. Repair prompt library

Surgical, one-defect-at-a-time edits. Every prompt **freezes all unrelated
pixels**. If a repair degrades a correct area, discard it and re-attach the last
accepted artifact. Where a defect region must be identified, fill the
`[DESCRIBE...]` operator field — keep it specific.

**Identity drift**

```
Edit the attached image. It has drifted from the approved hero's identity.
Restore the exact same individual kitten to match the attached hero: palette,
head-to-body ratio, crown tuft, ears, eyes, nose, mouth, chest ruff, tail.
Change only what is needed to restore identity; freeze correct pixels.
[PASTE: Preserve] [PASTE: Never add or change]
```

**Wrong pose / camera**

```
Edit the attached image. Change ONLY the pose/camera to: seated, front-facing,
head level, centered, uncropped, safe margins. Keep the same individual kitten,
palette, and upper-left light. Freeze the character's features.
[PASTE: Preserve]
```

**Eyes**

```
Edit the attached image. Fix ONLY the eyes: huge, widely spaced, amber-copper
irises, near-black pupils, and two white catchlights each (one big, one small) in
matching positions. Freeze everything else. Do not change eye placement or size
relative to the head. [PASTE: Preserve]
```

**Asymmetry**

```
Edit the attached image. Fix ONLY the asymmetry in [DESCRIBE the asymmetric
region, e.g. "the ears — the left ear is taller than the right"]. Make the two
sides match while keeping the same individual kitten. Freeze all other pixels.
[PASTE: Preserve]
```

**Anatomy / paws**

```
Edit the attached image. Fix ONLY the anatomy defect: [DESCRIBE, e.g. "the right
forepaw has five toes and is malformed"]. Restore two short forelegs and two
broad rounded paws, correct count and shape. Freeze all other pixels.
[PASTE: Never add or change]
```

**Crown tuft or tail**

```
Edit the attached image. Fix ONLY [DESCRIBE: "the crown tuft" or "the tail"] so
it matches the hero: the crown is one swept, layered, spiky tuft; the plume tail
curls upward on the kitten's LEFT. Freeze all other pixels. [PASTE: Preserve]
```

**Fur / rendering**

```
Edit the attached image. Fix ONLY the fur rendering in [DESCRIBE the region] so
it is premium painterly with dimensional fur strands and soft volume — not flat,
not plastic 3D, not photographic. Keep the same shapes and palette. Freeze all
other pixels.
```

**Palette / lighting**

```
Edit the attached image. Fix ONLY the palette/lighting: restore the pale
pearl-lavender fur (not gray, not white) and a warm key light from the upper LEFT
with restrained cool-lavender shadow on the lower right. Do not move or reshape
anything. Freeze geometry. [PASTE: Preserve]
```

**Transparency / background**

```
Edit the attached image. Make the background fully transparent with clean, soft
alpha edges around the kitten. Remove any background color, checkerboard, halo,
or diffuse alpha haze. Do not change the kitten. Return a transparent PNG.
```

**Crop / safe margin**

```
Edit the attached image. The kitten is cropped or touching the edge. Recompose so
the entire kitten is visible and centered on a 2048×2048 transparent canvas with
generous safe margins. Do not change the character. [PASTE: Preserve]
```

**Baked shadow / glow**

```
Edit the attached image. Remove ONLY the baked-in [DESCRIBE: "ground/contact
shadow" or "rim glow/halo"] from under/around the kitten. Leave the kitten and
its own soft-form shading untouched. Return a transparent PNG with an empty
background.
```

**Expression drift**

```
Edit the attached image. The expression drifted. Restore ONLY the eyes, brows,
and mouth to the target expression: [DESCRIBE target, e.g. "surprised — wide
round eyes, small open o mouth"]. Keep the skull, eye placement, and identity
fixed. Freeze all other pixels.
```

**Assembled layer seams**

```
Edit the attached assembled image. Fix ONLY the visible seam/gap between layers
at [DESCRIBE location, e.g. "where the head meets the body under the chest
ruff"]. Blend so the join is invisible without moving any part. Freeze all other
pixels. Note: seam fixes on the composite are references; the real fix is in the
separated layer files.
```

---

## 10. Quality gates

Advance only when every box in a gate is true.

**Hero gate**
- [ ] Same individual kitten as Reference A.
- [ ] Palette, crown tuft, ears, eyes + both catchlights, nose, mouth, chest ruff.
- [ ] Tail plume on the LEFT; two forelegs, two broad rounded paws.
- [ ] No accessories, markings, whiskers, scenery, text, baked shadow/glow, haze.
- [ ] Saved as `hero_locked.png`.

**Master gate**
- [ ] Front-facing, level, seated, neutral; centered, uncropped, safe margins.
- [ ] 2048×2048 transparent; no baked shadow, glow, or edge haze.
- [ ] Same character as the hero (pose/camera changed only). Saved as `rig_master.png`.

**Expressions gate**
- [ ] All six expressions present and correct (normal, happy, surprised, wink,
      sleepy, sad).
- [ ] Skull, eye placement, camera, scale, light, and fur identical across cells.
- [ ] Labeled clearly as a painting reference, not a layer.

**All-layers gate**
- [ ] All 28 required `k_*.png` files exist at full-canvas 2048×2048, in place.
- [ ] Hidden areas painted; clean soft alpha; safe margins; upper-left light.
- [ ] `k_shadow` separate; left ear/brow to be mirrored; `k_iris`/`k_pupil`
      shared; catchlights not mirrored.
- [ ] Pivots set for `k_head`, `k_ear_left`, `k_tail`.

**Import / runtime gate**
- [ ] `swift Tools/KittenArt/import.swift` runs without missing-part errors.
- [ ] Rig assembles with no gaps or seams; parts land at correct positions.

**iPhone gate**
- [ ] Kitten renders centered and uncropped; expressions switch correctly; no
      halo or hard edges at device scale.

**Watch gate**
- [ ] Kitten reads clearly at small size; no clipped parts; identity still
      recognizable; expressions legible.

---

## 11. Import command

After the editor produces all 28 `k_*.png` files in `Art/Kitten/`, import them:

```sh
swift Tools/KittenArt/import.swift
```

---

## 12. Execution log

Keep one row per request.

| # | Stage | Input artifact | Prompt (short) | Result | Defects found | Repair applied | Accepted? | Output file |
|---|-------|----------------|----------------|--------|---------------|----------------|-----------|-------------|
| 1 | Analysis | A + B | reference analysis (text) | spec text | — | — | Y/N | — |
| 2 | Hero gen | A + B | candidate 01 | | | | Y/N | hero_candidate_01.png |
| 3 | | | | | | | | |
| 4 | | | | | | | | |

---

## 13. Recommended first action

Start with **Section 4.1 Reference analysis**. Attach Reference A and Reference B
and run the text-only analysis prompt. **Do not generate any art** until ChatGPT
returns a written identity specification you have read and confirmed against
Section 3. Only then move to hero candidate generation (4.2).
