import XCTest
import SecondShotCore

final class SessionStateMachineTests: XCTestCase {
    private let savedReference = TakeID("reference-take")
    private let savedRetake = TakeID("retake-take")
    private let project = ProjectID("project-a")
    private let otherProject = ProjectID("project-b")

    /// The reducer mints identities as `<kind>-<generation>`; the tests assert
    /// against that documented shape rather than against a hidden counter.
    private func token(_ operation: String, _ generation: Int) -> OperationToken {
        OperationToken(operationID: OperationID("\(operation)-\(generation)"), generation: generation)
    }

    /// Walk the production path up to a saved reference and return the state.
    private func statesThroughReference() throws -> SessionState {
        var state = SessionState.initial
        state = try SessionReducer.reduce(state, intent: .beginSetup).state
        XCTAssertEqual(state.phase, .requestingPermission)
        state = try SessionReducer.reduce(state, event: .permissionsResolved(granted: true, code: nil)).state
        XCTAssertEqual(state.phase, .preparing)
        state = try SessionReducer.reduce(state, event: .capturePrepared).state
        XCTAssertEqual(state.phase, .ready)

        var transition = try SessionReducer.reduce(state, intent: .beginReference)
        XCTAssertEqual(transition.state.phase, .recordingReference)
        XCTAssertEqual(transition.effects, [.startReferenceCapture(token: token("reference", 1))])
        state = transition.state

        transition = try SessionReducer.reduce(state, intent: .stopReference)
        XCTAssertEqual(transition.state.phase, .finalizingReference)
        XCTAssertEqual(transition.effects, [.stopReferenceCapture(token: token("reference", 1))])
        state = transition.state

        transition = try SessionReducer.reduce(
            state,
            event: .referenceSaved(takeID: savedReference, token: token("reference", 1))
        )
        XCTAssertEqual(transition.state.phase, .referenceAvailable)
        XCTAssertEqual(transition.state.referenceTakeID, savedReference)
        XCTAssertNil(transition.state.token)
        return transition.state
    }

    // MARK: - Happy path

    func testHappyPathWalksPermissionPreparationReferenceRelocalizationRetakeReviewAndExport() throws {
        var state = try statesThroughReference()

        var transition = try SessionReducer.reduce(state, intent: .prepareRetake)
        XCTAssertEqual(transition.state.phase, .relocalizing)
        XCTAssertEqual(transition.effects, [.beginRelocalization(token: token("relocalize", 2))])
        state = transition.state

        transition = try SessionReducer.reduce(state, event: .relocalized(token: token("relocalize", 2)))
        XCTAssertEqual(transition.state.phase, .guiding)
        XCTAssertEqual(transition.effects, [.startGuidance(referenceTakeID: savedReference)])
        state = transition.state

        transition = try SessionReducer.reduce(state, intent: .startRetake)
        XCTAssertEqual(transition.state.phase, .recordingRetake)
        XCTAssertEqual(transition.effects, [.startRetakeCapture(token: token("retake", 3))])
        state = transition.state

        transition = try SessionReducer.reduce(state, intent: .stopRetake)
        XCTAssertEqual(transition.state.phase, .finalizingRetake)
        state = transition.state

        transition = try SessionReducer.reduce(
            state,
            event: .retakeSaved(takeID: savedRetake, token: token("retake", 3))
        )
        XCTAssertEqual(transition.state.phase, .reviewing)
        XCTAssertEqual(transition.state.retakeTakeID, savedRetake)
        XCTAssertEqual(transition.effects, [.stopGuidance])
        state = transition.state

        transition = try SessionReducer.reduce(state, intent: .beginExport)
        XCTAssertEqual(transition.state.phase, .exporting)
        XCTAssertEqual(
            transition.effects,
            [.beginExport(token: token("export", 4), takeID: savedRetake)]
        )
        state = SessionState(
            phase: transition.state.phase,
            projectID: project,
            referenceTakeID: savedReference,
            retakeTakeID: savedRetake,
            token: transition.state.token,
            generation: transition.state.generation
        )

        transition = try SessionReducer.reduce(
            state,
            event: .exportFinished(projectID: project, takeID: savedRetake, token: token("export", 4))
        )
        XCTAssertEqual(transition.state.phase, .reviewing)
        XCTAssertEqual(transition.state.exportedTakeID, savedRetake)
        XCTAssertNil(transition.state.token)
        state = transition.state

        transition = try SessionReducer.reduce(state, intent: .closeReview)
        XCTAssertEqual(transition.state.phase, .referenceAvailable)
        XCTAssertTrue(transition.state.hasReference)
        XCTAssertEqual(transition.effects, [.stopGuidance])
    }

