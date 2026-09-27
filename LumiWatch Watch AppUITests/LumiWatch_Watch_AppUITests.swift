//
//  LumiWatch_Watch_AppUITests.swift
//  LumiWatch Watch AppUITests
//
//  Task 14a: verifies Lumi renders centered and correctly sized on the watch.
//

import XCTest

final class LumiWatch_Watch_AppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWatchPetIsCentered() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-LumiUITest", "-LumiSeed", "42"]
        app.launch()

        let pet = app.descendants(matching: .any)["lumi.pet"]
        XCTAssertTrue(pet.waitForExistence(timeout: 10), "lumi.pet never appeared")

        let window = app.windows.firstMatch.frame
        let petFrame = pet.frame

        let dx = abs(petFrame.midX - window.midX)
        let dy = abs(petFrame.midY - window.midY)
        XCTAssertLessThanOrEqual(dx, 0.03 * window.width, "pet not horizontally centered: dx=\(dx)")
        XCTAssertLessThanOrEqual(dy, 0.03 * window.height, "pet not vertically centered: dy=\(dy)")

        let longest = max(petFrame.width, petFrame.height)
        let shorter = min(window.width, window.height)
        let fraction = longest / shorter
        let expected: CGFloat = 0.62
        XCTAssertTrue(
            fraction >= expected * 0.85 && fraction <= expected * 1.15,
            "pet size fraction \(fraction) not within ±15% of \(expected)"
        )

        XCTAssertFalse(pet.label.isEmpty, "pet accessibility label is empty")
    }
}
