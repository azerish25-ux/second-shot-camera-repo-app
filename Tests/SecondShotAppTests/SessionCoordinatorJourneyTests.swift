import XCTest
import SecondShotCore
@testable import SecondShot

/// Fault journeys for the session adapter.
///
/// These drive the real `SessionCoordinator`, the real storage actor, the real
/// serialized media queue and the real reducer, with synthetic providers for the
/// seams and `SessionHold` for deterministic interleaving. Nothing sleeps, so the
/// interleavings are reproducible and no assertion depends on wall-clock timing.
@MainActor
final class SessionCoordinatorJourneyTests: XCTestCase {
    private var hold: SessionHold!

    // MARK: - Helpers

    private func makeEnvironment(
        profile: SessionFaultProfile = .none,
        exporter: TakeExporting? = nil,
        hold: SessionHold = SessionHold()
    ) -> SessionEnvironment {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("SecondShotJourney-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: base) }
        let clock = SyntheticSessionClock()
        self.hold = hold
        return SessionEnvironment.synthetic(
            profile: profile,
            clock: clock,
            root: base,
            hold: hold,
            exporter: exporter
        )
    }

    /// The reducer mints identities as `<kind>-<generation>`; the tests assert the
    /// documented shape instead of a hidden counter.
    private func token(_ kind: String, _ generation: Int) -> OperationToken {
        OperationToken(operationID: OperationID("\(kind)-\(generation)"), generation: generation)
    }

    /// Walks the production path to a saved reference.
    @discardableResult
    private func savedReference(profile: SessionFaultProfile = .none) async throws -> SessionEnvironment {
        let environment = makeEnvironment(profile: profile)
        await environment.coordinator.send(.beginSetup)
        XCTAssertEqual(environment.coordinator.state.phase, .ready)
        await environment.coordinator.send(.beginReference)
        XCTAssertEqual(environment.coordinator.state.phase, .recordingReference)
        await environment.coordinator.send(.stopReference)
        XCTAssertEqual(environment.coordinator.state.phase, .referenceAvailable)
        return environment
    }

    private func records(_ environment: SessionEnvironment) async throws -> [SessionRecord] {
        try await environment.storage.records(projectID: SessionEnvironment.projectID)
    }

    private func openWriters(_ environment: SessionEnvironment) async -> Int {
        await environment.media.openWriterCount()
    }

    private func mediaFiles(_ environment: SessionEnvironment) async -> Int {
        await environment.capture.mediaFileCount()
    }

    /// The invariant every journey ends with: nothing left open, nothing parked
    /// inside an adapter, and no unexplained transition.
    private func assertClean(_ environment: SessionEnvironment) async {
        let writers = await openWriters(environment)
        let holding = await hold.holdingCount()
        XCTAssertEqual(writers, 0, "a writer was left open")
        XCTAssertEqual(holding, 0, "an adapter is still parked on a hold point")
        XCTAssertEqual(environment.coordinator.unexpectedFailures, [], "an unexplained transition was recorded")
    }

    // MARK: - Happy path

    func testReferenceJourneyExecutesEveryReducersEffectAndCommitsOneCompleteRecord() async throws {
        let environment = makeEnvironment()
        let coordinator = environment.coordinator

        await coordinator.send(.beginSetup)
        XCTAssertEqual(coordinator.state.phase, .ready)
        XCTAssertEqual(coordinator.executedEffects, [.requestCapturePermission, .prepareCapture])

        await coordinator.send(.beginReference)
        // The record exists before any publishable media, so an interrupted
        // finalize leaves something reconcileable rather than a phantom take.
        let duringRecording = try await records(environment)
        XCTAssertEqual(duringRecording.count, 1)
        XCTAssertEqual(duringRecording.first?.completion, .incomplete)
        XCTAssertNil(duringRecording.first?.takeID)
        XCTAssertEqual(duringRecording.first?.kind, .reference)

        await coordinator.send(.stopReference)
        XCTAssertEqual(coordinator.state.phase, .referenceAvailable)
        let takeID = try XCTUnwrap(coordinator.state.referenceTakeID)
        XCTAssertEqual(takeID, TakeID("reference-take-1"))

        let committed = try await records(environment)
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed.first?.completion, .complete)
        XCTAssertEqual(committed.first?.takeID, takeID)

        let entries = await environment.media.entries()
        XCTAssertEqual(entries.map(\.stage), [.writerOpened, .writerFinalized])
        let observed0 = await mediaFiles(environment)
        XCTAssertEqual(observed0, 1)

        XCTAssertEqual(coordinator.executedEffects, [
            .requestCapturePermission,
            .prepareCapture,
            .startReferenceCapture(token: token("reference", 1)),
            .stopReferenceCapture(token: token("reference", 1))
        ])
        XCTAssertEqual(coordinator.droppedReplies, [])
        await assertClean(environment)
    }