    func testIdempotentRepeatsDoNotIssueADuplicateCommand() throws {
        let repeats: [(SessionState, SessionIntent)] = [
            (SessionState(phase: .finalizingReference, token: token("reference", 1)), .stopReference),
            (SessionState(phase: .finalizingRetake, token: token("retake", 1)), .stopRetake),
            (
                SessionState(phase: .relocalizing, referenceTakeID: savedReference, token: token("relocalize", 1)),
                .prepareRetake
            ),
            (SessionState(phase: .exporting, token: token("export", 1)), .beginExport),
            (SessionState(phase: .reviewing, referenceTakeID: savedReference), .openReview)
        ]
        for (state, intent) in repeats {
            let transition = try SessionReducer.reduce(state, intent: intent)
            XCTAssertEqual(transition.state, state, "\(intent) must not move the session")
            XCTAssertTrue(transition.effects.isEmpty, "\(intent) must not repeat side effects")
        }
    }

    func testIllegalTransitionsAreRejected() {
        XCTAssertThrowsError(try SessionReducer.reduce(.initial, intent: .stopReference)) { error in
            XCTAssertEqual(
                error as? SessionError,
                .illegalTransition(from: .idle, intent: "stopReference")
            )
        }
        // Double tap while recording is rejected instead of starting twice.
        let recording = SessionState(phase: .recordingReference, token: token("reference", 1))
        XCTAssertThrowsError(try SessionReducer.reduce(recording, intent: .beginReference))
        XCTAssertThrowsError(try SessionReducer.reduce(recording, intent: .resume))
        XCTAssertThrowsError(try SessionReducer.reduce(.initial, intent: .prepareRetake))
        // Review and export are unreachable before a reference exists.
        XCTAssertThrowsError(try SessionReducer.reduce(SessionState(phase: .ready), intent: .prepareRetake))
        XCTAssertThrowsError(try SessionReducer.reduce(SessionState(phase: .reviewing), intent: .beginExport))
    }

    // MARK: - Permission, preparation and failure

    func testPermissionDenialIsRecoverableAndDoesNotClaimSuccess() throws {
        let requesting = try SessionReducer.reduce(.initial, intent: .beginSetup).state
        let denied = try SessionReducer.reduce(
            requesting,
            event: .permissionsResolved(granted: false, code: "camera-denied")
        )
        XCTAssertEqual(denied.state.phase, .interrupted)
        XCTAssertEqual(denied.state.interruption, .cameraDenied)
        XCTAssertEqual(denied.state.diagnosticCode, "camera-denied")
        XCTAssertFalse(denied.state.hasReference)
        XCTAssertEqual(denied.effects, [.stopSensors])

        // Asking again is explicit, and returns to the permission step rather than
        // retrying a capture nobody approved.
        let retry = try SessionReducer.reduce(denied.state, intent: .resume)
        XCTAssertEqual(retry.state.phase, .requestingPermission)
        XCTAssertEqual(retry.effects, [.requestCapturePermission])
    }

    func testPreparationFailureEndsFailedWithAContentFreeCode() throws {
        let preparing = try SessionReducer.reduce(
            try SessionReducer.reduce(.initial, intent: .beginSetup).state,
            event: .permissionsResolved(granted: true, code: nil)
        ).state
        let failed = try SessionReducer.reduce(preparing, event: .preparationFailed(code: "format-2"))
        XCTAssertEqual(failed.state.phase, .failed)
        XCTAssertEqual(failed.state.diagnosticCode, "format-2")
        XCTAssertEqual(failed.effects, [.releaseCapturePreparation, .stopSensors])

        let retried = try SessionReducer.reduce(failed.state, intent: .retry)
        XCTAssertEqual(retried.state.phase, .preparing)
        XCTAssertEqual(retried.effects, [.stopSensors, .prepareCapture])
        XCTAssertNil(retried.state.diagnosticCode)
    }

    func testWriterFailureIsNotSuccess() throws {
        let finalizing = try SessionReducer.reduce(
            SessionState(phase: .recordingReference, token: token("reference", 1), generation: 1),
            intent: .stopReference
        ).state
        let failed = try SessionReducer.reduce(
            finalizing,
            event: .referenceFailed(code: "writer-3", token: token("reference", 1))
        )
        XCTAssertEqual(failed.state.phase, .failed)
        XCTAssertNil(failed.state.referenceTakeID)
        XCTAssertFalse(failed.state.hasReference)
        XCTAssertNil(failed.state.token)
    }

