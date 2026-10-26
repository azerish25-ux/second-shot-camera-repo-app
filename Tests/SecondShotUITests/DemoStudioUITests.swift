import XCTest

/// Simulator journeys over the synthetic demo. These verify navigation, labels,
/// screenshot evidence and failure states; they cannot verify camera or AR
/// behaviour, which requires physical devices.
final class DemoStudioUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSyntheticReferenceGuidanceInterruptionReviewAndExportExplanation() throws {
        let openDemo = app.buttons["library.demo.open"]
        XCTAssertTrue(openDemo.waitForExistence(timeout: 30), "Library should expose the demo entry")
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "demo.badge").firstMatch.exists,
            "The synthetic mode badge must be visible in the library"
        )
        attachScreenshot("01-library")

        openDemo.tap()

        let simulateReference = app.buttons["demo.reference.create"]
        XCTAssertTrue(simulateReference.waitForExistence(timeout: 20), "Reference stage should load")
        attachScreenshot("02-reference")

        simulateReference.tap()

        let startRetake = app.buttons["demo.retake.start"]
        XCTAssertTrue(startRetake.waitForExistence(timeout: 20), "Reference must save before retake")
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "demo.badge").firstMatch.exists,
            "Synthetic badge must persist across the journey"
        )
        attachScreenshot("03-reference-ready")

        startRetake.tap()

        let guidance = app.staticTexts["retake.guidance"]
        XCTAssertTrue(guidance.waitForExistence(timeout: 20), "Guidance instruction should be visible")
        attachScreenshot("04-guidance")

        let trackingStatus = app.descendants(matching: .any)
            .matching(identifier: "retake.tracking.status").firstMatch
        XCTAssertTrue(trackingStatus.waitForExistence(timeout: 10), "Tracking status must be redundant, not color-only")

        let interrupt = app.buttons["demo.tracking.interrupt"]
        XCTAssertTrue(interrupt.waitForExistence(timeout: 10))
        interrupt.tap()

        XCTAssertTrue(
            app.staticTexts["Guidance unavailable"].waitForExistence(timeout: 10),
            "Lost tracking must remove precision guidance"
        )
        XCTAssertTrue(
            app.buttons["demo.tracking.resume"].waitForExistence(timeout: 10),
            "Recovery must be offered rather than resuming on its own"
        )
        XCTAssertFalse(
            app.buttons["demo.review.open"].exists,
            "An ended, incomplete attempt must not be offered as a reviewable take"
        )
        attachScreenshot("05-tracking-unavailable")

        let resume = app.buttons["demo.tracking.resume"]
        resume.tap()
        XCTAssertFalse(app.staticTexts["Guidance unavailable"].exists, "Recovery should clear the unavailable state")

        // Recovery returns to the saved reference, so a noticeplate says so and a
        // brand-new attempt has to be started deliberately.
        let restart = app.buttons["demo.retake.restart"]
        XCTAssertTrue(restart.waitForExistence(timeout: 10), "A fresh attempt must be started deliberately")
        XCTAssertEqual(
            app.staticTexts["retake.guidance"].label,
            "Reference ready",
            "Recovery lands on the saved reference, not in a half-finished recording"
        )
        restart.tap()

        XCTAssertTrue(
            app.buttons["demo.review.open"].waitForExistence(timeout: 10),
            "Stop must be reachable during a new attempt"
        )
        XCTAssertFalse(app.staticTexts["Guidance unavailable"].exists, "The new attempt guides again")

        let review = app.buttons["demo.review.open"]
        XCTAssertTrue(review.waitForExistence(timeout: 10))
        review.tap()

        let export = app.buttons["review.export.open"]
        XCTAssertTrue(export.waitForExistence(timeout: 20), "Review should expose the export entry")
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "review.source").firstMatch.exists,
            "Review must say the comparison is synthetic"
        )
        attachScreenshot("06-review")

        export.tap()
        XCTAssertTrue(
            app.staticTexts["export.unavailable"].waitForExistence(timeout: 10),
            "Export must explain that no footage exists instead of showing a share sheet"
        )
        attachScreenshot("07-export-explanation")

        app.buttons["export.close"].tap()
        let done = app.buttons["review.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        done.tap()

        XCTAssertTrue(
            app.buttons["library.demo.open"].waitForExistence(timeout: 20),
            "Finishing the demo returns to the library"
        )
    }

    func testLargeTextKeepsPrimaryActionsVisible() throws {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()

        let openDemo = app.buttons["library.demo.open"]
        XCTAssertTrue(openDemo.waitForExistence(timeout: 30))
        attachScreenshot("08-library-large-text")
        openDemo.tap()

        let simulateReference = app.buttons["demo.reference.create"]
        XCTAssertTrue(simulateReference.waitForExistence(timeout: 20))
        attachScreenshot("09-reference-large-text")

        simulateReference.tap()
        let startRetake = app.buttons["demo.retake.start"]
        XCTAssertTrue(startRetake.waitForExistence(timeout: 20))
        attachScreenshot("10-reference-ready-large-text")
    }
}
