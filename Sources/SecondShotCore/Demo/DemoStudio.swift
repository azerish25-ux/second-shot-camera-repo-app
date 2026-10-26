import Foundation

/// Deterministic, clearly synthetic fixtures for the demo studio.
///
/// Nothing here is camera footage, an AR measurement or evidence of real-world
/// accuracy. The path is an analytic arc around a tabletop subject and every
/// sample is tagged `PoseProvenance.synthetic`.
public enum DemoStudio {
    public static let isSynthetic = true
    public static let sceneTitle = "Tabletop arc"
    public static let sceneSummary =
        "A slow six-second arc around a small still-life. Synthetic poses, no camera access."
    public static let projectedDurationSeconds: Double = 6.0
    public static let sampleIntervalSeconds: Double = 0.25

    /// The scaffold has no media pipeline. Review must show this instead of an
    /// empty share sheet or a fabricated success.
    public static let exportUnavailableTitle = "Export is not available yet"
    public static let exportUnavailableExplanation =
        "This demo contains no recorded footage, so there is nothing to export. Real capture, comparison rendering and export arrive in later phases and require physical-device validation."
    public static let origin = PoseOriginID("demo-origin-tabletop-arc")
    public static let epoch = TrackingEpochID("demo-epoch-01")
    public static let referenceTake = TakeID("demo-reference-take")
    public static let retakeTake = TakeID("demo-retake-take")

    /// Reference-frame radius of the synthetic arc, in meters.
    public static let arcRadiusMeters: Double = 1.25

    public static var sampleCount: Int {
        Int((projectedDurationSeconds / sampleIntervalSeconds).rounded()) + 1
    }

    /// The recorded reference: an arc from camera-left to camera-right with a
    /// small rise toward the end, always facing the tabletop subject.
    public static func referenceTrack() throws -> PoseTrack {
        try PoseTrack(samples: samples(for: referenceTake, lateralOffset: 0, yawOffsetDegrees: 0, pitchDegrees: 0))
    }

    /// A plausible retake: slightly ahead of the reference and rotated a little,
    /// used only to demonstrate comparison math on synthetic input.
    public static func retakeTrack() throws -> PoseTrack {
        try PoseTrack(samples: try retakeSamples())
    }

    public static func referenceSample(atElapsed elapsed: Double) throws -> PoseSample {
        try referenceTrack().sample(atElapsed: elapsed)
    }

    private static func samples(
        for take: TakeID,
        lateralOffset: Double,
        yawOffsetDegrees: Double,
        pitchDegrees: Double
    ) -> [PoseSample] {
        let count = sampleCount
        var result: [PoseSample] = []
        result.reserveCapacity(count)

        for index in 0..<count {
            let elapsed = Double(index) * sampleIntervalSeconds
            let progress = count > 1 ? Double(index) / Double(count - 1) : 0

            // Yaw sweeps -20° to +20° around the subject.
            let yawDegrees = -20 + 40 * progress + yawOffsetDegrees
            let yaw = yawDegrees * .pi / 180

            let radius = arcRadiusMeters + lateralOffset
            let position = Vector3(
                x: radius * sin(yaw),
                y: 1.12 + 0.05 * progress,
                z: radius * cos(yaw)
            )

            // Camera faces the subject (origin) with a slight downward tilt.
            let yawRotation = try? Quaternion(axis: .up, angleRadians: yaw)
            let pitchRotation = try? Quaternion(
                axis: .right,
                angleRadians: (pitchDegrees - 4) * .pi / 180
            )
            let rotation = (yawRotation ?? .identity)
                .concatenating(pitchRotation ?? .identity)

            result.append(
                PoseSample(
                    sampleID: SampleID(String(format: "%@-%03d", take.rawValue, index)),
                    takeID: take,
                    provenance: .synthetic,
                    sourceTimestamp: 1_000 + elapsed,
                    elapsed: elapsed,
                    pose: RigidPose(rotation: rotation, translation: position),
                    tracking: .normal,
                    origin: origin,
                    epoch: epoch,
                    convention: .arWorldRightHandedMetersV1
                )
            )
        }
        return result
    }

    private static func retakeSamples() throws -> [PoseSample] {
        let base = samples(
            for: retakeTake,
            lateralOffset: 0.04,
            yawOffsetDegrees: 1.6,
            pitchDegrees: 1.2
        )
        // Validate the fixture explicitly so it cannot drift into an invalid
        // rotation unnoticed.
        return try base.map { try $0.validated() }
    }

    /// A synthetic "operator" pose that starts slightly off the reference and
    /// converges on it. It exists so the guidance screen exercises real error
    /// maths on labelled demo input; it is not an operator measurement.
    public static func rehearsalSample(atElapsed elapsed: Double) throws -> PoseSample {
        let reference = try referenceSample(atElapsed: elapsed)
        let progress = min(1, max(0, elapsed / projectedDurationSeconds))
        let decay = 1 - progress
        let translation = reference.pose.translation
            + Vector3(x: 0.24 * decay, y: 0.04 * decay, z: 0)
        let pose = RigidPose(rotation: reference.pose.rotation, translation: translation)
        try pose.validated()
        return PoseSample(
            sampleID: SampleID("demo-operator"),
            takeID: retakeTake,
            provenance: .synthetic,
            sourceTimestamp: reference.sourceTimestamp,
            elapsed: elapsed,
            pose: pose,
            tracking: .normal,
            origin: origin,
            epoch: epoch,
            convention: .arWorldRightHandedMetersV1
        )
    }

    /// A short, deterministic cue sequence for the guidance screen, derived from
    /// the real core maths against the reference path.
    public static func rehearsalCues(atElapsed elapsed: Double) throws -> GuidanceReading {
        let reference = try referenceSample(atElapsed: elapsed)
        let current = try rehearsalSample(atElapsed: elapsed)
        return try GuidanceEngine.reading(current: current, reference: reference)
    }
}
