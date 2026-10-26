import XCTest
@testable import SecondShot

final class AppFormattingTests: XCTestCase {
    func testCentimetersKeepTheUnit() {
        XCTAssertEqual(AppFormatting.centimeters(0.874), "87 cm")
        XCTAssertEqual(AppFormatting.centimeters(0), "0 cm")
        XCTAssertEqual(AppFormatting.centimeters(.nan), "—")
    }

    func testDegreesUseOneDecimalPlace() {
        XCTAssertEqual(AppFormatting.degrees(1.64), "1.6°")
        XCTAssertEqual(AppFormatting.degrees(.infinity), "—")
    }

    func testClockUsesMinutesSecondsAndTenths() {
        XCTAssertEqual(AppFormatting.clock(0), "00:00.0")
        XCTAssertEqual(AppFormatting.clock(6), "00:06.0")
        XCTAssertEqual(AppFormatting.clock(64.25), "01:04.2")
        XCTAssertEqual(AppFormatting.clock(-2), "00:00.0")
    }

    func testPercentClampsToValidRange() {
        XCTAssertEqual(AppFormatting.percent(0.5), "50%")
        XCTAssertEqual(AppFormatting.percent(1.7), "100%")
        XCTAssertEqual(AppFormatting.percent(-0.2), "0%")
    }
}
