import Foundation

/// Explicit session phases. This is the bootstrap slice of the phase-03
/// lifecycle: it covers the synthetic reference → guidance → retake → review
/// journey and keeps every recording state distinguishable from its saved state.
public enum SessionPhase: String, Sendable, Codable, CaseIterable {
    case idle
    case recordingReference
    case finishingReference
    case referenceReady
    case guiding
    case recordingRetake
    case finishingRetake
    case reviewing
    case interrupted
    case failed

    public var isRecording: Bool {
        self == .recordingReference || self == .recordingRetake
    }

    public var isWorking: Bool {
        isRecording || self == .finishingReference || self == .finishingRetake
    }
}

public enum InterruptionReason: String, Sendable, Codable, CaseIterable {
    case trackingLost
    case appBackgrounded
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

/// User intents. Separate from adapter events so UI code cannot invent completion.
public enum SessionIntent: Equatable, Sendable {
    case beginReference
    case stopReference
    case prepareRetake
    case startRetake
    case stopRetake
    case openReview
    case closeReview
    case interrupt(InterruptionReason)
    case resume
    case retry
    case cancel
}

/// Facts reported by adapters. The reducer decides what they mean.
public enum SessionEvent: Equatable, Sendable {
    case referenceSaved(TakeID)
    case referenceFailed(code: String)
    case retakeSaved(TakeID)
    case retakeFailed(code: String)
    case trackingChanged(TrackingAvailability)
}

/// Declarative work for a platform adapter. The reducer never performs IO.
public enum SessionEffect: Equatable, Sendable {
    case startReferenceCapture
    case stopReferenceCapture
    case discardReferenceCapture
    case startGuidance
    case stopGuidance
    case startRetakeCapture
    case stopRetakeCapture
    case discardRetakeCapture
    case stopSensors
    case preserveIncompleteTake
}

public struct SessionState: Equatable, Sendable {
    public var phase: SessionPhase
    public var referenceTakeID: TakeID?
    public var retakeTakeID: TakeID?
    public var interruption: InterruptionReason?
    /// Content-free diagnostic code for support; never contains media, room or
    /// personal information.
    public var diagnosticCode: String?

    public init(
        phase: SessionPhase = .idle,
        referenceTakeID: TakeID? = nil,
        retakeTakeID: TakeID? = nil,
        interruption: InterruptionReason? = nil,
        diagnosticCode: String? = nil
    ) {
        self.phase = phase
        self.referenceTakeID = referenceTakeID
        self.retakeTakeID = retakeTakeID
        self.interruption = interruption
        self.diagnosticCode = diagnosticCode
    }

    public static let initial = SessionState()

    public var hasReference: Bool { referenceTakeID != nil }
    public var hasRetake: Bool { retakeTakeID != nil }
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

