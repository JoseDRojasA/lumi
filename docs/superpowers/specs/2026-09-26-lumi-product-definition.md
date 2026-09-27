# Lumi Product Definition

**Milestone:** 0 — Random Lumi  
**Status:** Approved for implementation planning  
**Date:** 2026-09-26  
**Platforms:** iOS, iPadOS, macOS, watchOS

## 1. Product statement

Lumi is an Apple-ecosystem virtual companion represented by a configurable SpriteKit pet in a soft plush cinematic chibi style. Milestone 0 proves the technical foundation: generate one valid random Lumi, persist it locally, synchronize it through the user's private iCloud database, and render the same living pet breathing with plausible animal anatomy in the center of the screen on iPhone, iPad, Mac, and Apple Watch.

The milestone is intentionally narrow. It validates shared product code, deterministic generation, SwiftData and CloudKit integration, SpriteKit rendering, and native platform targets before care mechanics or other product features are introduced.

## 2. Verified current state

Paths in this document use the Xcode workspace-relative organization supplied by the project.

The starter project is the default SwiftData item template rather than a Lumi implementation.

| Area | Current state | Evidence |
|---|---|---|
| Application UI | Displays, adds, navigates to, and deletes timestamp items | `app/app/ContentView.swift:11-58` |
| Persistence | Creates a local SwiftData container containing only `Item` | `app/app/appApp.swift:13-30` |
| Model | `Item` contains only a `timestamp` | `app/app/Item.swift:11-17` |
| iCloud | CloudKit service is declared, but the container identifier array is empty | `app/app/app.entitlements:9-14` |
| Entitlements linkage | The application target does not currently evaluate a `CODE_SIGN_ENTITLEMENTS` path | Target build settings inspected 2026-09-26 |
| Background sync | Remote notification background mode is present | `app/app/Info.plist:5-8` |
| Platforms | The application target covers iPhone, iPad, Mac, and visionOS; no watchOS target exists | Target and build settings inspected 2026-09-26 |
| Tests | Unit and UI tests are placeholders | `app/appTests/appTests.swift:10-16`, `app/appUITests/appUITests.swift:25-41` |

Vision Pro is not part of this milestone. Native visionOS SpriteKit support is outside the requested product scope, so the application target should no longer advertise visionOS during the milestone implementation.

## 3. Milestone goal

A successful Milestone 0 produces the following observable experience:

1. The user launches Lumi on a supported device.
2. Lumi loads an existing pet or generates one random valid configuration.
3. The pet configuration is persisted before it is presented.
4. A layered SpriteKit pet appears in the exact visual center of the available scene.
5. The pet continuously performs ambient idle animations.
6. Relaunching shows the same pet.
7. After CloudKit synchronization, another device using the same iCloud account shows the same pet configuration.

The pet starts at level 1. The level is persisted but is not shown or changed in this milestone.

## 4. Scope

### 4.1 Included

- One active Lumi per user interface.
- Collection-ready pet identity so multiple Lumis can be added later.
- Versioned deterministic random pet generation.
- Configuration-driven body, face, color, marking, tail, ear, tuft, magical, and motion traits.
- A modular SpriteKit rig built from layered `SKSpriteNode` textures, masks, color treatments, and restrained shader accents.
- A production visual-style contract derived from the supplied reference: soft plush fur, rounded chibi proportions, oversized glossy eyes, tiny facial features, pastel coloring, and cinematic soft lighting.
- Anatomically believable resting breathing, plus blinking, gaze, ear, tail, and body-weight motion.
- Production-ready texture artwork for every required rig part and supported trait in generator version 1.
- A centered, adaptive presentation on iPhone, iPad, Mac, and Apple Watch.
- SwiftData local persistence.
- SwiftData-managed synchronization through a private CloudKit database.
- Offline-first operation without an in-app account.
- Swift Testing coverage for domain, persistence, and rendering behavior.
- XCUIAutomation launch coverage for each application shell.

### 4.2 Explicitly excluded

- Onboarding, tutorials, story, egg selection, and hatching sequences.
- Care meters, feeding, petting, sleeping, mood simulation, or progression rules.
- Level gain or visual evolution. Only the initial level value is stored.
- Mini-games, memories, inventory, accessories, or customization interfaces.
- Foundation Models or generated dialogue.
- Sign in with Apple or any Lumi-managed user account.
- StoreKit products, subscriptions, or purchase restoration.
- Multiple-pet creation or collection UI.
- Widgets, complications, App Intents, Live Activities, and Control Center controls.
- WatchConnectivity fast-path messaging.
- Push content from a Lumi-operated server.
- Audio, haptics, analytics, or remote configuration.

