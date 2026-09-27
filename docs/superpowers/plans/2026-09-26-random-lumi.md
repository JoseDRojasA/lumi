# Random Lumi Milestone 0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one persistent, synchronized, randomly configured Lumi that renders in the center of iPhone, iPad, Mac, and Apple Watch with the approved textured chibi style and anatomically believable breathing.

**Architecture:** Keep the existing multiplatform application as a thin iOS/iPadOS/macOS shell and add a watchOS companion app. Put deterministic domain logic, SwiftData persistence, and SpriteKit rendering in three local `LumiKit` package products with one-way dependencies into `LumiCore`. Save a generated configuration before rendering, synchronize its `PetRecord` through a private CloudKit database, and inject immutable `PetPresentation` values into SpriteKit.

**Tech Stack:** Swift 6 language mode compatible with the project toolchain, SwiftUI, SwiftData, CloudKit managed sync, SpriteKit, `SKTextureAtlas`, Swift Testing, XCUIAutomation, watchOS, Xcode capability tooling.

**Source specification:** `app/docs/superpowers/specs/2026-09-26-lumi-product-definition.md`

---

## Execution constraints

- Create an isolated worktree with `superpowers:using-git-worktrees` before implementation.
- Do not change the CloudKit production schema until all `PetRecord` fields and package tests are locked.
- Entitlements must be changed with Xcode capability tools, never by editing `.entitlements` directly.
- Info.plist keys must be changed with `AddInfoPlist`, never by editing the plist directly.
- Build settings must be changed with `GetTargetBuildSettings` and `UpdateTargetBuildSetting`, never by reading or editing `project.pbxproj`.
- Production visual acceptance requires modular painted texture assets. The repository currently contains no pet-part atlas, so Task 7 is a real art-input gate rather than a code-generated substitute.
- Commit steps require the user's authorization at execution start. If authorization is not provided, stop at each checkpoint with a clean verified diff instead of creating the commit.

### Path convention

File tables and Xcode tool calls use the workspace-relative navigator paths supplied by Xcode, which begin with the project group `app/`. Bash, SwiftPM, and git commands run from `/Users/joserojas/Documents/projects/lumi/app/app`; those commands omit the navigator-only leading `app/`. For example, Xcode path `app/app/ContentView.swift` is filesystem path `app/ContentView.swift`, and Xcode path `app/Packages/LumiKit` is filesystem path `Packages/LumiKit`.

## Locked target map

| Name | Kind | Platforms | Dependencies |
|---|---|---|---|
| `app` (display name `Lumi`) | Existing multiplatform app | iOS, iPadOS, macOS | `LumiCore`, `LumiPersistence`, `LumiRendering` |
| `LumiWatch` | New watch app | watchOS | `LumiCore`, `LumiPersistence`, `LumiRendering` |
| `LumiCore` | Local Swift package library | iOS, macOS, watchOS | Foundation |
| `LumiPersistence` | Local Swift package library | iOS, macOS, watchOS | `LumiCore`, SwiftData |
| `LumiRendering` | Local Swift package library | iOS, macOS, watchOS | `LumiCore`, SpriteKit |
| Existing app tests | Swift Testing and XCUIAutomation | iOS, iPadOS, macOS | `Lumi` |
| Watch tests generated with app template | Swift Testing | watchOS | `LumiWatch` |

Use watch template `com.apple.dt.unit.application.watchOS` with `languageChoice=Swift`, `appLifecycle=SwiftUI`, and `testingSystem=Swift Testing`, embedded in the existing `app` target.

## Locked file map

### Existing files

| File | Action |
|---|---|
| `app/app/appApp.swift` | Replace with application composition root |
| `app/app/ContentView.swift` | Replace timestamp list with load/error/pet presentation |
| `app/app/Item.swift` | Delete after `PetRecord` integration passes |
| `app/app/Assets.xcassets` | Retain for app identity and background assets |
| `app/app/app.entitlements` | Configure through capability tooling |
| `app/app/Info.plist` | Retain remote-notification mode |
| `app/appTests/appTests.swift` | Replace template test with app integration tests |
| `app/appUITests/appUITests.swift` | Replace template journey with centered-pet checks |

### Package files

```text
app/Packages/LumiKit/
├── Package.swift
├── Sources/
│   ├── LumiCore/
│   │   ├── RGBAColor.swift
│   │   ├── PetTraits.swift
│   │   ├── PetConfiguration.swift
│   │   ├── PetConfigurationCodec.swift
│   │   ├── SplitMix64.swift
│   │   ├── PetConfigurationValidator.swift
│   │   ├── PetGenerator.swift
│   │   ├── Pet.swift
│   │   └── PetRepository.swift
│   ├── LumiPersistence/
│   │   ├── PetRecord.swift
│   │   ├── LumiModelContainerFactory.swift
│   │   └── SwiftDataPetRepository.swift
│   └── LumiRendering/
│       ├── PetPresentation.swift
│       ├── PetTextureCatalog.swift
│       ├── PetRig.swift
│       ├── PetNodeFactory.swift
│       ├── BreathingProfile.swift
│       ├── BreathingController.swift
│       ├── SecondaryMotionController.swift
│       └── PetScene.swift
└── Tests/
    ├── LumiCoreTests/
    │   ├── TestPetConfiguration.swift
    │   ├── PetConfigurationCodecTests.swift
    │   ├── PetGeneratorTests.swift
    │   ├── PetConfigurationValidatorTests.swift
    │   └── PetDefaultsTests.swift
    ├── LumiPersistenceTests/
    │   └── SwiftDataPetRepositoryTests.swift
    └── LumiRenderingTests/
        ├── TestRenderingFixtures.swift
        ├── PetNodeFactoryTests.swift
        ├── BreathingControllerTests.swift
        └── PetSceneTests.swift
```

### App shell files

```text
app/app/
├── AppDependencies.swift
├── LumiViewModel.swift
├── PreviewPet.swift
└── PetSceneHost.swift

app/appTests/
└── PetTextureAtlasIntegrationTests.swift

app/LumiWatch/
├── LumiWatchApp.swift
├── WatchLumiViewModel.swift
├── WatchRootView.swift
└── WatchPetSceneHost.swift

app/LumiWatchTests/
└── WatchLumiViewModelTests.swift
```

### Required art resources

```text
app/app/LumiPet.atlas/
app/LumiWatch/LumiPetWatch.atlas/
app/app/RigAnchors.json
app/LumiWatch/RigAnchors.json
```

---

### Task 1: Establish targets and the local LumiKit package

**Files:**
- Create: `app/Packages/LumiKit/Package.swift`
- Create: `app/Packages/LumiKit/Sources/LumiCore/LumiCore.swift`
- Create: `app/Packages/LumiKit/Sources/LumiPersistence/LumiPersistence.swift`
- Create: `app/Packages/LumiKit/Sources/LumiRendering/LumiRendering.swift`
- Modify: application display-name metadata
- Modify: application target build settings
- Create target: `LumiWatch`

- [ ] **Step 1: Set the user-visible application name**

Keep target and scheme identifiers as `app`. Use `AddInfoPlist` for target `app` to set `CFBundleDisplayName` to the string `Lumi`. Confirm `GetTargetBuildSettings(targetName: "app")` still reports bundle identifier `heylumipet.app`; no module or test import is renamed.

- [ ] **Step 2: Remove unsupported visionOS destinations**

Use `GetTargetBuildSettings(targetName: "app")`, then set:

```text
SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx
TARGETED_DEVICE_FAMILY = 1,2
```

Use `UpdateTargetBuildSetting` for both settings. Re-list run destinations and confirm iPhone, iPad, and Mac remain eligible and visionOS no longer appears as eligible.

- [ ] **Step 3: Create the package manifest and marker sources**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11)
    ],
    products: [
        .library(name: "LumiCore", targets: ["LumiCore"]),
        .library(name: "LumiPersistence", targets: ["LumiPersistence"]),
        .library(name: "LumiRendering", targets: ["LumiRendering"])
    ],
    targets: [
        .target(name: "LumiCore"),
        .target(name: "LumiPersistence", dependencies: ["LumiCore"]),
        .target(name: "LumiRendering", dependencies: ["LumiCore"]),
        .testTarget(name: "LumiCoreTests", dependencies: ["LumiCore"]),
        .testTarget(name: "LumiPersistenceTests", dependencies: ["LumiPersistence", "LumiCore"]),
        .testTarget(name: "LumiRenderingTests", dependencies: ["LumiRendering", "LumiCore"])
    ]
)
```

Each marker source contains one declaration so SwiftPM accepts the target:

```swift
public enum LumiCoreModule {}
```

Use corresponding names `LumiPersistenceModule` and `LumiRenderingModule` in the other targets.

- [ ] **Step 4: Verify package compilation**

Run:

```bash
swift test --package-path Packages/LumiKit
```

Expected: exit status 0 and three package targets compile.

- [ ] **Step 5: Add the local package to the Xcode project**

In Xcode choose **File → Add Package Dependencies → Add Local**, select `app/Packages/LumiKit`, then link `LumiCore`, `LumiPersistence`, and `LumiRendering` to target `app`. Do not add remote dependencies.

- [ ] **Step 6: Create the watchOS application target**

Use `XcodeNewTarget` with:

```json
{
  "templateIdentifier": "com.apple.dt.unit.application.watchOS",
  "productName": "LumiWatch",
  "organizationIdentifier": "heylumipet",
  "embedInAppNamed": "app",
  "options": {
    "languageChoice": "Swift",
    "appLifecycle": "SwiftUI",
    "testingSystem": "Swift Testing"
  }
}
```

Link the three local package products to `LumiWatch`. The watch bundle identifier must be prefixed by `heylumipet.app` and the generated watch target must be embedded in `Lumi`.

- [ ] **Step 7: Build both application schemes**

Switch to scheme `app`, run `BuildProject`, then switch to the generated `LumiWatch` scheme and run `BuildProject` again.

Expected: both builds succeed before domain code is introduced.

- [ ] **Step 8: Commit the foundation checkpoint**

```bash
git add Packages/LumiKit app.xcodeproj
git commit -m "build: add Lumi shared modules and watch target"
```

---

### Task 2: Define the versioned pet configuration

**Files:**
- Create: `app/Packages/LumiKit/Sources/LumiCore/RGBAColor.swift`
- Create: `app/Packages/LumiKit/Sources/LumiCore/PetTraits.swift`
- Create: `app/Packages/LumiKit/Sources/LumiCore/PetConfiguration.swift`
- Create: `app/Packages/LumiKit/Sources/LumiCore/PetConfigurationCodec.swift`
- Test: `app/Packages/LumiKit/Tests/LumiCoreTests/PetConfigurationCodecTests.swift`
- Delete: package marker `LumiCore.swift`

- [ ] **Step 1: Write the failing canonical-codec tests**

```swift
import Foundation
import Testing
@testable import LumiCore