    public var description: String {
        switch self {
        case let .illegalTransition(from, intent):
            return "Intent \(intent) is not valid from \(from.rawValue)."
        case let .illegalEvent(from, event):
            return "Event \(event) is not valid from \(from.rawValue)."
        case .missingReference:
            return "A saved reference take is required first."
        }
    }
}

extension SessionError: CustomStringConvertible {}

public enum SessionReducer {
    /// Pure transition for a user intent. Illegal transitions throw; they never
    /// fall back to a neighbouring state.
    public static func reduce(_ state: SessionState, intent: SessionIntent) throws -> SessionTransition {
        switch (state.phase, intent) {
        case (.idle, .beginReference), (.referenceReady, .beginReference):
            var next = state
            next.phase = .recordingReference
            next.interruption = nil
            next.diagnosticCode = nil
            return SessionTransition(state: next, effects: [.startReferenceCapture])

        case (.recordingReference, .stopReference):
            var next = state
            next.phase = .finishingReference
            return SessionTransition(state: next, effects: [.stopReferenceCapture])

        case (.finishingReference, .stopReference), (.finishingRetake, .stopRetake), (.reviewing, .openReview):
            // Repeated stop/review is idempotent; no duplicate writer commands.
            return SessionTransition(state: state, effects: [])

        case (.referenceReady, .prepareRetake), (.guiding, .prepareRetake):
            guard state.hasReference else { throw SessionError.missingReference }
            var next = state
            next.phase = .guiding
            return SessionTransition(state: next, effects: [.startGuidance])

        case (.guiding, .startRetake):
            guard state.hasReference else { throw SessionError.missingReference }
            var next = state
            next.phase = .recordingRetake
            next.interruption = nil
            return SessionTransition(state: next, effects: [.startRetakeCapture])

        case (.recordingRetake, .stopRetake):
            var next = state
            next.phase = .finishingRetake
            return SessionTransition(state: next, effects: [.stopRetakeCapture])

        case (.reviewing, .closeReview):
            guard state.hasRetake else { throw SessionError.missingReference }
            var next = state
            next.phase = .referenceReady
            return SessionTransition(state: next, effects: [.stopGuidance])

        case (.idle, .cancel), (.referenceReady, .cancel), (.failed, .cancel):
            var next = state
            next.phase = state.hasReference ? .referenceReady : .idle
            next.interruption = nil
            return SessionTransition(state: next, effects: [.stopSensors])

        case (.guiding, .cancel), (.reviewing, .cancel):
            var next = state
            next.phase = .referenceReady
            next.interruption = nil
            return SessionTransition(state: next, effects: [.stopGuidance])

        case (.recordingReference, .cancel):
            var next = state
            next.phase = .idle
            next.diagnosticCode = nil
            return SessionTransition(
                state: next,
                effects: [.stopReferenceCapture, .discardReferenceCapture, .stopSensors]
            )

        case (.recordingRetake, .cancel):
            var next = state
            next.phase = .referenceReady
            next.retakeTakeID = nil
            return SessionTransition(
                state: next,
                effects: [.stopRetakeCapture, .discardRetakeCapture]
            )

        case (.interrupted, .resume), (.failed, .retry):
            var next = state
            next.phase = state.hasReference ? .referenceReady : .idle
            next.interruption = nil
            next.diagnosticCode = nil
            return SessionTransition(state: next, effects: [.stopSensors])

        case (.interrupted, .cancel):
            var next = state
            next.phase = state.hasReference ? .referenceReady : .idle
            next.interruption = nil
            return SessionTransition(state: next, effects: [.stopSensors])

        default:
            if case let .interrupt(reason) = intent, isInterruptible(state.phase) {
                var next = state
                next.phase = .interrupted
                next.interruption = reason
                var effects: [SessionEffect] = []
                switch state.phase {
                case .recordingReference:
                    effects.append(.stopReferenceCapture)
                    effects.append(.preserveIncompleteTake)
                case .recordingRetake:
                    effects.append(.stopRetakeCapture)
                    effects.append(.preserveIncompleteTake)
                case .guiding, .reviewing:
                    effects.append(.stopGuidance)
                default:
                    effects.append(.preserveIncompleteTake)
                }
                effects.append(.stopSensors)
                return SessionTransition(state: next, effects: effects)
            }
            throw SessionError.illegalTransition(from: state.phase, intent: String(describing: intent))
        }
    }

    /// Pure transition for an adapter event.
    public static func reduce(_ state: SessionState, event: SessionEvent) throws -> SessionTransition {
        switch (state.phase, event) {
        case let (.finishingReference, .referenceSaved(takeID)):
            var next = state
            next.phase = .referenceReady
            next.referenceTakeID = takeID
            next.retakeTakeID = nil
            next.diagnosticCode = nil
            return SessionTransition(state: next, effects: [])

        case let (.finishingReference, .referenceFailed(code)):
            var next = state
            next.phase = .failed
            next.diagnosticCode = code
            return SessionTransition(state: next, effects: [.stopSensors])

        case let (.finishingRetake, .retakeSaved(takeID)):
            var next = state
            next.phase = .reviewing
            next.retakeTakeID = takeID
            next.diagnosticCode = nil
            return SessionTransition(state: next, effects: [.stopGuidance])

        case let (.finishingRetake, .retakeFailed(code)):
            var next = state
            next.phase = .failed
            next.diagnosticCode = code
            return SessionTransition(state: next, effects: [.stopSensors, .stopGuidance])

        case let (.recordingReference, .trackingChanged(availability)),
             let (.recordingRetake, .trackingChanged(availability)),
             let (.guiding, .trackingChanged(availability)):
            guard !availability.supportsPreciseGuidance else {
                return SessionTransition(state: state, effects: [])
            }
            var next = state
            next.phase = .interrupted
            next.interruption = .trackingLost
            next.diagnosticCode = "tracking-\(availability.rawValue)"
            var effects: [SessionEffect] = state.phase == .guiding ? [.stopGuidance] : []
            if state.phase.isRecording {
                effects.append(state.phase == .recordingReference ? .stopReferenceCapture : .stopRetakeCapture)
                effects.append(.preserveIncompleteTake)
            }
            effects.append(.stopSensors)
            return SessionTransition(state: next, effects: effects)

        case (.interrupted, .trackingChanged):
            // Tracking recovery is deliberate: it never auto-resumes a capture.
            return SessionTransition(state: state, effects: [])

        default:
            throw SessionError.illegalEvent(from: state.phase, event: String(describing: event))
        }
    }

    private static func isInterruptible(_ phase: SessionPhase) -> Bool {
        switch phase {
        case .recordingReference, .finishingReference, .guiding,
             .recordingRetake, .finishingRetake, .reviewing:
            return true
        case .idle, .referenceReady, .interrupted, .failed:
            return false
        }
    }
}