    /// A writer that cannot even be created is a different failure from one that
    /// fails while finalizing, and it must end the attempt with the incomplete
    /// media preserved exactly once.
    func testWriterCreationFailureStopsCaptureAndPreservesTheIncompleteTake() throws {
        let recording = SessionState(phase: .recordingReference, token: token("reference", 1), generation: 1)
        let failed = try SessionReducer.reduce(
            recording,
            event: .captureFailed(code: "writer-create-4", token: token("reference", 1))
        )
        XCTAssertEqual(failed.state.phase, .failed)
        XCTAssertEqual(failed.state.diagnosticCode, "writer-create-4")
        XCTAssertNil(failed.state.referenceTakeID)
        XCTAssertNil(failed.state.token)
        XCTAssertEqual(
            failed.effects,
            [
                .stopReferenceCapture(token: token("reference", 1)),
                .preserveIncompleteTake(takeID: nil),
                .stopSensors
            ]
        )
    }

    func testWriterCreationFailureDuringARetakeKeepsTheReferenceAndTheComingTake() throws {
        let recording = SessionState(
            phase: .recordingRetake,
            referenceTakeID: savedReference,
            token: token("retake", 3),
            generation: 3
        )
        let failed = try SessionReducer.reduce(
            recording,
            event: .captureFailed(code: "writer-create-5", token: token("retake", 3))
        )
        XCTAssertEqual(failed.state.phase, .failed)
        XCTAssertEqual(failed.state.referenceTakeID, savedReference)
        XCTAssertNil(failed.state.retakeTakeID)
        XCTAssertEqual(
            failed.effects,
            [
                .stopRetakeCapture(token: token("retake", 3)),
                .preserveIncompleteTake(takeID: savedReference),
                .stopSensors
            ]
        )
        // A retry returns to the saved reference; it never resumes the failed take.
        let retried = try SessionReducer.reduce(failed.state, intent: .retry)
        XCTAssertEqual(retried.state.phase, .referenceAvailable)
        XCTAssertNil(retried.state.interruption)
        XCTAssertNil(retried.state.diagnosticCode)
    }

    func testACaptureFailureCarryingAnOlderGenerationIsRefusedAsStale() throws {
        let recording = SessionState(phase: .recordingReference, token: token("reference", 2), generation: 2)
        XCTAssertThrowsError(
            try SessionReducer.reduce(
                recording,
                event: .captureFailed(code: "writer-create-1", token: token("reference", 1))
            )
        ) { error in
            XCTAssertEqual(
                error as? SessionError,
                .staleOperation(expected: self.token("reference", 2), received: self.token("reference", 1))
            )
        }
    }

    // MARK: - Stale results and operation identity

    func testStaleWriterResultCannotPublishIntoANewerAttempt() throws {
        // A first attempt is cancelled while the writer is still finalizing.
        var state = SessionState(phase: .recordingReference, token: token("reference", 1), generation: 1)
        let firstToken = try XCTUnwrap(state.token)
        state = try SessionReducer.reduce(state, intent: .stopReference).state
        let cancelled = try SessionReducer.reduce(state, intent: .cancel)
        XCTAssertEqual(cancelled.state.phase, .idle)
        XCTAssertNil(cancelled.state.token)
        XCTAssertEqual(cancelled.effects, [.discardReferenceCapture(takeID: nil), .stopSensors])
        XCTAssertGreaterThan(cancelled.state.generation, firstToken.generation)

        // A later result that arrives in the wrong phase is refused outright.
        XCTAssertThrowsError(
            try SessionReducer.reduce(
                cancelled.state,
                event: .referenceSaved(takeID: savedReference, token: firstToken)
            )
        ) { error in
            guard case let .illegalEvent(from, _) = error as? SessionError else {
                return XCTFail("expected an illegal-event refusal, got \(error)")
            }
            XCTAssertEqual(from, .idle)
        }

        // A second attempt finishes: the first attempt's token no longer matches,
        // so its late completion is refused as stale instead of publishing.
        var secondAttempt = try SessionReducer.reduce(
            SessionState(phase: .ready, token: nil, generation: cancelled.state.generation),
            intent: .beginReference
        ).state
        let secondToken = try XCTUnwrap(secondAttempt.token)
        XCTAssertNotEqual(secondToken, firstToken)
        secondAttempt = try SessionReducer.reduce(secondAttempt, intent: .stopReference).state

        XCTAssertThrowsError(
            try SessionReducer.reduce(
                secondAttempt,
                event: .referenceSaved(takeID: savedReference, token: firstToken)
            )
        ) { error in
            XCTAssertEqual(
                error as? SessionError,
                .staleOperation(expected: secondToken, received: firstToken)
            )
        }
        XCTAssertNil(secondAttempt.referenceTakeID)

        // The matching result still settles the take.
        let settled = try SessionReducer.reduce(
            secondAttempt,
            event: .referenceSaved(takeID: savedReference, token: secondToken)
        ).state
        XCTAssertEqual(settled.phase, .referenceAvailable)
        XCTAssertEqual(settled.referenceTakeID, savedReference)
    }

