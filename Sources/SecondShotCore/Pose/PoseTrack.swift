import Foundation

/// An ordered, validated pose sequence from exactly one take, origin and
/// tracking epoch.
///
/// Interpolation is timestamp-bracketed linear position plus shortest-path
/// spherical orientation. Nothing is extrapolated: asking for time outside the
/// recorded range is a typed failure, not a wrap-around or a clamped guess.
public struct PoseTrack: Equatable, Sendable {
    public static let defaultSampleLimit = 50_000

    public let samples: [PoseSample]

    public init(samples: [PoseSample], sampleLimit: Int = PoseTrack.defaultSampleLimit) throws {
        guard sampleLimit > 0 else {
            throw PoseError.invalidThreshold(name: "sampleLimit", value: Double(sampleLimit))
        }
        guard !samples.isEmpty else {
            throw PoseError.emptyTrack
        }
        guard samples.count <= sampleLimit else {
            throw PoseError.excessiveSampleCount(limit: sampleLimit, count: samples.count)
        }

        let first = samples[0]
        try first.validated()

        for index in 1..<samples.count {
            let previous = samples[index - 1]
            let current = samples[index]
            try current.validated()

            if current.elapsed == previous.elapsed {
                throw PoseError.duplicateTimestamp(index: index)
            }
            if current.elapsed < previous.elapsed {
                throw PoseError.nonMonotonicTimestamp(index: index)
            }
            if current.origin != first.origin {
                throw PoseError.originMismatch(mine: first.origin, theirs: current.origin)
            }
            if current.epoch != first.epoch {
                throw PoseError.epochMismatch(mine: first.epoch, theirs: current.epoch)
            }
            if current.takeID != first.takeID {
                throw PoseError.mixedTakeIDs(mine: first.takeID, theirs: current.takeID)
            }
            if current.provenance != first.provenance {
                throw PoseError.mixedProvenance(mine: first.provenance, theirs: current.provenance)
            }
        }

        self.samples = samples
    }

    public var startElapsed: Double { samples[0].elapsed }
    public var endElapsed: Double { samples[samples.count - 1].elapsed }
    public var duration: Double { endElapsed - startElapsed }
    public var origin: PoseOriginID { samples[0].origin }
    public var epoch: TrackingEpochID { samples[0].epoch }
    public var takeID: TakeID { samples[0].takeID }
    public var provenance: PoseProvenance { samples[0].provenance }
    public var isSynthetic: Bool { provenance == .synthetic }
    public var sampleCount: Int { samples.count }

    /// Total recorded path length in meters. Useful for a truthful demo metric;
    /// it is a geometric property, not an accuracy claim.
    public var pathLengthMeters: Double {
        guard samples.count > 1 else { return 0 }
        var total = 0.0
        for index in 1..<samples.count {
            total += samples[index].pose.translation.distance(to: samples[index - 1].pose.translation)
        }
        return total
    }

    /// Interpolates at an elapsed time inside the recorded range.
    public func sample(atElapsed elapsed: Double) throws -> PoseSample {
        guard elapsed.isFinite else {
            throw PoseError.nonFiniteValue(field: "elapsed")
        }
        let tolerance = 1e-9
        guard elapsed >= startElapsed - tolerance, elapsed <= endElapsed + tolerance else {
            throw PoseError.timeOutsideRecordedRange(
                start: startElapsed,
                end: endElapsed,
                requested: elapsed
            )
        }

        if elapsed <= startElapsed { return samples[0] }
        if elapsed >= endElapsed { return samples[samples.count - 1] }

        // Exact match wins, so callers get recorded identities for recorded times.
        var low = 0
        var high = samples.count - 1
        while low <= high {
            let middle = (low + high) / 2
            let candidate = samples[middle].elapsed
            if candidate == elapsed { return samples[middle] }
            if candidate < elapsed {
                low = middle + 1
            } else {
                high = middle - 1
            }
        }

        // `high` is the last sample before `elapsed`, `low` the first after it.
        let before = samples[max(0, high)]
        let after = samples[min(samples.count - 1, low)]
        let span = after.elapsed - before.elapsed
        guard span > 0 else { return before }

        let fraction = (elapsed - before.elapsed) / span
        let translation = before.pose.translation
            + (after.pose.translation - before.pose.translation) * fraction
        let rotation = try Quaternion.slerp(
            from: before.pose.rotation,
            to: after.pose.rotation,
            fraction: fraction
        )
        let tracking = worseTracking(before.tracking, after.tracking)
        let sourceTimestamp = before.sourceTimestamp
            + (after.sourceTimestamp - before.sourceTimestamp) * fraction

        let pose = RigidPose(rotation: rotation, translation: translation)
        try pose.validated()

        return PoseSample(
            sampleID: SampleID("\(before.sampleID.rawValue)+interp"),
            takeID: before.takeID,
            provenance: before.provenance,
            sourceTimestamp: sourceTimestamp,
            elapsed: elapsed,
            pose: pose,
            tracking: tracking,
            origin: before.origin,
            epoch: before.epoch,
            convention: before.convention
        )
    }

    /// The more cautious of two tracking states; uncertainty is never averaged
    /// away by an adjacent healthy sample.
    private func worseTracking(_ a: TrackingStatus, _ b: TrackingStatus) -> TrackingStatus {
        if a.severity == b.severity { return a }
        return a.severity > b.severity ? a : b
    }
}
