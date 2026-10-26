import Foundation

/// A rigid transform stored as `rotation` plus `translation` in meters.
///
/// Naming convention: `destinationFromSource`. `pose.applying(point)` maps a
/// source-local point into the destination frame.
public struct RigidPose: Equatable, Sendable, Codable {
    public let rotation: Quaternion
    public let translation: Vector3

    public init(rotation: Quaternion, translation: Vector3) {
        self.rotation = rotation
        self.translation = translation
    }

    public static let identity = RigidPose(rotation: .identity, translation: .zero)

    /// Throws when any component is non-finite or the rotation is not a usable
    /// unit quaternion. Never returns an identity substitute.
    public func validated(tolerance: Double = 1e-6) throws -> RigidPose {
        guard translation.isFinite else {
            throw PoseError.nonFiniteValue(field: "translation")
        }
        guard rotation.isFinite else {
            throw PoseError.nonFiniteValue(field: "rotation")
        }
        guard rotation.norm > 1e-12 else {
            throw PoseError.degenerateQuaternion
        }
        guard rotation.isUnit(tolerance: tolerance) else {
            throw PoseError.invalidQuaternionNorm(norm: rotation.norm)
        }
        return self
    }

    /// True rigid inverse. Uses the quaternion conjugate over the squared norm so
    /// that an unnormalized (but finite) rotation cannot silently invert wrongly.
    public var inverse: RigidPose {
        let inverseRotation = rotation.conjugate / max(rotation.normSquared, 1e-12)
        return RigidPose(rotation: inverseRotation, translation: -inverseRotation.rotated(translation))
    }

    /// Applies the rotation and translation to a source-local point.
    public func applying(to point: Vector3) -> Vector3 {
        rotation.rotated(point) + translation
    }

    /// Composition: `self` after `other` (apply `other` first).
    public func concatenating(_ other: RigidPose) -> RigidPose {
        RigidPose(
            rotation: rotation.concatenating(other.rotation),
            translation: rotation.rotated(other.translation) + translation
        )
    }

    public func isApproximatelyEqual(to other: RigidPose, tolerance: Double = 1e-9) -> Bool {
        rotation.isApproximatelyEqual(to: other.rotation, tolerance: tolerance)
            && translation.isApproximatelyEqual(to: other.translation, tolerance: tolerance)
    }
}

extension Quaternion {
    static func / (lhs: Quaternion, rhs: Double) -> Quaternion {
        Quaternion(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs, w: lhs.w / rhs)
    }
}