These exclusions are product boundaries, not architectural dead ends. The code structure must allow these features to be added without replacing the pet model, generator, renderer, or persistence layer.

## 5. Product principles

1. **The pet is data, not artwork selection.** A Lumi is reconstructed from a versioned configuration and modular art parts rather than identified by one pre-rendered character image.
2. **Generation is permanent and reproducible.** The saved seed and generator version can reproduce a configuration if its encoded payload becomes unreadable.
3. **Rendering never owns product state.** SpriteKit receives immutable presentation data and reports interactions through explicit interfaces.
4. **The style is a contract.** Every generated combination must preserve the reference's soft plush chibi character, cohesive lighting, readable face, and warm emotional appeal.
5. **Motion follows anatomy.** Breathing and idle motion originate from plausible body regions and joints; the renderer must never simulate life by uniformly scaling the complete character.
6. **Local use never depends on network access.** CloudKit synchronizes the local replica when system conditions permit.
7. **Every platform feels native.** Shared logic does not require identical platform navigation or lifecycle code.
8. **Random does not mean invalid.** Every generated combination must pass compatibility, visibility, range, and visual-cohesion validation.
9. **Motion creates attachment.** Even this minimal milestone must feel alive while respecting battery, lifecycle, and Reduce Motion settings.

## 6. Target and module architecture

### 6.1 Milestone target graph

Keep the existing `app` application target and shared scheme as internal Xcode identifiers; set the bundle display name to `Lumi`. The target remains the multiplatform shell for iOS, iPadOS, and macOS. Add `LumiWatch` as the only new application target in this milestone.

| Target or product | Platform | Milestone responsibility |
|---|---|---|
| `app` (display name `Lumi`) | iOS, iPadOS, macOS | Thin application composition root and centered pet screen |
| `LumiWatch` | watchOS | Independent watch application shell and centered pet screen |
| `LumiCore` | Shared Swift package product | Configuration, generator, validator, domain values, and repository protocol |
| `LumiPersistence` | Shared Swift package product | SwiftData records, container creation, repository implementation, and schema migration |
| `LumiRendering` | Shared Swift package product | SpriteKit scene, pet rig, node factory, animation controller, and render policy |
| `LumiCoreTests` | Shared package tests | Pure generation and configuration tests |
| `LumiPersistenceTests` | Shared package tests | In-memory repository and schema tests |
| `LumiRenderingTests` | Shared package tests | Rig composition and animation-state tests |
| `LumiUITests` | iOS, iPadOS, macOS UI tests | Launch and centered-pet assertions |
| `LumiWatchUITests` | watchOS UI tests | Watch launch and pet-presence assertions |

Empty future targets and modules must not be created during Milestone 0. WidgetKit and broader feature modules are introduced only when their first behavior is implemented.

### 6.2 Intended project organization

```text
app/
├── Apps/
│   ├── LumiApp/
│   │   ├── LumiApp.swift
│   │   ├── AppDependencies.swift
│   │   ├── MobileRootView.swift
│   │   ├── MacRootView.swift
│   │   └── Resources/
│   │       ├── LumiPet.atlas/
│   │       └── RigAnchors.json
│   └── LumiWatch/
│       ├── LumiWatchApp.swift
│       ├── WatchRootView.swift
│       └── Resources/
│           ├── LumiPetWatch.atlas/
│           └── RigAnchors.json
├── Packages/
│   └── LumiKit/
│       ├── Package.swift
│       ├── Sources/
│       │   ├── LumiCore/
│       │   ├── LumiPersistence/
│       │   └── LumiRendering/
│       └── Tests/
│           ├── LumiCoreTests/
│           ├── LumiPersistenceTests/
│           └── LumiRenderingTests/
├── Resources/
│   └── Assets.xcassets
├── appTests/
└── appUITests/
```

### 6.3 Dependency rules

```text
Lumi app ─────┬──> LumiPersistence ──┐
              ├──> LumiRendering ────┼──> LumiCore
LumiWatch ────┴──> LumiPersistence ──┘
              └──> LumiRendering ───────> LumiCore
```

- `LumiCore` imports Foundation only.
- `LumiPersistence` imports SwiftData and `LumiCore`.
- `LumiRendering` imports SpriteKit and `LumiCore`.
- App targets import SwiftUI and compose concrete dependencies.
- `LumiRendering` must not import SwiftData.
- `LumiPersistence` must not import SpriteKit or SwiftUI.
- Views and SpriteKit scenes must not access `ModelContext` directly.
- No module imports an application target.

