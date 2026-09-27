import Foundation
import Testing
@testable import LumiCore
@testable import LumiRendering

struct PetRigLayoutTests {
    @Test func decodesRealLayout() throws {
        let layout = try RenderingFixtures.realLayout()
        #expect(layout.canvasSize == CGSize(width: 1024, height: 1024))
    }

    @Test func allSeventeenAnchorsPresent() throws {
        let layout = try RenderingFixtures.realLayout()
        let expected = [
            "shadow", "paws", "body", "abdomen", "chest", "tail", "head",
            "leftEar", "rightEar", "headTuft", "leftEye", "rightEye",
            "muzzle", "nose", "leftCheek", "rightCheek", "magic"
        ]
        #expect(expected.count == 17)
        for name in expected {
            #expect(layout.hasAnchor(name), "missing anchor \(name)")
        }
    }

    @Test func texturesEqualRequiredNames() throws {
        let layout = try RenderingFixtures.realLayout()
        #expect(layout.textureNames.count == 56)
        #expect(layout.textureNames == Set(PetTextureCatalog.requiredTextureNames))
    }

    @Test func headVariantsMapAllFurStyles() throws {
        let layout = try RenderingFixtures.realLayout()
        for style in FurStyle.allCases {
            #expect(layout.headVariant(for: style) != nil, "missing headVariant \(style)")
        }
        #expect(layout.headVariant(for: .smooth) == "fur_smooth")
        #expect(layout.headVariant(for: .fluffy) == "fur_fluffy")
        #expect(layout.headVariant(for: .spiky) == "fur_spiky")
    }

    @Test func relativeSizesInUnitInterval() throws {
        let layout = try RenderingFixtures.realLayout()
        for value in [layout.relativeSizes.iris, layout.relativeSizes.pupil, layout.relativeSizes.catchlight] {
            #expect(value > 0 && value < 1)
        }
    }

    @Test func pointForHeadUsesCanvasCenterOrigin() throws {
        let layout = try RenderingFixtures.realLayout()
        // From JSON: head = { x: 0.500, y: 0.647 }, canvas 1024.
        let expected = CGPoint(x: (0.500 - 0.5) * 1024, y: (0.647 - 0.5) * 1024)
        let point = layout.point(for: "head")
        #expect(abs(point.x - expected.x) < 1e-6)
        #expect(abs(point.y - expected.y) < 1e-6)
    }

    @Test func missingAnchorThrows() throws {
        let json = """
        {
          "version": 1,
          "canvas": { "width": 1024, "height": 1024 },
          "anchors": { "shadow": { "x": 0.5, "y": 0.1 } },
          "relativeSizes": { "iris": 0.8, "pupil": 0.4, "catchlight": 0.4 },
          "headVariants": { "smooth": "fur_smooth", "fluffy": "fur_fluffy", "spiky": "fur_spiky" },
          "textures": {}
        }
        """
        #expect(throws: PetRigLayoutError.self) {
            _ = try PetRigLayout.decode(Data(json.utf8))
        }
    }

    @Test func unsupportedVersionThrows() throws {
        let json = """
        {
          "version": 2,
          "canvas": { "width": 1024, "height": 1024 },
          "anchors": {},
          "relativeSizes": { "iris": 0.8, "pupil": 0.4, "catchlight": 0.4 },
          "headVariants": { "smooth": "fur_smooth", "fluffy": "fur_fluffy", "spiky": "fur_spiky" },
          "textures": {}
        }
        """
        #expect {
            _ = try PetRigLayout.decode(Data(json.utf8))
        } throws: { error in
            (error as? PetRigLayoutError) == .unsupportedVersion(2)
        }
    }

    @Test func designSizeReturnsTextureDimensions() throws {
        let layout = try RenderingFixtures.realLayout()
        #expect(try layout.designSize(of: "body_round") == CGSize(width: 440, height: 380))
    }

    @Test func designSizeThrowsForUnknownTexture() throws {
        let layout = try RenderingFixtures.realLayout()
        #expect(throws: PetRigLayoutError.self) {
            _ = try layout.designSize(of: "does_not_exist")
        }
    }
}
