import XCTest
@testable import KAIZENN

final class UserProfileTests: XCTestCase {

    func testBMRMale() {
        var p = UserProfile()
        p.gender = .male
        p.currentWeightKg = 80
        p.heightCm = 180
        p.age = 30
        // (10*80) + (6.25*180) - (5*30) + 5 = 800 + 1125 - 150 + 5 = 1780
        XCTAssertEqual(p.bmr, 1780, accuracy: 0.5)
    }

    func testBMRFemale() {
        var p = UserProfile()
        p.gender = .female
        p.currentWeightKg = 65
        p.heightCm = 165
        p.age = 28
        // (10*65) + (6.25*165) - (5*28) - 161 = 650 + 1031.25 - 140 - 161 = 1380.25
        XCTAssertEqual(p.bmr, 1380.25, accuracy: 0.5)
    }

    func testBMROther() {
        var p = UserProfile()
        p.gender = .other
        p.currentWeightKg = 70
        p.heightCm = 175
        p.age = 25
        // (10*70) + (6.25*175) - (5*25) - 78 = 700 + 1093.75 - 125 - 78 = 1590.75
        XCTAssertEqual(p.bmr, 1590.75, accuracy: 0.5)
    }

    func testBMI() {
        var p = UserProfile()
        p.currentWeightKg = 81
        p.heightCm = 180
        // 81 / (1.8*1.8) = 81 / 3.24 = 25.0
        XCTAssertEqual(p.bmi, 25.0, accuracy: 0.01)
    }

    func testDailyCalorieTargetFloorsAt1200() {
        var p = UserProfile()
        p.gender = .female
        p.currentWeightKg = 45
        p.heightCm = 150
        p.age = 60
        p.activityLevel = .sedentary
        p.goal = .loseFat
        p.weeklyGoalKg = 5.0 // extreme deficit -> 5*1100 = 5500 cal deficit
        XCTAssertEqual(p.dailyCalorieTarget, 1200)
    }

    func testMacrosPositiveAndCarbsFloor() {
        var p = UserProfile()
        p.gender = .male
        p.currentWeightKg = 80
        p.heightCm = 180
        p.age = 30
        p.activityLevel = .moderatelyActive
        p.goal = .buildMuscle
        let m = p.macroTargets
        XCTAssertGreaterThan(m.proteinG, 0)
        XCTAssertGreaterThan(m.fatG, 0)
        XCTAssertGreaterThanOrEqual(m.carbsG, 50)
        XCTAssertEqual(m.calories, p.dailyCalorieTarget)
    }

    func testCarbsFloorWhenDeficitHigh() {
        // Construct a scenario where computed carb calories would be very low.
        var p = UserProfile()
        p.gender = .female
        p.currentWeightKg = 50
        p.heightCm = 150
        p.age = 55
        p.activityLevel = .sedentary
        p.goal = .loseFat
        p.weeklyGoalKg = 5.0 // floors calories at 1200
        let m = p.macroTargets
        XCTAssertGreaterThanOrEqual(m.carbsG, 50)
    }
}
