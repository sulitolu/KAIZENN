import XCTest
@testable import KAIZENN

final class ReadinessEngineTests: XCTestCase {

    private func baseline(hrvN: Int = 60, sleepN: Int = 60) -> ReadinessBaseline {
        ReadinessBaseline(
            hrvLnSDNN: SignalBaseline(mean: 3.8, sd: 0.2, n: hrvN),       // ln(SDNN) ~ ln(45ms)
            restingHR: SignalBaseline(mean: 55, sd: 4, n: hrvN),
            sleepHours: SignalBaseline(mean: 7.5, sd: 0.8, n: sleepN),
            sleepNeed: 8.0
        )
    }

    private func inputs(hrv: Double? = 3.8, rhr: Double? = 55, sleep: Double? = 7.5,
                        debt: Double = 0, reg: Double? = 0.5,
                        acute: Double = 50, chronic: Double = 50,
                        base: ReadinessBaseline? = nil) -> ReadinessInputs {
        ReadinessInputs(hrvLnSDNNToday: hrv, restingHRToday: rhr, sleepHoursLast: sleep,
                        sleepDebtHours: debt, sleepRegularitySD: reg,
                        acuteLoad: acute, chronicLoad: chronic,
                        consumedCalories: 2000, calorieTarget: 2000, proteinConsumed: 150, proteinTarget: 150,
                        baseline: base ?? baseline())
    }

    func testZSubMapping() {
        XCTAssertEqual(ReadinessEngine.sub(z: 0), 80, accuracy: 0.001)
        XCTAssertEqual(ReadinessEngine.sub(z: 1), 100, accuracy: 0.001)   // capped
        XCTAssertEqual(ReadinessEngine.sub(z: -2), 40, accuracy: 0.001)
        XCTAssertEqual(ReadinessEngine.sub(z: -5), 0, accuracy: 0.001)    // floored
    }

    func testAtBaselineScoresAroundEighty() {
        let b = ReadinessEngine.breakdown(for: inputs())
        XCTAssertFalse(b.isCalibrating)
        XCTAssertGreaterThanOrEqual(b.score, 74)
        XCTAssertLessThanOrEqual(b.score, 86)
        XCTAssertEqual(b.label, .ready)
    }

    func testLowHRVDropsRecovery() {
        let low = ReadinessEngine.breakdown(for: inputs(hrv: 3.8 - 2 * 0.2))
        XCTAssertNotNil(low.recovery)
        XCTAssertLessThan(low.recovery!, 70)
    }

    func testHighRestingHRIsPenalised() {
        let normal = ReadinessEngine.breakdown(for: inputs())
        let highRHR = ReadinessEngine.breakdown(for: inputs(rhr: 55 + 2 * 4))
        XCTAssertLessThan(highRHR.recovery!, normal.recovery!)
    }

    func testStrainPenalisesAcuteSpike() {
        let spike = ReadinessEngine.strainScore(inputs(acute: 100, chronic: 50))!
        XCTAssertLessThan(spike, 60)
    }

    func testMissingPillarRenormalises() {
        let b = ReadinessEngine.breakdown(for: inputs(hrv: nil, rhr: nil))
        XCTAssertNil(b.recovery)
        XCTAssertGreaterThan(b.score, 0)
    }

    func testCalibratingUsesFallbackAndFlags() {
        let cal = ReadinessEngine.breakdown(for: inputs(base: baseline(hrvN: 5, sleepN: 5)))
        XCTAssertTrue(cal.isCalibrating)
        XCTAssertGreaterThan(cal.score, 0)
        XCTAssertLessThanOrEqual(cal.score, 100)
    }

    func testLabelBoundaries() {
        XCTAssertEqual(ReadinessEngine.label(for: 85), .primed)
        XCTAssertEqual(ReadinessEngine.label(for: 84), .ready)
        XCTAssertEqual(ReadinessEngine.label(for: 70), .ready)
        XCTAssertEqual(ReadinessEngine.label(for: 69), .moderate)
        XCTAssertEqual(ReadinessEngine.label(for: 55), .moderate)
        XCTAssertEqual(ReadinessEngine.label(for: 54), .caution)
        XCTAssertEqual(ReadinessEngine.label(for: 40), .caution)
        XCTAssertEqual(ReadinessEngine.label(for: 39), .recover)
    }
}