struct PetConfigurationCodecTests {
    @Test func roundTripPreservesEveryTrait() throws {
        let configuration = PetConfiguration.fixture(seed: 42)
        let data = try PetConfigurationCodec.encode(configuration)
        let decoded = try PetConfigurationCodec.decode(data)
        #expect(decoded == configuration)
    }

    @Test func encodingIsCanonical() throws {
        let configuration = PetConfiguration.fixture(seed: 42)
        #expect(try PetConfigurationCodec.encode(configuration) == PetConfigurationCodec.encode(configuration))
    }
}
```

Create `TestPetConfiguration.swift` with this test-only fixture:

```swift
@testable import LumiCore

extension PetConfiguration {
    static func fixture(seed: UInt64) -> PetConfiguration {
        PetConfiguration(
            formatVersion: 1,
            generatorVersion: 1,
            seed: seed,
            body: BodyTraits(bodyShape: .round, bodyScale: 1, headScale: 1.05, furStyle: .fluffy, patternStyle: .spots, patternDensity: 0.4, patternScale: 1),
            palette: Palette(
                baseColor: RGBAColor(red: 0.72, green: 0.62, blue: 0.92),
                secondaryColor: RGBAColor(red: 0.95, green: 0.90, blue: 0.98),
                accentColor: RGBAColor(red: 0.46, green: 0.72, blue: 0.94)
            ),
            face: FaceTraits(
                eyeShape: .round,
                eyeScale: 1.08,
                irisColor: RGBAColor(red: 0.28, green: 0.16, blue: 0.12),
                pupilStyle: .round,
                muzzleStyle: .small,
                noseStyle: .heart,
                noseColor: RGBAColor(red: 0.74, green: 0.36, blue: 0.48),
                cheekStyle: .blush,
                cheekColor: RGBAColor(red: 0.94, green: 0.62, blue: 0.72)
            ),
            ears: EarTraits(earStyle: .pointed, earScale: 1, earAngle: 0.5),
            tail: TailTraits(tailStyle: .plume, tailLength: 1, tailThickness: 1),
            details: DetailTraits(
                headTuftStyle: .windswept,
                chestTuftStyle: .cloud,
                magicalFeature: .sparkles,
                magicalColor: RGBAColor(red: 0.82, green: 0.72, blue: 1),
                magicalIntensity: 0.5
            ),
            motionPersonality: .curious
        )
    }
}
```

- [ ] **Step 2: Run the focused tests and verify red**

```bash
swift test --package-path Packages/LumiKit --filter PetConfigurationCodecTests
```

Expected: compilation fails because `PetConfiguration`, trait types, and `PetConfigurationCodec` do not exist.

- [ ] **Step 3: Implement `RGBAColor`**

```swift
import Foundation

public struct RGBAColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public func clamped() -> RGBAColor {
        RGBAColor(
            red: red.clamped(to: 0...1),
            green: green.clamped(to: 0...1),
            blue: blue.clamped(to: 0...1),
            alpha: alpha.clamped(to: 0...1)
        )
    }

    public func distance(to other: RGBAColor) -> Double {
        let dr = red - other.red
        let dg = green - other.green
        let db = blue - other.blue
        return (dr * dr + dg * dg + db * db).squareRoot()
    }
}

extension Comparable {
    fileprivate func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
```

- [ ] **Step 4: Implement all trait enums and groups**

`PetTraits.swift` defines these `String`, `CaseIterable`, `Codable`, `Sendable` enums exactly:

```swift
public enum BodyShape: String, CaseIterable, Codable, Sendable { case round, compact, pear }
public enum FurStyle: String, CaseIterable, Codable, Sendable { case smooth, fluffy, spiky }
public enum PatternStyle: String, CaseIterable, Codable, Sendable { case none, spots, stripes, mask, socks, gradient }
public enum EyeShape: String, CaseIterable, Codable, Sendable { case round, almond, sleepy }
public enum PupilStyle: String, CaseIterable, Codable, Sendable { case round, vertical, star }
public enum EarStyle: String, CaseIterable, Codable, Sendable { case pointed, rounded, long, floppy }
public enum TailStyle: String, CaseIterable, Codable, Sendable { case short, long, curled, plume }
public enum HeadTuftStyle: String, CaseIterable, Codable, Sendable { case none, curl, split, windswept }
public enum ChestTuftStyle: String, CaseIterable, Codable, Sendable { case none, small, layered, cloud }
public enum MuzzleStyle: String, CaseIterable, Codable, Sendable { case small, round, pronounced }
public enum NoseStyle: String, CaseIterable, Codable, Sendable { case dot, triangle, heart }
public enum CheekStyle: String, CaseIterable, Codable, Sendable { case none, blush, freckles, glow }
public enum MagicalFeature: String, CaseIterable, Codable, Sendable { case none, glow, sparkles, orbitingLight }
public enum MotionPersonality: String, CaseIterable, Codable, Sendable { case calm, curious, playful, lively, sleepy }
```

Define the nested trait groups exactly as follows:

```swift
public struct BodyTraits: Codable, Equatable, Sendable {
    public var bodyShape: BodyShape
    public var bodyScale: Double
    public var headScale: Double
    public var furStyle: FurStyle
    public var patternStyle: PatternStyle
    public var patternDensity: Double
    public var patternScale: Double

    public init(bodyShape: BodyShape, bodyScale: Double, headScale: Double, furStyle: FurStyle, patternStyle: PatternStyle, patternDensity: Double, patternScale: Double) {
        self.bodyShape = bodyShape
        self.bodyScale = bodyScale
        self.headScale = headScale
        self.furStyle = furStyle
        self.patternStyle = patternStyle
        self.patternDensity = patternDensity
        self.patternScale = patternScale
    }
}

public struct Palette: Codable, Equatable, Sendable {
    public var baseColor: RGBAColor
    public var secondaryColor: RGBAColor
    public var accentColor: RGBAColor

    public init(baseColor: RGBAColor, secondaryColor: RGBAColor, accentColor: RGBAColor) {
        self.baseColor = baseColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
    }
}

public struct FaceTraits: Codable, Equatable, Sendable {
    public var eyeShape: EyeShape
    public var eyeScale: Double
    public var irisColor: RGBAColor
    public var pupilStyle: PupilStyle
    public var muzzleStyle: MuzzleStyle
    public var noseStyle: NoseStyle
    public var noseColor: RGBAColor
    public var cheekStyle: CheekStyle
    public var cheekColor: RGBAColor

    public init(eyeShape: EyeShape, eyeScale: Double, irisColor: RGBAColor, pupilStyle: PupilStyle, muzzleStyle: MuzzleStyle, noseStyle: NoseStyle, noseColor: RGBAColor, cheekStyle: CheekStyle, cheekColor: RGBAColor) {
        self.eyeShape = eyeShape
        self.eyeScale = eyeScale
        self.irisColor = irisColor
        self.pupilStyle = pupilStyle
        self.muzzleStyle = muzzleStyle
        self.noseStyle = noseStyle
        self.noseColor = noseColor
        self.cheekStyle = cheekStyle
        self.cheekColor = cheekColor
    }
}

public struct EarTraits: Codable, Equatable, Sendable {
    public var earStyle: EarStyle
    public var earScale: Double
    public var earAngle: Double

    public init(earStyle: EarStyle, earScale: Double, earAngle: Double) {
        self.earStyle = earStyle
        self.earScale = earScale
        self.earAngle = earAngle
    }
}

public struct TailTraits: Codable, Equatable, Sendable {
    public var tailStyle: TailStyle
    public var tailLength: Double
    public var tailThickness: Double

    public init(tailStyle: TailStyle, tailLength: Double, tailThickness: Double) {
        self.tailStyle = tailStyle
        self.tailLength = tailLength
        self.tailThickness = tailThickness
    }
}

public struct DetailTraits: Codable, Equatable, Sendable {
    public var headTuftStyle: HeadTuftStyle
    public var chestTuftStyle: ChestTuftStyle
    public var magicalFeature: MagicalFeature
    public var magicalColor: RGBAColor
    public var magicalIntensity: Double

