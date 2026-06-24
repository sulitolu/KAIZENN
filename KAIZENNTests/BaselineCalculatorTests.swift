// KAIZENNTests/BaselineCalculatorTests.swift
import XCTest
import Foundation
@testable import KAIZENN

@MainActor
final class BaselineCalculatorTests: XCTestCase {
    private func snap(_ daysAgo: Int, hrv: Double?, rhr: Double?, sleepMin: Double?) -> DailyHealthSnapshot {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let s = DailyHealthSnapshot(dayKey: HealthStore.dayKey(for: date), date: date)
        s.hrvSDNN = hrv; s.restingHR = rhr; s.sleepDurationMinutes = sleepMin
        return s
    }

    func test_signalBaseline_meanAndSD() {
        let b = BaselineCalculator.signalBaseline([2, 4, 6])
        XCTAssertEqual(b?.mean ?? 0, 4, accuracy: 0.0001)
        XCTAssertEqual(b?.sd ?? 0, 2, accuracy: 0.0001)   // sample SD, n-1
        XCTAssertEqual(b?.n, 3)
    }

    func test_signalBaseline_emptyIsNil() {
        XCTAssertNil(BaselineCalculator.signalBaseline([]))
    }

    func test_baseline_skipsGapDays_andLogsHRV() {
        let snaps = [
            snap(1, hrv: 50, rhr: 52, sleepMin: 420),
            snap(2, hrv: nil, rhr: nil, sleepMin: nil),   // gap day — ignored
            snap(3, hrv: 50, rhr: 54, sleepMin: 480),
        ]
        let base = BaselineCalculator.baseline(from: snaps)
        XCTAssertEqual(base.hrvLnSDNN?.n, 2)               // gap day excluded
        XCTAssertEqual(base.hrvLnSDNN?.mean ?? 0, log(50), accuracy: 0.0001)  // ln transform
        XCTAssertEqual(base.sleepHours?.mean ?? 0, 7.5, accuracy: 0.0001)     // (7+8)/2 hours
    }

    func test_latestHRVLnSDNN_logOfAverageSDNN() {
        let snaps = [
            snap(1, hrv: 50, rhr: nil, sleepMin: nil),
            snap(2, hrv: 100, rhr: nil, sleepMin: nil),
        ]
        let v = BaselineCalculator.latestHRVLnSDNN(from: snaps)
        // ln of the AVERAGE SDNN (75), not the average of the lns
        XCTAssertEqual(v ?? 0, log(75), accuracy: 1e-9)
    }

    func test_latestHRVLnSDNN_allNilIsNil() {
        let snaps = [
            snap(1, hrv: nil, rhr: 52, sleepMin: 420),
            snap(2, hrv: nil, rhr: 54, sleepMin: 480),
        ]
        XCTAssertNil(BaselineCalculator.latestHRVLnSDNN(from: snaps))
        XCTAssertNil(BaselineCalculator.latestHRVLnSDNN(from: []))
    }
}
