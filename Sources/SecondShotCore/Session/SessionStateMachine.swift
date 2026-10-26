import Foundation

/// Identity of one in-flight asynchronous operation inside a session.
///
/// Every capture, relocalization and export is a separate operation with an
/// escalation-free identity: the reducer mints it, the adapter echoes it back
/// with its result, and a result carrying an older identity is discarded. This
/// is what stops a cancelled writer, a late relocalization or a previous
/// project's export from publishing into a newer screen.
public struct OperationID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

/// An operation identity plus the generation it belongs to. The generation
/// advances whenever the session abandons work (cancel, interruption, retry,
/// resume), so stale completions can never match.
public struct OperationToken: Equatable, Sendable, Codable {
    public let operationID: OperationID
    public let generation: Int

    public init(operationID: OperationID, generation: Int) {
        self.operationID = operationID
        self.generation = generation
    }
}

/// Explicit production session phases. They describe *work that is happening*,
/// so the UI can render a state instead of guessing from several booleans.
public enum SessionPhase: String, Sendable, Codable, CaseIterable {
    case idle
    case requestingPermission
    case preparing
    case ready
    case recordingReference
    case finalizingReference
    case referenceAvailable
    case relocalizing
    case guiding
    case recordingRetake
    case finalizingRetake
    case reviewing
    case exporting
    case interrupted
    case failed

    /// A writer owns media in these phases.
    public var isRecording: Bool {
        self == .recordingReference || self == .recordingRetake
    }

    /// Busy phases: the app may not silently claim the work succeeded here.
    public var isBusy: Bool {
        switch self {
        case .requestingPermission, .preparing, .recordingReference, .finalizingReference,
             .relocalizing, .recordingRetake, .finalizingRetake, .exporting:
            return true
        case .idle, .ready, .referenceAvailable, .guiding, .reviewing, .interrupted, .failed:
            return false
        }
    }

    /// Whether a result screen may be shown for a completed operation.
    public var isReviewable: Bool { self == .reviewing }
}

public enum InterruptionReason: String, Sendable, Codable, CaseIterable {
    case trackingLost
    case appBackgrounded
    case deviceLocked
    case cameraDenied
    case storageLow
    case thermalPressure
    case writerFailure
    case sceneNotRecognized

    /// User-facing explanation of what happened and what was preserved. These do
    /// not claim that a movie is playable until the writer has actually finished.
    public var explanation: String {
        switch self {
        case .trackingLost:
            return "Spatial tracking was lost. Precision guidance is unavailable until the scene is found again."
        case .appBackgrounded:
            return "The app left the foreground. Recording stopped; nothing continues in the background."
        case .deviceLocked:
            return "The iPhone was locked. Recording stopped and the take is marked incomplete."
        case .cameraDenied:
            return "Camera access is not available. The synthetic demo still works without it."
        case .storageLow:
            return "Storage is nearly full. Stop and free space before starting another take."
        case .thermalPressure:
            return "The iPhone is warm. Recording stopped so the device can recover."
        case .writerFailure:
            return "Saving the take failed. The project was not marked complete."
        case .sceneNotRecognized:
            return "The saved start position could not be verified in this scene."
        }
    }
}

/// User intents. Separate from adapter events so no UI code can invent completion.
public enum SessionIntent: Equatable, Sendable {
    case beginSetup
    case beginReference
    case stopReference
    case prepareRetake
    case startRetake
    case stopRetake
    case openReview
    case closeReview
    case beginExport
    case cancelExport
    case interrupt(InterruptionReason)
    case resume
    case retry
    case cancel
}

/// Facts reported by platform adapters. The reducer decides what they mean; a
/// result that does not match the state's in-flight operation is rejected.
public enum SessionEvent: Equatable, Sendable {
    case permissionsResolved(granted: Bool, code: String?)
    case capturePrepared
    case preparationFailed(code: String)
    case referenceSaved(takeID: TakeID, token: OperationToken)
    case referenceFailed(code: String, token: OperationToken)
    case relocalized(token: OperationToken)
    case relocalizationFailed(reason: InterruptionReason, token: OperationToken)
    case retakeSaved(takeID: TakeID, token: OperationToken)
    case retakeFailed(code: String, token: OperationToken)
    case trackingChanged(TrackingAvailability)
    case exportFinished(projectID: ProjectID, takeID: TakeID, token: OperationToken)
    case exportFailed(code: String, token: OperationToken)
}