    func testRetakeJourneyReachesReviewWithTwoCommittedRecords() async throws {
        let environment = try await savedReference()
        let coordinator = environment.coordinator

        await coordinator.send(.prepareRetake)
        XCTAssertEqual(coordinator.state.phase, .guiding)
        XCTAssertEqual(coordinator.guidanceReferenceTakeID, TakeID("reference-take-1"))

        await coordinator.send(.startRetake)
        XCTAssertEqual(coordinator.state.phase, .recordingRetake)

        await coordinator.send(.stopRetake)
        XCTAssertEqual(coordinator.state.phase, .reviewing)
        XCTAssertEqual(coordinator.state.retakeTakeID, TakeID("retake-take-3"))
        XCTAssertTrue(coordinator.state.phase.isReviewable)

        let committed = try await records(environment)
        XCTAssertEqual(committed.map(\.completion), [.complete, .complete])
        XCTAssertEqual(committed.map(\.kind), [.reference, .retake])
        XCTAssertEqual(committed.map(\.takeID), [TakeID("reference-take-1"), TakeID("retake-take-3")])
        let published = await environment.capture.publishedTakeIDs()
        XCTAssertEqual(published, [TakeID("reference-take-1"), TakeID("retake-take-3")])
        let observed1 = await mediaFiles(environment)
        XCTAssertEqual(observed1, 2)
        await assertClean(environment)
    }

    func testARepeatedStopWhileFinalizingFinalizesTheWriterExactlyOnce() async throws {
        let environment = makeEnvironment()
        let coordinator = environment.coordinator
        await coordinator.send(.beginSetup)
        await coordinator.send(.beginReference)
        await hold.close(.finalize)

        let stop = Task { await coordinator.send(.stopReference) }
        await hold.awaitArrival(of: .finalize)
        XCTAssertEqual(coordinator.state.phase, .finalizingReference)

        // A second stop while the writer is finalizing is idempotent: no second
        // writer command, no second record, no error.
        await coordinator.send(.stopReference)
        XCTAssertEqual(coordinator.state.phase, .finalizingReference)
        XCTAssertEqual(coordinator.unexpectedFailures, [])

        await hold.release(.finalize)
        await stop.value

        XCTAssertEqual(coordinator.state.phase, .referenceAvailable)
        let entries = await environment.media.entries()
        XCTAssertEqual(entries.map(\.stage), [.writerOpened, .writerFinalized])
        let observed2 = try await records(environment).count
        XCTAssertEqual(observed2, 1)
        await assertClean(environment)
    }

    // MARK: - Permission

    func testPermanentCameraDenialStaysInterruptedAndNeverClaimsAReference() async throws {
        let environment = makeEnvironment(profile: .permissionDenied)
        let coordinator = environment.coordinator

        await coordinator.send(.beginSetup)
        XCTAssertEqual(coordinator.state.phase, .interrupted)
        XCTAssertEqual(coordinator.state.interruption, .cameraDenied)
        XCTAssertEqual(coordinator.state.diagnosticCode, "permission-camera-denied")
        XCTAssertFalse(coordinator.state.hasReference)

        // Returning to the foreground re-asks, and the refusal is still honoured.
        await coordinator.applicationBecameActive()
        XCTAssertEqual(coordinator.state.phase, .interrupted)
        XCTAssertFalse(coordinator.state.hasReference)
        XCTAssertNil(coordinator.lastError)

        let committed = try await records(environment)
        XCTAssertTrue(committed.isEmpty)
        let observed3 = await mediaFiles(environment)
        XCTAssertEqual(observed3, 0)
        await assertClean(environment)
    }

