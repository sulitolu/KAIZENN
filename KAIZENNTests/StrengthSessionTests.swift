import XCTest
@testable import KAIZENN

final class StrengthSessionTests: XCTestCase {

    func testEmptySessionVolumeIsZero() {
        let session = StrengthSession()
        XCTAssertEqual(session.totalVolumeKg, 0, accuracy: 0.0001)
        XCTAssertEqual(session.sessionLoad, 0, accuracy: 0.0001)
    }

    func testVolumeAndSessionLoad() {
        var squat = StrengthExercise(name: "Squat")
        squat.sets = [
            ExerciseSet(reps: 5, weightKg: 100),
            ExerciseSet(reps: 5, weightKg: 100)
        ]
        var session = StrengthSession()
        session.exercises = [squat]
        // 5*100 + 5*100 = 1000
        XCTAssertEqual(session.totalVolumeKg, 1000, accuracy: 0.0001)
        XCTAssertEqual(session.sessionLoad, 1.0, accuracy: 0.0001)
        XCTAssertEqual(squat.totalVolumeKg, 1000, accuracy: 0.0001)
    }

    func testEstimated1RMEpley() {
        var ex = StrengthExercise(name: "Bench Press")
        ex.sets = [ExerciseSet(reps: 5, weightKg: 100)]
        // 100 * (1 + 5/30) = 100 * 1.16667 = 116.667
        XCTAssertEqual(ex.estimated1RM, 116.67, accuracy: 0.1)
    }

    func testEstimated1RMSingleRepReturnsWeight() {
        var ex = StrengthExercise(name: "Deadlift")
        ex.sets = [ExerciseSet(reps: 1, weightKg: 140)]
        // reps > 0 -> Epley: 140 * (1 + 1/30) = 144.667
        XCTAssertEqual(ex.estimated1RM, 140 * (1 + 1.0/30.0), accuracy: 0.01)
    }

    func testEstimated1RMZeroRepsReturnsWeight() {
        var ex = StrengthExercise(name: "Hold")
        ex.sets = [ExerciseSet(reps: 0, weightKg: 120)]
        // reps == 0 -> returns the weight directly
        XCTAssertEqual(ex.estimated1RM, 120, accuracy: 0.0001)
    }

    func testEstimated1RMEmptySetsIsZero() {
        let ex = StrengthExercise(name: "Empty")
        XCTAssertEqual(ex.estimated1RM, 0, accuracy: 0.0001)
    }

    func testEstimated1RMPicksHeaviestSet() {
        var ex = StrengthExercise(name: "Mixed")
        ex.sets = [
            ExerciseSet(reps: 10, weightKg: 60),
            ExerciseSet(reps: 3, weightKg: 120) // heaviest
        ]
        // heaviest is 120 @ 3 reps: 120 * (1 + 3/30) = 132
        XCTAssertEqual(ex.estimated1RM, 132, accuracy: 0.01)
    }
}