/// Declarative work for a platform adapter. The reducer never performs IO, and
/// anything whose result could arrive late carries the identity it belongs to.
public enum SessionEffect: Equatable, Sendable {
    case requestCapturePermission
    case prepareCapture
    case releaseCapturePreparation
    case startReferenceCapture(token: OperationToken)
    case stopReferenceCapture(token: OperationToken)
    case discardReferenceCapture(takeID: TakeID?)
    case beginRelocalization(token: OperationToken)
    case cancelRelocalization(token: OperationToken)
    case startGuidance(referenceTakeID: TakeID)
    case stopGuidance
    case startRetakeCapture(token: OperationToken)
    case stopRetakeCapture(token: OperationToken)
    case discardRetakeCapture(takeID: TakeID?)
    case preserveIncompleteTake(takeID: TakeID?)
    case beginExport(token: OperationToken, takeID: TakeID)
    case cancelExport(token: OperationToken)
    case stopSensors
}

public struct SessionState: Equatable, Sendable {
    public var phase: SessionPhase
    public var projectID: ProjectID?
    public var referenceTakeID: TakeID?
    public var retakeTakeID: TakeID?
    /// Identity of the operation currently in flight, if any.
    public var token: OperationToken?
    /// Attempt counter for the current project. Advanced when work is abandoned.
    public var generation: Int
    public var exportedTakeID: TakeID?
    public var interruption: InterruptionReason?
    /// Content-free diagnostic code for support; never media, room or personal data.
    public var diagnosticCode: String?

    public init(
        phase: SessionPhase = .idle,
        projectID: ProjectID? = nil,
        referenceTakeID: TakeID? = nil,
        retakeTakeID: TakeID? = nil,
        token: OperationToken? = nil,
        generation: Int = 0,
        exportedTakeID: TakeID? = nil,
        interruption: InterruptionReason? = nil,
        diagnosticCode: String? = nil
    ) {
        self.phase = phase
        self.projectID = projectID
        self.referenceTakeID = referenceTakeID
        self.retakeTakeID = retakeTakeID
        self.token = token
        self.generation = generation
        self.exportedTakeID = exportedTakeID
        self.interruption = interruption
        self.diagnosticCode = diagnosticCode
    }

    public static let initial = SessionState()

    public var hasReference: Bool { referenceTakeID != nil }
    public var hasRetake: Bool { retakeTakeID != nil }

    /// Starting a new operation: mint a deterministic identity and drop any
    /// previous attempt's diagnostics.
    func starting(_ kind: String) -> SessionState {
        var next = self
        next.generation = generation + 1
        next.token = OperationToken(
            operationID: OperationID("\(kind)-\(next.generation)"),
            generation: next.generation
        )
        next.interruption = nil
        next.diagnosticCode = nil
        return next
    }

    /// Abandoning work: advance the generation so late adapter results are stale.
    func abandoning() -> SessionState {
        var next = self
        next.generation = generation + 1
        next.token = nil
        return next
    }
}

public struct SessionTransition: Equatable, Sendable {
    public let state: SessionState
    public let effects: [SessionEffect]

    public init(state: SessionState, effects: [SessionEffect]) {
        self.state = state
        self.effects = effects
    }
}

public enum SessionError: Error, Equatable, Sendable {
    case illegalTransition(from: SessionPhase, intent: String)
    case illegalEvent(from: SessionPhase, event: String)
    case missingReference
    case permissionNotGranted
    case staleOperation(expected: OperationToken?, received: OperationToken)
    case foreignProject(expected: ProjectID?, received: ProjectID)

    public var description: String {
        switch self {
        case let .illegalTransition(from, intent):
            return "Intent \(intent) is not valid from \(from.rawValue)."
        case let .illegalEvent(from, event):
            return "Event \(event) is not valid from \(from.rawValue)."
        case .missingReference:
            return "A saved reference take is required first."
        case .permissionNotGranted:
            return "Capture permission was not granted."
        case let .staleOperation(expected, received):
            let expectedLabel = expected.map { "\($0.operationID)@\($0.generation)" } ?? "none"
            return "Result for \(received.operationID)@\(received.generation) does not match the in-flight \(expectedLabel)."
        case let .foreignProject(expected, received):
            return "Result for project \(received) does not belong to the open project \(expected.map(\.rawValue) ?? "none")."
        }
    }
}

extension SessionError: CustomStringConvertible {}

public enum SessionReducer {
    // MARK: - User intents

