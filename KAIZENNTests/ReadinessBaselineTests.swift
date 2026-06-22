import XCTest
@testable import KAIZENN

final class ReadinessBaselineTests: XCTestCase {

    func testSignalBaselineMeanAndSD() {
        let b = SignalBaseline.from([2, 4, 4, 4, 5, 5, 7, 9])!
        XCTAssertEqual(b.mean, 5, accuracy: 0.001)
        XCTAssertEqual(b.sd, 2, accuracy: 0.001)   // population SD
        XCTAssertEqual(b.n, 8)
    }

    func testSignalBaselineNilBelowMinN() {
        XCTAssertNil(SignalBaseline.from([5], minN: 2))
        XCTAssertNil(SignalBaseline.from([], minN: 2))
    }

    func testSignalBaselineSDFloorAvoidsZero() {
        let b = SignalBaseline.from([5, 5, 5])!   // sd would be 0
        XCTAssertGreaterThan(b.sd, 0)             // floored, never 0 (no div-by-zero downstream)
    }

    func testCalibratingWhenBothHRVAndSleepBelowMinDays() {
        let few = SignalBaseline(mean: 3.9, sd: 0.1, n: 5)
        let base = ReadinessBaseline(hrvLnSDNN: few, restingHR: nil, sleepHours: few)
        XCTAssertTrue(base.isCalibrating)         // n=5 < 14 for both
    }

    func testNotCalibratingWhenSleepHasEnough() {
        let many = SignalBaseline(mean: 7.5, sd: 0.8, n: 20)
        let base = ReadinessBaseline(hrvLnSDNN: nil, restingHR: nil, sleepHours: many)
        XCTAssertFalse(base.isCalibrating)        // sleep n=20 >= 14
    }
}