    public init(headTuftStyle: HeadTuftStyle, chestTuftStyle: ChestTuftStyle, magicalFeature: MagicalFeature, magicalColor: RGBAColor, magicalIntensity: Double) {
        self.headTuftStyle = headTuftStyle
        self.chestTuftStyle = chestTuftStyle
        self.magicalFeature = magicalFeature
        self.magicalColor = magicalColor
        self.magicalIntensity = magicalIntensity
    }
}
```

- [ ] **Step 5: Implement `PetConfiguration`**

```swift
public struct PetConfiguration: Codable, Equatable, Sendable {
    public var formatVersion: Int
    public var generatorVersion: Int
    public var seed: UInt64
    public var body: BodyTraits
    public var palette: Palette
    public var face: FaceTraits
    public var ears: EarTraits
    public var tail: TailTraits
    public var details: DetailTraits
    public var motionPersonality: MotionPersonality

    public init(
        formatVersion: Int,
        generatorVersion: Int,
        seed: UInt64,
        body: BodyTraits,
        palette: Palette,
        face: FaceTraits,
        ears: EarTraits,
        tail: TailTraits,
        details: DetailTraits,
        motionPersonality: MotionPersonality
    ) {
        self.formatVersion = formatVersion
        self.generatorVersion = generatorVersion
        self.seed = seed
        self.body = body
        self.palette = palette
        self.face = face
        self.ears = ears
        self.tail = tail
        self.details = details
        self.motionPersonality = motionPersonality
    }
}
```

- [ ] **Step 6: Implement canonical JSON encoding**

```swift
import Foundation

public enum PetConfigurationCodec {
    public static func encode(_ configuration: PetConfiguration) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(configuration)
    }

    public static func decode(_ data: Data) throws -> PetConfiguration {
        try JSONDecoder().decode(PetConfiguration.self, from: data)
    }
}
```

- [ ] **Step 7: Run codec tests and the package suite**

```bash
swift test --package-path Packages/LumiKit --filter PetConfigurationCodecTests
swift test --package-path Packages/LumiKit
```

Expected: both codec tests pass; package exits 0.

- [ ] **Step 8: Commit the configuration checkpoint**

```bash
git add Packages/LumiKit
git commit -m "feat: define versioned Lumi configuration"
```

---

### Task 3: Implement stable seeded random generation

**Files:**
- Create: `app/Packages/LumiKit/Sources/LumiCore/SplitMix64.swift`
- Create: `app/Packages/LumiKit/Sources/LumiCore/PetGenerator.swift`
- Test: `app/Packages/LumiKit/Tests/LumiCoreTests/PetGeneratorTests.swift`

- [ ] **Step 1: Write failing generator tests**

```swift
import Testing
@testable import LumiCore

struct PetGeneratorTests {
    @Test func sameSeedProducesSameCanonicalBytes() throws {
        let first = try PetGenerator.generate(seed: 9_001, version: 1)
        let second = try PetGenerator.generate(seed: 9_001, version: 1)
        #expect(try PetConfigurationCodec.encode(first) == PetConfigurationCodec.encode(second))
    }

    @Test func differentSeedsProduceVariation() throws {
        let first = try PetGenerator.generate(seed: 1, version: 1)
        let second = try PetGenerator.generate(seed: 2, version: 1)
        #expect(first != second)
    }

    @Test func unsupportedGeneratorVersionThrows() {
        #expect(throws: PetGeneratorError.unsupportedVersion(2)) {
            try PetGenerator.generate(seed: 1, version: 2)
        }
    }
}
```

- [ ] **Step 2: Run generator tests and verify red**

```bash
swift test --package-path Packages/LumiKit --filter PetGeneratorTests
```

Expected: compilation fails because `PetGenerator` and `PetGeneratorError` are undefined.

- [ ] **Step 3: Implement `SplitMix64`**

```swift
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func unitDouble() -> Double {
        Double(next() >> 11) / 9_007_199_254_740_992
    }

    mutating func value(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + unitDouble() * (range.upperBound - range.lowerBound)
    }

    mutating func element<T>(from values: [T]) -> T {
        values[Int(next() % UInt64(values.count))]
    }
}
```

- [ ] **Step 4: Implement generator version 1**

Define `PetGeneratorError: Error, Equatable` with `unsupportedVersion(Int)`. `PetGenerator.generate` creates one `SplitMix64`, consumes values in a fixed documented order, and fills every trait group. Use `Array(EnumType.allCases)` for categorical traits and exact closed ranges from product-definition section 7.3.

Generate colors with this concrete helper:

```swift
private static func color(using random: inout SplitMix64) -> RGBAColor {
    let hue = random.unitDouble()
    let saturation = random.value(in: 0.22...0.52)
    let brightness = random.value(in: 0.72...0.96)
    return RGBAColor.hsb(hue: hue, saturation: saturation, brightness: brightness)
}
```

Add a deterministic `RGBAColor.hsb(hue:saturation:brightness:)` conversion in `RGBAColor.swift`. Return the raw generated configuration; Task 4 adds validation.

- [ ] **Step 5: Run generator tests twice**

```bash
swift test --package-path Packages/LumiKit --filter PetGeneratorTests
swift test --package-path Packages/LumiKit --filter PetGeneratorTests
```

Expected: both runs pass with identical results.

- [ ] **Step 6: Commit the generator checkpoint**

```bash
git add Packages/LumiKit
git commit -m "feat: generate deterministic random Lumis"
```

---

### Task 4: Validate and repair generated configurations

**Files:**
- Create: `app/Packages/LumiKit/Sources/LumiCore/PetConfigurationValidator.swift`
- Modify: `app/Packages/LumiKit/Sources/LumiCore/PetGenerator.swift`
- Test: `app/Packages/LumiKit/Tests/LumiCoreTests/PetConfigurationValidatorTests.swift`
- Modify test: `app/Packages/LumiKit/Tests/LumiCoreTests/PetGeneratorTests.swift`

- [ ] **Step 1: Write failing validator tests**

```swift
import Testing
@testable import LumiCore

struct PetConfigurationValidatorTests {
    @Test func clampsAllNumericTraits() throws {
        var input = PetConfiguration.fixture(seed: 7)
        input.body.bodyScale = 4
        input.ears.earAngle = -3
        input.details.magicalIntensity = 9

        let output = try PetConfigurationValidator.validate(input)

        #expect(output.body.bodyScale == 1.10)
        #expect(output.ears.earAngle == 0)
        #expect(output.details.magicalIntensity == 1)
    }

    @Test func repairsLowContrastColorsDeterministically() throws {
        var input = PetConfiguration.fixture(seed: 8)
        input.palette.secondaryColor = input.palette.baseColor
        let first = try PetConfigurationValidator.validate(input)
        let second = try PetConfigurationValidator.validate(input)
        #expect(first == second)
        #expect(first.palette.secondaryColor.distance(to: first.palette.baseColor) >= 0.28)
    }

    @Test func rejectsUnsupportedFormat() {
        var input = PetConfiguration.fixture(seed: 9)
        input.formatVersion = 2
        #expect(throws: PetValidationError.unsupportedFormat(2)) {
            try PetConfigurationValidator.validate(input)
        }
    }
}
```

- [ ] **Step 2: Run validator tests and verify red**

```bash
swift test --package-path Packages/LumiKit --filter PetConfigurationValidatorTests
```

Expected: compilation fails because validator types do not exist.

- [ ] **Step 3: Implement deterministic validation**

```swift
public enum PetValidationError: Error, Equatable {
    case unsupportedFormat(Int)
}

