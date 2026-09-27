//
//  appUITests.swift
//  appUITests
//
//  Task 14a: verifies Lumi renders centered and correctly sized across
//  iPhone, iPad, and Mac. Launches with an in-memory store + fixed seed so
//  the pet is deterministic.
//

import XCTest

final class appUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        #if os(iOS)
        // Restore portrait so a rotation test doesn't leak into later tests.
        XCUIDevice.shared.orientation = .portrait
        #endif
    }

    // MARK: - Helpers

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-LumiUITest", "-LumiSeed", "42"]
        app.launch()
        return app
    }

    /// The fraction of the window's shorter side the pet's longest side should
    /// occupy, per the render policy for the current device/orientation.
    @MainActor
    private func expectedFraction(landscape: Bool) -> CGFloat {
        #if os(macOS)
        return 0.38
        #else
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            return 0.42
        default:
            return landscape ? 0.40 : 0.46
        }
        #endif
    }

    @MainActor
    private func assertCentered(
        _ app: XCUIApplication,
        landscape: Bool = false,
        checkSize: Bool = true,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let pet = app.descendants(matching: .any)["lumi.pet"]
        XCTAssertTrue(pet.waitForExistence(timeout: 10), "lumi.pet never appeared", file: file, line: line)

        let window = app.windows.firstMatch.frame
        let petFrame = pet.frame

        let dx = abs(petFrame.midX - window.midX)
        let dy = abs(petFrame.midY - window.midY)
        XCTAssertLessThanOrEqual(
            dx, 0.03 * window.width,
            "pet not horizontally centered: dx=\(dx), tol=\(0.03 * window.width)",
            file: file, line: line
        )
        XCTAssertLessThanOrEqual(
            dy, 0.03 * window.height,
            "pet not vertically centered: dy=\(dy), tol=\(0.03 * window.height)",
            file: file, line: line
        )

        if checkSize {
            let longest = max(petFrame.width, petFrame.height)
            let shorter = min(window.width, window.height)
            let fraction = longest / shorter
            let expected = expectedFraction(landscape: landscape)
            let lower = expected * 0.85
            let upper = expected * 1.15
            XCTAssertTrue(
                fraction >= lower && fraction <= upper,
                "pet size fraction \(fraction) not within ±15% of \(expected) [\(lower), \(upper)]",
                file: file, line: line
            )
        }

        XCTAssertFalse(pet.label.isEmpty, "pet accessibility label is empty", file: file, line: line)
    }

    // MARK: - Tests

    @MainActor
    func testPetIsCenteredAndSized() throws {
        let app = launchApp()
        assertCentered(app)
    }

    #if os(iOS)
    @MainActor
    func testPetStaysCenteredAfterRotation() throws {
        let app = launchApp()
        let pet = app.descendants(matching: .any)["lumi.pet"]
        XCTAssertTrue(pet.waitForExistence(timeout: 10), "lumi.pet never appeared")

        XCUIDevice.shared.orientation = .landscapeLeft
        // Allow the layout to settle after rotation.
        Thread.sleep(forTimeInterval: 1.0)

        // iPad keeps the .pad fraction in landscape; phone switches to .40.
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        assertCentered(app, landscape: !isPad)
    }
    #endif

    #if os(macOS)
    @MainActor
    func testPetStaysCenteredAfterWindowResize() throws {
        let app = launchApp()
        let pet = app.descendants(matching: .any)["lumi.pet"]
        XCTAssertTrue(pet.waitForExistence(timeout: 10), "lumi.pet never appeared")

        let window = app.windows.firstMatch
        let bottomRight = window.coordinate(withNormalizedOffset: CGVector(dx: 1.0, dy: 1.0))
        let target = bottomRight.withOffset(CGVector(dx: -300, dy: -200))
        bottomRight.press(forDuration: 0.2, thenDragTo: target)
        Thread.sleep(forTimeInterval: 1.0)

        assertCentered(app)
    }
    #endif

    // testSamePetPersistsAcrossRelaunch is intentionally omitted: with the
    // in-memory store used under -LumiUITest, nothing persists across relaunch,
    // so the pet would differ. The seed makes each launch deterministic instead.
}
