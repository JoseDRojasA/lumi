# Lumi kitten image-generation prompt pack design

**Date:** 2026-09-27  
**Status:** Approved design  
**Final deliverable:** `Art/Kitten/IMAGE_GENERATION_PROMPTS.md`

## Purpose

Create an ordered prompt pack for ChatGPT Images / GPT Image that first locks a polished hero kitten and then produces the references needed to build Lumi's layered SpriteKit character. The process must preserve one recognizable character across every image while adapting the supplied polished three-quarter reference to a centered, front-facing, animation-friendly rig.

This is a hybrid art workflow. AI generates the master paintings and controlled variants; an editor separates, aligns, and repairs the production layers. The workflow does not assume that independently generated sprite parts will reassemble reliably.

## Inputs

- **Reference A:** `/Users/joserojas/Downloads/ChatGPT Image Sep 27, 2026, 10_48_39 AM.png`
  - Primary authority for identity, face, fur treatment, palette, and premium painterly finish.
- **Reference B:** `/Users/joserojas/Downloads/ChatGPT Image Sep 27, 2026, 10_50_29 AM.png`
  - Primary authority for front-facing proportions, layerable structure, expressions, and intended animation use.
- **Approved hero:** the accepted output from the hero-lock stage. Once selected, it becomes the primary identity reference attached to every later request.
- **Existing art contract:** `docs/superpowers/specs/2026-09-27-kitten-art-and-expressions.md`.
- **Import pipeline:** `Tools/KittenArt/import.swift`, `Art/Kitten/pivots.json`, and `app/KittenRig.json`.

## Selected approach: character-lock pipeline

The prompt pack is an executable sequence, not a menu of unrelated prompts:

1. Establish generation rules and reference priority.
2. Extract and freeze the kitten's visual DNA.
3. Generate several hero candidates.
4. Refine one candidate through image edits until approved.
5. Freeze the approved hero as the canonical identity reference.
6. Convert that hero into a frontal neutral rig master without redesigning it.
7. Generate hidden-area, expression, and optional motion-pose references from the master.
8. Separate and repair the production layers in an image editor.
9. Import the layers and evaluate the assembled SpriteKit rig.
10. Use targeted repair prompts only when a stage fails its quality gate.

Each accepted output is the input to the next stage. A failed artifact is corrected in place; the workflow must not advance by silently accepting drift.

## Prompt-pack structure

The final Markdown file will contain these sections in execution order:

1. **Quick start** — required attachments, naming, canvas, transparency, and how to use image edits.
2. **Reference hierarchy** — Reference A controls identity and finish; Reference B controls production structure; the approved hero supersedes both for later identity matching.
3. **Canonical character DNA** — a reusable invariant block included in every generation.
4. **Global freeze and exclusion rules** — instructions that prevent redesign, incidental changes, and unwanted visual features.
5. **Hero-lock prompts** — candidate generation, candidate critique, targeted refinement, and final identity-lock confirmation.
6. **Frontal rig-master prompts** — conversion to a level, centered, symmetrical, neutral, seated master on a 2048 × 2048 transparent canvas.
7. **Production-reference prompts** — hidden-area guide, expression sheet, and optional motion-pose sheets.
8. **Layer-separation brief** — full-canvas alignment, completed covered regions, clean alpha, safe margins, filenames, mirroring, reuse, and pivots.
9. **Repair prompt library** — identity drift, pose drift, eye mismatch, anatomy, symmetry, fur, lighting, alpha, crop, shadow, and layer-seam corrections.
10. **Quality gates** — checklists for the hero, rig master, expression reference, separated layers, imported rig, iPhone scale, and Watch scale.
11. **Execution log template** — accepted image, rejected issue, repair used, and resulting canonical reference.

Every operational prompt will have four clearly marked pieces:

- **Attach:** the images that must accompany the request.
- **Goal:** the one transformation being requested.
- **Preserve:** identity and rendering properties that must remain unchanged.
- **Reject if:** concrete failure conditions that require another edit.

## Locked visual target

The kitten is one specific recurring character, not a generic lavender kitten.

### Silhouette and proportions

- Oversized rounded head with soft cheek tufts.
- Compact pear-shaped seated body.
- Short forelegs and broad, rounded front paws.
- Large fluffy plume tail curling upward on the kitten's left.
- Tall pointed ears with warm pink interiors and soft inner-ear fur.
- Distinctive swept, layered, spiky crown tuft.
- Layered light chest ruff.

### Face

- Extremely large, widely spaced amber-copper eyes.
- Dark near-black pupils with a fixed large and small white catchlight arrangement.
- Consistent iris diameter, eye spacing, eyelid contour, and gaze across outputs.
- Tiny rounded pink triangular nose.
- Very small cat mouth and subtle warm-pink cheek blush.
- Cute and alert, but not baby-human, doll-like, or excessively surprised.

### Color and rendering

- Near-white pearl-lavender fur.
- Slightly deeper cool lavender in shadow and warmer pearl highlights.
- Pink ears, nose, and blush; warm amber-copper irises.
- Premium painterly character illustration with dimensional fur strands and soft volume.
- More polished and dimensional than Reference B, without becoming photorealistic, plastic, or toy-like.
- Soft warm key light from the upper left with restrained cool-lavender shadow.
- Clean, soft alpha edges with intentional wispy fur tips, not a diffuse haze.

### Pose rules

- Hero candidates may retain a slight expressive head tilt.
- The production master must be level, frontal, centered, neutral, seated, and bilaterally balanced.
- The conversion to the production master may change pose and camera only. It must not change identity, proportions, facial geometry, palette, tuft design, tail design, or rendering style.

