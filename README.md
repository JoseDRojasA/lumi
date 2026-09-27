# Lumi

A virtual pet for iPhone, iPad, Mac and Apple Watch. Milestone 0 ("Random Lumi") generates one persistent, random Lumi and shows it breathing in the middle of the screen.

- Spec: `docs/superpowers/specs/2026-09-26-lumi-product-definition.md`
- Plan: `docs/superpowers/plans/2026-09-26-random-lumi.md`

## Layout

| Path | What it is |
|---|---|
| `Packages/LumiKit` | Swift package: `LumiCore` (traits, seeded generator, validator), `LumiPersistence` (SwiftData + CloudKit), `LumiRendering` (SpriteKit rig, breathing, idle motion, scene) |
| `app/` | iPhone/iPad/Mac app (target and scheme `app`, display name Lumi) |
| `LumiWatch Watch App/` | watchOS app |
| `Tools/TextureGenerator/generate.swift` | Regenerates the placeholder texture atlases and `RigAnchors.json` |
| `Tools/VisualReview` | Renders 24-seed review sheets and breathing strips to `/tmp/lumi-review/` |

## Commands

```sh
swift test --package-path Packages/LumiKit             # package tests
swift Tools/TextureGenerator/generate.swift            # regenerate atlases (deterministic)
swift run --package-path Tools/VisualReview LumiVisualReview   # visual review sheets
```

App, UI and watch tests run from Xcode, or with `xcodebuild test` on the `app` and `LumiWatch Watch App` schemes. For UI tests, the launch arguments `-LumiUITest -LumiSeed <n>` use an in-memory store and a fixed pet.

## iCloud sync (currently off)

The CloudKit code is complete, but sync is turned off. Personal (free) development teams can't sign the iCloud and Push capabilities. With sync off, both apps keep the pet in a local-only SwiftData store.

To turn sync on:

1. Join the Apple Developer Program. In **Signing & Capabilities**, choose the paid team for both the `app` and `LumiWatch Watch App` targets.
2. Set the `CODE_SIGN_ENTITLEMENTS` build setting:
   - `app`: `app/app.entitlements`
   - `LumiWatch Watch App`: `LumiWatch Watch App/LumiWatch Watch App.entitlements`

   Both files already contain the `iCloud.heylumipet.app` container, CloudKit and push settings.
3. Set `LumiCloudKitEnabled` to `YES` in `app/Info.plist` and `LumiWatch-Watch-App-Info.plist`.

Do step 3 only together with steps 1 and 2. Without the entitlement, CloudKit crashes the app shortly after launch instead of returning an error, which is why the switch exists. If CloudKit fails to open while the switch is on, the app falls back to the same local store, so the pet is kept.
