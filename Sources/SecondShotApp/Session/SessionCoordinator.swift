import Foundation
import SecondShotCore

/// A reply that was refused before it could change anything.
struct DroppedReply: Equatable, Sendable {
    enum Reason: String, Sendable {
        /// The reply's `<kind>-<generation>` token no longer matches the session.
        case staleToken
        /// The reply named a different project, so it may not advance this screen.
        case foreignProject
        /// The work had already been abandoned, so no reply was expected at all.
        case noLongerExpected
    }

    /// Content-free description, e.g. `referenceSaved`.
    let event: String
    let reason: Reason
}

/// Cancellation responsiveness, measured with the injected monotonic clock from
/// the intent being accepted to the writer being closed and resources released.
struct CancellationSample: Equatable, Sendable {
    let intent: String
    let latencySeconds: TimeInterval
    let generation: Int
}

/// The platform adapter: executes the reducer's declarative effects.
///
/// The reducer stays pure and decides *what* should happen. This class is the only
/// place that mutates UI state, awaits adapters, and feeds their results back as
/// events. Three rules keep it honest:
///
/// 1. Every reply is checked against the operation it belongs to before it can
///    change anything. Stale and foreign replies are dropped and recorded rather
///    than applied, so a cancelled take can never publish into a newer screen.
/// 2. A stop whose result is no longer expected is turned into an abandonment
///    instead of a finalize, so cancelled work is not published and then deleted.
/// 3. Cancellation latency is measured with the injected clock, never with the
///    wall clock, so the budget is checked deterministically.
@MainActor
final class SessionCoordinator {
    // MARK: Injected seams

    private let projectID: ProjectID
    private let clock: SessionClock
    private let permissions: PermissionProviding
    private let capabilities: CapabilityProviding
    private let capture: CaptureProviding
    private let storage: SessionRecording
    private let media: MediaWriting
    private let exporter: TakeExporting?

    // MARK: Published session state

    private(set) var state: SessionState
    /// Set when the user must know that work stopped. Content-free adapter codes.
    private(set) var lastError: String?
    /// Effects executed in order, for journey assertions and support diagnostics.
    private(set) var executedEffects: [SessionEffect] = []
    private(set) var droppedReplies: [DroppedReply] = []
    /// Replies that could not be explained by a stale or foreign operation. A
    /// non-empty list is a defect, and the fault journeys assert it stays empty.
    private(set) var unexpectedFailures: [String] = []
    private(set) var cancellationSamples: [CancellationSample] = []
    /// The reference currently being guided. Set by guidance, cleared on stop.
    private(set) var guidanceReferenceTakeID: TakeID?

    /// Called after every accepted state change so the UI can mirror it.
    var sessionDidChange: (@MainActor (SessionState) -> Void)?

    // MARK: Attempt bookkeeping

    private var currentAttemptID: String?
    private var currentAttemptToken: OperationToken?
    /// True once the capture path actually began for the current attempt. An
    /// attempt whose writer could not be created never captured anything, so there
    /// is nothing to preserve for it.
    private var attemptIsCapturing = false
    private var recordingStartedAt: TimeInterval?
    private var lastReportedTracking: TrackingAvailability?

    init(
        projectID: ProjectID,
        clock: SessionClock,
        permissions: PermissionProviding,
        capabilities: CapabilityProviding,
        capture: CaptureProviding,
        storage: SessionRecording,
        media: MediaWriting,
        exporter: TakeExporting? = nil
    ) {
        self.projectID = projectID
        self.clock = clock
        self.permissions = permissions
        self.capabilities = capabilities
        self.capture = capture
        self.storage = storage
        self.media = media
        self.exporter = exporter
        state = SessionState(projectID: projectID)
    }

    /// Monotonic capture time for the UI. Never the wall clock.
    var elapsedSeconds: TimeInterval {
        guard let started = recordingStartedAt else { return 0 }
        return max(0, clock.now() - started)
    }

    // MARK: - Intents

