import XCTest
@testable import KAIZENN

final class SportProfileTests: XCTestCase {

    func testProteinPerKg() {
        XCTAssertEqual(SportProfile.Sport.rugby.proteinPerKg, 2.0, accuracy: 0.0001)
        XCTAssertEqual(SportProfile.Sport.gym.proteinPerKg, 2.0, accuracy: 0.0001)
        XCTAssertEqual(SportProfile.Sport.soccer.proteinPerKg, 1.8, accuracy: 0.0001)
        XCTAssertEqual(SportProfile.Sport.basketball.proteinPerKg, 1.8, accuracy: 0.0001)
        XCTAssertEqual(SportProfile.Sport.swimming.proteinPerKg, 1.6, accuracy: 0.0001)
        XCTAssertEqual(SportProfile.Sport.athletics.proteinPerKg, 1.6, accuracy: 0.0001)
        XCTAssertEqual(SportProfile.Sport.cycling.proteinPerKg, 1.6, accuracy: 0.0001)
        XCTAssertEqual(SportProfile.Sport.other.proteinPerKg, 1.6, accuracy: 0.0001)
    }

    func testEverySportHasPositions() {
        for sport in SportProfile.Sport.allCases {
            XCTAssertFalse(sport.positions.isEmpty, "\(sport) should have positions")
        }
    }

    func testDaysUntilPerformanceInRange() {
        var p = SportProfile()
        p.performanceDayOfWeek = 6
        XCTAssertTrue((0...6).contains(p.daysUntilPerformance))
    }

    func testDaysUntilPerformanceZeroWhenToday() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        var p = SportProfile()
        p.performanceDayOfWeek = todayWeekday
        XCTAssertEqual(p.daysUntilPerformance, 0)
    }

    func testDaysUntilPerformanceMatchesFormula() {
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        for target in 1...7 {
            var p = SportProfile()
            p.performanceDayOfWeek = target
            let diff = target - todayWeekday
            let expected = diff >= 0 ? diff : diff + 7
            XCTAssertEqual(p.daysUntilPerformance, expected, "target=\(target)")
        }
    }
}
