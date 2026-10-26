import XCTest
@testable import SecondShotCore

final class SessionStateMachineTests: XCTestCase {
    private let savedReference = TakeID("reference-take")
    private let savedRetake = TakeID("retake-take")

    func testHappyPathReferenceGuidanceRetakeReview() throws {
        var state = SessionState.initial

        var transition = try SessionReducer.reduce(state, intent: .beginReference)
        XCTAssertEqual(transition.state.phase, .recordingReference)
        XCTAssertEqual(transition.effects, [.startReferenceCapture])
        state = transition.state

        transition = try SessionReducer.reduce(state, intent: .stopReference)
        XCTAssertEqual(transition.state.phase, .finishingReference)
        XCTAssertEqual(transition.effects, [.stopReferenceCapture])
        state = transition.state

        transition = try SessionReducer.reduce(state, event: .referenceSaved(savedReference))
        XCTAssertEqual(transition.state.phase, .referenceReady)
        XCTAssertEqual(transition.state.referenceTakeID, savedReference)
        XCTAssertTrue(transition.state.hasReference)
        XCTAssertFalse(transition.state.hasRetake)
        state = transition.state

        transition = try SessionReducer.reduce(state, intent: .prepareRetake)
        XCTAssertEqual(transition.state.phase, .guiding)
        XCTAssertEqual(transition.effects, [.startGuidance])
        state = transition.state

        transition = try SessionReducer.reduce(state, intent: .startRetake)
        XCTAssertEqual(transition.state.phase, .recordingRetake)
        XCTAssertEqual(transition.effects, [.startRetakeCapture])
        state = transition.state

        transition = try SessionReducer.reduce(state, intent: .stopRetake)
        XCTAssertEqual(transition.state.phase, .finishingRetake)
        state = transition.state

        transition = try SessionReducer.reduce(state, event: .retakeSaved(savedRetake))
        XCTAssertEqual(transition.state.phase, .reviewing)
        XCTAssertEqual(transition.state.retakeTakeID, savedRetake)
        state = transition.state

        transition = try SessionReducer.reduce(state, intent: .closeReview)
        XCTAssertEqual(transition.state.phase, .referenceReady)
        XCTAssertTrue(transition.state.hasReference)
        XCTAssertEqual(transition.effects, [.stopGuidance])
    }

    func testRepeatedStopIsIdempotent() throws {
        let state = SessionState(phase: .finishingReference)
        let first = try SessionReducer.reduce(state, intent: .stopReference)
        let second = try SessionReducer.reduce(state, intent: .stopReference)
        XCTAssertEqual(first.state, state)
        XCTAssertTrue(first.effects.isEmpty)
        XCTAssertEqual(second, first)
    }

    func testIllegalTransitionsAreRejected() {
        XCTAssertThrowsError(try SessionReducer.reduce(.initial, intent: .stopReference)) { error in
            XCTAssertEqual(
                error as? SessionError,
                .illegalTransition(from: .idle, intent: "stopReference")
            )
        }
        // Double tap on record is rejected rather than starting twice.
        let recording = SessionState(phase: .recordingReference)
        XCTAssertThrowsError(try SessionReducer.reduce(recording, intent: .beginReference))
        XCTAssertThrowsError(try SessionReducer.reduce(recording, intent: .resume))
        XCTAssertThrowsError(try SessionReducer.reduce(.initial, intent: .prepareRetake))
    }

    func testPreparingARetakeNeedsAReference() {
        let inconsistent = SessionState(phase: .referenceReady)
        XCTAssertThrowsError(try SessionReducer.reduce(inconsistent, intent: .prepareRetake)) { error in
            XCTAssertEqual(error as? SessionError, .missingReference)
        }
    }

    func testOutOfOrderCallbacksAreRejected() {
        XCTAssertThrowsError(
            try SessionReducer.reduce(.initial, event: .referenceSaved(savedReference))
        ) { error in
            guard case let .illegalEvent(from, _) = error as? SessionError else {
                return XCTFail("Expected an illegal-event error, got \(error)")
            }
            XCTAssertEqual(from, .idle)
        }
        XCTAssertThrowsError(
            try SessionReducer.reduce(SessionState(phase: .finishingReference), event: .retakeSaved(savedRetake))
        )
    }