    func testDeniedCameraAccessIsRequeriedWhenTheAppReturnsToTheForeground() async throws {
        let environment = makeEnvironment(profile: .permissionDeniedThenGranted)
        let coordinator = environment.coordinator

        await coordinator.send(.beginSetup)
        XCTAssertEqual(coordinator.state.phase, .interrupted)
        XCTAssertEqual(coordinator.state.interruption, .cameraDenied)

        // The user grants access in Settings and comes back. The app re-queries
        // instead of assuming, and nothing starts recording by itself.
        await coordinator.applicationBecameActive()
        XCTAssertEqual(coordinator.state.phase, .ready)
        XCTAssertNil(coordinator.state.interruption)
        XCTAssertNil(coordinator.state.token)

        await coordinator.send(.beginReference)
        await coordinator.send(.stopReference)
        XCTAssertEqual(coordinator.state.phase, .referenceAvailable)
        XCTAssertEqual(coordinator.state.referenceTakeID, TakeID("reference-take-3"))
        let observed4 = try await records(environment).count
        XCTAssertEqual(observed4, 1)
        await assertClean(environment)
    }

    func testTrackingLossWhileRequestingPermissionIsNotDispatched() async throws {
        let environment = makeEnvironment()
        let coordinator = environment.coordinator
        await hold.close(.permission)

        let setup = Task { await coordinator.send(.beginSetup) }
        await hold.awaitArrival(of: .permission)
        XCTAssertEqual(coordinator.state.phase, .requestingPermission)

        // A phase with no tracking behaviour must not turn a report into a defect.
        await coordinator.reportTracking(.unavailable)
        XCTAssertEqual(coordinator.state.phase, .requestingPermission)

        await hold.release(.permission)
        await setup.value
        XCTAssertEqual(coordinator.state.phase, .ready)
        await assertClean(environment)
    }

    // MARK: - Preparation

    func testPreparationFailureIsRecoverableAndReportsAContentFreeCode() async throws {
        let environment = makeEnvironment(profile: .preparationFailure)
        let coordinator = environment.coordinator

        await coordinator.send(.beginSetup)
        XCTAssertEqual(coordinator.state.phase, .failed)
        XCTAssertEqual(coordinator.state.diagnosticCode, "capture-prepare-unavailable")
        XCTAssertFalse(coordinator.state.hasReference)

        // Retry is deliberate and re-prepares; nothing was published by the failure.
        await coordinator.send(.retry)
        XCTAssertEqual(coordinator.state.phase, .ready)
        XCTAssertNil(coordinator.state.diagnosticCode)

        await coordinator.send(.beginReference)
        await coordinator.send(.stopReference)
        XCTAssertEqual(coordinator.state.phase, .referenceAvailable)
        await assertClean(environment)
    }

    func testTrackingLossWhilePreparingIsNotDispatched() async throws {
        let environment = makeEnvironment()
        let coordinator = environment.coordinator
        await hold.close(.prepare)

        let setup = Task { await coordinator.send(.beginSetup) }
        await hold.awaitArrival(of: .prepare)
        XCTAssertEqual(coordinator.state.phase, .preparing)

        await coordinator.reportTracking(.unavailable)
        XCTAssertEqual(coordinator.state.phase, .preparing)

        await hold.release(.prepare)
        await setup.value
        XCTAssertEqual(coordinator.state.phase, .ready)
        await assertClean(environment)
    }

    // MARK: - Writer creation and finalization failures