### Exclusions

No accessories, clothing, markings, stripes, spots, whiskers, extra limbs, malformed paws, mismatched eyes, asymmetric eye rendering, background scenery, text, labels, border, outline-heavy vector style, plastic 3D surface, baked rim glow, or baked ground shadow.

## Production asset contract

The editor will derive full-canvas 2048 × 2048 PNG layers from the approved frontal master. Layers stay in their original canvas position and must include painted content beneath overlaps so animation never exposes holes.

The current rig requires these 28 texture names:

- `k_shadow`
- `k_tail`
- `k_body`
- `k_chest`
- `k_paw_left`
- `k_paw_right`
- `k_head`
- `k_ear_left`
- `k_hair`
- `k_eye_white_left`
- `k_eye_white_right`
- `k_iris`
- `k_pupil`
- `k_catchlight_big`
- `k_catchlight_small`
- `k_lid_left`
- `k_lid_right`
- `k_brow_left`
- `k_nose`
- `k_blush_left`
- `k_eye_happy_left`
- `k_eye_happy_right`
- `k_eye_closed_left`
- `k_eye_closed_right`
- `k_mouth_neutral`
- `k_mouth_smile`
- `k_mouth_o`
- `k_mouth_sad`

Only the left ear and left brow are authored because the rig mirrors them. Iris and pupil art is authored once and reused for the right eye; catchlights keep the same upper-left light direction rather than being mirrored. The head, left ear, and tail require pivots. `k_tear_left` may be created later but is not part of the required texture contract.

The master and layers must contain no baked ground shadow; `k_shadow` remains a separate asset. Leave safe transparent margins around the ears, tail, and hair so deformation and rotation do not clip.

## Generation and editing flow

### Stage 1: hero lock

Generate four to six candidates from both source references. Select one based on identity fidelity, silhouette, face geometry, palette, painterly finish, and emotional appeal. Refine the selected candidate using image edits that change only named defects. Once approved, rename and preserve it as the canonical hero.

### Stage 2: frontal neutral master

Attach both original references and the approved hero, with the hero identified as the primary authority. Produce a 2048 × 2048 transparent master that is centered, level, straight-on, neutral, seated, uncropped, and surrounded by safe margin. Correct the master through edits until it matches the hero when compared side by side.

### Stage 3: supporting references

Generate references that help the editor paint rather than attempting to replace the editor:

- A construction/occlusion reference showing plausible complete fur beneath the head, ears, chest, paws, and tail overlaps.
- A consistent expression sheet for normal, happy, surprised, wink, sleepy, and sad.
- Optional walk, tail-wag, blink, excited, sleep, and jump pose references for later phases.

These images are visual guides. They are not accepted automatically as aligned production layers.

### Stage 4: manual separation and repair

Separate the approved frontal master in Procreate, Photoshop, Krita, Affinity, or an equivalent editor. Paint hidden regions, preserve the master canvas coordinates, keep lighting coherent, and export each required layer as a full-canvas transparent PNG.

### Stage 5: import and assembled review

Run:

```sh
swift Tools/KittenArt/import.swift
```

Review the assembled kitten at normal iPhone size and reduced Watch size. Exercise head tilt, ear rotation, tail motion, blinking, gaze, breathing, and expression swaps. Repair source layers or use a targeted AI edit only for a clearly isolated visual defect.

## Quality gates

### Hero gate

Pass only when the candidate unmistakably matches Reference A's character identity while retaining the production-friendly intent of Reference B. Eye geometry, crown tuft, ear shape, cheek silhouette, chest ruff, tail plume, palette, and fur finish must all be stable.

### Rig-master gate

Pass only when the kitten remains the same character after the frontal conversion. The full body must be visible, centered, level, symmetrical enough to rig, neutral in expression, evenly separated from the canvas edge, and free of scenery, text, baked shadow, and clipping.

### Expression gate

Pass only when every expression reads clearly without changing skull shape, eye placement, iris color, fur shape, tuft arrangement, ear anatomy, camera, scale, light, or paint treatment.

### Layer gate

Pass only when all 28 required files exist at full-canvas coordinates; covered areas are painted; alpha edges are clean; mirrored/reused components follow the rig contract; and the head, ear, and tail have sufficient overlap and margin around their pivots.

### Runtime gate

Pass only when the assembled character has no visible holes, halos, double edges, lighting discontinuities, or clipping during supported motion and remains legible on both iPhone and Watch.

## Failure handling

The pack will favor surgical image edits over regeneration. A repair prompt must:

1. Name the single defect.
2. Define the exact region or property allowed to change.
3. Freeze identity, composition, anatomy, palette, lighting, texture, camera, and all unrelated pixels.
4. Restate the objective pass condition.
5. Require a clean transparent output when appropriate.

If an edit introduces a second defect, return to the last accepted artifact rather than stacking repairs on a degraded image. If repeated edits cannot fix a structural issue, regenerate from the last approved stage—not from an unapproved intermediate.

## Success criteria

The final prompt pack succeeds when a user can follow it without inventing missing steps; establish one approved hero; reproduce that identity in a frontal neutral master; generate consistent expression and construction references; prepare every required Lumi layer; diagnose common generation failures; and validate the assembled character against the approved hero on both iPhone and Watch.

## Scope boundaries

The deliverable contains prompts, attachment instructions, production notes, repair recipes, and QA checklists. It does not generate the final art, edit the PNG layers, change SpriteKit code, or redesign the existing rig contract.
