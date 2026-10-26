import Foundation

public enum TrackingAvailability: String, Sendable, Codable, CaseIterable {
    case normal
    case limited
    case unavailable

    /// Only `normal` tracking may drive precise guidance. `limited` still needs
    /// a visible warning; it is never presented as reliable.
    public var supportsPreciseGuidance: Bool { self == .normal }
}

public enum TrackingReason: String, Sendable, Codable, CaseIterable {
    case initializing
    case excessiveMotion
    case insufficientFeatures
    case relocalizing
    case interrupted
    case stale
    case notSupported
}

/// Tracking quality plus its cause. Text and shape in the UI both derive from
/// this value; color alone is never the signal.
public struct TrackingStatus: Equatable, Sendable, Codable {
    public let availability: TrackingAvailability
    public let reason: TrackingReason?

    public init(availability: TrackingAvailability, reason: TrackingReason? = nil) {
        self.availability = availability
        self.reason = reason
    }

    public static let normal = TrackingStatus(availability: .normal)

    public static func limited(_ reason: TrackingReason) -> TrackingStatus {
        TrackingStatus(availability: .limited, reason: reason)
    }

    public static func unavailable(_ reason: TrackingReason) -> TrackingStatus {
        TrackingStatus(availability: .unavailable, reason: reason)
    }

    public var supportsPreciseGuidance: Bool {
        availability.supportsPreciseGuidance && reason == nil
    }

    /// Throws when the combination could mislead: `normal` with a failure reason,
    /// or `limited`/`unavailable` with no reason at all.
    public func validated() throws -> TrackingStatus {
        switch availability {
        case .normal:
            if reason != nil {
                throw PoseError.inconsistentTrackingState(availability: availability, reason: reason)
            }
        case .limited, .unavailable:
            if reason == nil {
                throw PoseError.inconsistentTrackingState(availability: availability, reason: reason)
            }
        }
        return self
    }

    /// Severity ordering used when interpolating between two samples.
    var severity: Int {
        switch availability {
        case .normal: return 0
        case .limited: return 1
        case .unavailable: return 2
        }
    }
}
