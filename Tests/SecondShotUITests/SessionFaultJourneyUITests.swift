import XCTest

/// Simulator journeys for the injected session faults.
///
/// Each launch names one fault through `-ss-fault`; the app then has to show its
/// real consequence in the real screens instead of a fabricated success. Nothing
/// here starts a camera or an AR session, and none of it is device evidence.
final class SessionFaultJourneyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @discardableResult
    private func launch(fault: String) -> XCUIApplication {
        app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-ss-fault", fault
        ]
        app.launch()
        return app
    }

    private var failureNotice: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "session.failure").firstMatch
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Opens the demo and stops on the reference stage.
    private func openReferenceStage() -> XCUIElement {
        let openDemo = app.buttons["library.demo.open"]
        XCTAssertTrue(openDemo.waitForExistence(timeout: 30), "the library should expose the demo")
        openDemo.tap()

        let simulate = app.buttons["demo.reference.create"]
        XCTAssertTrue(simulate.waitForExistence(timeout: 20), "the reference stage should load")
        return simulate
    }

    func testDeniedCameraIsExplainedAndRecoversAfterAccessIsGranted() throws {
        launch(fault: "permissionDeniedThenGranted")
        let simulate = openReferenceStage()

        simulate.tap()

        XCTAssertTrue(
            failureNotice.waitForExistence(timeout: 20),
            "a refused permission must be explained on screen"
        )
        XCTAssertFalse(
            app.buttons["demo.retake.start"].exists,
            "a refused permission must not produce a reference"
        )
        attachScreenshot("11-permission-refused")

        // Returning from Settings: the app re-queries when it comes back to the
        // foreground, and the same button then completes the reference.
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(simulate.waitForExistence(timeout: 20))

        simulate.tap()
        XCTAssertTrue(
            app.buttons["demo.retake.start"].waitForExistence(timeout: 20),
            "granted access must let the reference be created"
        )
        attachScreenshot("12-permission-granted")
    }

    func testPreparationFailureIsRecoverableOnASecondAttempt() throws {
        launch(fault: "preparationFailure")
        let simulate = openReferenceStage()

        simulate.tap()
        XCTAssertTrue(failureNotice.waitForExistence(timeout: 20), "a preparation failure must be visible")
        XCTAssertFalse(app.buttons["demo.retake.start"].exists)
        attachScreenshot("13-preparation-failure")

        simulate.tap()
        XCTAssertTrue(
            app.buttons["demo.retake.start"].waitForExistence(timeout: 20),
            "the documented retry must recover once the device is available"
        )
    }

    func testWriterCreationFailureNeverClaimsAReference() throws {
        launch(fault: "writerCreationFailure")
        let simulate = openReferenceStage()

        simulate.tap()
        XCTAssertTrue(failureNotice.waitForExistence(timeout: 20), "a failed writer must be visible")
        XCTAssertFalse(app.buttons["demo.retake.start"].exists, "nothing may be published after a writer failure")
        attachScreenshot("14-writer-creation-failure")
    }

    func testWriterFinalizeFailureNeverClaimsAReferenceAndKeepsStopReachable() throws {
        launch(fault: "writerFinalizeFailure")
        let simulate = openReferenceStage()

        simulate.tap()
        XCTAssertTrue(failureNotice.waitForExistence(timeout: 20), "a failed finalize must be visible")
        XCTAssertFalse(app.buttons["demo.retake.start"].exists, "a failed finalize may not publish a take")
        XCTAssertTrue(
            simulate.isHittable,
            "recovery must stay reachable after a failed finalize"
        )
        attachScreenshot("15-writer-finalize-failure")
    }
}