## 7. Core domain contract

### 7.1 Shared value types

All configuration value types conform to `Codable`, `Equatable`, and `Sendable`.

```text
PetConfiguration
├── Configuration metadata
├── Body configuration
├── Palette and markings
├── Face configuration
├── Ear and tail configuration
├── Tufts and magical feature
└── Motion personality
```

`PetConfiguration` is an immutable value after creation. Future visual evolution is represented by a separate overlay rather than mutating the original genome.

### 7.2 Configuration metadata

| Property | Type | Rule |
|---|---|---|
| `formatVersion` | `Int` | Starts at `1`; version of encoded configuration |
| `generatorVersion` | `Int` | Starts at `1`; selects exact generation rules |
| `seed` | `UInt64` | Generated once from `SystemRandomNumberGenerator` |

### 7.3 Appearance properties

| Property | Type | Milestone values or range |
|---|---|---|
| `bodyShape` | `BodyShape` | `round`, `compact`, `pear` |
| `bodyScale` | `Double` | `0.90...1.10` |
| `headScale` | `Double` | `0.90...1.15` |
| `furStyle` | `FurStyle` | `smooth`, `fluffy`, `spiky` |
| `baseColor` | `RGBAColor` | Four normalized channels |
| `secondaryColor` | `RGBAColor` | Four normalized channels |
| `accentColor` | `RGBAColor` | Four normalized channels |
| `patternStyle` | `PatternStyle` | `none`, `spots`, `stripes`, `mask`, `socks`, `gradient` |
| `patternDensity` | `Double` | `0...1` |
| `patternScale` | `Double` | `0.75...1.25` |
| `eyeShape` | `EyeShape` | `round`, `almond`, `sleepy` |
| `eyeScale` | `Double` | `0.85...1.15` |
| `irisColor` | `RGBAColor` | Four normalized channels |
| `pupilStyle` | `PupilStyle` | `round`, `vertical`, `star` |
| `earStyle` | `EarStyle` | `pointed`, `rounded`, `long`, `floppy` |
| `earScale` | `Double` | `0.80...1.20` |
| `earAngle` | `Double` | `0...1`, mapped to a safe rig angle |
| `tailStyle` | `TailStyle` | `short`, `long`, `curled`, `plume` |
| `tailLength` | `Double` | `0.80...1.20` |
| `tailThickness` | `Double` | `0.80...1.20` |
| `headTuftStyle` | `HeadTuftStyle` | `none`, `curl`, `split`, `windswept` |
| `chestTuftStyle` | `ChestTuftStyle` | `none`, `small`, `layered`, `cloud` |
| `muzzleStyle` | `MuzzleStyle` | `small`, `round`, `pronounced` |
| `noseStyle` | `NoseStyle` | `dot`, `triangle`, `heart` |
| `noseColor` | `RGBAColor` | Four normalized channels |
| `cheekStyle` | `CheekStyle` | `none`, `blush`, `freckles`, `glow` |
| `cheekColor` | `RGBAColor` | Four normalized channels |
| `magicalFeature` | `MagicalFeature` | `none`, `glow`, `sparkles`, `orbitingLight` |
| `magicalColor` | `RGBAColor` | Four normalized channels |
| `magicalIntensity` | `Double` | `0...1` |
| `motionPersonality` | `MotionPersonality` | `calm`, `curious`, `playful`, `lively`, `sleepy` |

`RGBAColor` is a platform-independent structure containing `red`, `green`, `blue`, and `alpha` values. SwiftUI `Color` and SpriteKit colors are created only in presentation modules.

Configurations use canonical JSON encoding with sorted keys. This gives the cross-platform determinism test a stable byte representation and keeps the persisted payload inspectable during development.

### 7.4 Future configuration additions

The following trait families are intentionally deferred but fit the versioned configuration format: wings, horns, antennae, multiple tails, mane variants, accessories, continuous body proportions, richer fur masks, species archetypes, personality values, and level-evolution overlays. Existing configurations remain valid when these fields are introduced because decoding supplies version-specific defaults.

## 8. Deterministic generation

`PetGenerator` exposes one product operation:

```swift
func generate(seed: UInt64, version: Int) throws -> PetConfiguration
```

Generation rules:

1. `SystemRandomNumberGenerator` creates the seed only once.
2. A project-owned stable seeded generator, not Swift hashing or platform randomness, resolves every trait.
3. The same seed and generator version must return byte-equivalent encoded configuration on every supported platform.
4. Trait catalogs use explicit weights stored in code for generator version 1.
5. Generation runs through `PetConfigurationValidator` before persistence.
6. Incompatible combinations are resolved deterministically, not rerolled with system randomness.
7. Secondary and accent colors must remain visibly distinct from the base color by hue or brightness.
8. Eyes, pupils, and facial marks must remain visible against adjacent colors.
9. Shape values are clamped to the safe rig ranges listed above.
10. Every generated configuration must produce every required rig node.

Generator rules are immutable after release. A changed algorithm receives a new `generatorVersion`.

## 9. Persistence model

### 9.1 `PetRecord`

Milestone 0 uses one CloudKit-compatible SwiftData model with no relationships.

| Property | Type | Initial value or rule |
|---|---|---|
| `id` | `UUID` | Created once; no SwiftData unique constraint |
| `configurationData` | `Data` | Encoded immutable `PetConfiguration` |
| `configurationFormatVersion` | `Int` | `1` |
| `generatorVersion` | `Int` | `1` |
| `seed` | `String` | Decimal representation of the full `UInt64` seed |
| `name` | `String` | `"Lumi"`; no rename UI in this milestone |
| `createdAt` | `Date` | Creation timestamp |
| `updatedAt` | `Date` | Last record update timestamp |
| `level` | `Int` | `1` |
| `experience` | `Int` | `0` |
| `isActive` | `Bool` | `true` for the canonical visible pet |

The encoded appearance payload is appropriate because the configuration is immutable. CloudKit conflict resolution therefore never needs to merge individual appearance traits.

CloudKit schema constraints:

- Every persisted property has a default value or is optional.
- No `@Attribute(.unique)` constraint is used because CloudKit cannot enforce it.
- No nonoptional relationships are introduced.
- Production schema changes are additive.
- Development schema initialization occurs only in debug tooling and is promoted before release.

### 9.2 Repository boundary

`PetRepository` is declared in `LumiCore` and implemented in `LumiPersistence`.

```swift
protocol PetRepository: Sendable {
    func activePet() async throws -> Pet?
    func createPetIfNeeded() async throws -> Pet
}
```

The repository owns SwiftData access. `Pet` is a domain value containing the record identity, decoded configuration, name, level, and experience.

### 9.3 Duplicate creation convergence

Two offline devices can each create a pet before CloudKit has delivered either record. Milestone 0 handles this without deleting future collection data:

1. Fetch all active `PetRecord` values.
2. Sort by `createdAt`, then by `id.uuidString` as a deterministic tie-breaker.
3. Select the first record as the canonical active Lumi.
4. Mark later records inactive after they arrive locally.
5. Expose only the canonical pet in Milestone 0.
6. Preserve inactive records for future multiple-Lumi migration.

All devices converge on the same canonical record after receiving the same CloudKit data set.

## 10. CloudKit synchronization

### 10.1 Configuration

- Use SwiftData's managed CloudKit integration rather than direct `CKRecord` APIs or `CKSyncEngine`.
- Use a private CloudKit database with container identifier `iCloud.heylumipet.app`.
- Set the model configuration explicitly to that private container rather than relying on entitlement order.
- Attach `app/app/app.entitlements` to the application target's `CODE_SIGN_ENTITLEMENTS` setting.
- Add the same CloudKit container capability to the watchOS app target.
- Retain the remote-notification background mode required for managed synchronization.
- Use one schema across phone, tablet, desktop, and watch applications.

Entitlement changes must be made through Xcode capability tooling, not by hand-editing the entitlement file.

### 10.2 Account behavior

- Sign in with Apple is not required.
- SwiftData works locally without any account.
- CloudKit sync is available when the user is signed into iCloud at the operating-system level and CloudKit is available.
- iCloud unavailability never blocks local pet creation or rendering.
- Synchronization is asynchronous and must not be described in the interface as immediate.
- When iCloud later becomes available, the existing local record enters managed synchronization automatically.

### 10.3 Store bootstrap

The starter's `fatalError` model-container failure path must be replaced. `LumiModelContainer` reports one of these states:

| State | Application behavior |
|---|---|
| `ready` | Load or create the pet and render it |
| `loading` | Show a centered system progress indicator if loading exceeds 150 ms |
| `failed` | Show a plain recovery view with error description and Retry |

The application must not silently switch to an in-memory store after a persistent-store failure because that would generate a temporary pet that disappears.

## 11. SpriteKit rendering architecture

### 11.1 Scene ownership

`PetScene` receives a `PetPresentation` value created from the domain pet. It does not query persistence, generate traits, calculate levels, or own application navigation.