    /// Reduces a user intent, then executes its effects. The returned transition's
    /// effects have finished by the time this returns, so tests need no sleeps.
    func send(_ intent: SessionIntent) async {
        let startedAt = clock.now()
        let isCancellation = Self.isCancellation(intent)
        do {
            let transition = try SessionReducer.reduce(state, intent: intent)
            apply(transition)
            await perform(transition.effects)
        } catch let error as SessionError {
            record(unexpected: error.description, context: "intent \(intent)")
        } catch {
            record(unexpected: "\(error)", context: "intent \(intent)")
        }
        if isCancellation {
            cancellationSamples.append(
                CancellationSample(
                    intent: String(describing: intent),
                    latencySeconds: max(0, clock.now() - startedAt),
                    generation: state.generation
                )
            )
        }
        sessionDidChange?(state)
    }

    /// Reports a tracking change from the adapter. Reports that arrive while the
    /// session is not tracking are ignored rather than treated as defects.
    func reportTracking(_ availability: TrackingAvailability) async {
        guard Self.tracksTracking(state.phase) else { return }
        lastReportedTracking = availability
        await dispatch(.trackingChanged(availability))
        sessionDidChange?(state)
    }

    /// Polls the adapter once. The UI ticker calls this instead of inventing
    /// tracking state, and a repeated report is not dispatched twice.
    func pollTracking() async {
        guard Self.tracksTracking(state.phase) else { return }
        let availability = await capture.currentTracking()
        guard availability != lastReportedTracking else { return }
        lastReportedTracking = availability
        await dispatch(.trackingChanged(availability))
        sessionDidChange?(state)
    }

    /// Cancels when the current phase defines a cancellation. A repeated or
    /// pointless cancel is a no-op rather than an illegal transition, because
    /// screen navigation asks for it more than once.
    func cancelIfPossible() async {
        switch state.phase {
        case .requestingPermission, .preparing, .ready, .recordingReference, .finalizingReference,
             .relocalizing, .guiding, .recordingRetake, .finalizingRetake, .reviewing,
             .exporting, .interrupted, .failed:
            await send(.cancel)
        case .idle, .referenceAvailable:
            break
        }
    }

    /// Ends the session deliberately: abandons any open capture, releases the
    /// preparation and returns to a fresh idle state. Never automatic — leaving a
    /// screen must not decide that a recording is over.
    func endSession() async {
        await abandonAttempt(token: nil)
        await capture.releasePreparation()
        recordingStartedAt = nil
        lastReportedTracking = nil
        guidanceReferenceTakeID = nil
        state = SessionState(projectID: projectID)
        lastError = nil
        sessionDidChange?(state)
    }

    /// Called when the app returns to the foreground, which is also how a user
    /// returns from Settings. A permission refusal is re-queried rather than
    /// assumed, and nothing resumes recording by itself.
    func applicationBecameActive() async {
        switch state.phase {
        case .requestingPermission:
            await resolvePermissions()
        case .interrupted where state.interruption == .cameraDenied:
            await send(.resume)
        default:
            break
        }
        sessionDidChange?(state)
    }

    // MARK: - Effect execution

    private func perform(_ effects: [SessionEffect]) async {
        for effect in effects {
            await perform(effect)
        }
    }

    private func perform(_ effect: SessionEffect) async {
        executedEffects.append(effect)
        switch effect {
        case .requestCapturePermission:
            await resolvePermissions()
        case .prepareCapture:
            await prepareCapture()
        case .releaseCapturePreparation:
            await capture.releasePreparation()
        case let .startReferenceCapture(token):
            await startCapture(kind: .reference, token: token)
        case let .stopReferenceCapture(token):
            await finishOrAbandon(kind: .reference, token: token)
        case .discardReferenceCapture:
            await abandonAttempt(token: currentAttemptToken)
        case let .beginRelocalization(token):
            await relocalize(token: token)
        case let .cancelRelocalization(token):
            await cancelRelocalization(token: token)
        case let .startGuidance(referenceTakeID):
            guidanceReferenceTakeID = referenceTakeID
        case .stopGuidance:
            guidanceReferenceTakeID = nil
        case let .startRetakeCapture(token):
            await startCapture(kind: .retake, token: token)
        case let .stopRetakeCapture(token):
            await finishOrAbandon(kind: .retake, token: token)
        case .discardRetakeCapture:
            await abandonAttempt(token: currentAttemptToken)
        case let .preserveIncompleteTake(takeID):
            await preserveIncompleteAttempt(kind: takeID == nil ? .reference : .retake)
        case let .beginExport(token, takeID):
            await export(token: token, takeID: takeID)
        case .cancelExport:
            // The reducer has already returned the screen to review. Partial
            // export output, when a real renderer exists, is discarded by it.
            await exporter?.cancelExport()
        case .stopSensors:
            await capture.stopSensors()
        }
    }

