import Foundation

/// Typed domain failures. Errors are values that callers must handle; none of
/// them degrade silently into an identity pose, a zero deviation or a success.
public enum PoseError: Error, Equatable, Sendable {
    case nonFiniteValue(field: String)
    case invalidQuaternionNorm(norm: Double)
    case degenerateQuaternion
    case degenerateAxis
    case negativeElapsedTime(seconds: Double)
    case nonMonotonicTimestamp(index: Int)
    case duplicateTimestamp(index: Int)
    case originMismatch(mine: PoseOriginID, theirs: PoseOriginID)
    case epochMismatch(mine: TrackingEpochID, theirs: TrackingEpochID)
    case mixedTakeIDs(mine: TakeID, theirs: TakeID)
    case mixedProvenance(mine: PoseProvenance, theirs: PoseProvenance)
    case inconsistentTrackingState(availability: TrackingAvailability, reason: TrackingReason?)
    case trackingClaimForUntrackedProvenance
    case trackingUnusable(availability: TrackingAvailability)
    case emptyTrack
    case excessiveSampleCount(limit: Int, count: Int)
    case timeOutsideRecordedRange(start: Double, end: Double, requested: Double)
    case invalidInterpolationFraction(Double)
    case invalidThreshold(name: String, value: Double)
}

extension PoseError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .nonFiniteValue(field):
            return "Non-finite value in \(field)."
        case let .invalidQuaternionNorm(norm):
            return "Quaternion norm \(norm) is not 1."
        case .degenerateQuaternion:
            return "Quaternion has zero length."
        case .degenerateAxis:
            return "Rotation axis has zero length."
        case let .negativeElapsedTime(seconds):
            return "Negative elapsed time \(seconds)."
        case let .nonMonotonicTimestamp(index):
            return "Sample \(index) is not later than its predecessor."
        case let .duplicateTimestamp(index):
            return "Sample \(index) repeats the previous timestamp."
        case let .originMismatch(mine, theirs):
            return "Origin mismatch: \(mine) versus \(theirs)."
        case let .epochMismatch(mine, theirs):
            return "Tracking epoch mismatch: \(mine) versus \(theirs)."
        case let .mixedTakeIDs(mine, theirs):
            return "A track mixed takes: \(mine) versus \(theirs)."
        case let .mixedProvenance(mine, theirs):
            return "A track mixed provenance: \(mine.rawValue) versus \(theirs.rawValue)."
        case let .inconsistentTrackingState(availability, reason):
            return "Tracking \(availability.rawValue) cannot carry reason \(reason?.rawValue ?? "none")."
        case .trackingClaimForUntrackedProvenance:
            return "Imported untracked footage cannot claim tracked poses."
        case let .trackingUnusable(availability):
            return "Tracking is \(availability.rawValue); precise comparison is unavailable."
        case .emptyTrack:
            return "The track contains no samples."
        case let .excessiveSampleCount(limit, count):
            return "Track has \(count) samples, above the \(limit) limit."
        case let .timeOutsideRecordedRange(start, end, requested):
            return "Requested \(requested)s outside the recorded \(start)...\(end)s range."
        case let .invalidInterpolationFraction(fraction):
            return "Interpolation fraction \(fraction) is outside 0...1."
        case let .invalidThreshold(name, value):
            return "Threshold \(name) is invalid (\(value))."
        }
    }
}
