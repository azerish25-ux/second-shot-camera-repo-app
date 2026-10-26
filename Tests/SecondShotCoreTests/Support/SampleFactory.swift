import Foundation
@testable import SecondShotCore

/// Hand-auditable fixtures shared by the domain tests.
enum Fixture {
    static let origin = PoseOriginID("origin-a")
    static let otherOrigin = PoseOriginID("origin-b")
    static let epoch = TrackingEpochID("epoch-a")
    static let otherEpoch = TrackingEpochID("epoch-b")
    static let take = TakeID("take-a")
    static let otherTake = TakeID("take-b")

    static func sample(
        elapsed: Double,
        translation: Vector3 = .zero,
        rotation: Quaternion = .identity,
        tracking: TrackingStatus = .normal,
        origin: PoseOriginID = Fixture.origin,
        epoch: TrackingEpochID = Fixture.epoch,
        take: TakeID = Fixture.take,
        provenance: PoseProvenance = .synthetic,
        sourceTimestamp: Double? = nil
    ) -> PoseSample {
        PoseSample(
            sampleID: SampleID(String(format: "sample-%06.3f", elapsed)),
            takeID: take,
            provenance: provenance,
            sourceTimestamp: sourceTimestamp ?? (500 + elapsed),
            elapsed: elapsed,
            pose: RigidPose(rotation: rotation, translation: translation),
            tracking: tracking,
            origin: origin,
            epoch: epoch,
            convention: .arWorldRightHandedMetersV1
        )
    }

    static func straightTrack(
        count: Int = 9,
        step: Double = 0.25,
        metersPerSecond: Double = 0.2
    ) throws -> PoseTrack {
        let samples = (0..<count).map { index -> PoseSample in
            let elapsed = Double(index) * step
            return sample(elapsed: elapsed, translation: Vector3(x: Double(index) * metersPerSecond * step, y: 0, z: 0))
        }
        return try PoseTrack(samples: samples)
    }
}