    private func resolvePermissions() async {
        var status = await permissions.status(of: .camera)
        if status == .notDetermined {
            status = await permissions.request(.camera)
        }
        let granted = status.allowsCapture
        let code = granted ? nil : "permission-camera-\(status.rawValue)"
        await deliver(
            .permissionsResolved(granted: granted, code: code),
            expecting: .requestingPermission,
            token: nil,
            label: "permissionsResolved"
        )
    }

    private func prepareCapture() async {
        let capabilities = await self.capabilities.capabilities()
        guard capabilities.canPrepareCapture else {
            await deliver(
                .preparationFailed(code: "capability-capture-unavailable"),
                expecting: .preparing,
                token: nil,
                label: "preparationFailed"
            )
            return
        }
        do {
            try await capture.prepare()
        } catch {
            await deliver(
                .preparationFailed(code: Self.diagnosticCode(for: error)),
                expecting: .preparing,
                token: nil,
                label: "preparationFailed"
            )
            return
        }
        await deliver(.capturePrepared, expecting: .preparing, token: nil, label: "capturePrepared")
    }

    private func startCapture(kind: TakeKind, token: OperationToken) async {
        let attemptID = "\(kind.rawValue)-\(token.generation)"
        let expectedPhase: SessionPhase = kind == .reference ? .recordingReference : .recordingRetake
        currentAttemptID = attemptID
        currentAttemptToken = token
        attemptIsCapturing = false
        recordingStartedAt = clock.now()
        lastReportedTracking = nil
        do {
            try await capture.startCapture(
                CaptureRequest(
                    token: token,
                    projectID: projectID,
                    attemptID: attemptID,
                    kind: kind,
                    referenceTakeID: state.referenceTakeID
                )
            )
            attemptIsCapturing = true
        } catch {
            recordingStartedAt = nil
            await deliver(
                .captureFailed(code: Self.diagnosticCode(for: error), token: token),
                expecting: expectedPhase,
                token: token,
                label: "captureFailed"
            )
        }
    }

    /// Stops a capture. The writer is finalized and the result published only while
    /// the session still waits for exactly this operation; otherwise the reply is
    /// dropped and the attempt is retired according to why the session moved on.
    private func finishOrAbandon(kind: TakeKind, token: OperationToken) async {
        let expectedPhase: SessionPhase = kind == .reference ? .finalizingReference : .finalizingRetake
        let saved = kind == .reference ? "referenceSaved" : "retakeSaved"
        guard isExpected(phase: expectedPhase, token: token) else {
            dropReply(saved, reason: .noLongerExpected)
            await retireUnpublishedAttempt(token: token, kind: kind)
            return
        }
        do {
            let takeID = try await capture.finishCapture(token: token)
            // The writer may have finalized and committed while a cancellation or an
            // interruption was being handled. The reply is only allowed to publish
            // while the session still waits for exactly this operation.
            guard isExpected(phase: expectedPhase, token: token) else {
                dropReply(saved, reason: .staleToken)
                await retireUnpublishedAttempt(token: token, kind: kind)
                return
            }
            await dispatch(
                kind == .reference
                    ? .referenceSaved(takeID: takeID, token: token)
                    : .retakeSaved(takeID: takeID, token: token)
            )
            if !Self.holdsCapture(state.phase) {
                // Published for good: the attempt bookkeeping is no longer needed,
                // and a later reset must not delete the take's media.
                currentAttemptID = nil
                currentAttemptToken = nil
                attemptIsCapturing = false
            }
        } catch {
            await deliver(
                kind == .reference
                    ? .referenceFailed(code: Self.diagnosticCode(for: error), token: token)
                    : .retakeFailed(code: Self.diagnosticCode(for: error), token: token),
                expecting: expectedPhase,
                token: token,
                label: kind == .reference ? "referenceFailed" : "retakeFailed"
            )
        }
        recordingStartedAt = nil
    }