public enum PetConfigurationValidator {
    public static func validate(_ input: PetConfiguration) throws -> PetConfiguration {
        guard input.formatVersion == 1 else {
            throw PetValidationError.unsupportedFormat(input.formatVersion)
        }

        var output = input
        output.body.bodyScale = output.body.bodyScale.clamped(to: 0.90...1.10)
        output.body.headScale = output.body.headScale.clamped(to: 0.90...1.15)
        output.body.patternDensity = output.body.patternDensity.clamped(to: 0...1)
        output.body.patternScale = output.body.patternScale.clamped(to: 0.75...1.25)
        output.face.eyeScale = output.face.eyeScale.clamped(to: 0.85...1.15)
        output.ears.earScale = output.ears.earScale.clamped(to: 0.80...1.20)
        output.ears.earAngle = output.ears.earAngle.clamped(to: 0...1)
        output.tail.tailLength = output.tail.tailLength.clamped(to: 0.80...1.20)
        output.tail.tailThickness = output.tail.tailThickness.clamped(to: 0.80...1.20)
        output.details.magicalIntensity = output.details.magicalIntensity.clamped(to: 0...1)
        output.palette.baseColor = output.palette.baseColor.clamped()
        output.palette.secondaryColor = output.palette.secondaryColor.clamped().ensuringDistance(0.28, from: output.palette.baseColor)
        output.palette.accentColor = output.palette.accentColor.clamped().ensuringDistance(0.28, from: output.palette.baseColor)
        output.face.irisColor = output.face.irisColor.clamped().ensuringDistance(0.34, from: output.palette.baseColor)
        output.face.noseColor = output.face.noseColor.clamped().ensuringDistance(0.28, from: output.palette.secondaryColor)
        output.face.cheekColor = output.face.cheekColor.clamped()
        output.details.magicalColor = output.details.magicalColor.clamped()
        return output
    }
}
```

Change the `Double.clamped` helper from `fileprivate` to internal module scope, then add this guaranteed color repair:

```swift
public func ensuringDistance(_ minimum: Double, from reference: RGBAColor) -> RGBAColor {
    let current = clamped()
    let reference = reference.clamped()
    guard current.distance(to: reference) < minimum else { return current }

    let pastelLight = RGBAColor(red: 0.96, green: 0.94, blue: 0.99, alpha: current.alpha)
    let pastelDark = RGBAColor(red: 0.20, green: 0.16, blue: 0.28, alpha: current.alpha)
    let pastelCandidate = pastelLight.distance(to: reference) >= pastelDark.distance(to: reference) ? pastelLight : pastelDark
    if pastelCandidate.distance(to: reference) >= minimum {
        return pastelCandidate
    }

    let black = RGBAColor(red: 0, green: 0, blue: 0, alpha: current.alpha)
    let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: current.alpha)
    return black.distance(to: reference) >= white.distance(to: reference) ? black : white
}
```

One of black or white is always at least `sqrt(0.75)` from any RGB point, so the final branch guarantees every milestone threshold up to `0.34`.

- [ ] **Step 4: Make generation always return validated output**

At the end of `PetGenerator.generate`, call:

```swift
return try PetConfigurationValidator.validate(configuration)
```

- [ ] **Step 5: Add the 1,000-seed property test**

```swift
@Test func oneThousandSeedsProduceValidConfigurations() throws {
    for seed in UInt64(0)..<1_000 {
        let configuration = try PetGenerator.generate(seed: seed, version: 1)
        #expect(configuration.body.bodyScale >= 0.90)
        #expect(configuration.body.bodyScale <= 1.10)
        #expect(configuration.palette.secondaryColor.distance(to: configuration.palette.baseColor) >= 0.28)
        #expect(configuration.palette.accentColor.distance(to: configuration.palette.baseColor) >= 0.28)
        #expect(configuration.face.irisColor.distance(to: configuration.palette.baseColor) >= 0.34)
    }
}
```

- [ ] **Step 6: Run all core tests**

```bash
swift test --package-path Packages/LumiKit --filter LumiCoreTests
```

Expected: all core tests pass, including 1,000 seeds.

- [ ] **Step 7: Commit the validation checkpoint**

```bash
git add Packages/LumiKit
git commit -m "feat: validate generated Lumi traits"
```

---

### Task 5: Define the persistent pet domain boundary

**Files:**
- Create: `app/Packages/LumiKit/Sources/LumiCore/Pet.swift`
- Create: `app/Packages/LumiKit/Sources/LumiCore/PetRepository.swift`
- Test: `app/Packages/LumiKit/Tests/LumiCoreTests/PetDefaultsTests.swift`

- [ ] **Step 1: Write the failing pet-default test**

```swift
import Foundation
import Testing
@testable import LumiCore

struct PetDefaultsTests {
    @Test func newPetStartsAtLevelOne() throws {
        let configuration = try PetGenerator.generate(seed: 88, version: 1)
        let pet = Pet.new(id: UUID(), configuration: configuration, now: .distantPast)
        #expect(pet.name == "Lumi")
        #expect(pet.level == 1)
        #expect(pet.experience == 0)
        #expect(pet.isActive)
    }
}
```

- [ ] **Step 2: Run and verify red**

```bash
swift test --package-path Packages/LumiKit --filter PetDefaultsTests
```

Expected: compilation fails because `Pet` does not exist.

- [ ] **Step 3: Implement `Pet` and `PetRepository`**

```swift
import Foundation

public struct Pet: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let configuration: PetConfiguration
    public let name: String
    public let createdAt: Date
    public let updatedAt: Date
    public let level: Int
    public let experience: Int
    public let isActive: Bool

    public init(id: UUID, configuration: PetConfiguration, name: String, createdAt: Date, updatedAt: Date, level: Int, experience: Int, isActive: Bool) {
        self.id = id
        self.configuration = configuration
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.level = level
        self.experience = experience
        self.isActive = isActive
    }

    public static func new(id: UUID, configuration: PetConfiguration, now: Date) -> Pet {
        Pet(
            id: id,
            configuration: configuration,
            name: "Lumi",
            createdAt: now,
            updatedAt: now,
            level: 1,
            experience: 0,
            isActive: true
        )
    }
}

public protocol PetRepository: Sendable {
    func activePet() async throws -> Pet?
    func createPetIfNeeded() async throws -> Pet
}
```

- [ ] **Step 4: Run core tests**

```bash
swift test --package-path Packages/LumiKit --filter LumiCoreTests
```

Expected: all core tests pass.

- [ ] **Step 5: Commit the domain checkpoint**

```bash
git add Packages/LumiKit
git commit -m "feat: add persistent pet domain boundary"
```

---

### Task 6: Implement local SwiftData persistence and convergence

**Files:**
- Create: `app/Packages/LumiKit/Sources/LumiPersistence/PetRecord.swift`
- Create: `app/Packages/LumiKit/Sources/LumiPersistence/LumiModelContainerFactory.swift`
- Create: `app/Packages/LumiKit/Sources/LumiPersistence/SwiftDataPetRepository.swift`
- Test: `app/Packages/LumiKit/Tests/LumiPersistenceTests/SwiftDataPetRepositoryTests.swift`
- Delete: package marker `LumiPersistence.swift`

- [ ] **Step 1: Write failing repository tests**

```swift
import Foundation
import SwiftData
import Testing
import LumiCore
@testable import LumiPersistence

struct SwiftDataPetRepositoryTests {
    @Test func firstRequestCreatesAndSecondRequestReusesPet() async throws {
        let container = try LumiModelContainerFactory.make(inMemory: true)
        let repository = SwiftDataPetRepository(container: container, seed: { 123 }, now: { .distantPast })
        let first = try await repository.createPetIfNeeded()
        let second = try await repository.createPetIfNeeded()
        #expect(first.id == second.id)
        #expect(first.configuration == second.configuration)
    }

    @Test func canonicalSelectionUsesDateThenID() async throws {
        let container = try LumiModelContainerFactory.make(inMemory: true)
        let earlierID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let laterID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        try insertRecord(id: laterID, createdAt: Date(timeIntervalSince1970: 2), seed: 2, into: container)
        try insertRecord(id: earlierID, createdAt: Date(timeIntervalSince1970: 1), seed: 1, into: container)
        let repository = SwiftDataPetRepository(container: container)
        #expect(try await repository.activePet()?.id == earlierID)
    }

    @Test func corruptPayloadRegeneratesFromStoredSeed() async throws {
        let container = try LumiModelContainerFactory.make(inMemory: true)
        try insertCorruptRecord(seed: 44, into: container)
        let repository = SwiftDataPetRepository(container: container)
        #expect(try await repository.activePet()?.configuration == PetGenerator.generate(seed: 44, version: 1))
    }
}
```

Implement test helpers in the test file with `ModelContext(container)`, explicit records, `context.insert`, and `try context.save()`.

- [ ] **Step 2: Run persistence tests and verify red**

```bash
swift test --package-path Packages/LumiKit --filter SwiftDataPetRepositoryTests
```

Expected: compilation fails because persistence types do not exist.

- [ ] **Step 3: Implement CloudKit-compatible `PetRecord`**

```swift
import Foundation
import SwiftData

@Model
public final class PetRecord {
    public var id: UUID = UUID()
    public var configurationData: Data = Data()
    public var configurationFormatVersion: Int = 1
    public var generatorVersion: Int = 1
    public var seed: String = "0"
    public var name: String = "Lumi"
    public var createdAt: Date = Date.distantPast
    public var updatedAt: Date = Date.distantPast
    public var level: Int = 1
    public var experience: Int = 0
    public var isActive: Bool = true

    public init(
        id: UUID,
        configurationData: Data,
        configurationFormatVersion: Int,
        generatorVersion: Int,
        seed: String,
        name: String,
        createdAt: Date,
        updatedAt: Date,
        level: Int,
        experience: Int,
        isActive: Bool
    ) {
        self.id = id
        self.configurationData = configurationData
        self.configurationFormatVersion = configurationFormatVersion
        self.generatorVersion = generatorVersion
        self.seed = seed
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.level = level
        self.experience = experience
        self.isActive = isActive
    }
}
```

Do not add a unique attribute or relationships.

- [ ] **Step 4: Implement the model-container factory**

```swift
import SwiftData

