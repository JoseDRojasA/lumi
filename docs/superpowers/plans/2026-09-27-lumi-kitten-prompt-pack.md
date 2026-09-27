# Lumi Kitten Image Prompt Pack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a complete, execution-ordered ChatGPT Images prompt pack that locks the Lumi kitten's identity and guides production of its SpriteKit art assets.

**Architecture:** One self-contained Markdown playbook will live beside the kitten source art. It will combine reusable invariant prompt blocks with stage-specific prompts, stop gates, repair recipes, a manual layer brief, and runtime QA; validation will compare its headings and texture names against the approved design and `KittenRigLayout.requiredPartNames`.

**Tech Stack:** Markdown, ChatGPT Images / GPT Image, Swift/SpriteKit asset conventions, Python 3 validation script executed inline.

---

## File structure

- Create `Art/Kitten/IMAGE_GENERATION_PROMPTS.md`: the operator-facing prompt sequence and production checklist.
- Reference `docs/superpowers/specs/2026-09-27-lumi-kitten-prompt-pack-design.md`: approved requirements and visual target.
- Reference `docs/superpowers/specs/2026-09-27-kitten-art-and-expressions.md`: existing art and export contract.
- Validate against `Packages/LumiKit/Sources/LumiRendering/KittenRigLayout.swift`: authoritative required texture names.

No production code, PNG assets, rig JSON, or import scripts will be modified.

### Task 1: Write the operator-facing prompt pack

**Files:**
- Create: `Art/Kitten/IMAGE_GENERATION_PROMPTS.md`
- Read: `docs/superpowers/specs/2026-09-27-lumi-kitten-prompt-pack-design.md`
- Read: `docs/superpowers/specs/2026-09-27-kitten-art-and-expressions.md`

- [ ] **Step 1: Write quick-start and reference instructions**

State the two source reference paths, label them Reference A and Reference B, establish the approved hero as the later primary identity reference, require image-edit mode after candidate selection, and define artifact filenames for accepted stages.

- [ ] **Step 2: Write reusable canonical prompt blocks**

Include copy-ready fenced blocks for `CHARACTER DNA`, `PRESERVE`, and `NEVER ADD OR CHANGE`. Encode the approved silhouette, facial geometry, palette, upper-left lighting, premium painterly fur treatment, transparency, and exclusions verbatim enough to prevent reinterpretation.

- [ ] **Step 3: Write the hero-lock sequence**

Provide copy-ready prompts for character analysis, four-to-six candidate generation, candidate critique without generation, targeted candidate refinement, and final hero lock. Each prompt must name attachments, one goal, preserved properties, and rejection conditions.

- [ ] **Step 4: Write the frontal rig-master sequence**

Provide copy-ready prompts that attach both originals plus the approved hero, change only pose/camera, create a level front-facing neutral seated 2048 × 2048 transparent master, check it side by side, and repair only identified drift.

- [ ] **Step 5: Write production-reference prompts**

Provide copy-ready prompts for an occlusion/hidden-area painting guide and a six-expression sheet: normal, happy, surprised, wink, sleepy, and sad. Add optional walk, tail-wag, blink, excited, sleep, and jump reference prompts clearly labeled as later-phase material rather than required current layers.

- [ ] **Step 6: Write the manual layer-production brief**

List all 28 required texture filenames exactly. Explain full-canvas export, hidden-area completion, alpha edges, safe margins, upper-left lighting, separate shadow, mirrored left ear/brow, reused iris/pupil, unmirrored catchlights, and pivots for head, left ear, and tail.

- [ ] **Step 7: Write the repair library**

Provide surgical copy-ready repair prompts for identity drift, wrong pose or camera, eye mismatch, asymmetry, anatomy/paws, tuft or tail drift, fur/rendering drift, palette/lighting drift, transparency/background errors, crop/safe-margin failures, baked shadow/glow, expression drift, and visible assembled-layer seams. Every repair must freeze unrelated pixels and instruct the operator to return to the last accepted artifact if the edit degrades another area.

- [ ] **Step 8: Write stage gates and execution log**

Add pass/fail checklists for hero, frontal master, expressions, separated layers, import, iPhone display, and Watch display. Include the exact import command `swift Tools/KittenArt/import.swift` and a compact log table for prompt number, input artifact, result, defects, repair, and acceptance.

### Task 2: Validate completeness and production usability

**Files:**
- Verify: `Art/Kitten/IMAGE_GENERATION_PROMPTS.md`
- Compare: `docs/superpowers/specs/2026-09-27-lumi-kitten-prompt-pack-design.md`
- Compare: `Packages/LumiKit/Sources/LumiRendering/KittenRigLayout.swift`

- [ ] **Step 1: Run the placeholder scan**

Run:

```sh
grep -Ein '\b(TBD|TODO|FIXME|XXX|fill in|add appropriate|similar to task)\b' Art/Kitten/IMAGE_GENERATION_PROMPTS.md
```

Expected: no output and exit status 1, indicating no incomplete placeholders.

- [ ] **Step 2: Verify all required sections are present**

Run:

```sh
python3 - <<'PY'
from pathlib import Path
text = Path('Art/Kitten/IMAGE_GENERATION_PROMPTS.md').read_text()
required = [
    'Quick start', 'Reference hierarchy', 'Canonical character DNA',
    'Hero lock', 'Frontal rig master', 'Production references',
    'Layer production', 'Repair prompt library', 'Quality gates',
    'Execution log',
]
missing = [heading for heading in required if heading.lower() not in text.lower()]
print('missing sections:', missing)
raise SystemExit(bool(missing))
PY
```

Expected: `missing sections: []` and exit status 0.

- [ ] **Step 3: Verify the documented texture contract**

Run:

```sh
python3 - <<'PY'
from pathlib import Path
import re
swift = Path('Packages/LumiKit/Sources/LumiRendering/KittenRigLayout.swift').read_text()
doc = Path('Art/Kitten/IMAGE_GENERATION_PROMPTS.md').read_text()
block = re.search(r'requiredPartNames: \[String\] = \[(.*?)\n    \]', swift, re.S).group(1)
required = set(re.findall(r'"(k_[^"]+)"', block))
documented = set(re.findall(r'`(k_[^`]+)`', doc))
missing = sorted(required - documented)
print(f'required={len(required)} documented-required={len(required & documented)}')
print('missing:', missing)
raise SystemExit(bool(missing))
PY
```

Expected: `required=28 documented-required=28`, `missing: []`, and exit status 0.

- [ ] **Step 4: Review prompt operability**

Read the document from top to bottom and confirm each numbered generation step states: attachments, single goal, preserved properties, rejection criteria, output filename, and next gate. Confirm required stages are not mixed with optional later animation references.

- [ ] **Step 5: Report the deliverable without committing**

Report the created file, validation evidence, and the recommended first prompt to run. Do not create a Git commit unless the user explicitly requests one.
