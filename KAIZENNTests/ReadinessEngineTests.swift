import XCTest
@testable import KAIZENN

final class ReadinessEngineTests: XCTestCase {

    func testSleepScoreCapsAtEightHours() {
        XCTAssertEqual(ReadinessEngine.sleepScore(8), 100, accuracy: 0.001)
        XCTAssertEqual(ReadinessEngine.sleepScore(4), 50, accuracy: 0.001)
        XCTAssertEqual(ReadinessEngine.sleepScore(10), 100, accuracy: 0.001) // capped
    }

    func testLoadScoreSweetSpotAndPenalty() {
        XCTAssertEqual(ReadinessEngine.loadScore(0), 75, accuracy: 0.001)   // unknown
        XCTAssertEqual(ReadinessEngine.loadScore(1.0), 100, accuracy: 0.001) // in 0.8...1.3
        // acwr 1.4 -> delta 0.1 -> 100 - 10 = 90
        XCTAssertEqual(ReadinessEngine.loadScore(1.4), 90, accuracy: 0.001)
    }

    func testFuelScoreHalfCaloriesHalfProtein() {
        // full calories, zero protein -> 50
        XCTAssertEqual(ReadinessEngine.fuelScore(consumedCalories: 2300, calorieTarget: 2300, proteinConsumed: 0, proteinTarget: 150), 50, accuracy: 0.001)
        // invalid targets -> 50 fallback
        XCTAssertEqual(ReadinessEngine.fuelScore(consumedCalories: 100, calorieTarget: 0, proteinConsumed: 10, proteinTarget: 0), 50, accuracy: 0.001)
    }

    func testHRVScoreAbsentReturns75() {
        XCTAssertEqual(ReadinessEngine.hrvScore(latest: nil, baseline: 50), 75, accuracy: 0.001)
        XCTAssertEqual(ReadinessEngine.hrvScore(latest: 50, baseline: nil), 75, accuracy: 0.001)
        XCTAssertEqual(ReadinessEngine.hrvScore(latest: 50, baseline: 50), 75, accuracy: 0.001) // at baseline
    }

    func testLabelBoundaries() {
        XCTAssertEqual(ReadinessEngine.label(for: 80), .peak)
        XCTAssertEqual(ReadinessEngine.label(for: 79), .gameReady)
        XCTAssertEqual(ReadinessEngine.label(for: 60), .gameReady)
        XCTAssertEqual(ReadinessEngine.label(for: 40), .build)
        XCTAssertEqual(ReadinessEngine.label(for: 39), .recovery)
    }

    func testBreakdownDropsHRVWeightingWhenAbsent() {
        // No HRV -> 3-pillar 0.33/0.33/0.34. All pillars 100 -> ~100.
        let inputs = ReadinessInputs(sleepHours: 8, acwr: 1.0,
            consumedCalories: 2300, calorieTarget: 2300,
            proteinConsumed: 150, proteinTarget: 150,
            hrvLatestMs: nil, hrvBaselineMs: nil)
        let b = ReadinessEngine.breakdown(for: inputs)
        XCTAssertFalse(b.hrvAvailable)
        XCTAssertEqual(b.score, 100)
        XCTAssertEqual(b.label, .peak)
    }
}