public enum LumiModelContainerFactory {
    public static let cloudContainerIdentifier = "iCloud.heylumipet.app"

    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([PetRecord.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory ? .none : .private(cloudContainerIdentifier)
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }
}
```

- [ ] **Step 5: Implement the repository actor**

`SwiftDataPetRepository` stores the `ModelContainer` and injected closures for seed, UUID, and date. Each public operation creates a `ModelContext` inside the actor. `activePet()` fetches all active records, sorts by `(createdAt, id.uuidString)`, marks noncanonical records inactive, saves once, and maps the canonical record to `Pet`. `createPetIfNeeded()` reuses `activePet()` or generates, validates, canonically encodes, inserts, saves, and only then returns the domain pet.

Use this exact decode fallback:

```swift
private func configuration(from record: PetRecord) throws -> PetConfiguration {
    if let decoded = try? PetConfigurationCodec.decode(record.configurationData) {
        return try PetConfigurationValidator.validate(decoded)
    }
    guard let seed = UInt64(record.seed) else {
        throw PetRepositoryError.invalidSeed(record.seed)
    }
    return try PetGenerator.generate(seed: seed, version: record.generatorVersion)
}
```

Define `PetRepositoryError.invalidSeed(String)` and `unsupportedGeneratorVersion(Int)`.

- [ ] **Step 6: Run persistence and package tests**

```bash
swift test --package-path Packages/LumiKit --filter LumiPersistenceTests
swift test --package-path Packages/LumiKit
```

Expected: creation is idempotent, canonical selection converges, corrupt data recovers, and all package tests pass.

- [ ] **Step 7: Commit the persistence checkpoint**

```bash
git add Packages/LumiKit
git commit -m "feat: persist canonical Lumi records"
```

---

### Task 7: Produce the approved modular texture atlases

**Files:**
- Create: `app/app/LumiPet.atlas/*.png`
- Create: `app/LumiWatch/LumiPetWatch.atlas/*.png`
- Create: `app/app/RigAnchors.json`
- Create: `app/LumiWatch/RigAnchors.json`

This task is an art-production gate. Do not substitute flat geometric shapes. Use the supplied reference image as art direction and export transparent, tint-friendly, soft-fur parts.

- [ ] **Step 1: Export required phone/Mac/iPad textures**

Export premultiplied-alpha PNGs at a common 1024 × 1024 rig canvas and consistent pivots. The atlas must contain exactly these semantic families:

```text
body_round, body_compact, body_pear
fur_smooth, fur_fluffy, fur_spiky
abdomen_soft
paws_round
head_base
pattern_spots, pattern_stripes, pattern_mask, pattern_socks, pattern_gradient
eye_round, eye_almond, eye_sleepy
iris_base
pupil_round, pupil_vertical, pupil_star
eye_catchlight, eyelid
ear_pointed, ear_rounded, ear_long, ear_floppy
tail_short, tail_long, tail_curled, tail_plume
headtuft_curl, headtuft_split, headtuft_windswept
chesttuft_small, chesttuft_layered, chesttuft_cloud
muzzle_small, muzzle_round, muzzle_pronounced
nose_dot, nose_triangle, nose_heart
cheek_blush, cheek_freckles, cheek_glow
magic_glow, magic_sparkles, magic_orbiting_light
shadow_diffuse
fallback_body, fallback_head, fallback_eye, fallback_ear, fallback_tail, fallback_paws
```

All visible textures must satisfy the style checklist in specification section 11.2.

- [ ] **Step 2: Export the watch atlas**

Export the same semantic names at 50% linear resolution. Preserve eye readability, face proportions, fur silhouette, and diffuse shading. Remove only interior micro-detail that is not visible at watch scale.

- [ ] **Step 3: Define exact rig anchors**

Both `RigAnchors.json` files use this schema and contain an entry for every named attachment:

```json
{
  "version": 1,
  "anchors": {
    "body": { "x": 0.5, "y": 0.34 },
    "abdomen": { "x": 0.5, "y": 0.32 },
    "chest": { "x": 0.5, "y": 0.48 },
    "paws": { "x": 0.5, "y": 0.14 },
    "head": { "x": 0.5, "y": 0.67 },
    "leftEar": { "x": 0.31, "y": 0.84 },
    "rightEar": { "x": 0.69, "y": 0.84 },
    "leftEye": { "x": 0.40, "y": 0.69 },
    "rightEye": { "x": 0.60, "y": 0.69 },
    "muzzle": { "x": 0.5, "y": 0.60 },
    "tail": { "x": 0.77, "y": 0.35 },
    "shadow": { "x": 0.5, "y": 0.10 }
  }
}
```

- [ ] **Step 4: Inspect atlas quality at native and watch sizes**

Check transparent edges against light and dark backgrounds. Reject halos, hard black outlines, inconsistent light direction, plastic highlights, or flat-fill body parts.

- [ ] **Step 5: Commit the art checkpoint**

```bash
git add app/LumiPet.atlas LumiWatch/LumiPetWatch.atlas app/RigAnchors.json LumiWatch/RigAnchors.json
git commit -m "art: add modular Lumi texture atlases"
```

---

### Task 8: Load textures and construct the semantic pet rig

**Files:**
- Create: `app/Packages/LumiKit/Sources/LumiRendering/PetPresentation.swift`
- Create: `app/Packages/LumiKit/Sources/LumiRendering/PetTextureCatalog.swift`
- Create: `app/Packages/LumiKit/Sources/LumiRendering/PetRig.swift`
- Create: `app/Packages/LumiKit/Sources/LumiRendering/PetNodeFactory.swift`
- Test: `app/appTests/PetTextureAtlasIntegrationTests.swift`
- Test support: `app/Packages/LumiKit/Tests/LumiRenderingTests/TestRenderingFixtures.swift`
- Test: `app/Packages/LumiKit/Tests/LumiRenderingTests/PetNodeFactoryTests.swift`
- Delete: package marker `LumiRendering.swift`

- [ ] **Step 1: Write the failing app-hosted texture-contract test**

Create `app/appTests/PetTextureAtlasIntegrationTests.swift`:

```swift
import SpriteKit
import Testing
import LumiRendering

struct PetTextureAtlasIntegrationTests {
    @Test func requiredSemanticTexturesArePresentInApplicationBundle() throws {
        let atlas = SKTextureAtlas(named: "LumiPet")
        let catalog = try PetTextureCatalog(atlas: atlas)
        for name in PetTextureCatalog.requiredTextureNames {
            #expect(catalog.contains(name))
        }
    }
}
```

This test remains in the app-hosted test target because `SKTextureAtlas(named:)` searches the compiled application bundle containing `LumiPet.atlas`.

- [ ] **Step 2: Write failing rig tests**

```swift
struct PetNodeFactoryTests {
    @Test func everyRepresentativeSeedBuildsUniqueRequiredNodes() throws {
        for seed in PetReferenceSeeds.all {
            let configuration = try PetGenerator.generate(seed: seed, version: 1)
            let rig = try PetNodeFactory(catalog: PetTextureCatalog.testCatalog()).makeRig(
                presentation: PetPresentation(configuration: configuration)
            )
            #expect(Set(rig.requiredNodes.map(\.name)).count == rig.requiredNodes.count)
            #expect(rig.abdomen.name == "pet.abdomen")
            #expect(rig.chest.name == "pet.chest")
            #expect(rig.head.name == "pet.head")
            #expect(rig.leftEye.name == "pet.eye.left")
            #expect(rig.rightEye.name == "pet.eye.right")
        }
    }
}
```

Create `TestRenderingFixtures.swift` with all shared rendering fixtures:

```swift
import SpriteKit
import LumiCore
@testable import LumiRendering

enum PetReferenceSeeds {
    static let all: [UInt64] = [
        1, 2, 3, 5, 8, 13, 21, 34,
        55, 89, 144, 233, 377, 610, 987, 1_597,
        2_584, 4_181, 6_765, 10_946, 17_711, 28_657, 46_368, 75_025
    ]
}

extension PetTextureCatalog {
    static func testCatalog() throws -> PetTextureCatalog {
        try PetTextureCatalog(
            availableNames: Set(requiredTextureNames),
            textureLoader: { SKTexture(imageNamed: "__lumi_test_texture__") }
        )
    }
}

extension PetRig {
    static func testRig() throws -> PetRig {
        let configuration = try PetGenerator.generate(seed: 101, version: 1)
        return try PetNodeFactory(catalog: PetTextureCatalog.testCatalog()).makeRig(
            presentation: PetPresentation(configuration: configuration)
        )
    }
}

extension PetScene {
    static func testing() throws -> PetScene {
        let configuration = try PetGenerator.generate(seed: 101, version: 1)
        return try PetScene(
            presentation: PetPresentation(configuration: configuration),
            catalog: PetTextureCatalog.testCatalog(),
            policy: .phone,
            reduceMotion: false
        )
    }
}
```

- [ ] **Step 3: Run rendering tests and verify red**

Run the package rig test:

```bash
swift test --package-path Packages/LumiKit --filter PetNodeFactoryTests
```

Then use `GetTestList` and `RunSomeTests` for `PetTextureAtlasIntegrationTests` in the app test target.

Expected: package compilation fails because rendering types do not exist, and the app-hosted test fails until the catalog exists and the compiled atlas contains every required semantic name.

- [ ] **Step 4: Implement presentation and catalog types**

`PetPresentation` contains only `PetConfiguration` plus an accessibility description. `PetTextureCatalog` exposes `init(atlas: SKTextureAtlas)` for application bundles and an internal `init(availableNames:textureLoader:)` for package tests. Both initializers validate `requiredTextureNames`; missing names throw `PetTextureCatalogError.missingRequired(Set<String>)`. `contains(_:)` checks the captured name set, and `texture(named:fallback:)` uses the injected loader after selecting the requested or fallback semantic name.

```swift
public struct PetPresentation: Equatable, Sendable {
    public let configuration: PetConfiguration
    public let accessibilityDescription: String

    public init(configuration: PetConfiguration) {
        self.configuration = configuration
        self.accessibilityDescription = configuration.accessibilityDescription
    }
}

extension PetConfiguration {
    var accessibilityDescription: String {
        "A \(motionPersonality.rawValue), \(body.furStyle.rawValue) Lumi with \(ears.earStyle.rawValue) ears and a \(tail.tailStyle.rawValue) tail"
    }
}
```

- [ ] **Step 5: Implement `PetRig`**

Define the captured transform values used by animation and tests:

```swift
public struct PetNodeTransform: Equatable, Sendable {
    public let position: CGPoint
    public let xScale: CGFloat
    public let yScale: CGFloat
    public let zRotation: CGFloat
}

public struct PetRigBaseTransforms: Equatable, Sendable {
    public let root: PetNodeTransform
    public let abdomen: PetNodeTransform
    public let chest: PetNodeTransform
    public let head: PetNodeTransform
    public let paws: PetNodeTransform
    public let leftEar: PetNodeTransform
    public let rightEar: PetNodeTransform
    public let tail: PetNodeTransform
    public let chestTuft: PetNodeTransform
    public let leftCheek: PetNodeTransform
    public let rightCheek: PetNodeTransform
}
```

`PetRig` owns public read-only typed references to `root`, `body`, `abdomen`, `chest`, `head`, both eyes and lids, both ears, tail, chest tuft, cheek nodes, magic node, paws, and shadow. It also exposes `public let base: PetRigBaseTransforms` and `public let requiredNodes: [SKNode]`. `requiredNodes` contains root, body, abdomen, chest, head, both eyes, both ears, tail, paws, and shadow exactly once. Capture `base` after assembly and before any animation starts. `restoreBaseTransforms()` assigns every captured position, scale, and rotation back to its corresponding node.

- [ ] **Step 6: Implement `PetNodeFactory`**

Create `SKSpriteNode` parts from semantic texture names, apply configured tints with `colorBlendFactor`, attach them using normalized rig anchors, and assign the exact semantic names from specification section 11.3. The root coordinate system uses a 1,024-point design canvas. Paws and shadow define ground level `y = 0`.

Do not query SwiftData, call `PetGenerator`, or start animation in the factory.

- [ ] **Step 7: Run rendering, atlas, and package tests**

```bash
swift test --package-path Packages/LumiKit --filter LumiRenderingTests
swift test --package-path Packages/LumiKit
```

Use `RunSomeTests` to run `PetTextureAtlasIntegrationTests` in the app-hosted target after the package commands.

Expected: package rig tests pass and the app-hosted test confirms every required semantic texture is present in the compiled application atlas.

- [ ] **Step 8: Commit the rig checkpoint**

```bash
git add Packages/LumiKit appTests/PetTextureAtlasIntegrationTests.swift
git commit -m "feat: construct textured Lumi rigs"
```

---

### Task 9: Implement anatomical breathing with red-green tests

**Files:**
- Create: `app/Packages/LumiKit/Sources/LumiRendering/BreathingProfile.swift`
- Create: `app/Packages/LumiKit/Sources/LumiRendering/BreathingController.swift`
- Test: `app/Packages/LumiKit/Tests/LumiRenderingTests/BreathingControllerTests.swift`

- [ ] **Step 1: Write failing breathing-profile tests**

```swift
import Testing
import LumiCore
@testable import LumiRendering

struct BreathingControllerTests {
    @Test func cycleTimingMatchesAnimalRestingRange() {
        for personality in MotionPersonality.allCases {
            let profile = BreathingProfile(personality: personality, reduceMotion: false)
            #expect((2.4...4.0).contains(profile.duration))
            #expect(profile.inhaleShare == 0.32)
            #expect(profile.pauseShare == 0.04)
            #expect(profile.exhaleShare == 0.44)
            #expect(profile.restShare == 0.20)
        }
    }

    @Test func reduceMotionPreservesFortyPercentBreathingAmplitude() {
        let normal = BreathingProfile(personality: .calm, reduceMotion: false)
        let reduced = BreathingProfile(personality: .calm, reduceMotion: true)
        #expect(reduced.abdomenXAmplitude == normal.abdomenXAmplitude * 0.4)
        #expect(reduced.headRise == normal.headRise * 0.4)
    }

    @Test func completedCycleRestoresBaseTransforms() throws {
        let rig = try PetRig.testRig()
        let controller = BreathingController(rig: rig, profile: .init(personality: .calm, reduceMotion: false))
        controller.apply(phase: 1)
        controller.apply(phase: 0)
        #expect(rig.root.xScale == rig.base.root.xScale)
        #expect(rig.head.xScale == rig.base.head.xScale)
        #expect(rig.paws.position == rig.base.paws.position)
    }
}
```

- [ ] **Step 2: Run and verify red**

```bash
swift test --package-path Packages/LumiKit --filter BreathingControllerTests
```

Expected: compilation fails because breathing types are undefined.

- [ ] **Step 3: Implement `BreathingProfile`**

Use fixed phase shares totaling `1.0`. Map personalities to durations: calm `3.6`, curious `3.1`, playful `2.8`, lively `2.4`, sleepy `4.0`. Normal amplitudes are abdomen X `0.028`, abdomen Y `0.018`, chest rise `0.015` of body height, and head rise `0.008` of body height. Multiply amplitudes by `0.4` under Reduce Motion.

- [ ] **Step 4: Implement anatomical phase application**

`BreathingController.apply(phase:)` accepts normalized cycle progress, maps it through inhale/pause/exhale/rest, and applies asymmetric cubic easing. It changes only abdomen scale, chest position, shoulder/body offset, head Y position, chest tuft, cheek, and tail-tip secondary offsets. It never changes `root` scale, head scale, eye scale, nose scale, mouth scale, paw position, or shadow scale.

Use these easing functions:

```swift
private func easeOutCubic(_ value: CGFloat) -> CGFloat {
    1 - pow(1 - value, 3)
}

private func easeInOutCubic(_ value: CGFloat) -> CGFloat {
    value < 0.5 ? 4 * value * value * value : 1 - pow(-2 * value + 2, 3) / 2
}
```

At phase `0` and `1`, call `rig.restoreBaseTransforms()`.

- [ ] **Step 5: Add the repeating SpriteKit action**

Build one `SKAction.customAction(withDuration:)` per cycle that converts elapsed time to normalized phase and calls `apply(phase:)`. Sequence it forever under action key `pet.breathing`. Vary duration by at most 5% only after three to six complete breaths; never vary within a cycle.

- [ ] **Step 6: Run breathing tests, then verify red-green integrity**

```bash
swift test --package-path Packages/LumiKit --filter BreathingControllerTests
```

Expected: all breathing tests pass.

Temporarily change `inhaleShare` from `0.32` to `0.33`, rerun the focused test and confirm it fails, restore `0.32`, then rerun and confirm it passes.

- [ ] **Step 7: Commit the breathing checkpoint**

```bash
git add Packages/LumiKit
git commit -m "feat: add anatomical Lumi breathing"
```

---

### Task 10: Add secondary idle motion and the SpriteKit scene

**Files:**
- Create: `app/Packages/LumiKit/Sources/LumiRendering/SecondaryMotionController.swift`
- Create: `app/Packages/LumiKit/Sources/LumiRendering/PetScene.swift`
- Modify test: `app/Packages/LumiKit/Tests/LumiRenderingTests/BreathingControllerTests.swift`
- Create test: `app/Packages/LumiKit/Tests/LumiRenderingTests/PetSceneTests.swift`

- [ ] **Step 1: Write failing scene behavior tests**

```swift
import SpriteKit
import Testing
@testable import LumiRendering

struct PetSceneTests {
    @Test @MainActor func sceneStartsAllIndependentChannels() throws {
        let scene = try PetScene.testing()
        scene.startAnimation()
        #expect(scene.petRoot.action(forKey: "pet.breathing") != nil)
        #expect(scene.petRoot.action(forKey: "pet.blink.scheduler") != nil)
        #expect(scene.petRoot.action(forKey: "pet.gaze.scheduler") != nil)
        #expect(scene.petRoot.action(forKey: "pet.ear.scheduler") != nil)
        #expect(scene.petRoot.action(forKey: "pet.tail") != nil)
        #expect(scene.petRoot.action(forKey: "pet.weight.scheduler") != nil)
    }

    @Test @MainActor func backgroundPauseStopsSceneWork() throws {
        let scene = try PetScene.testing()
        scene.setApplicationActive(false)
        #expect(scene.isPaused)
        scene.setApplicationActive(true)
        #expect(!scene.isPaused)
    }
}
```

- [ ] **Step 2: Run and verify red**

```bash
swift test --package-path Packages/LumiKit --filter PetSceneTests
```

Expected: compilation fails because `PetScene` is not implemented.

- [ ] **Step 3: Implement `SecondaryMotionController`**

Create keyed SpriteKit channels for blink/double blink, gaze, ear twitch, tail movement, and body-weight shift. Use `SplitMix64(seed: configuration.seed ^ 0xA11CE)` for session scheduling so tests can be deterministic. Each channel affects only its semantic nodes and returns to captured base transforms.

- [ ] **Step 4: Implement `PetScene`**

Define:

```swift
public enum PetRenderPolicy: Equatable, Sendable {
    case phone
    case phoneLandscape
    case pad
    case mac
    case watch

    public var sizeFraction: CGFloat {
        switch self {
        case .phone: 0.46
        case .phoneLandscape: 0.40
        case .pad: 0.42
        case .mac: 0.38
        case .watch: 0.62
        }
    }

    public var preferredFramesPerSecond: Int {
        self == .watch ? 30 : 60
    }
}
```

`PetScene` owns the rig, breathing controller, and secondary controller and provides this initializer:

```swift
@MainActor
public init(
    presentation: PetPresentation,
    catalog: PetTextureCatalog,
    policy: PetRenderPolicy,
    reduceMotion: Bool
) throws
```

Set `scaleMode = .resizeFill`, transparent scene background, and `anchorPoint = CGPoint(x: 0.5, y: 0.5)`. In `didChangeSize`, place `pet.root` at `.zero` and calculate scale from the shorter scene dimension using `policy.sizeFraction`.

Expose:

```swift
@MainActor public var petRoot: SKNode { rig.root }
@MainActor public func startAnimation()
@MainActor public func setApplicationActive(_ active: Bool)
@MainActor public func setReduceMotion(_ enabled: Bool)
```

Rebuilding the animation profile must restore base transforms before restarting keyed actions.

- [ ] **Step 5: Run rendering tests and 30-minute accelerated drift test**

```bash
swift test --package-path Packages/LumiKit --filter LumiRenderingTests
```

Add an accelerated test that applies 30,000 normalized breathing samples and verifies every base transform at completed-cycle boundaries with tolerance `0.0001`.

Expected: all rendering tests pass with no drift.

- [ ] **Step 6: Commit the scene checkpoint**

```bash
git add Packages/LumiKit
git commit -m "feat: animate living Lumi scenes"
```

---

### Task 11: Replace the starter app with the centered Lumi shell

**Files:**
- Create: `app/app/AppDependencies.swift`
- Create: `app/app/LumiViewModel.swift`
- Create: `app/app/PreviewPet.swift`
- Create: `app/app/PetSceneHost.swift`
- Modify: `app/app/appApp.swift`
- Modify: `app/app/ContentView.swift`
- Modify: `app/appTests/appTests.swift`
- Include test: `app/appTests/PetTextureAtlasIntegrationTests.swift`
- Delete after green: `app/app/Item.swift`

- [ ] **Step 1: Write the failing app view-model tests**

Replace `appTests.swift` with Swift Testing cases and complete test doubles:

```swift
import Foundation
import Testing
import LumiCore
@testable import app

private enum StubError: LocalizedError, Sendable {
    case failed

    var errorDescription: String? { "Load failed" }
}

private actor PetRepositorySpy: PetRepository {
    let result: Result<Pet, StubError>

    init(result: Result<Pet, StubError>) {
        self.result = result
    }

    func activePet() async throws -> Pet? {
        try result.get()
    }

    func createPetIfNeeded() async throws -> Pet {
        try result.get()
    }
}

@MainActor
struct LumiViewModelTests {
    @Test func loadPublishesPetOnlyAfterRepositoryReturns() async throws {
        let configuration = try PetGenerator.generate(seed: 101, version: 1)
        let pet = Pet.new(id: UUID(), configuration: configuration, now: .distantPast)
        let model = LumiViewModel(repository: PetRepositorySpy(result: .success(pet)))
        #expect(model.state == .loading)
        await model.load()
        #expect(model.state == .loaded(pet))
    }

    @Test func loadPublishesRetryableFailure() async {
        let model = LumiViewModel(repository: PetRepositorySpy(result: .failure(.failed)))
        await model.load()
        #expect(model.state == .failed("Load failed"))
    }
}
```

- [ ] **Step 2: Run the focused app tests and verify red**

Use `GetTestList`, select the two `LumiViewModelTests`, and run them with `RunSomeTests`.

Expected: compilation fails because `LumiViewModel` does not exist.

- [ ] **Step 3: Implement dependencies and view model**

```swift
import Observation
import LumiCore

@MainActor
@Observable
final class LumiViewModel {
    enum State: Equatable {
        case loading
        case loaded(Pet)
        case failed(String)
    }

    private let repository: any PetRepository
    private(set) var state: State = .loading

    init(repository: any PetRepository) {
        self.repository = repository
    }

    func load() async {
        state = .loading
        do {
            state = .loaded(try await repository.createPetIfNeeded())
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
```

`AppDependencies` constructs `LumiModelContainerFactory.make()` and `SwiftDataPetRepository`. It returns a typed failure instead of calling `fatalError`.

- [ ] **Step 4: Implement `PetSceneHost`**

Create the phone/iPad/Mac atlas with `SKTextureAtlas(named: "LumiPet")`, build one `PetScene`, and display it through `SpriteView`. Observe `scenePhase` and `accessibilityReduceMotion`; forward changes to the scene. Expose the host as one accessibility element, set `.accessibilityIdentifier("lumi.pet")`, and set its descriptive accessibility label from `PetPresentation.accessibilityDescription`.

- [ ] **Step 5: Replace `ContentView`**

Render exactly three states:

```swift
switch model.state {
case .loading:
    ProgressView().controlSize(.large)
case .loaded(let pet):
    PetSceneHost(pet: pet)
case .failed(let message):
    ContentUnavailableView {
        Label("Lumi couldn’t open", systemImage: "exclamationmark.triangle")
    } description: {
        Text(message)
    } actions: {
        Button("Retry") { Task { await model.load() } }
    }
}
```

Center every state in an edge-to-edge softly lit background. Add no navigation or product controls.

- [ ] **Step 6: Replace the app composition root**

`appApp.swift` becomes `LumiApp` and injects one `LumiViewModel`. Remove the `.modelContainer` view modifier because repository access is encapsulated by `LumiPersistence`.

- [ ] **Step 7: Run app tests and build all three destinations**

Run the two focused tests, then `BuildProject` for an iPhone simulator, an iPad simulator, and My Mac by switching eligible destinations with `XcodeSwitchRunDestination`.

Expected: tests pass and all three builds succeed.

- [ ] **Step 8: Render and inspect the SwiftUI preview**

Create `PreviewPet.swift` under `#if DEBUG`:

```swift
import Foundation
import LumiCore

enum PreviewPet {
    static func make(seed: UInt64 = 101) throws -> Pet {
        let configuration = try PetGenerator.generate(seed: seed, version: 1)
        let id = UUID(uuidString: "00000000-0000-0000-0000-000000000101") ?? UUID()
        return Pet.new(id: id, configuration: configuration, now: .distantPast)
    }
}
```

Add previews for loaded, loading, and failed states. The loaded preview uses `if let pet = try? PreviewPet.make()` and renders a clear preview-only error view if generation fails. Use `RenderPreview` on `ContentView.swift`; confirm the loaded pet is centered and no list UI remains.

- [ ] **Step 9: Remove `Item.swift`**

Use `XcodeRM` only after app tests and all three builds are green. Search for `Item` with `XcodeGrep` and confirm zero source references remain.

- [ ] **Step 10: Commit the app-shell checkpoint**

```bash
git add app appTests Packages/LumiKit app.xcodeproj
git commit -m "feat: display a persistent random Lumi"
```

---

### Task 12: Implement the watchOS shell

**Files:**
- Modify generated: `app/LumiWatch/LumiWatchApp.swift`
- Create: `app/LumiWatch/WatchLumiViewModel.swift`
- Create: `app/LumiWatch/WatchRootView.swift`
- Create: `app/LumiWatch/WatchPetSceneHost.swift`
- Test: `app/LumiWatchTests/WatchLumiViewModelTests.swift`

- [ ] **Step 1: Write the failing watch launch-state test**

Create `WatchLumiViewModelTests.swift`:

```swift
import Foundation
import Testing
import LumiCore
@testable import LumiWatch

private enum WatchStubError: LocalizedError, Sendable {
    case failed

    var errorDescription: String? { "Load failed" }
}

private actor WatchPetRepositorySpy: PetRepository {
    let result: Result<Pet, WatchStubError>

    init(result: Result<Pet, WatchStubError>) {
        self.result = result
    }

    func activePet() async throws -> Pet? {
        try result.get()
    }

    func createPetIfNeeded() async throws -> Pet {
        try result.get()
    }
}

@MainActor
struct WatchLumiViewModelTests {
    @Test func loadPublishesPet() async throws {
        let configuration = try PetGenerator.generate(seed: 202, version: 1)
        let pet = Pet.new(id: UUID(), configuration: configuration, now: .distantPast)
        let model = WatchLumiViewModel(repository: WatchPetRepositorySpy(result: .success(pet)))
        #expect(model.state == .loading)
        await model.load()
        #expect(model.state == .loaded(pet))
    }

    @Test func loadPublishesRetryableFailure() async {
        let model = WatchLumiViewModel(repository: WatchPetRepositorySpy(result: .failure(.failed)))
        await model.load()
        #expect(model.state == .failed("Load failed"))
    }
}
```

- [ ] **Step 2: Run the watch test and verify red**

Switch to the watch scheme, use `GetTestList`, and run the new focused test with `RunSomeTests`.

Expected: compilation fails because watch root types are absent.

- [ ] **Step 3: Implement the watch view model and root**

Implement `WatchLumiViewModel` as an `@MainActor @Observable` final class with the same three state cases and `load()` behavior as `LumiViewModel`, depending only on `any PetRepository`. Keep it in the watch target; do not create a fourth shared package product for two small shell models.

Use the same `LumiModelContainerFactory` and `SwiftDataPetRepository`. `WatchRootView` displays only loading, loaded, and retryable error states. `WatchPetSceneHost` loads `LumiPetWatch`, injects the watch render policy, targets 30 FPS, forwards inactive and Reduce Motion states, and exposes one accessibility element with identifier `lumi.pet` plus the generated descriptive label.

- [ ] **Step 4: Verify watch-safe layout**

The pet uses 62% of the shorter safe-area dimension. Ensure ears, tail, fur tufts, and shadow remain inside the safe area on the smallest eligible watch simulator. No text overlays the pet.

- [ ] **Step 5: Build and run the watch app**

Select an eligible paired watch simulator, run `BuildProject`, then use a workspace device interaction session to install and launch. Inspect the UI hierarchy and capture the current state. Confirm one accessible Lumi element exists.

Expected: watch build succeeds and the pet appears centered.

- [ ] **Step 6: Commit the watch checkpoint**

```bash
git add LumiWatch app.xcodeproj
git commit -m "feat: display Lumi on Apple Watch"
```

---

### Task 13: Enable private CloudKit synchronization

**Files:**
- Modify through tools: capabilities for `Lumi`
- Modify through tools: capabilities for `LumiWatch`
- Modify through tools: `CODE_SIGN_ENTITLEMENTS` build settings
- Verify: `app/app/app.entitlements`
- Verify generated watch entitlements

- [ ] **Step 1: Confirm final SwiftData schema tests are green**

```bash
swift test --package-path Packages/LumiKit --filter LumiPersistenceTests
```

Expected: all persistence tests pass. Do not continue if `PetRecord` still needs a destructive field change.

- [ ] **Step 2: Link the existing application entitlement file**

Use `UpdateTargetBuildSetting`:

```text
Target: app
CODE_SIGN_ENTITLEMENTS = app/app.entitlements
```

Read the evaluated setting back with `GetTargetBuildSettings` and confirm it is nonempty.

- [ ] **Step 3: Add application CloudKit entitlements**

Use `AddEntitlement` for target `app` to update the existing keys to these exact values:

```text
com.apple.developer.icloud-container-identifiers = [iCloud.heylumipet.app]
com.apple.developer.icloud-services = [CloudKit]
aps-environment = development
com.apple.developer.aps-environment = development
```

The tool must replace the existing empty iCloud identifier array rather than append a second key. The two notification keys are intentional for this multiplatform target: `aps-environment` serves iOS/iPadOS and `com.apple.developer.aps-environment` serves macOS. Read the resulting entitlement file with `XcodeRead` and confirm each key occurs once. Retain `UIBackgroundModes = [remote-notification]` in the app Info.plist.

- [ ] **Step 4: Add watch CloudKit entitlements**

Use `AddEntitlement` for target `LumiWatch` with the same iCloud container and CloudKit service. Use `AddInfoPlist` to set `UIBackgroundModes` to the string array `[remote-notification]`; setting the key is idempotent if the template already supplied it.

- [ ] **Step 5: Build signed app and watch products**

Run `BuildProject` for a physical-device-eligible iOS destination and a watchOS destination.

Expected: no missing entitlement, provisioning, container, or code-signing errors.

- [ ] **Step 6: Initialize and inspect the development schema**

Launch a debug build with the development iCloud container. In CloudKit Console confirm one `CD_PetRecord` record type exists with fields corresponding to every `PetRecord` property. Enable query support required by the managed store. Do not promote to production during this task.

- [ ] **Step 7: Verify sequential cross-device sync**

On device A, remove the app's development data, launch, record pet UUID and canonical configuration hash, and wait for the record in CloudKit Console. On device B using the same iCloud test account, launch after the record appears. Confirm the UUID and configuration hash match device A.

- [ ] **Step 8: Verify offline convergence**

Launch clean installations on devices A and B while both are offline, reconnect both, and wait for CloudKit delivery. Confirm both repositories eventually choose the same `(createdAt, UUID)` canonical record and mark the other inactive without deleting it.

- [ ] **Step 9: Commit the CloudKit checkpoint**

```bash
git add app.xcodeproj app/app.entitlements LumiWatch
git commit -m "feat: sync Lumi through private CloudKit"
```

---

### Task 14: Complete UI, visual, motion, and regression verification

**Files:**
- Modify: `app/appUITests/appUITests.swift`
- Create or modify: watch UI test generated by the watch template
- Create evidence: `app/docs/superpowers/evidence/random-lumi/phone/*.png`
- Create evidence: `app/docs/superpowers/evidence/random-lumi/watch/*.png`
- Create evidence: `app/docs/superpowers/evidence/random-lumi/breathing-review.md`

- [ ] **Step 1: Replace the starter UI test**

```swift
import XCTest

final class LumiUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLumiAppearsNearScreenCenter() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-seed", "101"]
        app.launch()

        let lumi = app.otherElements["lumi.pet"]
        XCTAssertTrue(lumi.waitForExistence(timeout: 5))

        let screen = app.windows.firstMatch.frame
        XCTAssertEqual(lumi.frame.midX, screen.midX, accuracy: screen.width * 0.03)
        XCTAssertEqual(lumi.frame.midY, screen.midY, accuracy: screen.height * 0.03)
    }
}
```

Add iPad rotation and Mac window-resize variants with the same 3% center tolerance.

- [ ] **Step 2: Add deterministic UI-test launch configuration**

When `-ui-testing -seed 101` is present, use an in-memory store and injected seed `101`. This path must remain compiled only in debug builds and must not change production generation.

- [ ] **Step 3: Add watch UI coverage**

Launch `LumiWatch`, wait up to 5 seconds for accessibility identifier `lumi.pet`, and assert its frame remains inside the safe content frame.

- [ ] **Step 4: Generate the 24-seed visual matrix**

Use these fixed seeds:

```text
1, 2, 3, 5, 8, 13, 21, 34,
55, 89, 144, 233, 377, 610, 987, 1597,
2584, 4181, 6765, 10946, 17711, 28657, 46368, 75025
```

Render each at phone atlas quality and watch atlas quality. Review every snapshot against specification section 11.2. Reject any hard outline, flat vector appearance, plastic highlight, unreadable eye, color collision, detached part, inconsistent light direction, or clipped fur silhouette.

- [ ] **Step 5: Inspect breathing at normal and quarter speed**

Record at least five full cycles for calm, lively, and sleepy profiles. At quarter speed verify abdomen lead, delayed chest/shoulder/head movement, planted paws, exhale fur lag, asymmetric easing, and exact rest-pose return. Reject uniform root scaling or visible head scaling.

- [ ] **Step 6: Run all automated tests**

Run:

```bash
swift test --package-path Packages/LumiKit
```

Then use `RunAllTests` on the active Xcode test plan for the application and watch schemes.

Expected: zero failed Swift Testing or XCUIAutomation cases.

- [ ] **Step 7: Build every required destination**

Use `BuildProject` after selecting one iPhone simulator, one iPad simulator, My Mac, and one Apple Watch simulator.

Expected: four successful builds and no warnings caused by Lumi source files.

- [ ] **Step 8: Run the final manual matrix**

Complete every scenario in specification section 14.3, including 30-minute animation stability, background/foreground pause, Reduce Motion, no-iCloud local use, later iCloud enablement, sequential sync, and offline convergence.

- [ ] **Step 9: Audit scope and source references**

Use `XcodeGrep` to confirm:

```text
Item                       → 0 source matches
FoundationModels           → 0 source matches
StoreKit                   → 0 source matches
NavigationStack/List UI    → 0 root-screen matches
fatalError                 → 0 production source matches
```

Confirm no onboarding, care, game, memory, widget, purchase, or multi-pet UI was introduced.

- [ ] **Step 10: Commit the acceptance checkpoint**

```bash
git add appUITests LumiWatch Packages/LumiKit
git commit -m "test: verify Random Lumi milestone"
```

---

## Acceptance-criteria traceability

| Spec criterion | Implementing tasks | Verification |
|---|---|---|
| 1–2: Required targets and platforms | 1, 12 | Four destination builds |
| 3: Remove starter item UI/model | 11 | Source grep and app UI test |
| 4: One level-1 pet | 5, 6, 11 | Defaults and repository tests |
| 5–6: Valid deterministic generation | 2–4 | Codec, generator, validator, 1,000-seed tests |
| 7: Relaunch stability | 6, 11 | Repository reuse test and manual relaunch |
| 8–9: CloudKit and offline use | 6, 13 | Two-device and no-iCloud matrix |
| 10: Centered adaptive layout | 10–12, 14 | UI tests within 3% center tolerance |
| 11–12: Reference style and textured rig | 7, 8, 14 | Texture contract and 24-seed snapshots |
| 13–16: Anatomical breathing and idle motion | 9, 10, 14 | Profile, drift, Reduce Motion, slow-motion review |
| 17: Lifecycle pause | 10–12 | Scene pause test and manual backgrounding |
| 18: No fatal recovery | 6, 11, 14 | Error tests and source grep |
| 19: Complete test pass | 14 | Package and Xcode test runs |
| 20: No excluded scope | 14 | Final source and UI audit |

## Final execution gate

Do not declare Milestone 0 complete until all of the following evidence exists in the execution session:

1. Fresh package test output with zero failures.
2. Fresh Xcode test output with zero failures.
3. Successful iPhone, iPad, Mac, and Apple Watch builds.
4. A reviewed 24-seed phone/watch visual matrix.
5. Slow-motion breathing review for calm, lively, and sleepy profiles.
6. Two-device CloudKit identity and configuration-hash match.
7. Offline duplicate convergence result.
8. Thirty-minute no-drift observation.
9. Final scope grep with no forbidden production references.
