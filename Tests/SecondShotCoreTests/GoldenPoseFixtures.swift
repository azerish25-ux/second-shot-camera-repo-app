import XCTest
import SecondShotCore

/// Golden values derived **by hand**, not produced by the implementation under
/// test: every expectation below is either a literal quaternion written in
/// `x, y, z, w` order or a value computed from the rotation matrix for the same
/// rotation. If the core's convention, quaternion order or composition order
/// drifts, these tests disagree with it.
final class GoldenPoseFixtureTests: XCTestCase {
    /// sin(45°) = cos(45°) = √2 / 2, written out to full double precision.
    private let halfSqrtTwo = 0.7071067811865476
    /// 1 / √3, the unit axis shared by all three components of the composed turn.
    private let oneOverSqrtThree = 0.5773502691896258
    private let tolerance = 1e-12

    // MARK: - Literal rotations

    private var quarterTurnAboutX: Quaternion {
        Quaternion(x: halfSqrtTwo, y: 0, z: 0, w: halfSqrtTwo)
    }

    private var quarterTurnAboutY: Quaternion {
        Quaternion(x: 0, y: halfSqrtTwo, z: 0, w: halfSqrtTwo)
    }

    private var quarterTurnAboutZ: Quaternion {
        Quaternion(x: 0, y: 0, z: halfSqrtTwo, w: halfSqrtTwo)
    }

    func testAxisAngleConstructionMatchesLiteralQuaternions() throws {
        XCTAssertTrue(
            try Quaternion(axis: .right, angleRadians: .pi / 2)
                .isApproximatelyEqual(to: quarterTurnAboutX, tolerance: tolerance)
        )
        XCTAssertTrue(
            try Quaternion(axis: .up, angleRadians: .pi / 2)
                .isApproximatelyEqual(to: quarterTurnAboutY, tolerance: tolerance)
        )
        XCTAssertTrue(
            try Quaternion(axis: Vector3(x: 0, y: 0, z: 1), angleRadians: .pi / 2)
                .isApproximatelyEqual(to: quarterTurnAboutZ, tolerance: tolerance)
        )
        // Negative angle about the same axis is the conjugate representation.
        XCTAssertTrue(
            try Quaternion(axis: .up, angleRadians: -.pi / 2)
                .isApproximatelyEqual(to: quarterTurnAboutY.conjugate, tolerance: tolerance)
        )
    }

    func testRotatingAxesWithLiteralQuaternionsMatchesRotationMatrices() {
        // R_y(90°) = [0 0 1; 0 1 0; -1 0 0] maps +X to -Z and +Z to +X.
        XCTAssertTrue(
            quarterTurnAboutY.rotated(.right).isApproximatelyEqual(to: .forward, tolerance: tolerance)
        )
        XCTAssertTrue(
            quarterTurnAboutY.rotated(Vector3(x: 0, y: 0, z: 1))
                .isApproximatelyEqual(to: .right, tolerance: tolerance)
        )
        // R_x(90°) maps +Y to +Z and +Z to -Y.
        XCTAssertTrue(
            quarterTurnAboutX.rotated(.up).isApproximatelyEqual(to: Vector3(x: 0, y: 0, z: 1), tolerance: tolerance)
        )
        XCTAssertTrue(
            quarterTurnAboutX.rotated(Vector3(x: 0, y: 0, z: 1))
                .isApproximatelyEqual(to: Vector3(x: 0, y: -1, z: 0), tolerance: tolerance)
        )
        // R_z(90°) leaves +Z untouched and maps +X to +Y.
        XCTAssertTrue(
            quarterTurnAboutZ.rotated(.right).isApproximatelyEqual(to: .up, tolerance: tolerance)
        )
        XCTAssertTrue(
            quarterTurnAboutZ.rotated(Vector3(x: 0, y: 0, z: 1))
                .isApproximatelyEqual(to: Vector3(x: 0, y: 0, z: 1), tolerance: tolerance)
        )
    }

