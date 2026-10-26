import Foundation

/// Measured difference between two camera poses in the same reference frame.
/// Distances are meters; angles are degrees only at this presentation boundary.
public struct PoseDeviation: Equatable, Sendable {
    public let translationMeters: Double
    public let rotationDegrees: Double

    public init(translationMeters: Double, rotationDegrees: Double) {
        self.translationMeters = translationMeters
        self.rotationDegrees = rotationDegrees
    }

    public var isFinite: Bool {
        translationMeters.isFinite && rotationDegrees.isFinite
    }
}

public enum PoseComparator {
    /// Euclidean distance between two camera centers in meters.
    public static func translationErrorMeters(_ a: RigidPose, _ b: RigidPose) -> Double {
        a.translation.distance(to: b.translation)
    }

    /// Shortest equivalent rotation in degrees, in `0...180`.
    ///
    /// Equivalent quaternions `q` and `-q` produce exactly zero.
    public static func angularErrorDegrees(_ a: Quaternion, _ b: Quaternion) -> Double {
        guard let normalizedA = try? a.normalized(), let normalizedB = try? b.normalized() else {
            return .nan
        }
        let dot = abs(normalizedA.dot(normalizedB))
        let clamped = min(1, max(0, dot))
        return 2 * acos(clamped) * 180 / .pi
    }

    /// Compares two samples only when their provenance, origin and tracking
    /// quality permit a meaningful answer.
    public static func deviation(reference: PoseSample, candidate: PoseSample) throws -> PoseDeviation {
        try reference.validated()
        try candidate.validated()

        guard reference.origin == candidate.origin else {
            throw PoseError.originMismatch(mine: reference.origin, theirs: candidate.origin)
        }
        guard reference.tracking.supportsPreciseGuidance else {
            throw PoseError.trackingUnusable(availability: reference.tracking.availability)
        }
        guard candidate.tracking.supportsPreciseGuidance else {
            throw PoseError.trackingUnusable(availability: candidate.tracking.availability)
        }

        let translation = translationErrorMeters(reference.pose, candidate.pose)
        let rotation = angularErrorDegrees(reference.pose.rotation, candidate.pose.rotation)
        guard translation.isFinite, rotation.isFinite else {
            throw PoseError.nonFiniteValue(field: "deviation")
        }
        return PoseDeviation(translationMeters: translation, rotationDegrees: rotation)
    }
}