    /// Pure transition for a user intent. Illegal transitions throw; they never
    /// fall back to a neighbouring state, and repeated stop/cancel is idempotent
    /// instead of issuing a second writer command.
    public static func reduce(_ state: SessionState, intent: SessionIntent) throws -> SessionTransition {
        switch (state.phase, intent) {
        case (.idle, .beginSetup):
            var next = state
            next.phase = .requestingPermission
            next.interruption = nil
            next.diagnosticCode = nil
            return SessionTransition(state: next, effects: [.requestCapturePermission])

        case (.requestingPermission, .cancel), (.preparing, .cancel), (.ready, .cancel):
            var next = state.abandoning()
            next.phase = state.hasReference ? .referenceAvailable : .idle
            next.interruption = nil
            let effects: [SessionEffect] = state.phase == .preparing
                ? [.releaseCapturePreparation, .stopSensors]
                : [.stopSensors]
            return SessionTransition(state: next, effects: effects)

        case (.ready, .beginReference), (.referenceAvailable, .beginReference):
            var next = state.starting("reference")
            next.phase = .recordingReference
            next.retakeTakeID = nil
            next.exportedTakeID = nil
            let token = try token(for: next, action: "beginReference")
            return SessionTransition(state: next, effects: [.startReferenceCapture(token: token)])

        case (.recordingReference, .stopReference):
            let token = try token(for: state, action: "stopReference")
            var next = state
            next.phase = .finalizingReference
            return SessionTransition(state: next, effects: [.stopReferenceCapture(token: token)])

        case (.finalizingReference, .stopReference),
             (.finalizingRetake, .stopRetake),
             (.relocalizing, .prepareRetake),
             (.exporting, .beginExport),
             (.reviewing, .openReview):
            // Idempotent repeats: no duplicate writer, export or guidance command.
            return SessionTransition(state: state, effects: [])

        case (.referenceAvailable, .prepareRetake):
            guard let reference = state.referenceTakeID else { throw SessionError.missingReference }
            var next = state.starting("relocalize")
            next.phase = .relocalizing
            let token = try token(for: next, action: "prepareRetake")
            _ = reference
            return SessionTransition(state: next, effects: [.beginRelocalization(token: token)])

        case (.relocalizing, .cancel):
            let token = try token(for: state, action: "cancel")
            var next = state.abandoning()
            next.phase = .referenceAvailable
            next.interruption = nil
            return SessionTransition(
                state: next,
                effects: [.cancelRelocalization(token: token), .stopSensors]
            )

        case (.guiding, .startRetake):
            guard state.hasReference else { throw SessionError.missingReference }
            var next = state.starting("retake")
            next.phase = .recordingRetake
            let token = try token(for: next, action: "startRetake")
            return SessionTransition(state: next, effects: [.startRetakeCapture(token: token)])

        case (.recordingRetake, .stopRetake):
            let token = try token(for: state, action: "stopRetake")
            var next = state
            next.phase = .finalizingRetake
            return SessionTransition(state: next, effects: [.stopRetakeCapture(token: token)])

        case (.reviewing, .closeReview):
            guard state.hasRetake || state.hasReference else { throw SessionError.missingReference }
            var next = state
            next.phase = .referenceAvailable
            next.interruption = nil
            return SessionTransition(state: next, effects: [.stopGuidance])

        case (.reviewing, .beginExport):
            guard let take = state.retakeTakeID ?? state.referenceTakeID else {
                throw SessionError.missingReference
            }
            var next = state.starting("export")
            next.phase = .exporting
            let token = try token(for: next, action: "beginExport")
            return SessionTransition(state: next, effects: [.beginExport(token: token, takeID: take)])

        case (.exporting, .cancelExport):
            let token = try token(for: state, action: "cancelExport")
            var next = state.abandoning()
            next.phase = .reviewing
            return SessionTransition(state: next, effects: [.cancelExport(token: token)])

        case (.recordingReference, .cancel), (.finalizingReference, .cancel):
            let token = state.token
            var next = state.abandoning()
            next.phase = state.hasReference ? .referenceAvailable : .idle
            next.interruption = nil
            next.diagnosticCode = nil
            var effects: [SessionEffect] = []
            if state.phase == .recordingReference, let token {
                effects.append(.stopReferenceCapture(token: token))
            }
            effects.append(.discardReferenceCapture(takeID: nil))
            effects.append(.stopSensors)
            return SessionTransition(state: next, effects: effects)

        case (.recordingRetake, .cancel), (.finalizingRetake, .cancel):
            let token = state.token
            var next = state.abandoning()
            next.phase = .referenceAvailable
            next.retakeTakeID = nil
            next.interruption = nil
            next.diagnosticCode = nil
            var effects: [SessionEffect] = []
            if state.phase == .recordingRetake, let token {
                effects.append(.stopRetakeCapture(token: token))
            }
            effects.append(.discardRetakeCapture(takeID: nil))
            effects.append(.stopSensors)
            return SessionTransition(state: next, effects: effects)

        case (.guiding, .cancel), (.reviewing, .cancel):
            var next = state.abandoning()
            next.phase = .referenceAvailable
            next.interruption = nil
            return SessionTransition(state: next, effects: [.stopGuidance, .stopSensors])

        case (.interrupted, .cancel), (.failed, .cancel):
            var next = state.abandoning()
            next.phase = state.hasReference ? .referenceAvailable : .idle
            next.interruption = nil
            next.diagnosticCode = nil
            return SessionTransition(state: next, effects: [.stopSensors])

        case (.interrupted, .resume), (.failed, .retry):
            if state.hasReference {
                var next = state.abandoning()
                next.phase = .referenceAvailable
                next.interruption = nil
                next.diagnosticCode = nil
                return SessionTransition(state: next, effects: [.stopSensors])
            }
            // Without a reference the capture path must be re-established, so a
            // permission refusal goes back to the permission step and everything
            // else returns to preparation. Nothing resumes recording by itself.
            var next = state.abandoning()
            if state.interruption == .cameraDenied {
                next.phase = .requestingPermission
                next.interruption = nil
                next.diagnosticCode = nil
                return SessionTransition(state: next, effects: [.requestCapturePermission])
            }
            next.phase = .preparing
            next.interruption = nil
            next.diagnosticCode = nil
            return SessionTransition(state: next, effects: [.stopSensors, .prepareCapture])

        default:
            if case let .interrupt(reason) = intent, isInterruptible(state.phase) {
                return try interruptionTransition(state, reason: reason)
            }
            throw SessionError.illegalTransition(from: state.phase, intent: String(describing: intent))
        }
    }

