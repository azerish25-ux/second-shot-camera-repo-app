import SecondShotCore
import XCTest
@testable import SecondShot

@MainActor
final class DemoSessionStoreTests: XCTestCase {
    func testSimulatingReferenceReachesADurableReadyState() {
        let store = DemoSessionStore()
        store.simulateReference()

        XCTAssertEqual(store.state.phase, .referenceReady)
        XCTAssertEqual(store.state.referenceTakeID, DemoStudio.referenceTake)
        XCTAssertNotNil(store.referenceTrack)
        XCTAssertNil(store.lastError)
        XCTAssertEqual(store.route, [.reference])
    }

    func testRetakeJourneyUsesTheReducerAndStopsIntoReview() {
        let store = DemoSessionStore()
        store.simulateReference()
        store.startRetake()

        XCTAssertEqual(store.state.phase, .recordingRetake)
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

    func testTrackingLossRemovesGuidanceButKeepsTheTake() {
        let store = DemoSessionStore()
        store.simulateReference()
        store.startRetake()

        store.interruptTracking()
        XCTAssertTrue(store.isTrackingLost)
        XCTAssertNil(store.guidanceReading)
        XCTAssertEqual(store.state.phase, .recordingRetake)

        store.resumeTracking()
        XCTAssertFalse(store.isTrackingLost)
        XCTAssertNotNil(store.guidanceReading)
        store.finishDemo()
    }

    func testIllegalIntentDoesNotMoveTheSession() {
        let store = DemoSessionStore()
        store.startRetake()
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertTrue(store.route.isEmpty)
    }
}
