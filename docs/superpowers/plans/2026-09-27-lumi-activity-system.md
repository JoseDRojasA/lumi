# Lumi Activity System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Lumi lively, varied, interruptible motion — jump, dance, and weighted-random idle activities — that reads as depth (squash/stretch, arcs, anticipation, follow-through) without literal 3D. Build it as new procedural motion **sources** on the existing `PetMotionComposer`, so it works for every seeded pet variant and is triggerable/interruptible for future minigames.

**Non-goals:** No new renderer, no 3D, no frame-based sprite art, no new texture assets. No change to the `pet.*` node-naming contract. No literal camera-angle perspective.

**Architecture:** Two new types in `LumiRendering`, mirroring the existing `SecondaryMotionController` design exactly:

- `PetActivity` — a pure, data-driven description of a timed animation as **keyframed channel offsets** (root arc, body/chest squash-stretch via scale, paw lift, ear/tail follow-through, head bob). Value type, `Sendable`, no SpriteKit calls. Fully unit-testable.
- `ActivityController` — a `@MainActor` motion source, like `SecondaryMotionController`: deterministic `advance(by:)` driven purely by elapsed time, writes offsets into the composer under its own source keys, never calls `composer.apply()`. Owns a small state machine (`idle` / `playing`) and an `ActivityDirector` scheduler that picks weighted-random idle activities (with cooldowns) from a `SplitMix64` seeded stream, and exposes `play(_:)` / `stop()` for explicit (minigame) control that overrides the scheduler.

`PetScene` owns an `ActivityController` alongside `breathing`/`secondary`, advances it in `step(...)`, and continues to apply the composer once per frame in `didEvaluateActions()`. Activities layer additively on top of breathing and secondary motion because the composer sums position/rotation and multiplies scale across sources.

**Tech Stack:** Swift, SpriteKit, `Packages/LumiKit` (`LumiRendering`), Swift Testing/XCTest as used by existing `LumiRenderingTests`. Deterministic time-driven math (no wall clock, no `SKAction`, no system RNG) so it tests headless like `SecondaryMotionController`.

**Key facts grounded in current code:**
- `PetMotionChannel` cases available: `root, abdomen, chest, head, paws, leftEar, rightEar, tail, chestTuft, leftCheek, rightCheek`. Activities will primarily drive `root, chest, abdomen, paws, head, tail, leftEar, rightEar`.
- `PetMotionOffset`: `position` (additive), `zRotation` (additive), `xScale`/`yScale` (multiplicative, neutral = 1). Squash/stretch = scale offsets on `chest`/`abdomen`/`root`; hop = `position.dy` on `root`.
- Right ear is mirrored (`xScale -1`): rotation offsets applied to `.rightEar` must be negated relative to `.leftEar` (see `SecondaryMotionController.updateEar`).
- Composer combines sources deterministically sorted by `PetMotionSource.rawValue`. New sources must use stable, distinct raw values.
- Reduce Motion: amplitudes scale down (existing convention `× 0.25`); scheduling/timing need not change. Activities must honor this and the render policy (e.g. lower tiers may disable activities or shorten them).
- Scene lifecycle: `startAnimation()` resets/begins sources; `stopAnimation()` calls each controller's `reset()` then `composer.apply()`. `ActivityController.reset()` must clear its sources and return to idle.

---

## File structure

- Create `Packages/LumiKit/Sources/LumiRendering/PetActivity.swift`: the data model + built-in activity definitions (jump, dance, idle set) as keyframed channel tracks, plus the sampling function `sample(at:) -> [PetMotionChannel: PetMotionOffset]`.
- Create `Packages/LumiKit/Sources/LumiRendering/ActivityController.swift`: the `@MainActor` controller + `ActivityDirector` scheduler.
- Modify `Packages/LumiKit/Sources/LumiRendering/PetScene.swift`: own, advance, reset, and expose the controller; add `play(_:)`/`stopActivity()` passthroughs and a test accessor.
- Create `Packages/LumiKit/Tests/LumiRenderingTests/PetActivityTests.swift`: pure sampling/curve/keyframe tests.
- Create `Packages/LumiKit/Tests/LumiRenderingTests/ActivityControllerTests.swift`: determinism, layering, reduce-motion, interrupt/override, reset.
- Reference (read-only): `PetMotionComposer.swift`, `SecondaryMotionController.swift`, `BreathingController.swift`, `PetRig.swift`.

No art, atlas, rig JSON, or import scripts are modified.

---

## Task 1: `PetActivity` data model and built-in activities

**Files:**
- Create: `Packages/LumiKit/Sources/LumiRendering/PetActivity.swift`
- Read: `Packages/LumiKit/Sources/LumiRendering/PetMotionComposer.swift`
- Read: `Packages/LumiKit/Sources/LumiRendering/SecondaryMotionController.swift`

- [ ] **Step 1: Define the keyframe primitives**