```text
PetPresentation
      ↓
PetNodeFactory
      ↓
PetRig
      ↓
IdleAnimationController
      ├── BreathingController
      └── SecondaryMotionController
      ↓
PetScene
```

### 11.2 Visual-style contract

The supplied reference image is the Milestone 0 art-direction source. Every generated Lumi must belong to the same cohesive visual family even when its configuration changes.

Required characteristics:

- Soft plush or downy fur with visible directional tufts around the crown, cheeks, chest, body edge, and tail.
- Rounded chibi proportions: the head occupies 50–58% of total character height, the torso is compact, and the paws are short and softly rounded.
- Oversized glossy eyes occupying 24–30% of head width each, with a very dark pupil, colored iris rim, soft reflection gradient, and two controlled catchlights.
- A tiny nose and restrained mouth placed low on the face, preserving an innocent and approachable expression.
- Large expressive ears with soft inner-ear coloring and fur-integrated edges.
- Pastel, low-to-medium saturation colors with enough value separation to keep the face, chest, markings, and silhouette readable.
- Soft cinematic lighting: broad key light, gentle ambient fill, subtle rim separation, and a diffuse contact shadow beneath the pet.
- Rounded forms and soft edge transitions without hard black outlines.
- Enough texture and tonal depth to read as plush fur rather than flat vector shapes.

The pet must not look photorealistic, cel-shaded, pixel-art, flat-symbolic, plastic, metallic, or outlined like a sticker. Randomization may change traits and colors but may not break these style constraints.

### 11.3 Modular texture system

The production rig uses layered `SKSpriteNode` parts sourced from `SKTextureAtlas` resources compiled into each host app bundle. The iPhone/iPad/Mac shell injects `LumiPet`; the watch shell injects `LumiPetWatch`. This keeps asset loading native to SpriteKit while `LumiRendering` remains reusable and testable with an injected catalog. `SKShapeNode` is limited to invisible masks, debugging overlays, the diffuse ground shadow, and emergency fallback geometry; it is not the accepted final pet appearance.

Texture requirements:

- Each interchangeable part category uses a shared canvas, scale, pivot convention, and named attachment anchors.
- Base fur parts provide tint-friendly luminance and alpha information; markings and accent details use separate masks or overlay textures.
- Eyes separate sclera/iris, pupil, eyelid, and catchlight layers so gaze and blinking do not deform the complete head.
- Fur edge textures include transparent tuft silhouettes instead of relying on a smooth geometric outline.
- Baked shading remains neutral enough to accept configured colors without muddying the palette.
- A reduced-resolution watch atlas preserves the same silhouette and face while lowering memory and fill-rate cost.
- Atlas and node names are stable API within a generator version.
- Missing optional textures omit only the optional feature. Missing required textures use a reference-style fallback texture, never a flat colored primitive in the release build.

```text
pet.root
├── pet.shadow
├── pet.tail
│   └── pet.tail.detail
├── pet.body
│   ├── pet.body.base
│   ├── pet.abdomen
│   ├── pet.body.pattern
│   ├── pet.chest
│   └── pet.paws
├── pet.head
│   ├── pet.head.base
│   ├── pet.ears
│   ├── pet.headTuft
│   ├── pet.facePattern
│   ├── pet.eyes
│   │   ├── pet.eye.left
│   │   │   ├── pet.eye.left.iris
│   │   │   ├── pet.eye.left.pupil
│   │   │   ├── pet.eye.left.catchlight
│   │   │   └── pet.eye.left.lid
│   │   └── pet.eye.right
│   ├── pet.muzzle
│   ├── pet.nose
│   └── pet.cheeks
└── pet.magic
```

Every node has a stable semantic name. Animations address semantic nodes rather than array indexes.

### 11.4 Realistic resting breathing

Breathing must resemble a calm living animal rather than a generic pulse animation. `BreathingController` runs continuously and composes with all other idle channels.

A normal awake resting cycle lasts 2.4–4.0 seconds, corresponding to approximately 15–25 breaths per minute. `motionPersonality` selects a stable point inside that range and introduces gradual variation of no more than 5% across groups of three to six breaths.

Each cycle has four asymmetric phases:

| Phase | Cycle share | Motion |
|---|---:|---|
| Inhale | 32% | Abdomen expands first, followed by the chest and a slight shoulder lift |
| Inhale pause | 4% | The expanded pose holds briefly without becoming static |
| Exhale | 44% | Chest and abdomen settle smoothly, with fur and tail-tip motion lagging behind |
| Rest | 20% | The body remains near its base pose before the next inhale |

