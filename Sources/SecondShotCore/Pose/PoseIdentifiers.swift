import Foundation

/// Stable, opaque identifier for a persisted reference origin.
///
/// Distinct from the AR session tracking epoch: restoring the same reference
/// frame may happen in a new session with a new epoch.
public struct PoseOriginID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

public struct TrackingEpochID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

public struct TakeID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

public struct SampleID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

public struct ProjectID: Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }
}

/// Where a pose sample came from. Synthetic fixtures can never masquerade as
/// device AR data, and imported untracked footage can never claim tracked poses.
public enum PoseProvenance: String, Sendable, Codable, CaseIterable {
    case synthetic
    case deviceAR
    case importedUntracked
}

/// Named coordinate convention. The value is persisted so a change cannot be
/// silently reinterpreted later.
public enum PoseConvention: String, Sendable, Codable, CaseIterable {
    /// Right-handed, meters, gravity-aligned AR world; camera forward is -Z;
    /// quaternions serialize as x, y, z, w; matrices, when used, are column-major.
    case arWorldRightHandedMetersV1 = "ar-world-rh-m-v1"
}