    // MARK: - Hand-computed composition

    func testComposedQuarterTurnsMatchHandComputedProduct() {
        // q_x ∘ q_z with (w, x, y, z) products written out:
        //   x = wₐx_b + xₐw_b + yₐz_b − zₐy_b = 0.5
        //   y = wₐy_b − xₐz_b + yₐw_b + zₐx_b = −0.5
        //   z = wₐz_b + xₐy_b − yₐx_b + zₐw_b = 0.5
        //   w = wₐw_b − xₐx_b − yₐy_b − zₐz_b = 0.5
        let expected = Quaternion(x: 0.5, y: -0.5, z: 0.5, w: 0.5)
        let actual = quarterTurnAboutX.concatenating(quarterTurnAboutZ)
        XCTAssertTrue(actual.isApproximatelyEqual(to: expected, tolerance: tolerance))

        // That product is a 120° turn: 2·acos(0.5) = 120°, axis (1, −1, 1)/√3.
        XCTAssertEqual(actual.angleRadians * 180 / .pi, 120, accuracy: 1e-9)
        XCTAssertEqual(actual.x / sin(actual.angleRadians / 2), oneOverSqrtThree, accuracy: 1e-12)
        XCTAssertEqual(actual.y / sin(actual.angleRadians / 2), -oneOverSqrtThree, accuracy: 1e-12)
        XCTAssertEqual(actual.z / sin(actual.angleRadians / 2), oneOverSqrtThree, accuracy: 1e-12)
    }

    func testCompositionOrderIsVisibleOnAnActualPoint() {
        // Documented order: a.concatenating(b) applies b first, then a.
        // q_z maps +X to +Y, then q_x maps +Y to +Z: expected (0, 0, 1).
        let zThenX = quarterTurnAboutX.concatenating(quarterTurnAboutZ)
        XCTAssertTrue(
            zThenX.rotated(.right).isApproximatelyEqual(to: Vector3(x: 0, y: 0, z: 1), tolerance: tolerance)
        )
        // The other order applies q_x first, which leaves +X fixed, so +X maps
        // to +Y instead: a measurably different rotation from the same factors.
        let xThenZ = quarterTurnAboutZ.concatenating(quarterTurnAboutX)
        XCTAssertTrue(
            xThenZ.rotated(.right).isApproximatelyEqual(to: .up, tolerance: tolerance)
        )
        // 120° about (1, 1, 1)/√3 versus 120° about (1, −1, 1)/√3: the shortest-arc
        // separation of the two products is 2·acos(0.5) = 120°.
        XCTAssertEqual(
            PoseComparator.angularErrorDegrees(zThenX, xThenZ),
            120,
            accuracy: 1e-9
        )
        XCTAssertGreaterThan(PoseComparator.angularErrorDegrees(zThenX, xThenZ), 90)
    }

    // MARK: - Hand-computed rigid transforms

    func testInverseOfLiteralPoseMatchesHandComputation() throws {
        // Pose: 90° about +Y, translated 1 m along +X. A camera at the origin in
        // its own frame sits at (1, 0, 0) in the parent frame.
        let pose = RigidPose(rotation: quarterTurnAboutY, translation: Vector3(x: 1, y: 0, z: 0))
        try pose.validated()
        XCTAssertTrue(pose.applying(to: .zero).isApproximatelyEqual(to: Vector3(x: 1, y: 0, z: 0), tolerance: tolerance))

        // Inverse rotation is −90° about +Y; its action on (1, 0, 0) is (0, 0, 1)
        // from R_y(−90°) = [0 0 −1; 0 1 0; 1 0 0], so the inverse translation is
        // −(0, 0, 1) = (0, 0, −1).
        let inverse = pose.inverse
        XCTAssertTrue(
            inverse.rotation.isApproximatelyEqual(to: quarterTurnAboutY.conjugate, tolerance: 1e-9)
        )
        XCTAssertTrue(
            inverse.translation.isApproximatelyEqual(to: Vector3(x: 0, y: 0, z: -1), tolerance: 1e-9)
        )
        XCTAssertTrue(inverse.applying(to: Vector3(x: 1, y: 0, z: 0)).isApproximatelyEqual(to: .zero, tolerance: 1e-9))
    }

