import XCTest
@testable import KAIZENN

final class CoachActionEngineTests: XCTestCase {

    private func breakdown(label: ReadinessLabel, strain: Double?) -> ReadinessBreakdown {
        ReadinessBreakdown(recovery: 70, sleep: 70, strain: strain, fuel: 70,
                           score: 60, label: label, isCalibrating: false)
    }

    func testLowReadinessProposesRecoveryAndSleep() {
        let p = CoachActionEngine.proposals(readiness: breakdown(label: .recover, strain: 70), sleepDebtHours: 0)
        XCTAssertTrue(p.contains { $0.id == "recovery-session" })
        XCTAssertTrue(p.contains { $0.id == "protect-sleep" })
        XCTAssertEqual(p.first { $0.id == "recovery-session" }?.task.category, .recovery)
    }

    func testHighStrainProposesEaseTraining() {
        let p = CoachActionEngine.proposals(readiness: breakdown(label: .ready, strain: 40), sleepDebtHours: 0)
        XCTAssertTrue(p.contains { $0.id == "ease-training" })
    }

    func testSleepDebtProposesWindDown() {
        let p = CoachActionEngine.proposals(readiness: breakdown(label: .ready, strain: 80), sleepDebtHours: 4)
        XCTAssertTrue(p.contains { $0.id == "wind-down" })
    }

    func testGoodDayProposesNothing() {
        let p = CoachActionEngine.proposals(readiness: breakdown(label: .primed, strain: 90), sleepDebtHours: 0)
        XCTAssertTrue(p.isEmpty)
    }

    func testCapsAtThreeProposals() {
        let p = CoachActionEngine.proposals(readiness: breakdown(label: .recover, strain: 30), sleepDebtHours: 5)
        XCTAssertLessThanOrEqual(p.count, 3)
    }

    func testDismissPersistsForToday() {
        let store = CoachActionStore()
        store.dismiss("recovery-session")
        XCTAssertTrue(store.dismissed().contains("recovery-session"))
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "kaizenn_coach_dismissed_actions")
        super.tearDown()
    }
}