    func testWriterCreationFailureEndsTheAttemptWithoutPublishingARecord() async throws {
        let environment = makeEnvironment(profile: .writerCreationFailure)
        let coordinator = environment.coordinator
        await coordinator.send(.beginSetup)

        await coordinator.send(.beginReference)
        // The capture could not start, so the attempt ended immediately.
        XCTAssertEqual(coordinator.state.phase, .failed)
        XCTAssertEqual(coordinator.state.diagnosticCode, "writer-create-1")
        XCTAssertFalse(coordinator.state.hasReference)

        let committed = try await records(environment)
        XCTAssertTrue(committed.isEmpty, "a failed writer creation must not leave a record")
        let observed5 = await mediaFiles(environment)
        XCTAssertEqual(observed5, 0)
        XCTAssertTrue(
            coordinator.executedEffects.contains(.startReferenceCapture(token: token("reference", 1))),
            "the reducer's start effect must have been executed"
        )
        await assertClean(environment)
    }

    func testWriterFinalizeFailureLeavesOneIncompleteRecordAndNoOpenWriter() async throws {
        let environment = makeEnvironment(profile: .writerFinalizeFailure)
        let coordinator = environment.coordinator
        await coordinator.send(.beginSetup)
        await coordinator.send(.beginReference)
        await coordinator.send(.stopReference)

        XCTAssertEqual(coordinator.state.phase, .failed)
        XCTAssertEqual(coordinator.state.diagnosticCode, "writer-finalize-2")
        XCTAssertFalse(coordinator.state.hasReference)
        XCTAssertNil(coordinator.state.token)

        // Nothing is published as complete; the incomplete record and the partial
        // media are exactly what launch recovery reconciles.
        let committed = try await records(environment)
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed.first?.completion, .incomplete)
        XCTAssertNil(committed.first?.takeID)

