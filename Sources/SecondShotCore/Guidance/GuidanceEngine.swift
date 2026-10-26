import Foundation

/// Tolerance policy for guidance cues. These are project thresholds for short,
/// slow moves, not measured physical accuracy.
public struct GuidanceThresholds: Equatable, Sendable {
    public var positionToleranceMeters: Double
    public var rotationToleranceDegrees: Double
    /// Beyond this backward error the honest instruction is to reset rather than
    /// to coax the operator into reversing through the scene.
    public var maximumInPlaceBackstepMeters: Double

    public init(
        positionToleranceMeters: Double = 0.08,
        rotationToleranceDegrees: Double = 4,
        maximumInPlaceBackstepMeters: Double = 0.5
    ) {
        self.positionToleranceMeters = positionToleranceMeters
        self.rotationToleranceDegrees = rotationToleranceDegrees
        self.maximumInPlaceBackstepMeters = maximumInPlaceBackstepMeters
    }

    public static let standard = GuidanceThresholds()

    public func validated() throws -> GuidanceThresholds {
        guard positionToleranceMeters.isFinite, positionToleranceMeters > 0 else {
            throw PoseError.invalidThreshold(name: "positionToleranceMeters", value: positionToleranceMeters)
        }
        guard rotationToleranceDegrees.isFinite, rotationToleranceDegrees > 0 else {
            throw PoseError.invalidThreshold(name: "rotationToleranceDegrees", value: rotationToleranceDegrees)
        }
        guard maximumInPlaceBackstepMeters.isFinite, maximumInPlaceBackstepMeters > 0 else {
            throw PoseError.invalidThreshold(
                name: "maximumInPlaceBackstepMeters",
                value: maximumInPlaceBackstepMeters
            )
        }
        return self
    }
}

/// One primary correction at a time. Directions are expressed in the operator's
/// current camera frame, so "shift left" means toward camera-left, not world -X.
public enum GuidanceCue: String, Sendable, Equatable, CaseIterable {
    case hold
    case shiftLeft
    case shiftRight
    case advanceSlowly
    case easeBack
    case raiseCamera
    case lowerCamera
    case turnLeft
    case turnRight
    case returnToStart

    public var instruction: String {
        switch self {
        case .hold: return "Hold here"
        case .shiftLeft: return "Shift left slightly"
        case .shiftRight: return "Shift right slightly"
        case .advanceSlowly: return "Step forward slowly"
        case .easeBack: return "Ease back a little"
        case .raiseCamera: return "Raise the camera slightly"
        case .lowerCamera: return "Lower the camera slightly"
        case .turnLeft: return "Turn left slightly"
        case .turnRight: return "Turn right slightly"
        case .returnToStart: return "Return to the start marker, then try again"
        }
    }

    /// Spoken hint for VoiceOver; includes a safety reminder for movement cues.
    public var accessibilityHint: String {
        switch self {
        case .hold:
            return "You are within tolerance of the reference position."
        case .returnToStart:
            return "The retake has drifted too far. Turn around when it is clear, then restart."
        default:
            return "Small adjustment. Check your footing and keep the move slow."
        }
    }
}

/// A guidance reading for presentation. `isEstimate` is always true: this is an
/// estimator-driven hint, never a robotic accuracy claim.
public struct GuidanceReading: Equatable, Sendable {
    public let cue: GuidanceCue
    public let translationMeters: Double
    public let rotationDegrees: Double
    public let withinTolerance: Bool
    public let isEstimate: Bool

    public var instruction: String { cue.instruction }

    /// Compact, unit-bearing detail string. Presentation composes the layout.
    public var detail: String {
        String(format: "%.0f cm · %.1f°", translationMeters * 100, rotationDegrees)
    }
}

public enum GuidanceEngine {
    /// Computes exactly one primary correction for the current sample against the
    /// reference sample with the same elapsed time.
    ///
    /// Fails when either sample is invalid, origins differ, or tracking is not
    /// precise. Callers must show an unavailable state instead of stale guidance.
    public static func reading(
        current: PoseSample,
        reference: PoseSample,
        thresholds: GuidanceThresholds = .standard
    ) throws -> GuidanceReading {
        let policy = try thresholds.validated()
        let deviation = try PoseComparator.deviation(reference: reference, candidate: current)

        let withinTolerance = deviation.translationMeters <= policy.positionToleranceMeters
            && deviation.rotationDegrees <= policy.rotationToleranceDegrees

        let cue = withinTolerance
            ? GuidanceCue.hold
            : primaryCue(current: current, reference: reference, thresholds: policy)

        return GuidanceReading(
            cue: cue,
            translationMeters: deviation.translationMeters,
            rotationDegrees: deviation.rotationDegrees,
            withinTolerance: withinTolerance,
            isEstimate: true
        )
    }

    private static func primaryCue(
        current: PoseSample,
        reference: PoseSample,
        thresholds: GuidanceThresholds
    ) -> GuidanceCue {
        // Orientation first: a badly rotated camera makes translation cues lie.
        let targetForward = reference.pose.rotation.rotated(.forward)
        let targetForwardInCurrent = current.pose.rotation.conjugate.rotated(targetForward)
        let signedYaw = atan2(targetForwardInCurrent.x, -targetForwardInCurrent.z) * 180 / .pi

        if abs(signedYaw) > thresholds.rotationToleranceDegrees {
            return signedYaw > 0 ? .turnRight : .turnLeft
        }

        let error = reference.pose.translation - current.pose.translation
        let local = current.pose.rotation.conjugate.rotated(error)
        let horizontal = abs(local.x)
        let vertical = abs(local.y)
        let depth = abs(local.z)

        if horizontal >= vertical && horizontal >= depth {
            return local.x > 0 ? .shiftRight : .shiftLeft
        }
        if vertical >= depth {
            return local.y > 0 ? .raiseCamera : .lowerCamera
        }

        // Camera forward is -Z: a target ahead has negative local Z.
        if local.z < 0 {
            return .advanceSlowly
        }
        return depth <= thresholds.maximumInPlaceBackstepMeters ? .easeBack : .returnToStart
    }
}