Anatomical motion rules:

- Paws remain planted and define the visual ground anchor.
- Abdomen width expands by 2.0–3.5% and height by 1.2–2.5% around a lower-body anchor.
- Chest rises by 1.0–2.0% of body height with a slight delay after abdominal expansion.
- Shoulders lift subtly; the head follows vertically by 0.5–1.2% of body height without changing head scale.
- Cheek, chest-tuft, and tail-tip nodes receive restrained delayed secondary motion during exhale.
- Eyes, pupils, nose, mouth, paws, ground shadow, and complete `pet.root` are never uniformly scaled to simulate breathing.
- The inhale and exhale use different ease curves; the cycle must not look sinusoidal or mechanically mirrored.
- The exact base transform is restored at every completed cycle, preventing cumulative drift.
- Watch uses the same timing and phase model while limiting secondary motion to the body, chest, and head.

### 11.5 Ambient animation set

| Animation | Timing | Configuration influence |
|---|---|---|
| Anatomical breathing | Continuous, 2.4–4.0 seconds per cycle | Motion personality changes rate and restrained amplitude |
| Blink | Random interval of 2.5–6 seconds | Sleepy personalities blink more slowly |
| Double blink | 15% of blink events | Curious personalities use it more often |
| Gaze | New target every 3–8 seconds | Curious and lively pets move farther |
| Ear twitch | Random interval of 5–12 seconds | Ear style constrains rotation axis |
| Tail motion | Continuous, 1.8–3.5 seconds per cycle | Tail style and personality change arc |
| Body weight shift | Random interval of 8–18 seconds | Calm pets use smaller movement |
| Magical effect | Intermittent when configured | Style, color, and intensity come from configuration |

Animation requirements:

- Actions use stable keys and replace prior actions with the same responsibility.
- Base transforms are stored so repeated animation never accumulates scale, rotation, or position drift.
- Breathing remains active while blink, gaze, ear, tail, and weight-shift channels run.
- Independent idle channels are staggered to prevent mechanical synchronization.
- Temporary animation randomness is session-local and is not persisted or synchronized.
- Scenes pause when their application scene is inactive.
- Large devices target 60 frames per second; Apple Watch targets 30 frames per second.
- Texture resolution, particle count, and effect complexity use a watch-specific performance policy.
- Reduce Motion preserves natural breathing at 40% of normal amplitude and blinking, while disabling orbiting effects and reducing gaze, ear, tail, and weight-shift motion to 25%.

### 11.6 Adaptive layout

The SpriteKit scene fills the available SwiftUI container. The rig remains centered at the scene's visual center and scales from the shorter scene dimension.

| Platform | Pet target size |
|---|---|
| iPhone portrait | 46% of the shorter scene dimension |
| iPhone landscape | 40% of the shorter scene dimension |
| iPad | 42% of the shorter scene dimension |
| macOS | 38% of the shorter scene dimension with min/max clamping |
| Apple Watch | 62% of the shorter scene dimension |

Safe areas affect the available container before the SpriteKit scene calculates its center. Window resizing and device rotation update the scene without reconstructing the pet configuration.

The milestone screen contains no navigation, controls, stats, story text, or decorative dashboard. It contains only an adaptive softly lit background, loading or error state when necessary, a diffuse contact shadow, and the centered Lumi.

Accessibility exposes the SpriteKit host as one element labeled with a generated description such as “A playful, fluffy purple Lumi with long ears.” Individual decorative rig nodes are not separately exposed.

## 12. Application data flow

```text
Application launch
      ↓
LumiModelContainer bootstrap
      ↓
PetRepository.activePet()
      ├── Existing record → decode configuration
      └── No record → create seed → generate → validate → persist
      ↓
Map Pet to immutable PetPresentation
      ↓
Create PetScene and PetRig
      ↓
Start ambient animation channels
      ↓
CloudKit synchronizes the local SwiftData replica opportunistically
```

The record save completes before `PetPresentation` is handed to the renderer. A force quit after presentation therefore cannot cause an appearance reroll on the next launch.

When a remote canonical record arrives after a locally generated record, the repository publishes the canonical pet and the app replaces the presentation using a short crossfade. No animation frame or temporary pose is synchronized.

## 13. Failure handling