    func testHandComputedDistanceAndAngleValues() throws {
        // 3–4–5 triangle: 0.3 m and 0.4 m components give exactly 0.5 m.
        let a = RigidPose(rotation: .identity, translation: .zero)
        let b = RigidPose(rotation: .identity, translation: Vector3(x: 0.3, y: 0, z: 0.4))
        XCTAssertEqual(PoseComparator.translationErrorMeters(a, b), 0.5, accuracy: 1e-12)

        // A literal 90° rotation is π/2 radians and 90 degrees at the boundary.
        XCTAssertEqual(quarterTurnAboutX.angleRadians, .pi / 2, accuracy: 1e-12)
        XCTAssertEqual(PoseComparator.angularErrorDegrees(quarterTurnAboutX, .identity), 90, accuracy: 1e-9)
        XCTAssertEqual(PoseComparator.angularErrorDegrees(quarterTurnAboutX.negated, .identity), 90, accuracy: 1e-9)
        XCTAssertEqual(PoseComparator.angularErrorDegrees(.identity, .identity), 0, accuracy: tolerance)
    }
}

/// Deterministic property-style sweeps. Seeds and iteration indices are part of
/// every failure message so a failure can be replayed exactly.
final class PosePropertyTests: XCTestCase {
    /// Small linear congruential generator. Not cryptographic: it exists only to
    /// make "random" sweeps reproducible on every machine and every run.
    private struct SeededRandom {
        private var state: UInt64

        init(seed: UInt64) {
            self.state = seed
        }

        mutating func nextUnit() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let bits = (state >> 11) & 0x1F_FFFF_FFFF_FFFF
            return Double(bits) / Double(0x20_0000_0000_0000)
        }