Add value types: an easing enum (`linear`, `easeIn`, `easeOut`, `easeInOut` — reuse the same math as `SecondaryMotionController`/`BreathingCurve`), a `Keyframe` (`time: Double` normalized `0...1`, plus the offset components it sets), and a `ChannelTrack` (an ordered list of keyframes for one `PetMotionChannel`, sampled by interpolating between surrounding keyframes with the segment's easing). Position/rotation interpolate around neutral `0`; scale interpolates around neutral `1`.

- [ ] **Step 2: Define `PetActivity`**

`PetActivity` holds: a `name`/`id`, a `duration` (seconds), a `loops: Bool` (dance loops; jump does not), an amplitude-reducible flag, and `tracks: [PetMotionChannel: ChannelTrack]`. Add `func sample(atProgress p: Double, amplitudeScale: Double) -> [PetMotionChannel: PetMotionOffset]` that samples every track at `p`, applies `amplitudeScale` to position/rotation deltas and to (scale − 1), and returns per-channel offsets. Must be pure and `Sendable`.

- [ ] **Step 3: Author the built-in activities as data**

Define static factory activities:
- `.jump`: anticipation crouch (root dy down, chest yScale < 1 squash) → takeoff (root dy up along an ease-out arc, chest yScale > 1 stretch, paws lift via `.paws` dy) → apex → landing (ease-in down, squash) → settle. ~0.9 s, non-looping.
- `.dance`: rhythmic looping — root x sway + small dy bob, head counter-bob/tilt, alternating ear rotation, tail swish, subtle chest scale pulse. ~2.0 s period, loops.
- Idle set `.stretch`, `.lookAround`, `.happyWiggle`: short (0.8–1.6 s), gentle, non-looping. `.lookAround` is mostly head rotation + tail; `.stretch` is body scale + paw; `.happyWiggle` is small root x sway + tail.

Remember right-ear rotation is negated vs left (mirrored node). Keep amplitudes conservative; document each track's intent in comments.

- [ ] **Step 4: Provide the idle catalog**

Add a static `idleActivities: [PetActivity]` (stretch, lookAround, happyWiggle) and a way to look activities up by id, for the director and for `play(_:)`.

## Task 2: `ActivityController` + `ActivityDirector`

**Files:**
- Create: `Packages/LumiKit/Sources/LumiRendering/ActivityController.swift`
- Read: `Packages/LumiKit/Sources/LumiRendering/SecondaryMotionController.swift` (pattern to mirror)
- Read: `Packages/LumiKit/Sources/LumiRendering/PetMotionComposer.swift`

- [ ] **Step 1: Controller skeleton mirroring `SecondaryMotionController`**

`@MainActor final class ActivityController`. Init with `rig`, `composer`, `configuration`, `reduceMotion`, and a render/`includesEffects`-style gate. Own `elapsed: TimeInterval`, a `SplitMix64` seeded from `configuration.seed ^ <distinct constant>` (different constant than secondary's `0xA11CE_5EED`). Define a distinct `PetMotionSource` raw value (e.g. `"activity"`). Add `public private(set) var current: PetActivity?` and a small `enum State { case idle, playing(startElapsed: Double) }`.

- [ ] **Step 2: `advance(by:)`**

Clamp `dt` to `0...0.1`, accumulate `elapsed`. If playing: compute progress = `(elapsed − start) / duration`; if `> 1` and non-looping, finish (clear source offsets, return to idle, ask director to schedule the next idle time); if looping, wrap progress. Sample the activity with the current `amplitudeScale` (Reduce Motion → reduced) and write each returned per-channel offset into the composer under the activity source; channels the activity does not touch must be explicitly cleared to `.identity` for the source so stale offsets never linger. Never call `composer.apply()`.

- [ ] **Step 3: `ActivityDirector` scheduling**

Nested/companion type that, when the controller is idle, counts down a randomized inter-activity interval (e.g. `6...16 s`, drawn from the controller RNG like `SecondaryMotionController.drawInterval`) and then picks a weighted-random idle activity, avoiding immediate repeats. Starting an activity sets state to `.playing`. Scheduling is fully deterministic from the seed.

- [ ] **Step 4: Explicit control API for minigames**

`func play(_ activity: PetActivity)` — interrupts any current activity and starts the given one immediately (overrides the director; e.g. a minigame calls `play(.jump)`). `func stopActivity()` — ends the current activity, clears the source, returns to idle, reschedules. Document that explicit `play` takes precedence and that the director does not auto-schedule while an explicit non-looping activity is playing.

- [ ] **Step 5: `reset()`, `setReduceMotion(_:)`, and gating**

`reset()` clears the activity source across all channels, returns to idle, zeroes `elapsed`-derived play state (matching `SecondaryMotionController.reset()` semantics used by `PetScene.stopAnimation()`). `setReduceMotion(_:)` updates the amplitude scale live (applies next frame). If the policy gate disables activities (e.g. `.watch`), the director never schedules and `play` is a no-op (or reduced) — decide per policy and document it.

## Task 3: Integrate into `PetScene`

**Files:**
- Modify: `Packages/LumiKit/Sources/LumiRendering/PetScene.swift`
- Read: (already understood) its `init`, `step`, `didEvaluateActions`, lifecycle methods.

- [ ] **Step 1: Own and construct the controller**

Add a `private let activity: ActivityController`, constructed in `init` after `secondary`, passing `configuration`, `reduceMotion`, and the policy's effects/tier gate. Do not change how `composer`/`stage`/bounds are set up.

- [ ] **Step 2: Advance in the frame loop**

In `step(currentTime:)`, after `secondary.advance(by: dt)`, call `activity.advance(by: dt)`. Leave `didEvaluateActions()`/`applyComposedMotion()` unchanged — the single `composer.apply()` per frame now includes activity offsets.

- [ ] **Step 3: Lifecycle wiring**

In `stopAnimation()`, call `activity.reset()` before the existing `composer.apply()`. In `setReduceMotion(_:)`, call `activity.setReduceMotion(enabled)`. In `setPolicy(_:)`, update the activity gate if the policy changes activity availability. `startAnimation()` needs no special call beyond existing reset-on-start behavior, but confirm `elapsed` starts clean.

- [ ] **Step 4: Public API + test accessor**

Expose `public func playActivity(_ activity: PetActivity)` and `public func stopActivity()` that forward to the controller (for hosts/minigames). Add `public var activityCurrentForTesting: PetActivity? { activity.current }` and `public var activityElapsedForTesting: TimeInterval { activity.elapsed }` mirroring the existing `*ForTesting` accessors.

## Task 4: Tests

**Files:**
- Create: `Packages/LumiKit/Tests/LumiRenderingTests/PetActivityTests.swift`
- Create: `Packages/LumiKit/Tests/LumiRenderingTests/ActivityControllerTests.swift`
- Read: `Packages/LumiKit/Tests/LumiRenderingTests/BreathingTests.swift` (harness/style reference)

- [ ] **Step 1: `PetActivity` pure tests**

Assert: sampling at `p = 0` and `p = 1` yields expected boundary offsets; scale tracks are neutral (`1`) where undefined and interpolate around `1`; position/rotation tracks are neutral (`0`) where undefined; `amplitudeScale = 0` collapses every offset to `.identity`; jump's root `dy` is `0` at start/end and positive at apex; right-ear rotation is the negation of left-ear at the same progress.

- [ ] **Step 2: Controller determinism + layering**

Build a rig (reuse the test rig helper used by `BreathingTests`/`KittenRigTests`). Assert: two controllers with the same seed produce identical offset streams across a fixed `advance` schedule (determinism); while an activity plays, composing with breathing/secondary present still restores exactly to base after the activity ends and the source is cleared (no drift — mirror `completedCycleRestoresExactBase`).

- [ ] **Step 3: Reduce Motion + gating**

Assert amplitudes shrink when `reduceMotion` is on (peak offset magnitude strictly smaller than full), and that a disabled policy gate yields `.identity` on all channels / no scheduling.

- [ ] **Step 4: Interrupt/override + reset**

Assert `play(.jump)` interrupts a running idle activity immediately and becomes `current`; `stopActivity()` returns to idle and clears the source; `reset()` clears all channels for the activity source and sets `current` to nil. Verify the director does not schedule while an explicit non-looping activity is mid-play.

## Task 5: Verify

**Files:**
- Verify: whole `LumiKit` package.

- [ ] **Step 1: Build + test the package**

Run:

```sh
swift test --package-path Packages/LumiKit
```

Expected: builds clean; all new and existing `LumiRendering` tests pass. Existing breathing/secondary/kitten-rig tests must remain green (no regression from the added source).

- [ ] **Step 2: Confirm no contract drift**

Confirm no changes to `PetMotionChannel`, the `pet.*` node names, or existing controller public APIs beyond additive members. `grep` the diff for accidental edits to `KittenRigLayout`/`KittenNodeFactory`/`PetNodeFactory`.

- [ ] **Step 3: Report**

Report the new files, the built-in activities implemented (jump, dance, stretch, lookAround, happyWiggle), test results as evidence, and the public API a host/minigame uses (`PetScene.playActivity(_:)` / `stopActivity()`). Do not create a Git commit unless the user explicitly requests one.

---

## Follow-ups (out of scope for this plan)

- Wire a debug UI (or a temporary gesture in the app target) to trigger `playActivity(.jump)` for on-device visual confirmation once the kitten atlas art is finalized.
- Optional per-activity art polish (e.g. a mid-jump ear shape) if procedural follow-through proves insufficient — deferred and optional per `AGENTS.md` decision 4.
- Minigame integration: the `play/stop` API is the seam; a future minigame controller drives it.