| Failure | Required behavior |
|---|---|
| iCloud unavailable | Continue with local SwiftData storage; do not show authentication UI |
| CloudKit synchronization delayed | Continue showing local state; converge when updates arrive |
| Persistent store cannot open | Show Retry; never create an in-memory replacement pet |
| Configuration payload cannot decode | Regenerate from saved seed and generator version |
| Saved generator version is unsupported | Render a safe built-in fallback configuration without overwriting the record |
| Generated configuration fails validation | Resolve incompatibilities deterministically; fail creation if still invalid |
| Optional rig part or texture cannot be created | Omit that optional feature and continue |
| Required texture is missing or corrupt | Use the bundled reference-style fallback texture for that semantic part and record a diagnostic |
| Required rig node cannot be created | Rebuild it with the corresponding fallback texture; flat primitive geometry is debug-only |
| Animation clip cannot find a node | Skip the clip and retain breathing/idle fallback |
| Application becomes inactive | Pause SpriteKit actions and expensive effects |
| Multiple active records synchronize | Apply deterministic canonical-record selection |

No recoverable failure may call `fatalError` in production code.

## 14. Testing strategy

### 14.1 Swift Testing

| Suite | Required checks | Minimum count |
|---|---|---:|
| Generator | Same seed/version produces identical configuration; different seeds vary; ranges are valid; colors remain visible; all rig-required traits exist | 5 |
| Validator | Clamps numeric fields; repairs incompatible combinations; rejects unsupported versions; remains deterministic | 4 |
| Encoding | Configuration round-trip; seed recovery reproduces configuration | 2 |
| Pet defaults | New pet has level 1, experience 0, name “Lumi,” and active state | 1 |
| Repository | First request creates once; second request reuses; canonical selection is stable; invalid payload recovers; persistent failures propagate | 5 |
| Rig | Every configuration builds required semantic nodes; texture and anchor names are unique; optional nodes match traits; release rigs contain no visible flat fallback primitives | 4 |
| Breathing | Phase proportions are correct; paws remain anchored; root and head scale remain unchanged; abdomen/chest/head deltas stay in anatomical ranges; every cycle restores base transforms; Reduce Motion policy applies | 6 |
| Ambient animation | Required channels receive keyed actions; breathing composes with other channels; stopping restores base transforms | 3 |

At least 1,000 seeded configurations are validated in a deterministic generator property test.

A fixed matrix of 24 representative seeds covers every body, fur, eye, ear, tail, marking, and magical category. Each seed has a reference render snapshot at phone and watch atlas quality. Snapshot review checks the explicit style contract: plush fur edges, chibi proportions, glossy layered eyes, tiny facial features, pastel tonal separation, soft lighting, diffuse contact shadow, and absence of hard outlines or flat vector appearance.

### 14.2 XCUIAutomation

| Platform | Journey | Required assertion |
|---|---|---|
| iPhone | Launch clean installation | One accessible Lumi exists near screen center |
| iPad | Launch and rotate | The same Lumi remains centered after rotation |
| macOS | Launch and resize window | The Lumi remains centered and clamped to the allowed scale |
| Apple Watch | Launch watch app | One accessible Lumi exists and renders within the safe area |

### 14.3 Manual integration matrix

| Scenario | Expected result |
|---|---|
| Relaunch same device | Identity and configuration are unchanged |
| Launch device A, allow sync, then launch device B | Device B renders the same pet ID and encoded configuration |
| Launch without iCloud | A local pet is created and remains usable |
| Enable iCloud later | The local record begins synchronizing without account UI |
| Create independently on two offline devices, then reconnect | Both devices converge on the same canonical active pet |
| Background and foreground repeatedly | Animation pauses and resumes without transform drift |
| Observe breathing at normal speed and quarter speed | Abdomen leads, chest and shoulders follow, head rises subtly, paws stay planted, and exhale secondary motion lags naturally |
| Inspect the 24-seed reference matrix | Every pet remains in the supplied soft plush cinematic chibi style |
| Run for 30 minutes | Rig remains centered with stable base scale and position |
| Enable Reduce Motion | Anatomical breathing remains subtle while larger movement and orbiting effects are suppressed |

CloudKit verification uses development-container data and at least two installations signed into the same iCloud test account. Simulator-only results are insufficient for the final watch synchronization check.

## 15. Acceptance criteria

