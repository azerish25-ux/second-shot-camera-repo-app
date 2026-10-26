import Foundation

/// One camera pose in a recorded reference frame.
///
/// `sourceTimestamp` is the raw source clock (ARFrame timestamp on device) and
/// `elapsed` is time since the first accepted frame of the take. Neither is
/// wall-clock time, so a clock change cannot move the recorded timeline.
public struct PoseSample: Equatable, Sendable, Codable {
    public let sampleID: SampleID
    public let takeID: TakeID
    public let provenance: PoseProvenance
    public let sourceTimestamp: Double
    public let elapsed: Double
    public let pose: RigidPose
    public let tracking: TrackingStatus
    public let origin: PoseOriginID
    public let epoch: TrackingEpochID
    public let convention: PoseConvention

    public init(
        sampleID: SampleID,
        takeID: TakeID,
        provenance: PoseProvenance,
        sourceTimestamp: Double,
        elapsed: Double,
        pose: RigidPose,
        tracking: TrackingStatus,
        origin: PoseOriginID,
        epoch: TrackingEpochID,
        convention: PoseConvention = .arWorldRightHandedMetersV1
    ) {
        self.sampleID = sampleID
        self.takeID = takeID
        self.provenance = provenance
        self.sourceTimestamp = sourceTimestamp
        self.elapsed = elapsed
        self.pose = pose
        self.tracking = tracking
        self.origin = origin
        self.epoch = epoch
        self.convention = convention
    }

    public var isSynthetic: Bool { provenance == .synthetic }

    /// Rejects non-finite numbers, negative elapsed time, malformed rotations,
    /// inconsistent tracking states and untracked provenance claiming pose data.
    @discardableResult
    public func validated() throws -> PoseSample {
        guard sourceTimestamp.isFinite else {
            throw PoseError.nonFiniteValue(field: "sourceTimestamp")
        }
        guard elapsed.isFinite else {
            throw PoseError.nonFiniteValue(field: "elapsed")
        }
        guard elapsed >= 0 else {
            throw PoseError.negativeElapsedTime(seconds: elapsed)
        }
        _ = try pose.validated()
        _ = try tracking.validated()
        if provenance == .importedUntracked && tracking.supportsPreciseGuidance {
            throw PoseError.trackingClaimForUntrackedProvenance
        }
        return self
    }

    /// A copy with a different sample identity, used for interpolated values so
    /// derived samples are never mistaken for recorded ones.
    public func withSampleID(_ sampleID: SampleID) -> PoseSample {
        PoseSample(
            sampleID: sampleID,
            takeID: takeID,
            provenance: provenance,
            sourceTimestamp: sourceTimestamp,
            elapsed: elapsed,
            pose: pose,
            tracking: tracking,
            origin: origin,
            epoch: epoch,
            convention: convention
        )
    }
}
