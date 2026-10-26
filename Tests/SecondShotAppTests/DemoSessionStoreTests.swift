import SecondShotCore
import XCTest
@testable import SecondShot

/// The demo store now drives `SessionCoordinator` rather than calling the reducer
/// itself, so these tests check the app-facing surface of the executed path:
/// elapsed time from the injected clock, interruptions ending rather than pausing,
/// and user-facing reasons for adapter faults.
@MainActor
final class DemoSessionStoreTests: XCTestCase {
    /// A store whose ticker will not fire during the test: every assertion is made
    /// after an explicit `tick()` or after an awaited intent, never after a wait.
    private func makeStore(profile: SessionFaultProfile = .none) -> DemoSessionStore {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("SecondShotStore-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: base) }
        let environment = SessionEnvironment.synthetic(
            profile: profile,
            clock: SyntheticSessionClock(),
            root: base
        )
        return DemoSessionStore(environment: environment, tickInterval: 3600)
    }

    private func storeAtSavedReference(profile: SessionFaultProfile = .none) async -> DemoSessionStore {
        let store = makeStore(profile: profile)
        await store.openDemo()
        await store.simulateReference()
        return store
    }

    func testSimulatingReferenceWalksTheProductionPathToASavedReference() async throws {
        let store = await storeAtSavedReference()

        XCTAssertEqual(store.state.phase, .referenceAvailable)
        XCTAssertEqual(store.state.referenceTakeID, TakeID("reference-take-1"))
        XCTAssertTrue(store.hasReference)
        XCTAssertTrue(store.canStartRetake)
        XCTAssertNotNil(store.referenceTrack)
        XCTAssertNotNil(store.retakeTrack)
        XCTAssertNil(store.lastError)
        XCTAssertEqual(store.route, [.reference])
        // The coordinator minted a real operation identity on the way here, and the
        // attempt's record was committed exactly once.
        XCTAssertNil(store.state.token)
        XCTAssertEqual(store.state.generation, 1)
        let records = try await store.environment.storage.records(projectID: SessionEnvironment.projectID)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.completion, .complete)
    }

    func testRetakeJourneyUsesTheCoordinatorAndStopsIntoReview() async throws {
        let store = await storeAtSavedReference()
        await store.startRetake()

        XCTAssertEqual(store.state.phase, .recordingRetake)
        XCTAssertTrue(store.isRecordingRetake)
        XCTAssertEqual(store.route, [.reference, .guidance])
        XCTAssertNotNil(store.guidanceReading)

        await store.stopAndReview()
        XCTAssertEqual(store.state.phase, .reviewing)
        XCTAssertEqual(store.state.retakeTakeID, TakeID("retake-take-3"))
        XCTAssertTrue(store.route.contains(.review))
        XCTAssertNotNil(store.endDeviation)

        await store.finishDemo()
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertTrue(store.route.isEmpty)
    }

    /// Elapsed capture time comes from the injected monotonic clock, not from a
    /// wall-clock delta and not from a fabricated counter.
    func testElapsedTimeComesFromTheInjectedClock() async throws {
        let store = await storeAtSavedReference()
        await store.startRetake()
        XCTAssertEqual(store.state.phase, .recordingRetake)

        store.environment.clock.modelCost(1.5)
        await store.tick()

        XCTAssertEqual(store.elapsed, 1.5, accuracy: 1e-9)
        XCTAssertEqual(store.progress, 0.25, accuracy: 1e-6)

        await store.finishDemo()
    }