    /// A take whose result is no longer wanted is never published. What happens to
    /// its media and record depends on *why* the session moved on: an interruption
    /// preserves the attempt as incomplete so recovery has something to reconcile,
    /// while a cancellation or a newer attempt discards it completely, so neither a
    /// file nor a record is left behind.
    private func retireUnpublishedAttempt(token: OperationToken, kind: TakeKind) async {
        recordingStartedAt = nil
        if state.phase == .interrupted {
            await capture.preserveCapture(token: token)
            await preserveIncompleteAttempt(kind: kind)
            return
        }
        await abandonAttempt(token: token)
    }

    /// Abandons one attempt: its writer, its media and its record.
    ///
    /// It is token-scoped, so a late reply for an older attempt can never delete a
    /// newer attempt's work. A cancelled take therefore leaves neither an open
    /// writer nor a record behind — even when the writer had already finalized and
    /// committed before the cancellation arrived.
    private func abandonAttempt(token: OperationToken?) async {
        guard let target = token ?? currentAttemptToken else {
            // Nothing is open or remembered, so discarding again is a no-op rather
            // than a second cleanup pass over someone else's take.
            recordingStartedAt = nil
            return
        }
        await capture.abandonCapture(token: target)
        if target == currentAttemptToken {
            currentAttemptID = nil
            currentAttemptToken = nil
        }
        attemptIsCapturing = false
        recordingStartedAt = nil
    }

    /// Writes the incomplete record that launch recovery reconciles. It is skipped
    /// for an attempt whose writer was never created, because that attempt captured
    /// nothing: an incomplete record there would be noise rather than evidence.
    private func preserveIncompleteAttempt(kind: TakeKind) async {
        guard attemptIsCapturing else { return }
        let attemptID = currentAttemptID ?? "interrupted-\(state.generation)"
        let sessionRecord = SessionRecord(
            attemptID: attemptID,
            projectID: projectID,
            kind: kind,
            takeID: nil,
            completion: .incomplete,
            diagnosticCode: state.diagnosticCode ?? state.interruption?.rawValue,
            createdOnSecond: clock.now(),
            updatedOnSecond: clock.now()
        )
        do {
            try await storage.upsert(sessionRecord)
        } catch {
            record(unexpected: "\(error)", context: "preserveIncompleteAttempt")
        }
    }

    private func relocalize(token: OperationToken) async {
        let capabilities = await self.capabilities.capabilities()
        guard capabilities.trackingAvailability.supportsPreciseGuidance else {
            await deliver(
                .relocalizationFailed(reason: .trackingLost, token: token),
                expecting: .relocalizing,
                token: token,
                label: "relocalizationFailed"
            )
            return
        }
        do {
            try await capture.beginRelocalization(token: token)
        } catch {
            await deliver(
                .relocalizationFailed(reason: .sceneNotRecognized, token: token),
                expecting: .relocalizing,
                token: token,
                label: "relocalizationFailed"
            )
            return
        }
        await deliver(.relocalized(token: token), expecting: .relocalizing, token: token, label: "relocalized")
    }

    private func cancelRelocalization(token: OperationToken) async {
        _ = token
        await capture.cancelRelocalization()
    }

    private func export(token: OperationToken, takeID: TakeID) async {
        guard let exporter else {
            await deliver(.exportFailed(code: "export-unavailable", token: token), expecting: .exporting, token: token, label: "exportFailed")
            return
        }
        do {
            let outcome = try await exporter.export(takeID: takeID, projectID: projectID)
            // The project is reported by the adapter, so a reply for another project
            // is possible and must be refused by the reducer.
            await deliver(
                .exportFinished(projectID: outcome.projectID, takeID: outcome.takeID, token: token),
                expecting: .exporting,
                token: token,
                label: "exportFinished"
            )
        } catch {
            await deliver(.exportFailed(code: Self.diagnosticCode(for: error), token: token), expecting: .exporting, token: token, label: "exportFailed")
        }
    }

    // MARK: - Reply policy

    /// Delivers an adapter reply only while the session still waits for exactly that
    /// operation. A reply that arrives after the work was abandoned is dropped and
    /// recorded rather than reduced into an illegal transition, and it never mutates
    /// state.
    @discardableResult
    private func deliver(
        _ event: SessionEvent,
        expecting phase: SessionPhase,
        token: OperationToken?,
        label: String
    ) async -> Bool {
        guard isExpected(phase: phase, token: token) else {
            dropReply(label, reason: token == nil ? .noLongerExpected : .staleToken)
            return false
        }
        await dispatch(event)
        return true
    }