1. The `app` target builds a product displayed as `Lumi` for iPhone, iPad, and Mac, and the project builds a `LumiWatch` application for Apple Watch.
2. Native visionOS is removed from the Milestone 0 application target's supported platforms.
3. The starter `Item` type and timestamp list behavior are no longer included in the application schema or root interface.
4. A clean installation creates exactly one visible canonical pet with level 1 and experience 0.
5. The generated pet configuration passes all declared range and compatibility rules.
6. The same seed and generator version produce an identical encoded configuration on every supported platform.
7. Relaunching the application does not change the pet ID or configuration.
8. After managed CloudKit synchronization, a second device renders the canonical pet's same ID and configuration.
9. The application remains usable when iCloud is unavailable and presents no Sign in with Apple interface.
10. The Lumi rig appears centered on every required device size and remains centered through rotation or window resizing.
11. Every generated pet in the 24-seed reference matrix satisfies the visual-style checklist: plush fur silhouette, rounded chibi proportions, oversized glossy layered eyes, tiny facial features, pastel tonal separation, soft cinematic lighting, and no hard outline or flat vector appearance.
12. Release rendering uses modular `SKSpriteNode` textures for all visible required pet parts; `SKShapeNode` is not used as the final visible character artwork.
13. Resting breathing completes within 2.4–4.0 seconds per cycle and follows the specified inhale, pause, exhale, and rest proportions.
14. Breathing originates in abdomen and chest nodes, keeps paws planted, moves the head only by translation, never uniformly scales `pet.root`, and restores exact base transforms after every cycle.
15. Blinking, gaze, ear twitch, tail motion, body-weight shifts, and breathing operate independently without cumulative transform drift.
16. Reduce Motion preserves breathing at 40% amplitude and blinking while suppressing the defined larger motions and effects.
17. Rendering pauses when the application scene becomes inactive.
18. No production recovery path calls `fatalError`.
19. All Swift Testing, render-snapshot, XCUIAutomation, and manual checks defined for this milestone pass.
20. No excluded product feature is introduced as part of Milestone 0.

## 16. Implementation sequence

```text
1. Shared package and target foundation
      ↓
2. Versioned PetConfiguration, generator, and validator
      ↓
3. SwiftData record, repository, and local persistence
      ↓
4. Reference-style texture atlases, layered SpriteKit rig, anatomical breathing, and ambient animation controller
      ↓
5. iPhone, iPad, and Mac centered presentation
      ↓
6. watchOS application and constrained renderer policy
      ↓
7. CloudKit capabilities, schema, and cross-device verification
      ↓
8. Full automated and manual acceptance pass
```

Sequencing rationale:

- The generator is implemented before persistence so its deterministic contract can be locked by tests.
- Persistence precedes UI so the app never displays an unsaved random pet.
- The shared textured renderer and anatomical breathing contract precede platform shells so every shell exercises the same approved art and motion system.
- Local behavior is verified before CloudKit is enabled, keeping persistence failures separate from synchronization failures.
- CloudKit is configured only after the schema is stable because production CloudKit schemas are additive.

## 17. Starter-file migration

| Current file | Milestone disposition |
|---|---|
| `app/app/appApp.swift` | Replace with the Lumi composition root and nonfatal container bootstrap |
| `app/app/ContentView.swift` | Replace timestamp navigation with the adaptive centered pet host |
| `app/app/Item.swift` | Remove after `PetRecord` is registered and tested |
| `app/app/Assets.xcassets` | Keep for app identity and background assets; compile `LumiPet.atlas` into the main app and `LumiPetWatch.atlas` into the watch app, then inject the selected atlas into `LumiRendering` |
| `app/app/app.entitlements` | Attach to target and configure the private CloudKit container using Xcode capability tooling |
| `app/app/Info.plist` | Keep remote notification background mode required for managed sync |
| `app/appTests/appTests.swift` | Replace placeholder with app-level integration coverage |
| `app/appUITests/appUITests.swift` | Replace placeholder journey with centered-pet launch assertions |

## 18. Growth path after Milestone 0

The next product modules can be added in this order without changing Milestone 0 boundaries:

1. Care simulation and mood projection in `LumiCore`.
2. Level progression and deterministic visual evolution overlays.
3. Native quick interactions and WatchConnectivity fast-path updates.
4. WidgetKit status widgets, watch complications, and App Intents.
5. Memories, games, collection UI, and multiple active Lumis.
6. StoreKit entitlements for recoverable non-consumable slots or subscriptions.
7. Optional Foundation Models dialogue behind an injected capability interface.

StoreKit remains independent from Sign in with Apple. Future purchases are recovered from App Store transaction entitlements, while pet data remains associated with the user's private iCloud database.

## 19. Definition of done

Milestone 0 is complete only when a developer can install Lumi on each required Apple platform, observe a centered random pet in the supplied soft plush cinematic chibi style, see it breathe with plausible animal anatomy and timing, relaunch without an appearance change, and verify that another device receives the same canonical pet through the configured private CloudKit database. The result must satisfy every acceptance criterion and contain none of the excluded product features.