    /// The old demo paused a retake when tracking was lost. The production rule is
    /// stricter: the attempt ends, stays incomplete, and never resumes by itself.
    func testTrackingLossEndsTheAttemptInsteadOfPausingIt() async throws {
        let store = await storeAtSavedReference()
        await store.startRetake()

        await store.interruptTracking()
        XCTAssertEqual(store.state.phase, .interrupted)
        XCTAssertEqual(store.state.interruption, .trackingLost)
        XCTAssertEqual(store.state.diagnosticCode, "tracking-unavailable")
        XCTAssertTrue(store.isTrackingLost)
        XCTAssertNil(store.guidanceReading)
        XCTAssertNil(store.state.retakeTakeID)
        XCTAssertTrue(store.state.hasReference)
        XCTAssertFalse(store.isRecordingRetake)
        XCTAssertFalse(store.state.phase.isReviewable)

        // The ended retake is preserved as incomplete, so nothing presents it as a
        // finished recording.
        let records = try await store.environment.storage.records(projectID: SessionEnvironment.projectID)
        XCTAssertEqual(records.map(\.completion), [.complete, .incomplete])

        // Recovery returns to the saved reference, and a fresh attempt is explicit.
        await store.resumeTracking()
        XCTAssertEqual(store.state.phase, .referenceAvailable)
        XCTAssertFalse(store.isTrackingLost)
        await store.startRetake()
        XCTAssertEqual(store.state.phase, .recordingRetake)
        XCTAssertNotNil(store.guidanceReading)
        await store.finishDemo()
    }

    func testDiscardingAnInterruptedAttemptKeepsTheReference() async throws {
        let store = await storeAtSavedReference()
        await store.startRetake()
        await store.interruptTracking()

        await store.discardAttempt()
        XCTAssertEqual(store.state.phase, .referenceAvailable)
        XCTAssertEqual(store.state.referenceTakeID, TakeID("reference-take-1"))
        XCTAssertEqual(store.route, [.reference])
        XCTAssertFalse(store.isTrackingLost)
        await store.finishDemo()
    }

    func testStartingARetakeWithoutAReferenceDoesNothing() async throws {
        let store = makeStore()
        await store.startRetake()
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertTrue(store.route.isEmpty)

        await store.simulateReference()
        XCTAssertEqual(store.state.phase, .referenceAvailable)
        await store.finishDemo()
    }

    /// A refused permission is explained in the user's words and never becomes a
    /// saved reference or a user-facing crash.
    func testADeniedCameraIsExplainedAndLeavesNoReference() async throws {
        let store = await storeAtSavedReference(profile: .permissionDenied)

        XCTAssertEqual(store.state.phase, .interrupted)
        XCTAssertEqual(store.state.interruption, .cameraDenied)
        XCTAssertFalse(store.hasReference)
        XCTAssertNil(store.referenceTrack)

        let reason = try XCTUnwrap(store.lastError)
        XCTAssertTrue(
            reason.contains("Camera access"),
            "the reason should be written for a person, not a raw code: \(reason)"
        )
        let records = try await store.environment.storage.records(projectID: SessionEnvironment.projectID)
        XCTAssertTrue(records.isEmpty)
        let writers = await store.environment.media.openWriterCount()
        XCTAssertEqual(writers, 0)
    }

    /// A preparation failure reports its content-free diagnostic code and a retry
    /// is an explicit user action.
    func testAPreparationFailureIsReportedAndCanBeRetried() async throws {
        let store = makeStore(profile: .preparationFailure)
        await store.openDemo()
        await store.simulateReference()

        XCTAssertEqual(store.state.phase, .failed)
        XCTAssertEqual(store.state.diagnosticCode, "capture-prepare-unavailable")
        let reason = try XCTUnwrap(store.lastError)
        XCTAssertTrue(reason.contains("capture-prepare-unavailable"), "reported reason was: \(reason)")

        // Same button, deliberate retry: the adapter's one-shot failure is over.
        await store.simulateReference()
        XCTAssertEqual(store.state.phase, .referenceAvailable)
        XCTAssertNil(store.lastError)
        await store.finishDemo()
    }

    func testAWriterFailureNeverBecomesASavedReference() async throws {
        for profile in [SessionFaultProfile.writerCreationFailure, .writerFinalizeFailure] {
            let store = await storeAtSavedReference(profile: profile)

            XCTAssertEqual(store.state.phase, .failed, "profile \(profile.rawValue)")
            XCTAssertFalse(store.hasReference, "profile \(profile.rawValue)")
            XCTAssertNotNil(store.lastError)

            let writers = await store.environment.media.openWriterCount()
            XCTAssertEqual(writers, 0, "profile \(profile.rawValue) left a writer open")
            let records = try await store.environment.storage.records(projectID: SessionEnvironment.projectID)
            XCTAssertFalse(
                records.contains { $0.completion == .complete },
                "profile \(profile.rawValue) published a take that failed"
            )
        }
    }
}
