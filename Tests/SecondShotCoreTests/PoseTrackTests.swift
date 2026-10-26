import XCTest
import SecondShotCore

final class PoseTrackTests: XCTestCase {
    func testTrackOrderingAndDerivedValues() throws {
        let track = try Fixture.straightTrack()
        XCTAssertEqual(track.sampleCount, 9)
        XCTAssertEqual(track.startElapsed, 0)
        XCTAssertEqual(track.endElapsed, 2.0, accuracy: 1e-12)
        XCTAssertEqual(track.duration, 2.0, accuracy: 1e-12)
        XCTAssertEqual(track.takeID, Fixture.take)
        XCTAssertEqual(track.provenance, .synthetic)
        XCTAssertTrue(track.isSynthetic)
        // 8 steps of 0.2 m/s * 0.25 s = 0.05 m each.
        XCTAssertEqual(track.pathLengthMeters, 0.4, accuracy: 1e-9)
    }

    func testInterpolationEndpointsAreRecordedSamples() throws {
        let track = try Fixture.straightTrack()
        let first = try track.sample(atElapsed: 0)
        let last = try track.sample(atElapsed: 2.0)
        XCTAssertEqual(first.sampleID, track.samples[0].sampleID)
        XCTAssertEqual(last.sampleID, track.samples[track.sampleCount - 1].sampleID)
        // A tiny numerical overshoot still resolves to the endpoint, never extrapolates.
        XCTAssertEqual(try track.sample(atElapsed: -1e-12).sampleID, track.samples[0].sampleID)
        XCTAssertEqual(try track.sample(atElapsed: 2.0 + 1e-12).sampleID, track.samples[track.sampleCount - 1].sampleID)
    }

    func testInterpolationMidpoint() throws {
        let track = try Fixture.straightTrack()
        let mid = try track.sample(atElapsed: 0.125)
        XCTAssertEqual(mid.elapsed, 0.125, accuracy: 1e-12)
        XCTAssertEqual(mid.pose.translation.x, 0.025, accuracy: 1e-12)
        XCTAssertEqual(mid.pose.translation.y, 0, accuracy: 1e-12)
        XCTAssertEqual(mid.pose.translation.z, 0, accuracy: 1e-12)
        XCTAssertTrue(mid.isSynthetic)
    }

    func testInterpolationRotatesAlongShortestArc() throws {
        let start = Fixture.sample(elapsed: 0, translation: Vector3(x: 0, y: 1, z: 0), rotation: .identity)
        let quarter = try Quaternion(axis: .up, angleRadians: .pi / 2)
        let end = Fixture.sample(elapsed: 1, translation: Vector3(x: 1, y: 1, z: 0), rotation: quarter)
        let track = try PoseTrack(samples: [start, end])

        let mid = try track.sample(atElapsed: 0.5)
        XCTAssertEqual(mid.pose.translation.x, 0.5, accuracy: 1e-12)
        XCTAssertEqual(PoseComparator.angularErrorDegrees(mid.pose.rotation, .identity), 45, accuracy: 1e-7)
    }

    func testInterpolationKeepsWorstTrackingState() throws {
        let limited = Fixture.sample(
            elapsed: 1,
            translation: Vector3(x: 1, y: 0, z: 0),
            tracking: .limited(.insufficientFeatures)
        )
        let start = Fixture.sample(elapsed: 0)
        let track = try PoseTrack(samples: [start, limited])
        let mid = try track.sample(atElapsed: 0.5)
        XCTAssertEqual(mid.tracking, .limited(.insufficientFeatures))
        XCTAssertFalse(mid.tracking.supportsPreciseGuidance)
        XCTAssertThrowsError(try GuidanceEngine.reading(current: mid, reference: start))
    }

    func testDuplicateAndDescendingTimestampsAreRejected() {
        let a = Fixture.sample(elapsed: 1)
        let duplicate = Fixture.sample(elapsed: 1, translation: Vector3(x: 1, y: 0, z: 0))
        XCTAssertThrowsError(try PoseTrack(samples: [a, duplicate])) { error in
            XCTAssertEqual(error as? PoseError, .duplicateTimestamp(index: 1))
        }

        let descending = Fixture.sample(elapsed: 0.5)
        XCTAssertThrowsError(try PoseTrack(samples: [a, descending])) { error in
            XCTAssertEqual(error as? PoseError, .nonMonotonicTimestamp(index: 1))
        }
    }

