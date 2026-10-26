import XCTest
import SecondShotCore

final class GeometryTests: XCTestCase {
    private let tolerance = 1e-9

    func testIdentityPoseLeavesPointUnchanged() {
        let pose = RigidPose.identity
        XCTAssertTrue(pose.applying(to: Vector3(x: 1, y: -2, z: 3))
            .isApproximatelyEqual(to: Vector3(x: 1, y: -2, z: 3), tolerance: tolerance))
    }

    func testTranslationByOneMeter() throws {
        let pose = RigidPose(
            rotation: .identity,
            translation: Vector3(x: 1, y: 0, z: 0)
        )
        try pose.validated()
        XCTAssertTrue(pose.applying(to: .zero)
            .isApproximatelyEqual(to: Vector3(x: 1, y: 0, z: 0), tolerance: tolerance))
        XCTAssertEqual(PoseComparator.translationErrorMeters(pose, .identity), 1.0, accuracy: tolerance)
    }

    func testQuarterTurnIsNinetyDegrees() throws {
        let rotation = try Quaternion(axis: .up, angleRadians: .pi / 2)
        XCTAssertEqual(PoseComparator.angularErrorDegrees(rotation, .identity), 90, accuracy: 1e-7)
        // Rotating +X by +90° about +Y gives -Z.
        let rotated = rotation.rotated(Vector3(x: 1, y: 0, z: 0))
        XCTAssertTrue(rotated.isApproximatelyEqual(to: Vector3(x: 0, y: 0, z: -1), tolerance: 1e-9))
    }

    func testHalfTurnIsOneHundredEightyDegrees() throws {
        let rotation = try Quaternion(axis: .up, angleRadians: .pi)
        XCTAssertEqual(PoseComparator.angularErrorDegrees(rotation, .identity), 180, accuracy: 1e-7)
    }

    func testQuaternionSignEquivalence() throws {
        let rotation = try Quaternion(axis: Vector3(x: 0.3, y: 0.8, z: 0.5), angleRadians: 0.7)
        let negated = rotation.negated
        XCTAssertTrue(rotation.isApproximatelyEqual(to: negated))
        XCTAssertEqual(PoseComparator.angularErrorDegrees(rotation, negated), 0, accuracy: 1e-12)
        XCTAssertEqual(
            rotation.rotated(Vector3(x: 1, y: 2, z: 3))
                .distance(to: negated.rotated(Vector3(x: 1, y: 2, z: 3))),
            0,
            accuracy: 1e-12
        )
    }

    func testCompositionIsNotCommutative() throws {
        let yaw = try Quaternion(axis: .up, angleRadians: .pi / 2)
        let pitch = try Quaternion(axis: .right, angleRadians: .pi / 2)
        let yawThenPitch = yaw.concatenating(pitch)
        let pitchThenYaw = pitch.concatenating(yaw)
        XCTAssertGreaterThan(PoseComparator.angularErrorDegrees(yawThenPitch, pitchThenYaw), 1)

        // Order is documented: a.concatenating(b) applies b first, then a.
        let point = Vector3(x: 0, y: 0, z: -1)
        let sequential = yaw.rotated(pitch.rotated(point))
        XCTAssertTrue(yawThenPitch.rotated(point).isApproximatelyEqual(to: sequential, tolerance: 1e-9))
    }

    func testInverseRoundTrip() throws {
        let pose = RigidPose(
            rotation: try Quaternion(axis: Vector3(x: 0.2, y: 1, z: 0.1), angleRadians: 0.9),
            translation: Vector3(x: 0.4, y: 1.2, z: -0.7)
        )
        try pose.validated()
        let point = Vector3(x: 0.1, y: 0.2, z: 0.3)
        let restored = pose.inverse.applying(to: pose.applying(to: point))
        XCTAssertTrue(restored.isApproximatelyEqual(to: point, tolerance: 1e-9))
        XCTAssertTrue(pose.concatenating(pose.inverse).isApproximatelyEqual(to: .identity, tolerance: 1e-9))
    }

    func testRotationPreservesLength() throws {
        // Seeded property-style sweep: fixed inputs, no hidden randomness.
        for step in 0..<200 {
            let angle = Double(step) * 0.031
            let axis = Vector3(x: sin(angle), y: cos(angle * 0.7), z: 0.35).normalized()
            let rotation = try Quaternion(axis: axis, angleRadians: angle * 1.7)
            let point = Vector3(x: 0.3, y: -1.2, z: 2.5)
            let rotated = rotation.rotated(point)
            XCTAssertEqual(rotated.length, point.length, accuracy: 1e-9)
        }
    }

    func testDegenerateQuaternionIsRejected() {
        XCTAssertThrowsError(try Quaternion(x: 0, y: 0, z: 0, w: 0).normalized()) { error in
            XCTAssertEqual(error as? PoseError, .degenerateQuaternion)
        }
        XCTAssertThrowsError(try Quaternion(axis: .zero, angleRadians: 1)) { error in
            XCTAssertEqual(error as? PoseError, .degenerateAxis)
        }
        XCTAssertThrowsError(try RigidPose(rotation: Quaternion(x: 0, y: 0, z: 2, w: 2), translation: .zero).validated())
    }

    func testNonFiniteValuesAreRejected() {
        let pose = RigidPose(
            rotation: .identity,
            translation: Vector3(x: .nan, y: 0, z: 0)
        )
        XCTAssertThrowsError(try pose.validated()) { error in
            XCTAssertEqual(error as? PoseError, .nonFiniteValue(field: "translation"))
        }
        XCTAssertFalse(Vector3(x: .infinity, y: 0, z: 0).isFinite)
    }

    func testSlerpEndpointsAndMidpoint() throws {
        let start = Quaternion.identity
        let end = try Quaternion(axis: .up, angleRadians: .pi / 2)

        let atStart = try Quaternion.slerp(from: start, to: end, fraction: 0)
        let atEnd = try Quaternion.slerp(from: start, to: end, fraction: 1)
        XCTAssertTrue(atStart.isApproximatelyEqual(to: start, tolerance: 1e-12))
        XCTAssertTrue(atEnd.isApproximatelyEqual(to: end, tolerance: 1e-12))

        let middle = try Quaternion.slerp(from: start, to: end, fraction: 0.5)
        XCTAssertEqual(PoseComparator.angularErrorDegrees(middle, start), 45, accuracy: 1e-7)
    }

    func testSlerpTakesShortestPathForOppositeSigns() throws {
        let start = Quaternion.identity
        let end = (try Quaternion(axis: .up, angleRadians: .pi / 3)).negated
        let middle = try Quaternion.slerp(from: start, to: end, fraction: 0.5)
        XCTAssertEqual(PoseComparator.angularErrorDegrees(middle, start), 30, accuracy: 1e-7)
    }

    func testSlerpRejectsFractionOutsideRange() {
        XCTAssertThrowsError(try Quaternion.slerp(from: .identity, to: .identity, fraction: 1.5))
        XCTAssertThrowsError(try Quaternion.slerp(from: .identity, to: .identity, fraction: .nan))
    }
}