    func testInterruptionDuringGuidanceStopsGuidanceAndSensors() throws {
        let state = SessionState(phase: .guiding, referenceTakeID: savedReference)
        let transition = try SessionReducer.reduce(state, intent: .interrupt(.appBackgrounded))
        XCTAssertEqual(transition.state.phase, .interrupted)
        XCTAssertEqual(transition.state.interruption, .appBackgrounded)
        XCTAssertEqual(transition.effects, [.stopGuidance, .stopSensors])

        // Recovery is deliberate and never auto-resumes.
        let resumed = try SessionReducer.reduce(transition.state, event: .trackingChanged(.normal))
        XCTAssertEqual(resumed.state, transition.state)
        XCTAssertTrue(resumed.effects.isEmpty)
    }

    func testInterruptionDuringRecordingPreservesIncompleteTake() throws {
        let state = SessionState(phase: .recordingReference)
        let transition = try SessionReducer.reduce(state, intent: .interrupt(.storageLow))
        XCTAssertEqual(transition.state.phase, .interrupted)
        XCTAssertEqual(transition.state.interruption, .storageLow)
        XCTAssertEqual(transition.effects, [.stopReferenceCapture, .preserveIncompleteTake, .stopSensors])
    }

    func testTrackingLossWhileRecordingIsAnInterruption() throws {
        let state = SessionState(phase: .recordingRetake, referenceTakeID: savedReference)
        let transition = try SessionReducer.reduce(state, event: .trackingChanged(.unavailable))
        XCTAssertEqual(transition.state.phase, .interrupted)
        XCTAssertEqual(transition.state.interruption, .trackingLost)
        XCTAssertEqual(transition.state.diagnosticCode, "tracking-unavailable")
        XCTAssertEqual(transition.effects, [.stopRetakeCapture, .preserveIncompleteTake, .stopSensors])
    }

    func testHealthyTrackingDoesNotChangeState() throws {
        let state = SessionState(phase: .guiding, referenceTakeID: savedReference)
        let transition = try SessionReducer.reduce(state, event: .trackingChanged(.normal))
        XCTAssertEqual(transition.state, state)
        XCTAssertTrue(transition.effects.isEmpty)
    }

    func testResumeRequiresDeliberateActionAndReturnsToAValidState() throws {
        let withReference = SessionState(
            phase: .interrupted,
            referenceTakeID: savedReference,
            interruption: .trackingLost
        )
        let resumed = try SessionReducer.reduce(withReference, intent: .resume)
        XCTAssertEqual(resumed.state.phase, .referenceReady)
        XCTAssertNil(resumed.state.interruption)

        let withoutReference = SessionState(phase: .interrupted, interruption: .cameraDenied)
        let reset = try SessionReducer.reduce(withoutReference, intent: .resume)
        XCTAssertEqual(reset.state.phase, .idle)
    }

    func testCancelDuringRecordingDiscardsOnlyThatTake() throws {
        let state = SessionState(phase: .recordingReference)
        let transition = try SessionReducer.reduce(state, intent: .cancel)
        XCTAssertEqual(transition.state.phase, .idle)
        XCTAssertEqual(
            transition.effects,
            [.stopReferenceCapture, .discardReferenceCapture, .stopSensors]
        )

        let retake = SessionState(phase: .recordingRetake, referenceTakeID: savedReference)
        let retakeTransition = try SessionReducer.reduce(retake, intent: .cancel)
        XCTAssertEqual(retakeTransition.state.phase, .referenceReady)
        XCTAssertNil(retakeTransition.state.retakeTakeID)
        XCTAssertEqual(retakeTransition.effects, [.stopRetakeCapture, .discardRetakeCapture])
    }

    func testFailureIsNotSuccess() throws {
        let state = SessionState(phase: .finishingReference)
        let failed = try SessionReducer.reduce(state, event: .referenceFailed(code: "writer-3"))
        XCTAssertEqual(failed.state.phase, .failed)
        XCTAssertEqual(failed.state.diagnosticCode, "writer-3")
        XCTAssertNil(failed.state.referenceTakeID)
        XCTAssertFalse(failed.state.hasReference)

        let retried = try SessionReducer.reduce(failed.state, intent: .retry)
        XCTAssertEqual(retried.state.phase, .idle)
        XCTAssertNil(retried.state.diagnosticCode)
    }

    func testIdleCannotBeInterrupted() {
        XCTAssertThrowsError(try SessionReducer.reduce(.initial, intent: .interrupt(.trackingLost)))
    }
}
