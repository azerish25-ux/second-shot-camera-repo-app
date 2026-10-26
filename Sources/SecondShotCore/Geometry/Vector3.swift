import Foundation

/// A three-dimensional vector in meters when used for translation, or a
/// dimensionless direction when used for axes.
///
/// Coordinate conventions come from `PoseConvention`: right-handed, meters,
/// camera forward is negative Z.
public struct Vector3: Equatable, Hashable, Sendable, Codable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = Vector3(x: 0, y: 0, z: 0)

    /// Camera-forward axis in a camera-local frame.
    public static let forward = Vector3(x: 0, y: 0, z: -1)
    public static let up = Vector3(x: 0, y: 1, z: 0)
    public static let right = Vector3(x: 1, y: 0, z: 0)

    public var isFinite: Bool {
        x.isFinite && y.isFinite && z.isFinite
    }

    public var lengthSquared: Double {
        x * x + y * y + z * z
    }

    public var length: Double {
        lengthSquared.squareRoot()
    }

    public func distance(to other: Vector3) -> Double {
        (self - other).length
    }

    public func dot(_ other: Vector3) -> Double {
        x * other.x + y * other.y + z * other.z
    }

    public func cross(_ other: Vector3) -> Vector3 {
        Vector3(
            x: y * other.z - z * other.y,
            y: z * other.x - x * other.z,
            z: x * other.y - y * other.x
        )
    }

    /// Unit vector in the same direction. Zero-length vectors return `.zero`
    /// rather than a fabricated direction.
    public func normalized() -> Vector3 {
        let magnitude = length
        guard magnitude > 0, magnitude.isFinite else { return .zero }
        return self / magnitude
    }

    public func isApproximatelyEqual(to other: Vector3, tolerance: Double = 1e-9) -> Bool {
        abs(x - other.x) <= tolerance
            && abs(y - other.y) <= tolerance
            && abs(z - other.z) <= tolerance
    }

    public static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    public static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    public static prefix func - (value: Vector3) -> Vector3 {
        Vector3(x: -value.x, y: -value.y, z: -value.z)
    }

    public static func * (lhs: Vector3, rhs: Double) -> Vector3 {
        Vector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    public static func * (lhs: Double, rhs: Vector3) -> Vector3 {
        rhs * lhs
    }

    public static func / (lhs: Vector3, rhs: Double) -> Vector3 {
        Vector3(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
    }
}