    func testMixedOriginEpochTakeAndProvenanceAreRejected() {
        let first = Fixture.sample(elapsed: 0)
        let otherOrigin = Fixture.sample(elapsed: 1, origin: Fixture.otherOrigin)
        XCTAssertThrowsError(try PoseTrack(samples: [first, otherOrigin])) { error in
            XCTAssertEqual(error as? PoseError, .originMismatch(mine: Fixture.origin, theirs: Fixture.otherOrigin))
        }

        let otherEpoch = Fixture.sample(elapsed: 1, epoch: Fixture.otherEpoch)
        XCTAssertThrowsError(try PoseTrack(samples: [first, otherEpoch])) { error in
            XCTAssertEqual(error as? PoseError, .epochMismatch(mine: Fixture.epoch, theirs: Fixture.otherEpoch))
        }

        let otherTake = Fixture.sample(elapsed: 1, take: Fixture.otherTake)
        XCTAssertThrowsError(try PoseTrack(samples: [first, otherTake])) { error in
            XCTAssertEqual(error as? PoseError, .mixedTakeIDs(mine: Fixture.take, theirs: Fixture.otherTake))
        }

        let device = Fixture.sample(elapsed: 1, provenance: .deviceAR)
        XCTAssertThrowsError(try PoseTrack(samples: [first, device])) { error in
            XCTAssertEqual(error as? PoseError, .mixedProvenance(mine: .synthetic, theirs: .deviceAR))
        }
    }

    func testEmptyAndOversizedTracksAreRejectedBeforeAllocation() {
        XCTAssertThrowsError(try PoseTrack(samples: [])) { error in
            XCTAssertEqual(error as? PoseError, .emptyTrack)
        }
        let samples = [Fixture.sample(elapsed: 0), Fixture.sample(elapsed: 1)]
        XCTAssertThrowsError(try PoseTrack(samples: samples, sampleLimit: 1)) { error in
            XCTAssertEqual(error as? PoseError, .excessiveSampleCount(limit: 1, count: 2))
        }
    }

    func testOutOfRangeRequestFailsInsteadOfExtrapolating() throws {
        let track = try Fixture.straightTrack()
        XCTAssertThrowsError(try track.sample(atElapsed: 2.5)) { error in
            XCTAssertEqual(
                error as? PoseError,
                .timeOutsideRecordedRange(start: 0, end: 2.0, requested: 2.5)
            )
        }
        XCTAssertThrowsError(try track.sample(atElapsed: .nan))
    }

    func testNegativeAndNonFiniteSamplesAreRejected() {
        XCTAssertThrowsError(try Fixture.sample(elapsed: -1).validated()) { error in
            XCTAssertEqual(error as? PoseError, .negativeElapsedTime(seconds: -1))
        }
        XCTAssertThrowsError(try Fixture.sample(elapsed: 0, sourceTimestamp: .nan).validated())
        XCTAssertThrowsError(
            try Fixture.sample(elapsed: 0, translation: Vector3(x: 0, y: .infinity, z: 0)).validated()
        )
    }

    func testUntrackedProvenanceCannotClaimTrackedPoses() {
        XCTAssertThrowsError(try Fixture.sample(elapsed: 0, provenance: .importedUntracked).validated()) { error in
            XCTAssertEqual(error as? PoseError, .trackingClaimForUntrackedProvenance)
        }
        let untracked = Fixture.sample(
            elapsed: 0,
            tracking: .unavailable(.notSupported),
            provenance: .importedUntracked
        )
        XCTAssertNoThrow(try untracked.validated())
    }

    func testInconsistentTrackingStatesAreRejected() {
        XCTAssertThrowsError(try TrackingStatus(availability: .normal, reason: .stale).validated())
        XCTAssertThrowsError(try TrackingStatus(availability: .limited).validated())
    }

    func testLargeNonuniformFixtureRemainsQueryable() throws {
        // 4000 samples with nonuniform cadence, followed by 500 seeded queries.
        var samples: [PoseSample] = []
        samples.reserveCapacity(4_000)
        var elapsed = 0.0
        for index in 0..<4_000 {
            if index > 0 { elapsed += 0.004 + Double(index % 7) * 0.0005 }
            let angle = Double(index) * 0.001
            let rotation = try Quaternion(axis: .up, angleRadians: angle)
            samples.append(
                Fixture.sample(
                    elapsed: elapsed,
                    translation: Vector3(x: sin(angle), y: 1.2, z: cos(angle) * 1.4),
                    rotation: rotation
                )
            )
        }
        let track = try PoseTrack(samples: samples)
        var state: UInt64 = 0x5EED
        for _ in 0..<500 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let fraction = Double(state % 10_000) / 10_000.0
            let query = track.startElapsed + (track.endElapsed - track.startElapsed) * fraction
            let sample = try track.sample(atElapsed: query)
            XCTAssertEqual(sample.elapsed, query, accuracy: 1e-9)
            XCTAssertTrue(sample.pose.translation.isFinite)
            XCTAssertTrue(sample.pose.rotation.isUnit(tolerance: 1e-6))
        }
        XCTAssertEqual(track.sampleCount, 4_000)
    }
}