        mutating func next(in range: ClosedRange<Double>) -> Double {
            range.lowerBound + (range.upperBound - range.lowerBound) * nextUnit()
        }
    }

    private func randomRotation(_ random: inout SeededRandom) throws -> Quaternion {
        // Axes built from a sweep and a fixed offset are never degenerate.
        let angle = random.next(in: -Double.pi...Double.pi)
        let axis = Vector3(
            x: cos(angle),
            y: sin(angle * 0.7),
            z: 0.37
        ).normalized()
        return try Quaternion(axis: axis, angleRadians: random.next(in: -Double.pi...Double.pi))
    }

    private func randomVector(_ random: inout SeededRandom, range: ClosedRange<Double>) -> Vector3 {
        Vector3(
            x: random.next(in: range),
            y: random.next(in: range),
            z: random.next(in: range)
        )
    }

    func testSeededRotationsPreserveVectorLength() throws {
        var random = SeededRandom(seed: 0x1CE)
        for iteration in 0..<300 {
            let rotation = try randomRotation(&random)
            let point = randomVector(&random, range: -5...5)
            let rotated = rotation.rotated(point)
            XCTAssertEqual(
                rotated.length,
                point.length,
                accuracy: 1e-9,
                "seed 0x1CE iteration \(iteration)"
            )
            XCTAssertTrue(rotation.isUnit(tolerance: 1e-9), "seed 0x1CE iteration \(iteration)")
        }
    }

    func testSeededComposedInversesRecoverPoints() throws {
        var random = SeededRandom(seed: 0xC0FFEE)
        for iteration in 0..<300 {
            let pose = RigidPose(
                rotation: try randomRotation(&random),
                translation: randomVector(&random, range: -2...2)
            )
            try pose.validated()
            let point = randomVector(&random, range: -3...3)
            let restored = pose.inverse.applying(to: pose.applying(to: point))
            XCTAssertTrue(
                restored.isApproximatelyEqual(to: point, tolerance: 1e-9),
                "seed 0xC0FFEE iteration \(iteration): \(restored) versus \(point)"
            )
            XCTAssertTrue(
                pose.concatenating(pose.inverse).isApproximatelyEqual(to: .identity, tolerance: 1e-9),
                "seed 0xC0FFEE iteration \(iteration)"
            )
        }
    }

    func testSeededInterpolationStaysBetweenRecordedEndpoints() throws {
        var random = SeededRandom(seed: 0xB0A7)
        for iteration in 0..<200 {
            let startPose = RigidPose(
                rotation: try randomRotation(&random),
                translation: randomVector(&random, range: -2...2)
            )
            let endPose = RigidPose(
                rotation: try randomRotation(&random),
                translation: randomVector(&random, range: -2...2)
            )
            let track = try PoseTrack(samples: [
                Fixture.sample(elapsed: 0, translation: startPose.translation, rotation: startPose.rotation),
                Fixture.sample(elapsed: 1, translation: endPose.translation, rotation: endPose.rotation)
            ])

            let fraction = random.next(in: 0...1)
            let sample = try track.sample(atElapsed: fraction)
            let note = "seed 0xB0A7 iteration \(iteration) fraction \(fraction)"

            XCTAssertEqual(sample.elapsed, fraction, accuracy: 1e-12, note)
            XCTAssertTrue(sample.pose.rotation.isUnit(tolerance: 1e-9), note)

            // Linear interpolation cannot leave the endpoints' bounding box.
            for (name, low, high, value) in [
                ("x", startPose.translation.x, endPose.translation.x, sample.pose.translation.x),
                ("y", startPose.translation.y, endPose.translation.y, sample.pose.translation.y),
                ("z", startPose.translation.z, endPose.translation.z, sample.pose.translation.z)
            ] {
                XCTAssertGreaterThanOrEqual(value, min(low, high) - 1e-12, "\(note) component \(name)")
                XCTAssertLessThanOrEqual(value, max(low, high) + 1e-12, "\(note) component \(name)")
            }

            // The detour through the midpoint cannot exceed the direct distance.
            let detour = sample.pose.translation.distance(to: startPose.translation)
                + sample.pose.translation.distance(to: endPose.translation)
            let direct = startPose.translation.distance(to: endPose.translation)
            XCTAssertLessThanOrEqual(detour, direct + 1e-9, note)

            // Orientation stays within the shortest-arc separation of the ends.
            let separation = PoseComparator.angularErrorDegrees(startPose.rotation, endPose.rotation)
            XCTAssertLessThanOrEqual(
                PoseComparator.angularErrorDegrees(sample.pose.rotation, startPose.rotation),
                separation + 1e-6,
                note
            )
        }
    }

    func testInterpolationInsideAZeroLengthTranslationSegmentKeepsRotation() throws {
        // Two distinct timestamps at the same position: position must not drift
        // and the orientation must still interpolate along the shortest arc.
        let rotation = try Quaternion(axis: .up, angleRadians: .pi / 2)
        let track = try PoseTrack(samples: [
            Fixture.sample(elapsed: 0, translation: Vector3(x: 0.5, y: 1.0, z: -0.25)),
            Fixture.sample(
                elapsed: 0.004,
                translation: Vector3(x: 0.5, y: 1.0, z: -0.25),
                rotation: rotation
            )
        ])
        let mid = try track.sample(atElapsed: 0.002)
        XCTAssertEqual(mid.pose.translation.x, 0.5, accuracy: 1e-12)
        XCTAssertEqual(mid.pose.translation.y, 1.0, accuracy: 1e-12)
        XCTAssertEqual(mid.pose.translation.z, -0.25, accuracy: 1e-12)
        XCTAssertEqual(
            PoseComparator.angularErrorDegrees(mid.pose.rotation, .identity),
            45,
            accuracy: 1e-7
        )
    }
}
