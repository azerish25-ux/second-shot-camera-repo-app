import Foundation

/// Unit-quaternion rotation, serialized in `x, y, z, w` order.
///
/// The memberwise initializer is intentionally unchecked so callers can build
/// values for validation; anything entering the domain model must pass
/// `validated()` or `normalized()` first. A zero-norm quaternion is never
/// silently coerced into the identity rotation.
public struct Quaternion: Equatable, Hashable, Sendable, Codable {
    public var x: Double
    public var y: Double
    public var z: Double
    public var w: Double

    public init(x: Double, y: Double, z: Double, w: Double) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    public static let identity = Quaternion(x: 0, y: 0, z: 0, w: 1)

    /// Rotation about a unit axis. Throws for non-finite or zero-length axes.
    public init(axis: Vector3, angleRadians: Double) throws {
        guard axis.isFinite, angleRadians.isFinite else {
            throw PoseError.nonFiniteValue(field: "quaternion")
        }
        let magnitude = axis.length
        guard magnitude > 1e-12 else {
            throw PoseError.degenerateAxis
        }
        let unit = axis / magnitude
        let half = angleRadians / 2
        let s = sin(half)
        self.init(x: unit.x * s, y: unit.y * s, z: unit.z * s, w: cos(half))
    }

    public var isFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite && w.isFinite
    }

    public var normSquared: Double {
        x * x + y * y + z * z + w * w
    }

    public var norm: Double {
        normSquared.squareRoot()
    }

    public func isUnit(tolerance: Double = 1e-6) -> Bool {
        isFinite && abs(norm - 1) <= tolerance
    }

    /// Normalizes the rotation, rejecting zero-length or non-finite values.
    public func normalized() throws -> Quaternion {
        guard isFinite else {
            throw PoseError.nonFiniteValue(field: "quaternion")
        }
        let magnitude = norm
        guard magnitude > 1e-12 else {
            throw PoseError.degenerateQuaternion
        }
        return Quaternion(x: x / magnitude, y: y / magnitude, z: z / magnitude, w: w / magnitude)
    }

    public var conjugate: Quaternion {
        Quaternion(x: -x, y: -y, z: -z, w: w)
    }

    public var negated: Quaternion {
        Quaternion(x: -x, y: -y, z: -z, w: -w)
    }

    public func dot(_ other: Quaternion) -> Double {
        x * other.x + y * other.y + z * other.z + w * other.w
    }

    /// Shortest-arc rotation angle in radians, in `0...pi`.
    public var angleRadians: Double {
        let clamped = min(1, max(0, abs(w) / max(norm, 1e-12)))
        return 2 * acos(clamped)
    }

    /// Applies the rotation to a vector. `q` and `-q` produce the same result.
    public func rotated(_ vector: Vector3) -> Vector3 {
        let axis = Vector3(x: x, y: y, z: z)
        let doubled = axis.cross(vector) * 2
        return vector + doubled * w + axis.cross(doubled)
    }

    /// Composition: `a.concatenating(b)` applies `b` first, then `a`.
    public func concatenating(_ other: Quaternion) -> Quaternion {
        Quaternion(
            x: w * other.x + x * other.w + y * other.z - z * other.y,
            y: w * other.y - x * other.z + y * other.w + z * other.x,
            z: w * other.z + x * other.y - y * other.x + z * other.w,
            w: w * other.w - x * other.x - y * other.y - z * other.z
        )
    }

    /// Shortest-path spherical interpolation. Endpoints are exact.
    public static func slerp(from start: Quaternion, to end: Quaternion, fraction: Double) throws -> Quaternion {
        guard fraction.isFinite, (0...1).contains(fraction) else {
            throw PoseError.invalidInterpolationFraction(fraction)
        }
        let a = try start.normalized()
        var b = try end.normalized()
        var dot = a.dot(b)
        if dot < 0 {
            b = b.negated
            dot = -dot
        }
        dot = min(1, max(-1, dot))

        // Near-collinear rotations: spherical interpolation is ill-conditioned,
        // so fall back to a normalized linear blend (stable and still exact at
        // the endpoints).
        if dot > 1 - 1e-9 {
            let blended = Quaternion(
                x: a.x + (b.x - a.x) * fraction,
                y: a.y + (b.y - a.y) * fraction,
                z: a.z + (b.z - a.z) * fraction,
                w: a.w + (b.w - a.w) * fraction
            )
            return try blended.normalized()
        }

        let theta = acos(dot)
        let sinTheta = sin(theta)
        guard sinTheta > 1e-12 else { return a }
        let weightA = sin((1 - fraction) * theta) / sinTheta
        let weightB = sin(fraction * theta) / sinTheta
        let blended = Quaternion(
            x: a.x * weightA + b.x * weightB,
            y: a.y * weightA + b.y * weightB,
            z: a.z * weightA + b.z * weightB,
            w: a.w * weightA + b.w * weightB
        )
        return try blended.normalized()
    }

    public func isApproximatelyEqual(to other: Quaternion, tolerance: Double = 1e-9) -> Bool {
        // Equivalent rotations include the negated representation.
        let direct = abs(x - other.x) <= tolerance
            && abs(y - other.y) <= tolerance
            && abs(z - other.z) <= tolerance
            && abs(w - other.w) <= tolerance
        let negatedMatch = abs(x + other.x) <= tolerance
            && abs(y + other.y) <= tolerance
            && abs(z + other.z) <= tolerance
            && abs(w + other.w) <= tolerance
        return direct || negatedMatch
    }
}
