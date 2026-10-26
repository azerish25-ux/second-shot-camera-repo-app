import XCTest
import SecondShotCore

final class PoseComparisonTests: XCTestCase {
    func testIdenticalPosesHaveZeroDeviation() throws {
        let sample = Fixture.sample(elapsed: 1.5, translation: Vector3(x: 0.3, y: 1.2, z: -0.4))
        let deviation = try PoseComparator.deviation(reference: sample, candidate: sample)
        XCTAssertEqual(deviation.translationMeters, 0, accuracy: 1e-12)
        XCTAssertEqual(deviation.rotationDegrees, 0, accuracy: 1e-12)
        XCTAssertTrue(deviation.isFinite)
    }

    func testOneMeterTranslation() throws {
        let reference = Fixture.sample(elapsed: 0)
        let candidate = Fixture.sample(elapsed: 0, translation: Vector3(x: 0, y: 0, z: 1))
        let deviation = try PoseComparator.deviation(reference: reference, candidate: candidate)
        XCTAssertEqual(deviation.translationMeters, 1, accuracy: 1e-12)
        XCTAssertEqual(deviation.rotationDegrees, 0, accuracy: 1e-12)
    }

    func testNinetyAndOneHundredEightyDegreeRotations() throws {
        let reference = Fixture.sample(elapsed: 0)
        let ninety = Fixture.sample(
            elapsed: 0,
            rotation: try Quaternion(axis: .up, angleRadians: .pi / 2)
        )
        let oneEighty = Fixture.sample(
            elapsed: 0,
            rotation: try Quaternion(axis: .up, angleRadians: .pi)
        )
        XCTAssertEqual(
            try PoseComparator.deviation(reference: reference, candidate: ninety).rotationDegrees,
            90,
            accuracy: 1e-7
        )
        XCTAssertEqual(
            try PoseComparator.deviation(reference: reference, candidate: oneEighty).rotationDegrees,
            180,
            accuracy: 1e-7
        )
    }

    func testOppositeQuaternionRepresentationHasZeroError() throws {
        let rotation = try Quaternion(axis: Vector3(x: 0.1, y: 1, z: 0.2), angleRadians: 1.1)
        let reference = Fixture.sample(elapsed: 0, rotation: rotation)
        let candidate = Fixture.sample(elapsed: 0, rotation: rotation.negated)
        let deviation = try PoseComparator.deviation(reference: reference, candidate: candidate)
        XCTAssertEqual(deviation.rotationDegrees, 0, accuracy: 1e-12)
    }

    func testMixedOriginsAreRejected() {
        let reference = Fixture.sample(elapsed: 0)
        let candidate = Fixture.sample(elapsed: 0, origin: Fixture.otherOrigin)
        XCTAssertThrowsError(try PoseComparator.deviation(reference: reference, candidate: candidate)) { error in
            XCTAssertEqual(
                error as? PoseError,
                .originMismatch(mine: Fixture.origin, theirs: Fixture.otherOrigin)
            )
        }
    }

    func testTrackingThatIsNotPreciseCannotProduceADeviation() {
        let reference = Fixture.sample(elapsed: 0)
        let limited = Fixture.sample(elapsed: 0, tracking: .limited(.excessiveMotion))
        XCTAssertThrowsError(try PoseComparator.deviation(reference: reference, candidate: limited)) { error in
            XCTAssertEqual(error as? PoseError, .trackingUnusable(availability: .limited))
        }

        let referenceLimited = Fixture.sample(elapsed: 0, tracking: .unavailable(.stale))
        XCTAssertThrowsError(try PoseComparator.deviation(reference: referenceLimited, candidate: reference)) { error in
            XCTAssertEqual(error as? PoseError, .trackingUnusable(availability: .unavailable))
        }
    }

    func testInvalidPoseCannotBeCompared() {
        let reference = Fixture.sample(elapsed: 0)
        let invalid = Fixture.sample(elapsed: 0, rotation: Quaternion(x: 0, y: 0, z: 0, w: 0))
        XCTAssertThrowsError(try PoseComparator.deviation(reference: reference, candidate: invalid)) { error in
            XCTAssertEqual(error as? PoseError, .degenerateQuaternion)
        }
    }
}