        let entries = await environment.media.entries()
        XCTAssertEqual(entries.map(\.stage), [.writerOpened, .writerFinalizeFailed, .writerDiscarded])
        await assertClean(environment)
    }

    // MARK: - Cancellation

    func testCancellingWhileRecordingLeavesNoWriterNoMediaAndNoRecord() async throws {
        let environment = makeEnvironment()
        let coordinator = environment.coordinator
        await coordinator.send(.beginSetup)
        await coordinator.send(.beginReference)
        XCTAssertEqual(coordinator.state.phase, .recordingReference)

        await coordinator.send(.cancel)

        XCTAssertEqual(coordinator.state.phase, .idle)
        XCTAssertNil(coordinator.state.token)
        let committed = try await records(environment)
        XCTAssertTrue(committed.isEmpty, "a cancelled attempt must not leave a record")
        let observed6 = await mediaFiles(environment)
        XCTAssertEqual(observed6, 0, "a cancelled attempt must not leave media")
        XCTAssertEqual(
            coordinator.droppedReplies,
            [DroppedReply(event: "referenceSaved", reason: .noLongerExpected)]
        )
        await assertClean(environment)
    }

    func testCancellingAfterTheWriterFinalizedLeavesNoRecordAndNoMedia() async throws {
        let environment = makeEnvironment()
        let coordinator = environment.coordinator
        await coordinator.send(.beginSetup)
        await coordinator.send(.beginReference)

        // The writer finalizes and commits its record, and only then is the result
        // held back — the window in which a cancellation arrives too late.
        await hold.close(.finalize)
        let stop = Task { await coordinator.send(.stopReference) }
        await hold.awaitArrival(of: .finalize)
        XCTAssertEqual(coordinator.state.phase, .finalizingReference)
        let committedWhileHeld = try await records(environment)
        XCTAssertEqual(committedWhileHeld.first?.completion, .complete)

        await coordinator.send(.cancel)
        // Cancelling a reference that never published returns to a saved-reference
        // -free state, not to a reference screen that does not exist yet.
        XCTAssertEqual(coordinator.state.phase, .idle)
        XCTAssertNil(coordinator.state.referenceTakeID)

        await hold.release(.finalize)
        await stop.value

        // The late reply is refused, and the take it described is not left behind
        // as an orphaned record or file.
        XCTAssertNil(coordinator.state.referenceTakeID)
        let committed = try await records(environment)
        XCTAssertTrue(committed.isEmpty, "a cancelled take must not survive as a record")
        let observed7 = await mediaFiles(environment)
        XCTAssertEqual(observed7, 0, "a cancelled take must not survive as a file")
        XCTAssertEqual(
            coordinator.droppedReplies,
            [DroppedReply(event: "referenceSaved", reason: .staleToken)]
        )
        await assertClean(environment)
    }

    func testALateReplyForAnEndedAttemptIsIgnoredWhileANewAttemptIsRecording() async throws {
        let environment = makeEnvironment()
        let coordinator = environment.coordinator
        await coordinator.send(.beginSetup)
        await coordinator.send(.beginReference)

        await hold.close(.finalize)
        let stop = Task { await coordinator.send(.stopReference) }
        await hold.awaitArrival(of: .finalize)

        // Cancel the first attempt, then start a second one before the first
        // attempt's reply arrives.
        await coordinator.send(.cancel)
        XCTAssertEqual(coordinator.state.phase, .idle)
        await coordinator.send(.beginSetup)
        await coordinator.send(.beginReference)
        XCTAssertEqual(coordinator.state.phase, .recordingReference)
        let secondToken = try XCTUnwrap(coordinator.state.token)
        XCTAssertEqual(secondToken, token("reference", 3))

        await hold.release(.finalize)
        await stop.value

        // The stale reply neither published the first take nor disturbed the
        // second attempt, which is still recording under its own identity.
        XCTAssertEqual(coordinator.state.phase, .recordingReference)
        XCTAssertEqual(coordinator.state.token, secondToken)
        XCTAssertNil(coordinator.state.referenceTakeID)
        let committed = try await records(environment)
        XCTAssertEqual(committed.count, 1, "only the second attempt's record may exist")
        XCTAssertEqual(committed.first?.attemptID, "reference-3")
        XCTAssertEqual(committed.first?.completion, .incomplete)
        let observed8 = await mediaFiles(environment)
        XCTAssertEqual(observed8, 1, "the second attempt's media must survive the stale reply")
        XCTAssertEqual(coordinator.droppedReplies.map(\.reason), [.staleToken])
        XCTAssertEqual(coordinator.unexpectedFailures, [])

        await coordinator.send(.cancel)
        let afterCancel = try await records(environment)
        XCTAssertTrue(afterCancel.isEmpty)
        let observed9 = await mediaFiles(environment)
        XCTAssertEqual(observed9, 0)
        let observed10 = await openWriters(environment)
        XCTAssertEqual(observed10, 0)
    }

    func testCancellationLatencyIsMeasuredWithTheInjectedClockAndInsideTheBudget() async throws {
        let environment = makeEnvironment()
        let coordinator = environment.coordinator
        await coordinator.send(.beginSetup)
        await coordinator.send(.beginReference)

        await coordinator.send(.cancel)

        let sample = try XCTUnwrap(coordinator.cancellationSamples.last)
        print("MEASURED cancellation latency while recording: \(sample.latencySeconds * 1000) ms")
        XCTAssertEqual(sample.intent, "cancel")
        // Acknowledged means the writer was closed and its resources released. The
        // modelled device-representative costs are 30 ms to abandon the attempt plus
        // 5 ms to stop sensor delivery, so the measured value is the sum of the work
        // the app actually awaited — not a constant and not a wall-clock reading.
        XCTAssertEqual(sample.latencySeconds, 0.035, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(sample.latencySeconds, 0.200, "the 200 ms cancellation budget was exceeded")
        await assertClean(environment)
    }

    func testCancellingWhileFinalizingIsAlsoMeasuredInsideTheBudget() async throws {
        let environment = makeEnvironment()
        let coordinator = environment.coordinator
        await coordinator.send(.beginSetup)
        await coordinator.send(.beginReference)

        await hold.close(.finalize)
        let stop = Task { await coordinator.send(.stopReference) }
        await hold.awaitArrival(of: .finalize)
        await coordinator.send(.cancel)
        let sample = try XCTUnwrap(coordinator.cancellationSamples.last)
        print("MEASURED cancellation latency while finalizing: \(sample.latencySeconds * 1000) ms")
        XCTAssertLessThanOrEqual(sample.latencySeconds, 0.200)
        XCTAssertEqual(sample.latencySeconds, 0.035, accuracy: 1e-9)

        await hold.release(.finalize)
        await stop.value
        await assertClean(environment)
    }

    // MARK: - Tracking interruption in every busy phase

    func testTrackingLossWhileRecordingAReferencePreservesAnIncompleteAttempt() async throws {
        let environment = makeEnvironment()
        let coordinator = environment.coordinator
        await coordinator.send(.beginSetup)
        await hold.close(.startCapture)

        let begin = Task { await coordinator.send(.beginReference) }
        await hold.awaitArrival(of: .startCapture)
        XCTAssertEqual(coordinator.state.phase, .recordingReference)

        await coordinator.reportTracking(.unavailable)
        XCTAssertEqual(coordinator.state.phase, .interrupted)
        XCTAssertEqual(coordinator.state.interruption, .trackingLost)
        XCTAssertEqual(coordinator.state.diagnosticCode, "tracking-unavailable")
        XCTAssertNil(coordinator.state.referenceTakeID)
        XCTAssertNil(coordinator.state.token)

        await hold.release(.startCapture)
        await begin.value

        // The attempt ended. It is preserved as incomplete — a file recovery can
        // reconcile — and it is never offered as a finished take.
        let committed = try await records(environment)
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed.first?.completion, .incomplete)
        XCTAssertNil(committed.first?.takeID)
        XCTAssertEqual(committed.first?.attemptID, "reference-1")
        XCTAssertFalse(coordinator.state.phase.isReviewable)
        let observed11 = await mediaFiles(environment)
        XCTAssertEqual(observed11, 1)
        await assertClean(environment)
    }

    func testTrackingLossWhileFinalizingAReferenceKeepsTheTakeUnpublished() async throws {
        let environment = makeEnvironment()
        let coordinator = environment.coordinator
        await coordinator.send(.beginSetup)
        await coordinator.send(.beginReference)

        await hold.close(.finalize)
        let stop = Task { await coordinator.send(.stopReference) }
        await hold.awaitArrival(of: .finalize)
        XCTAssertEqual(coordinator.state.phase, .finalizingReference)

        await coordinator.reportTracking(.unavailable)
        XCTAssertEqual(coordinator.state.phase, .interrupted)
        XCTAssertNil(coordinator.state.referenceTakeID)

        await hold.release(.finalize)
        await stop.value

        // The take had already committed; the interruption may not let it publish,
        // and the stored record is demoted to incomplete rather than staying complete.
        XCTAssertEqual(coordinator.state.phase, .interrupted)
        XCTAssertNil(coordinator.state.referenceTakeID)
        let committed = try await records(environment)
        XCTAssertEqual(committed.count, 1)
        XCTAssertEqual(committed.first?.completion, .incomplete)
        XCTAssertNil(committed.first?.takeID)
        XCTAssertEqual(coordinator.droppedReplies.map(\.reason), [.staleToken])
        await assertClean(environment)
    }

    /// A scene the adapter cannot recognise ends the attempt before guidance
    /// starts, and the reference survives so a new attempt is possible.
    func testRelocalizationFailureEndsTheAttemptWithoutGuidance() async throws {
        let environment = try await savedReference()
        let coordinator = environment.coordinator
        await environment.capture.failRelocalization(true)

        await coordinator.send(.prepareRetake)

        XCTAssertEqual(coordinator.state.phase, .interrupted)
        XCTAssertEqual(coordinator.state.interruption, .sceneNotRecognized)
        XCTAssertEqual(coordinator.state.diagnosticCode, "relocalize-sceneNotRecognized")
        XCTAssertNil(coordinator.guidanceReferenceTakeID)
        XCTAssertEqual(coordinator.state.referenceTakeID, TakeID("reference-take-1"))

        // Recovery is deliberate: the app does not slip into guidance without a
        // verified start position.
        await coordinator.send(.resume)
        XCTAssertEqual(coordinator.state.phase, .referenceAvailable)
        await environment.capture.failRelocalization(false)
        await coordinator.send(.prepareRetake)
        XCTAssertEqual(coordinator.state.phase, .guiding)
        await assertClean(environment)
    }

    /// A permission refused for good can still be granted later, and the app only
    /// proceeds once the OS actually reports access.
    func testAccessGrantedAfterAPermanentRefusalIsPickedUpOnReturn() async throws {
        let environment = makeEnvironment(profile: .permissionDenied)
        let coordinator = environment.coordinator
        await coordinator.send(.beginSetup)
        XCTAssertEqual(coordinator.state.phase, .interrupted)

        environment.permissions.grant(.camera)
        await coordinator.applicationBecameActive()

        XCTAssertEqual(coordinator.state.phase, .ready)
        await coordinator.send(.beginReference)
        await coordinator.send(.stopReference)
        XCTAssertEqual(coordinator.state.phase, .referenceAvailable)
        await assertClean(environment)
    }

    func testTrackingLossWhileRelocalizingEndsTheAttemptBeforeItStarts() async throws {
        let environment = try await savedReference()
        let coordinator = environment.coordinator
        await hold.close(.relocalize)

        let prepare = Task { await coordinator.send(.prepareRetake) }
        await hold.awaitArrival(of: .relocalize)
        XCTAssertEqual(coordinator.state.phase, .relocalizing)

        await coordinator.reportTracking(.unavailable)
        XCTAssertEqual(coordinator.state.phase, .interrupted)
        XCTAssertEqual(coordinator.state.interruption, .trackingLost)
        XCTAssertNil(coordinator.state.retakeTakeID)

        await hold.release(.relocalize)
        await prepare.value

        // The relocalization reply arrived after the session had moved on: dropped,
        // not reduced into a guidance session or an illegal transition.
        XCTAssertEqual(coordinator.state.phase, .interrupted)
        XCTAssertNil(coordinator.guidanceReferenceTakeID)
        XCTAssertEqual(coordinator.droppedReplies, [DroppedReply(event: "relocalized", reason: .staleToken)])

        // The saved reference survives; recovery is an explicit new attempt.
        XCTAssertEqual(coordinator.state.referenceTakeID, TakeID("reference-take-1"))
        await coordinator.send(.resume)
        XCTAssertEqual(coordinator.state.phase, .referenceAvailable)
        XCTAssertFalse(coordinator.state.phase.isReviewable)
        await coordinator.send(.prepareRetake)
        await coordinator.send(.startRetake)
        XCTAssertEqual(coordinator.state.phase, .recordingRetake)
        XCTAssertEqual(coordinator.state.token, token("retake", 6))
        await coordinator.send(.cancel)
        await assertClean(environment)
    }

    func testTrackingLossWhileRecordingARetakeEndsTheAttemptAndIsNeverReviewable() async throws {
        let environment = try await savedReference()
        let coordinator = environment.coordinator
        await coordinator.send(.prepareRetake)
        await hold.close(.startCapture)

        let begin = Task { await coordinator.send(.startRetake) }
        await hold.awaitArrival(of: .startCapture)
        XCTAssertEqual(coordinator.state.phase, .recordingRetake)

        await coordinator.reportTracking(.unavailable)
        XCTAssertEqual(coordinator.state.phase, .interrupted)
        XCTAssertNil(coordinator.state.retakeTakeID)
        XCTAssertTrue(coordinator.state.hasReference)
        XCTAssertFalse(coordinator.state.phase.isReviewable)

        await hold.release(.startCapture)
        await begin.value

        let committed = try await records(environment)
        XCTAssertEqual(committed.count, 2)
        XCTAssertEqual(committed.map(\.completion), [.complete, .incomplete])
        XCTAssertEqual(committed.last?.kind, .retake)
        XCTAssertNil(committed.last?.takeID)

        // Recovery returns to the saved reference and requires a new attempt; the
        // ended take is never resumed and never reviewable.
        await coordinator.send(.resume)
        XCTAssertEqual(coordinator.state.phase, .referenceAvailable)
        XCTAssertNotEqual(coordinator.state.phase, .reviewing)
        let observed12 = await openWriters(environment)
        XCTAssertEqual(observed12, 0)
        await assertClean(environment)
    }

    // MARK: - Export

    func testExportReportsUnavailableThroughTheRealPathAndReturnsToReview() async throws {
        let environment = try await savedReference()
        let coordinator = environment.coordinator
        await coordinator.send(.prepareRetake)
        await coordinator.send(.startRetake)
        await coordinator.send(.stopRetake)
        XCTAssertEqual(coordinator.state.phase, .reviewing)

        await hold.close(.export)
        let export = Task { await coordinator.send(.beginExport) }
        await hold.awaitArrival(of: .export)
        XCTAssertEqual(coordinator.state.phase, .exporting)

        // Exporting is not a tracking phase, so a tracking report is ignored
        // rather than treated as a defect.
        await coordinator.reportTracking(.unavailable)
        XCTAssertEqual(coordinator.state.phase, .exporting)

        await hold.release(.export)
        await export.value

        XCTAssertEqual(coordinator.state.phase, .reviewing)
        XCTAssertEqual(coordinator.state.diagnosticCode, "export-unavailable")
        XCTAssertNil(coordinator.state.exportedTakeID)
        XCTAssertTrue(coordinator.state.phase.isReviewable)
        await assertClean(environment)
    }

    func testAReplyForAnotherProjectIsRefusedInsteadOfAdvancingThisScreen() async throws {
        let environment = makeEnvironment(exporter: ForeignProjectExporter())
        let coordinator = environment.coordinator
        await coordinator.send(.beginSetup)
        await coordinator.send(.beginReference)
        await coordinator.send(.stopReference)
        await coordinator.send(.prepareRetake)
        await coordinator.send(.startRetake)
        await coordinator.send(.stopRetake)
        XCTAssertEqual(coordinator.state.phase, .reviewing)

        await coordinator.send(.beginExport)

        // The adapter claimed to export another project's take. That may not
        // advance this screen, and it is recorded as refused rather than applied.
        XCTAssertEqual(coordinator.state.phase, .exporting)
        XCTAssertNil(coordinator.state.exportedTakeID)
        XCTAssertEqual(
            coordinator.droppedReplies,
            [DroppedReply(event: "exportFinished", reason: .foreignProject)]
        )
        await assertClean(environment)
    }

    func testEveryJourneyEndsWithNoOpenWriterAndNoHeldAdapter() async throws {
        // A single sweep so a regression in any one path fails a named invariant.
        for profile in SessionFaultProfile.allCases {
            let environment = makeEnvironment(profile: profile)
            let coordinator = environment.coordinator
            await coordinator.send(.beginSetup)
            if coordinator.state.phase == .ready {
                await coordinator.send(.beginReference)
            }
            if coordinator.state.phase == .recordingReference {
                await coordinator.send(.stopReference)
            }
            await coordinator.cancelIfPossible()
            await coordinator.endSession()

            let writers = await openWriters(environment)
            XCTAssertEqual(writers, 0, "profile \(profile.rawValue) left a writer open")
            XCTAssertEqual(coordinator.unexpectedFailures, [], "profile \(profile.rawValue) recorded a defect")
        }
    }
}

/// Reports success while naming a different project, so the reducer's foreign
/// project rejection has something real to refuse.
private struct ForeignProjectExporter: TakeExporting {
    func export(takeID: TakeID, projectID: ProjectID) async throws -> ExportOutcome {
        ExportOutcome(projectID: ProjectID("someone-elses-project"), takeID: takeID)
    }

    func cancelExport() async {}
}