    // MARK: - Adapter events

    /// Pure transition for an adapter event. Results that do not belong to the
    /// in-flight operation or the open project are rejected, so a cancelled
    /// attempt can never publish completion into a newer screen.
    public static func reduce(_ state: SessionState, event: SessionEvent) throws -> SessionTransition {
        switch (state.phase, event) {
        case let (.requestingPermission, .permissionsResolved(granted, code)):
            guard granted else {
                var next = state.abandoning()
                next.phase = .interrupted
                next.interruption = .cameraDenied
                next.diagnosticCode = code
                return SessionTransition(state: next, effects: [.stopSensors])
            }
            var next = state
            next.phase = .preparing
            next.diagnosticCode = nil
            return SessionTransition(state: next, effects: [.prepareCapture])

        case (.preparing, .capturePrepared):
            var next = state
            next.phase = .ready
            next.diagnosticCode = nil
            return SessionTransition(state: next, effects: [])

        case let (.preparing, .preparationFailed(code)):
            var next = state.abandoning()
            next.phase = .failed
            next.diagnosticCode = code
            return SessionTransition(state: next, effects: [.releaseCapturePreparation, .stopSensors])

        case let (.finalizingReference, .referenceSaved(takeID, token)):
            try require(token, in: state)
            var next = state
            next.phase = .referenceAvailable
            next.token = nil
            next.referenceTakeID = takeID
            next.retakeTakeID = nil
            next.exportedTakeID = nil
            next.diagnosticCode = nil
            return SessionTransition(state: next, effects: [])

        case let (.finalizingReference, .referenceFailed(code, token)):
            try require(token, in: state)
            var next = state.abandoning()
            next.phase = .failed
            next.diagnosticCode = code
            return SessionTransition(state: next, effects: [.stopSensors])

        case let (.relocalizing, .relocalized(token)):
            try require(token, in: state)
            guard let reference = state.referenceTakeID else { throw SessionError.missingReference }
            var next = state
            next.phase = .guiding
            next.token = nil
            next.diagnosticCode = nil
            return SessionTransition(state: next, effects: [.startGuidance(referenceTakeID: reference)])

        case let (.relocalizing, .relocalizationFailed(reason, token)):
            try require(token, in: state)
            var next = state.abandoning()
            next.phase = .interrupted
            next.interruption = reason
            next.diagnosticCode = "relocalize-\(reason.rawValue)"
            return SessionTransition(state: next, effects: [.stopSensors])

        case let (.finalizingRetake, .retakeSaved(takeID, token)):
            try require(token, in: state)
            var next = state
            next.phase = .reviewing
            next.token = nil
            next.retakeTakeID = takeID
            next.diagnosticCode = nil
            return SessionTransition(state: next, effects: [.stopGuidance])

        case let (.finalizingRetake, .retakeFailed(code, token)):
            try require(token, in: state)
            var next = state.abandoning()
            next.phase = .failed
            next.diagnosticCode = code
            return SessionTransition(state: next, effects: [.stopGuidance, .stopSensors])

        case let (.exporting, .exportFinished(projectID, takeID, token)):
            try require(token, in: state)
            guard projectID == state.projectID else {
                throw SessionError.foreignProject(expected: state.projectID, received: projectID)
            }
            var next = state
            next.phase = .reviewing
            next.token = nil
            next.exportedTakeID = takeID
            next.diagnosticCode = nil
            return SessionTransition(state: next, effects: [])

        case let (.exporting, .exportFailed(code, token)):
            try require(token, in: state)
            var next = state.abandoning()
            next.phase = .reviewing
            next.diagnosticCode = code
            return SessionTransition(state: next, effects: [])

        case let (.guiding, .trackingChanged(availability)),
             let (.recordingReference, .trackingChanged(availability)),
             let (.recordingRetake, .trackingChanged(availability)),
             let (.relocalizing, .trackingChanged(availability)),
             let (.finalizingReference, .trackingChanged(availability)),
             let (.finalizingRetake, .trackingChanged(availability)):
            guard !availability.supportsPreciseGuidance else {
                return SessionTransition(state: state, effects: [])
            }
            var transition = try interruptionTransition(state, reason: .trackingLost)
            transition = SessionTransition(
                state: apply(diagnostic: "tracking-\(availability.rawValue)", to: transition.state),
                effects: transition.effects
            )
            return transition

        case (.interrupted, .trackingChanged):
            // Recovery is deliberate: a healthier tracking report never resumes a
            // capture or a guidance session by itself.
            return SessionTransition(state: state, effects: [])

        default:
            throw SessionError.illegalEvent(from: state.phase, event: String(describing: event))
        }
    }

