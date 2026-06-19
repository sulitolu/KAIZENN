import Foundation

struct ExerciseSet: Identifiable, Codable {
    var id: UUID = UUID()
    var reps: Int = 0
    var weightKg: Double = 0
}

struct StrengthExercise: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String = ""
    var sets: [ExerciseSet] = []

    /// Total volume load for this exercise (sets × reps × weight)
    var volumeLoad: Double {
        sets.reduce(0) { $0 + Double($1.reps) * $1.weightKg }
    }
}

struct StrengthSession: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var exercises: [StrengthExercise] = []
    var rpe: Int = 5  // Rate of perceived exertion 1-10
    var notes: String = ""

    static let storageKey = "strength_sessions"

    /// Total session load used for ACWR
    /// Formula: total volume load × RPE
    var sessionLoad: Double {
        exercises.reduce(0) { $0 + $1.volumeLoad } * Double(rpe)
    }
}
