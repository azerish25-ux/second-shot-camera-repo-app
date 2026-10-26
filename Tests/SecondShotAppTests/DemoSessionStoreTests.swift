import SecondShotCore
import XCTest
@testable import SecondShot

@MainActor
final class DemoSessionStoreTests: XCTestCase {
    private func storeAtSavedReference() -> DemoSessionStore {
        let store = DemoSessionStore()
        store.openDemo()
        store.simulateReference()
        return store
    }

    func testSimulatingReferenceWalksTheProductionPathToASavedReference() {
        let store = storeAtSavedReference()

        XCTAssertEqual(store.state.phase, .referenceAvailable)
        XCTAssertEqual(store.state.referenceTakeID, DemoStudio.referenceTake)
        XCTAssertTrue(store.hasReference)
        XCTAssertTrue(store.canStartRetake)
        XCTAssertNotNil(store.referenceTrack)
        XCTAssertNotNil(store.retakeTrack)
        XCTAssertNil(store.lastError)
        XCTAssertEqual(store.route, [.reference])
        // The synthetic adapter minted a real operation identity on the way here.
        XCTAssertNil(store.state.token)
        XCTAssertGreaterThan(store.state.generation, 0)
    }

    func testRetakeJourneyUsesTheReducerAndStopsIntoReview() {
        let store = storeAtSavedReference()
        store.startRetake()

        XCTAssertEqual(store.state.phase, .recordingRetake)
        XCTAssertTrue(store.isRecordingRetake)
        XCTAssertEqual(store.route, [.reference, .guidance])
        XCTAssertNotNil(store.guidanceReading)

        store.stopAndReview()
        XCTAssertEqual(store.state.phase, .reviewing)
        XCTAssertEqual(store.state.retakeTakeID, DemoStudio.retakeTake)
        XCTAssertTrue(store.route.contains(.review))
        XCTAssertNotNil(store.endDeviation)

        store.finishDemo()
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertTrue(store.route.isEmpty)
    }

    /// The old demo paused a retake when tracking was lost. The production rule
    /// is stricter: the attempt ends, stays incomplete, and never resumes by
    /// itself, so nothing can later be presented as a finished recording.
    func testTrackingLossEndsTheAttemptInsteadOfPausingIt() {
        let store = storeAtSavedReference()
        store.startRetake()

        store.interruptTracking()
        XCTAssertEqual(store.state.phase, .interrupted)
        XCTAssertEqual(store.state.interruption, .trackingLost)
        XCTAssertEqual(store.state.diagnosticCode, "tracking-unavailable")
        XCTAssertTrue(store.isTrackingLost)
        XCTAssertNil(store.guidanceReading)
        XCTAssertNil(store.state.retakeTakeID)
        XCTAssertTrue(store.state.hasReference)
        XCTAssertFalse(store.isRecordingRetake)

        // Recovery returns to the saved reference, and a fresh attempt is explicit.
        store.resumeTracking()
        XCTAssertEqual(store.state.phase, .referenceAvailable)
        XCTAssertFalse(store.isTrackingLost)
        store.startRetake()
        XCTAssertEqual(store.state.phase, .recordingRetake)
        XCTAssertNotNil(store.guidanceReading)
        store.finishDemo()
    }

    func testDiscardingAnInterruptedAttemptKeepsTheReference() {
        let store = storeAtSavedReference()
        store.startRetake()
        store.interruptTracking()

        store.discardAttempt()
        XCTAssertEqual(store.state.phase, .referenceAvailable)
        XCTAssertEqual(store.state.referenceTakeID, DemoStudio.referenceTake)
        XCTAssertEqual(store.route, [.reference])
        XCTAssertFalse(store.isTrackingLost)
        store.finishDemo()
    }

    func testStartingARetakeWithoutAReferenceDoesNothing() {
        let store = DemoSessionStore()
        store.startRetake()
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertTrue(store.route.isEmpty)

        store.simulateReference()
        XCTAssertEqual(store.state.phase, .referenceAvailable)
    }
}
