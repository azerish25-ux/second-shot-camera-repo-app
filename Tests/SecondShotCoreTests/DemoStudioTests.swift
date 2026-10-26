import XCTest
@testable import SecondShotCore

final class DemoStudioTests: XCTestCase {
    func testDemoIsLabelledSyntheticEverywhere() throws {
        XCTAssertTrue(DemoStudio.isSynthetic)
        XCTAssertEqual(DemoStudio.sceneTitle, "Tabletop arc")

        let reference = try DemoStudio.referenceTrack()
        let retake = try DemoStudio.retakeTrack()
        XCTAssertTrue(reference.isSynthetic)
        XCTAssertTrue(retake.isSynthetic)
        XCTAssertEqual(reference.provenance, .synthetic)
        XCTAssertTrue(reference.samples.allSatisfy { $0.provenance == .synthetic })
        XCTAssertTrue(retake.samples.allSatisfy { $0.provenance == .synthetic })
    }

    func testReferenceTrackShapeIsDeterministic() throws {
        let first = try DemoStudio.referenceTrack()
        let second = try DemoStudio.referenceTrack()
        XCTAssertEqual(first, second, "Demo fixtures must be reproducible across launches.")

        XCTAssertEqual(first.sampleCount, DemoStudio.sampleCount)
        XCTAssertEqual(first.sampleCount, 25)
        XCTAssertEqual(first.startElapsed, 0, accuracy: 1e-12)
        XCTAssertEqual(first.endElapsed, 6.0, accuracy: 1e-12)
        XCTAssertEqual(first.origin, DemoStudio.origin)
        XCTAssertEqual(first.epoch, DemoStudio.epoch)
        XCTAssertEqual(first.takeID, DemoStudio.referenceTake)
    }

    func testReferenceTrackIsAnArcAroundTheSubject() throws {
        let track = try DemoStudio.referenceTrack()
        let start = try track.sample(atElapsed: track.startElapsed)
        let end = try track.sample(atElapsed: track.endElapsed)

        // A 40° arc at 1.25 m radius is about 0.87 m of travel.
        XCTAssertGreaterThan(track.pathLengthMeters, 0.8)
        XCTAssertGreaterThan(end.pose.translation.x, start.pose.translation.x)

        // Every sample keeps the subject at roughly the arc radius.
        for sample in track.samples {
            let horizontalRadius = (sample.pose.translation.x * sample.pose.translation.x
                + sample.pose.translation.z * sample.pose.translation.z).squareRoot()
            XCTAssertEqual(horizontalRadius, DemoStudio.arcRadiusMeters, accuracy: 1e-9)
            XCTAssertTrue(sample.pose.rotation.isUnit())
        }
    }

    func testRetakeSharesOriginButDiffersSlightly() throws {
        let reference = try DemoStudio.referenceTrack()
        let retake = try DemoStudio.retakeTrack()
        XCTAssertEqual(reference.origin, retake.origin)
        XCTAssertEqual(reference.epoch, retake.epoch)
        XCTAssertNotEqual(reference.takeID, retake.takeID)

        let atEnd = try PoseComparator.deviation(
            reference: reference.sample(atElapsed: 3),
            candidate: retake.sample(atElapsed: 3)
        )
        XCTAssertGreaterThan(atEnd.translationMeters, 0.01)
        XCTAssertLessThan(atEnd.translationMeters, 0.2)
        XCTAssertGreaterThan(atEnd.rotationDegrees, 0.5)
        XCTAssertLessThan(atEnd.rotationDegrees, 10)
    }

    func testRehearsalCuesAreAvailableAcrossTheWholePath() throws {
        var step = 0.0
        while step <= DemoStudio.projectedDurationSeconds {
            let reading = try DemoStudio.rehearsalCues(atElapsed: step)
            XCTAssertTrue(reading.isEstimate)
            XCTAssertFalse(reading.instruction.isEmpty)
            XCTAssertTrue(reading.translationMeters.isFinite)
            XCTAssertGreaterThanOrEqual(reading.rotationDegrees, 0)
            step += 0.5
        }
    }

    func testDemoDoesNotDeclareUnavailableExportAsAvailable() {
        // The scaffold has no export pipeline. The core exposes the reason that
        // the review screen must show instead of an empty success state.
        XCTAssertEqual(DemoStudio.exportUnavailableTitle, "Export is not available yet")
        XCTAssertFalse(DemoStudio.exportUnavailableExplanation.isEmpty)
        XCTAssertTrue(DemoStudio.exportUnavailableExplanation.contains("no recorded footage"))
    }
}