    private func isExpected(phase: SessionPhase, token: OperationToken?) -> Bool {
        guard state.phase == phase else { return false }
        guard let token else { return true }
        return state.token == token
    }

    private func dropReply(_ event: String, reason: DroppedReply.Reason) {
        droppedReplies.append(DroppedReply(event: event, reason: reason))
    }

    // MARK: - Reply handling

    private func dispatch(_ event: SessionEvent) async {
        do {
            let transition = try SessionReducer.reduce(state, event: event)
            apply(transition)
            await perform(transition.effects)
        } catch let error as SessionError {
            switch error {
            case .staleOperation:
                droppedReplies.append(DroppedReply(event: Self.label(event), reason: .staleToken))
            case .foreignProject:
                droppedReplies.append(DroppedReply(event: Self.label(event), reason: .foreignProject))
            default:
                record(unexpected: error.description, context: "event \(Self.label(event))")
            }
        } catch {
            record(unexpected: "\(error)", context: "event \(Self.label(event))")
        }
    }

    private func apply(_ transition: SessionTransition) {
        state = transition.state
        lastError = nil
        if !Self.holdsCapture(transition.state.phase) {
            recordingStartedAt = nil
        }
        sessionDidChange?(state)
    }

    private func record(unexpected message: String, context: String) {
        lastError = message
        unexpectedFailures.append("\(context): \(message)")
    }

    // MARK: - Rules

    private static func isCancellation(_ intent: SessionIntent) -> Bool {
        switch intent {
        case .cancel, .cancelExport:
            return true
        case .beginSetup, .beginReference, .stopReference, .prepareRetake, .startRetake,
             .stopRetake, .openReview, .closeReview, .beginExport, .interrupt, .resume, .retry:
            return false
        }
    }

    /// Phases in which a capture is running or its writer is still being closed.
    private static func holdsCapture(_ phase: SessionPhase) -> Bool {
        switch phase {
        case .recordingReference, .finalizingReference, .recordingRetake, .finalizingRetake:
            return true
        case .idle, .requestingPermission, .preparing, .ready, .referenceAvailable, .relocalizing,
             .guiding, .reviewing, .exporting, .interrupted, .failed:
            return false
        }
    }

    /// Phases whose tracking report the reducer defines behaviour for.
    private static func tracksTracking(_ phase: SessionPhase) -> Bool {
        switch phase {
        case .guiding, .recordingReference, .recordingRetake, .relocalizing,
             .finalizingReference, .finalizingRetake:
            return true
        case .idle, .requestingPermission, .preparing, .ready, .referenceAvailable, .reviewing,
             .exporting, .interrupted, .failed:
            return false
        }
    }

    private static func label(_ event: SessionEvent) -> String {
        switch event {
        case .permissionsResolved: return "permissionsResolved"
        case .capturePrepared: return "capturePrepared"
        case .preparationFailed: return "preparationFailed"
        case .referenceSaved: return "referenceSaved"
        case .referenceFailed: return "referenceFailed"
        case .captureFailed: return "captureFailed"
        case .relocalized: return "relocalized"
        case .relocalizationFailed: return "relocalizationFailed"
        case .retakeSaved: return "retakeSaved"
        case .retakeFailed: return "retakeFailed"
        case .trackingChanged: return "trackingChanged"
        case .exportFinished: return "exportFinished"
        case .exportFailed: return "exportFailed"
        }
    }

    private static func diagnosticCode(for error: Error) -> String {
        if let adapter = error as? SessionAdapterError {
            return adapter.code
        }
        if let media = error as? MediaWriteError {
            switch media {
            case let .writerCreationFailed(code), let .writerFinalizeFailed(code):
                return code
            case let .writerAlreadyOpen(open, requested):
                return "writer-busy-\(open.rawValue)-\(requested.rawValue)"
            case let .writerNotOpen(requested):
                return "writer-missing-\(requested.rawValue)"
            }
        }
        if let store = error as? ProjectStoreError {
            switch store {
            case let .unreadableRecord(attemptID): return "record-unreadable-\(attemptID)"
            case let .missingRecord(attemptID): return "record-missing-\(attemptID)"
            }
        }
        // Never surface a raw error: it can contain paths or other private data.
        return "adapter-failure"
    }
}