    func testResultFromAPreviousGenerationIsRejected() throws {
        let relocalizing = try SessionReducer.reduce(try statesThroughReference(), intent: .prepareRetake).state
        let stale = OperationToken(operationID: OperationID("relocalize-0"), generation: 0)
        XCTAssertThrowsError(try SessionReducer.reduce(relocalizing, event: .relocalized(token: stale))) { error in
            guard let sessionError = error as? SessionError else { return XCTFail("wrong error type") }
            XCTAssertEqual(
                sessionError,
                .staleOperation(expected: relocalizing.token, received: stale)
            )
        }
    }

    func testExportFromAnotherProjectCannotAdvanceThisScreen() throws {
        var state = SessionState(
            phase: .exporting,
            projectID: project,
            referenceTakeID: savedReference,
            retakeTakeID: savedRetake,
            token: token("export", 1),
            generation: 1
        )
        XCTAssertThrowsError(
            try SessionReducer.reduce(
                state,
                event: .exportFinished(projectID: otherProject, takeID: savedRetake, token: token("export", 1))
            )
        ) { error in
            XCTAssertEqual(
                error as? SessionError,
                .foreignProject(expected: self.project, received: self.otherProject)
            )
        }

        // A mismatched operation is rejected before the project is even considered.
        XCTAssertThrowsError(
            try SessionReducer.reduce(
                state,
                event: .exportFinished(projectID: project, takeID: savedRetake, token: token("export", 9))
            )
        ) { error in
            guard case .staleOperation = error as? SessionError else {
                return XCTFail("expected a stale-operation error, got \(error)")
            }
        }

        // Only the matching result settles the export.
        state = try SessionReducer.reduce(
            state,
            event: .exportFinished(projectID: project, takeID: savedRetake, token: token("export", 1))
        ).state
        XCTAssertEqual(state.phase, .reviewing)
        XCTAssertEqual(state.exportedTakeID, savedRetake)
    }

    func testExportFailureReturnsToReviewWithADiagnostic() throws {
        let exporting = SessionState(
            phase: .exporting,
            projectID: project,
            referenceTakeID: savedReference,
            retakeTakeID: savedRetake,
            token: token("export", 1),
            generation: 1
        )
        let failed = try SessionReducer.reduce(
            exporting,
            event: .exportFailed(code: "export-7", token: token("export", 1))
        )
        XCTAssertEqual(failed.state.phase, .reviewing)
        XCTAssertEqual(failed.state.diagnosticCode, "export-7")
        XCTAssertNil(failed.state.exportedTakeID)
        XCTAssertTrue(failed.state.hasRetake, "a failed export must not discard the take")
    }

    // MARK: - Interruption and recovery

