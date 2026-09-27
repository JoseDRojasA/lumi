# AGENTS.md — Lumi decisions & conventions

Context for anyone (human or agent) working on Lumi. Records **decisions** and the
**reasoning** behind them so they aren't accidentally reversed. Keep this current when
a decision changes; note the date and supersede rather than silently editing history.

See also: `README.md` (layout, commands, iCloud), and the specs/plans under
`docs/superpowers/`.

---

## 1. Character

- **Decision:** Lumi's canonical character is the **fluffy pastel-lavender kitten** in
  `Art/Kitten/references/` (`hero.png` / `rig_master.png` are the identity anchors).
  Disney/Pixar-style soft-plush 3D look: pastel lavender-white fur, pink inner ears &
  cheek blush, oversized amber-brown eyes, tiny pink nose, big upswept crown tuft.
- **Why:** chosen as the app's mascot; all art and animation target this design.

## 2. Rendering architecture — 2.5D layered puppet (committed)

- **Decision:** Lumi is rendered as a **2.5D layered puppet in SpriteKit**, not a
  frame-based sprite animation and not a 3D model. We are **committing to 2.5D**.
- **How it works:** `KittenNodeFactory` (+ `KittenRigLayout` / `KittenRig.json`)
  assembles ~28 flat painted part layers (`k_*`) into a node tree following the
  `pet.*` naming contract. Motion is applied by transforming named nodes each frame.
- **Why:**
  - **Per-pet variety must be preserved** (the seeded generator composes different
    ears/tails/patterns/colors per pet). Variety works because motion acts on the rig
    *structure*, so every variant animates for free.
  - **Programmatic control** is required for planned **minigames** (trigger, interrupt,
    blend, react to input) — a puppet gives this; pre-baked frames do not.
  - True 3D perspective is **not** a requirement (see decision 4).
- **Rejected alternatives:**
  - *Frame-based sprite sheets* (whole-cat-per-frame): conflicts with per-pet variety
    (every trait combo would need re-rendered frame sets) and isn't programmatically
    controllable. (This is what an earlier ChatGPT/DALL·E export produced — see decision 3.)
  - *Full 3D (SceneKit/RealityKit)*: overkill for "lively motion," and fights variety
    (meshes + blendshapes + material swaps per trait). Only justified if literal
    camera-angle perspective becomes a hard requirement.

## 3. Kitten art pipeline

- **Decision:** kitten parts are produced as the **28 transparent `k_*` layers**
  required by `KittenRigLayout.requiredPartNames`, all on one shared square canvas
  (2048×2048 recommended), then imported with `Tools/KittenArt/import.swift`
  (→ `app/LumiKitten.atlas` + `app/KittenRig.json`). Three parts carry pivots
  (`k_head`, `k_ear_left`, `k_tail`) via `Art/Kitten/pivots.json`.
- **Mirroring:** right ear/cheek/brow and the right eye white/lid are **engine mirrors**
  of the left; iris/pupil/catchlights are painted once and reused for both eyes. Do NOT
  author right-side ear/cheek/brow art.
- **Best-quality source method:** cut the layers from **one master painting**
  (`rig_master.png`) so all parts share style, lighting, and registration — matching
  what `import.swift` was designed for. Expression eyes/mouths that don't exist in the
  neutral master come from `expr_sheet.png` / `motion_*.png`.
- **Why:** independent per-part image generation (tried with DALL·E) does **not**
  guarantee registration or on-model style — a delivered zip of 28 independently-drawn
  parts came back off-style and misaligned (blank right eye, single detached ear,
  fragmented tail). Slicing one painting avoids this.
- **Prompt/brief docs:** `Art/Kitten/DALLE_PROMPTS.md`, `Art/Kitten/CHATGPT_BRIEF.md`
  (kept for reference; note their known limitation above).
- **Status:** the shipping `k_*` atlas is not yet finalized from the reference art.

## 4. Motion — procedural "Activity" system (direction, not yet built)

- **Decision:** lively/varied motion (jump, dance, random idle activities) will be
  built as **procedural motion sources on the existing `PetMotionComposer`**, not as
  new art or a new renderer.
- **Design sketch:** an `ActivityController` (a `PetMotionSource`) plays keyframed
  channel offsets (root arc, body squash/stretch, ear/tail follow-through, paw lifts)
  that layer on top of `BreathingController` / `SecondaryMotionController`; an
  `ActivityDirector` schedules weighted-random idle activities and can be overridden by
  explicit `play(.jump)`-style calls for minigames.
- **Scope of "perspective":** means **lively motion that reads as depth**
  (squash/stretch, arcs, anticipation, follow-through) — NOT literal 3D camera rotation.
  Confirmed acceptable.
- **Why here:** the composer already blends multiple sources into per-node channels, so
  activities act on rig structure and work for every seeded variant, and are
  interruptible/triggerable for minigames.
- **Respect:** reduce-motion and render policy, exactly as breathing already does.

## Conventions

- Do **not** modify the `pet.*` node-naming contract without updating both node
  factories and the motion controllers/tests.
- Prefer extending the composer with new **sources** over hard-coding animations onto
  nodes.
- Package logic lives in `Packages/LumiKit`; run `swift test --package-path Packages/LumiKit`.
- iCloud sync is intentionally OFF (see README) — don't enable without the paid-team steps.
