import XCTest
@testable import SecondShotCore

final class GuidanceTests: XCTestCase {
    private let reference = Fixture.sample(elapsed: 0)

    private func reading(
        translation: Vector3 = .zero,
        rotation: Quaternion = .identity
    ) throws -> GuidanceReading {
        let current = Fixture.sample(elapsed: 0, translation: translation, rotation: rotation)
        return try GuidanceEngine.reading(current: current, reference: reference)
    }

    func testSmallDifferenceHolds() throws {
        let result = try reading(translation: Vector3(x: 0.02, y: 0.01, z: 0.01))
        XCTAssertEqual(result.cue, .hold)
        XCTAssertTrue(result.withinTolerance)
        XCTAssertTrue(result.isEstimate)
    }

    func testLateralCuesPointTowardTheReference() throws {
        // Standing to the right of the target means shifting left, and vice versa.
        XCTAssertEqual(try reading(translation: Vector3(x: 0.3, y: 0, z: 0)).cue, .shiftLeft)
        XCTAssertEqual(try reading(translation: Vector3(x: -0.3, y: 0, z: 0)).cue, .shiftRight)
    }

    func testVerticalCuesPointTowardTheReference() throws {
        XCTAssertEqual(try reading(translation: Vector3(x: 0, y: 0.3, z: 0)).cue, .lowerCamera)
        XCTAssertEqual(try reading(translation: Vector3(x: 0, y: -0.3, z: 0)).cue, .raiseCamera)
    }

    func testDepthCuesRespectForwardIsNegativeZ() throws {
        // Camera 30 cm behind the reference means the target is ahead: advance.
        XCTAssertEqual(try reading(translation: Vector3(x: 0, y: 0, z: 0.3)).cue, .advanceSlowly)
        // Camera 30 cm past the reference means the target is behind: ease back a little.
        XCTAssertEqual(try reading(translation: Vector3(x: 0, y: 0, z: -0.3)).cue, .easeBack)
    }

    func testFarOvershootAsksForASafeReset() throws {
        let result = try reading(translation: Vector3(x: 0, y: 0, z: -0.9))
        XCTAssertEqual(result.cue, .returnToStart)
        XCTAssertTrue(result.cue.accessibilityHint.contains("Turn around"))
    }

    func testOrientationCueTakesPriorityOverTranslation() throws {
        // Current camera is rotated 20° left of the reference, so the cue is to turn right.
        let turnedLeft = try Quaternion(axis: .up, angleRadians: 20 * .pi / 180)
        XCTAssertEqual(
            try reading(translation: Vector3(x: 0.3, y: 0, z: 0), rotation: turnedLeft).cue,
            .turnRight
        )

        let turnedRight = try Quaternion(axis: .up, angleRadians: -20 * .pi / 180)
        XCTAssertEqual(try reading(rotation: turnedRight).cue, .turnLeft)
    }

    func testCustomThresholdsAreHonoured() throws {
        let tight = GuidanceThresholds(
            positionToleranceMeters: 0.01,
            rotationToleranceDegrees: 0.5,
            maximumInPlaceBackstepMeters: 0.2
        )
        let result = try GuidanceEngine.reading(
            current: Fixture.sample(elapsed: 0, translation: Vector3(x: 0, y: 0, z: 0.05)),
            reference: reference,
            thresholds: tight
        )
        XCTAssertFalse(result.withinTolerance)
        XCTAssertEqual(result.cue, .advanceSlowly)
    }

    func testInvalidThresholdsAreRejected() {
        let invalid = GuidanceThresholds(positionToleranceMeters: 0)
        XCTAssertThrowsError(
            try GuidanceEngine.reading(current: reference, reference: reference, thresholds: invalid)
        )
        let nonFinite = GuidanceThresholds(rotationToleranceDegrees: .nan)
        XCTAssertThrowsError(
            try GuidanceEngine.reading(current: reference, reference: reference, thresholds: nonFinite)
        )
    }

    func testStaleTrackingProducesNoGuidance() {
        let stale = Fixture.sample(elapsed: 0, tracking: .unavailable(.stale))
        XCTAssertThrowsError(try GuidanceEngine.reading(current: stale, reference: reference)) { error in
            XCTAssertEqual(error as? PoseError, .trackingUnusable(availability: .unavailable))
        }
    }

    func testDetailStringUsesCentimetersAndDegrees() throws {
        let result = try reading(translation: Vector3(x: 0.12, y: 0, z: 0))
        XCTAssertTrue(result.detail.contains("cm"))
        XCTAssertTrue(result.detail.contains("°"))
    }
}