    func testTrackingLossDuringRetakeEndsTheTakeInsteadOfPausingIt() throws {
        let recording = SessionState(
            phase: .recordingRetake,
            projectID: project,
            referenceTakeID: savedReference,
            token: token("retake", 3),
            generation: 3
        )
        let interrupted = try SessionReducer.reduce(recording, event: .trackingChanged(.unavailable))
        XCTAssertEqual(interrupted.state.phase, .interrupted)
        XCTAssertEqual(interrupted.state.interruption, .trackingLost)
        XCTAssertEqual(interrupted.state.diagnosticCode, "tracking-unavailable")
        XCTAssertNil(interrupted.state.token)
        XCTAssertNil(interrupted.state.retakeTakeID, "an incomplete attempt is not a saved take")
        XCTAssertTrue(interrupted.state.hasReference, "the reference survives")
        XCTAssertEqual(
            interrupted.effects,
            [.stopRetakeCapture(token: token("retake", 3)), .preserveIncompleteTake(takeID: savedReference), .stopSensors]
        )

        // Healthy tracking reports never resume by themselves.
        let stillInterrupted = try SessionReducer.reduce(interrupted.state, event: .trackingChanged(.normal))
        XCTAssertEqual(stillInterrupted.state, interrupted.state)
        XCTAssertTrue(stillInterrupted.effects.isEmpty)

        // Recovery is deliberate and returns to the saved reference, not into a
        // half-finished recording.
        let recovered = try SessionReducer.reduce(interrupted.state, intent: .resume)
        XCTAssertEqual(recovered.state.phase, .referenceAvailable)
        XCTAssertEqual(recovered.effects, [.stopSensors])
    }

    func testEveryInterruptiblePhaseStopsItsOwnWorkAndNothingElse() throws {
        let cases: [(SessionState, [SessionEffect])] = [
            (
                SessionState(phase: .requestingPermission),
                [.stopSensors]
            ),
            (
                SessionState(phase: .preparing),
                [.releaseCapturePreparation, .stopSensors]
            ),
            (
                SessionState(phase: .recordingReference, token: token("reference", 1)),
                [.stopReferenceCapture(token: token("reference", 1)), .preserveIncompleteTake(takeID: nil), .stopSensors]
            ),
            (
                SessionState(phase: .finalizingReference, token: token("reference", 1)),
                [.preserveIncompleteTake(takeID: nil), .stopSensors]
            ),
            (
                SessionState(phase: .relocalizing, referenceTakeID: savedReference, token: token("relocalize", 2)),
                [.cancelRelocalization(token: token("relocalize", 2)), .stopSensors]
            ),
            (
                SessionState(phase: .guiding, referenceTakeID: savedReference),
                [.stopGuidance, .stopSensors]
            ),
            (
                SessionState(phase: .reviewing, referenceTakeID: savedReference, retakeTakeID: savedRetake),
                [.stopGuidance, .stopSensors]
            ),
            (
                SessionState(phase: .exporting, retakeTakeID: savedRetake, token: token("export", 4)),
                [.cancelExport(token: token("export", 4)), .preserveIncompleteTake(takeID: nil), .stopSensors]
            )
        ]

        for (state, expected) in cases {
            let reason: InterruptionReason = state.phase == .exporting ? .appBackgrounded : .deviceLocked
            let transition = try SessionReducer.reduce(state, intent: .interrupt(reason))
            XCTAssertEqual(transition.state.phase, .interrupted, "\(state.phase)")
            XCTAssertEqual(transition.state.interruption, reason, "\(state.phase)")
            XCTAssertNil(transition.state.token, "\(state.phase): abandoned work keeps no identity")
            XCTAssertEqual(transition.effects, expected, "\(state.phase)")
        }
    }

    func testInterruptionWithoutAReferenceRequiresPreparationAgain() throws {
        let requesting = try SessionReducer.reduce(.initial, intent: .beginSetup).state
        let interruptedState = try SessionReducer.reduce(
            requesting,
            intent: .interrupt(.appBackgrounded)
        ).state
        XCTAssertEqual(interruptedState.phase, .interrupted)
        XCTAssertEqual(interruptedState.interruption, .appBackgrounded)

        let resumed = try SessionReducer.reduce(interruptedState, intent: .resume)
        XCTAssertEqual(resumed.state.phase, .preparing)
        XCTAssertNil(resumed.state.interruption)
        XCTAssertEqual(resumed.effects, [.stopSensors, .prepareCapture])
    }

    func testRelocalizationFailureIsInterruptedRatherThanGuided() throws {
        let relocalizing = try SessionReducer.reduce(try statesThroughReference(), intent: .prepareRetake).state
        let failed = try SessionReducer.reduce(
            relocalizing,
            event: .relocalizationFailed(reason: .sceneNotRecognized, token: try XCTUnwrap(relocalizing.token))
        )
        XCTAssertEqual(failed.state.phase, .interrupted)
        XCTAssertEqual(failed.state.interruption, .sceneNotRecognized)
        XCTAssertEqual(failed.state.diagnosticCode, "relocalize-sceneNotRecognized")
        XCTAssertNil(failed.state.token)
    }