    // MARK: - Shared rules

    private static func interruptionTransition(
        _ state: SessionState,
        reason: InterruptionReason
    ) throws -> SessionTransition {
        var next = state.abandoning()
        next.phase = .interrupted
        next.interruption = reason

        var effects: [SessionEffect] = []
        switch state.phase {
        case .requestingPermission:
            break
        case .preparing:
            effects.append(.releaseCapturePreparation)
        case .recordingReference:
            if let token = state.token { effects.append(.stopReferenceCapture(token: token)) }
            effects.append(.preserveIncompleteTake(takeID: nil))
        case .finalizingReference:
            effects.append(.preserveIncompleteTake(takeID: nil))
        case .recordingRetake:
            if let token = state.token { effects.append(.stopRetakeCapture(token: token)) }
            effects.append(.preserveIncompleteTake(takeID: state.referenceTakeID))
        case .finalizingRetake:
            effects.append(.preserveIncompleteTake(takeID: state.referenceTakeID))
        case .relocalizing:
            if let token = state.token { effects.append(.cancelRelocalization(token: token)) }
        case .exporting:
            if let token = state.token { effects.append(.cancelExport(token: token)) }
            effects.append(.preserveIncompleteTake(takeID: state.referenceTakeID))
        case .guiding, .reviewing:
            effects.append(.stopGuidance)
        case .idle, .ready, .referenceAvailable, .interrupted, .failed:
            break
        }
        effects.append(.stopSensors)
        return SessionTransition(state: next, effects: effects)
    }

    private static func apply(diagnostic: String, to state: SessionState) -> SessionState {
        var next = state
        next.diagnosticCode = diagnostic
        return next
    }

    private static func token(for state: SessionState, action: String) throws -> OperationToken {
        guard let token = state.token else {
            throw SessionError.illegalTransition(from: state.phase, intent: action)
        }
        return token
    }

    private static func require(_ token: OperationToken, in state: SessionState) throws {
        guard let expected = state.token, expected == token else {
            throw SessionError.staleOperation(expected: state.token, received: token)
        }
    }

    private static func isInterruptible(_ phase: SessionPhase) -> Bool {
        switch phase {
        case .requestingPermission, .preparing, .ready, .recordingReference, .finalizingReference,
             .relocalizing, .guiding, .recordingRetake, .finalizingRetake, .reviewing, .exporting:
            return true
        case .idle, .referenceAvailable, .interrupted, .failed:
            return false
        }
    }
}