    func testIdleCannotBeInterrupted() {
        XCTAssertThrowsError(try SessionReducer.reduce(.initial, intent: .interrupt(.trackingLost)))
        XCTAssertThrowsError(
            try SessionReducer.reduce(SessionState(phase: .referenceAvailable), intent: .interrupt(.deviceLocked))
        )
    }

    // MARK: - Cancellation

    func testCancelBeforeAndAfterWriterFinalizationBothDiscardTheTake() throws {
        let recording = SessionState(
            phase: .recordingReference,
            token: token("reference", 1),
            generation: 1
        )
        let cancelledWhileRecording = try SessionReducer.reduce(recording, intent: .cancel)
        XCTAssertEqual(cancelledWhileRecording.state.phase, .idle)
        XCTAssertEqual(
            cancelledWhileRecording.effects,
            [.stopReferenceCapture(token: token("reference", 1)), .discardReferenceCapture(takeID: nil), .stopSensors]
        )

        let finalizing = try SessionReducer.reduce(recording, intent: .stopReference).state
        let cancelledWhileFinalizing = try SessionReducer.reduce(finalizing, intent: .cancel)
        XCTAssertEqual(cancelledWhileFinalizing.state.phase, .idle)
        XCTAssertEqual(
            cancelledWhileFinalizing.effects,
            [.discardReferenceCapture(takeID: nil), .stopSensors]
        )
        XCTAssertNil(cancelledWhileFinalizing.state.token)
    }

    func testCancelDuringRetakeOrGuidanceKeepsTheReference() throws {
        let recordingRetake = SessionState(
            phase: .recordingRetake,
            referenceTakeID: savedReference,
            token: token("retake", 3),
            generation: 3
        )
        let cancelled = try SessionReducer.reduce(recordingRetake, intent: .cancel)
        XCTAssertEqual(cancelled.state.phase, .referenceAvailable)
        XCTAssertEqual(cancelled.state.referenceTakeID, savedReference)
        XCTAssertNil(cancelled.state.retakeTakeID)
        XCTAssertEqual(
            cancelled.effects,
            [.stopRetakeCapture(token: token("retake", 3)), .discardRetakeCapture(takeID: nil), .stopSensors]
        )

        let guiding = SessionState(phase: .guiding, referenceTakeID: savedReference)
        let guidanceCancelled = try SessionReducer.reduce(guiding, intent: .cancel)
        XCTAssertEqual(guidanceCancelled.state.phase, .referenceAvailable)
        XCTAssertEqual(guidanceCancelled.effects, [.stopGuidance, .stopSensors])
    }

    func testCancelDuringExportReturnsToTheIntactReview() throws {
        let exporting = SessionState(
            phase: .exporting,
            projectID: project,
            referenceTakeID: savedReference,
            retakeTakeID: savedRetake,
            token: token("export", 4),
            generation: 4
        )
        let cancelled = try SessionReducer.reduce(exporting, intent: .cancelExport)
        XCTAssertEqual(cancelled.state.phase, .reviewing)
        XCTAssertTrue(cancelled.state.hasRetake)
        XCTAssertNil(cancelled.state.token)
        XCTAssertEqual(cancelled.effects, [.cancelExport(token: token("export", 4))])
    }

    // MARK: - Out-of-order callbacks

    func testOutOfOrderCallbacksAreRejected() {
        XCTAssertThrowsError(
            try SessionReducer.reduce(.initial, event: .referenceSaved(takeID: savedReference, token: token("reference", 1)))
        ) { error in
            guard case let .illegalEvent(from, _) = error as? SessionError else {
                return XCTFail("Expected an illegal-event error, got \(error)")
            }
            XCTAssertEqual(from, .idle)
        }
        XCTAssertThrowsError(
            try SessionReducer.reduce(
                SessionState(phase: .ready, token: token("reference", 1)),
                event: .referenceSaved(takeID: savedReference, token: token("reference", 1))
            )
        )
        XCTAssertThrowsError(try SessionReducer.reduce(SessionState(phase: .ready), event: .capturePrepared))
        XCTAssertThrowsError(try SessionReducer.reduce(.initial, event: .permissionsResolved(granted: true, code: nil)))
    }

    func testHealthyTrackingDoesNotChangeState() throws {
        let state = SessionState(phase: .guiding, referenceTakeID: savedReference)
        let transition = try SessionReducer.reduce(state, event: .trackingChanged(.normal))
        XCTAssertEqual(transition.state, state)
        XCTAssertTrue(transition.effects.isEmpty)
    }
}
