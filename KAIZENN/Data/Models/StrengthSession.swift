import Foundation

struct StrengthSession: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var exercises: [StrengthExercise] = []

    var totalVolumeKg: Double {
        exercises.flatMap(\.sets).reduce(0) { $0 + ($1.reps * $1.weightKg) }
    }

    var sessionLoad: Double { totalVolumeKg / 1000 }

    static let storageKey = "kaizenn_strength_sessions"
}

struct StrengthExercise: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var sets: [ExerciseSet] = []

    var totalVolumeKg: Double {
        sets.reduce(0) { $0 + ($1.reps * $1.weightKg) }
    }

    var estimated1RM: Double {
        guard let best = sets.max(by: { $0.weightKg < $1.weightKg }) else { return 0 }
        guard best.reps > 0 else { return best.weightKg }
        return best.weightKg * (1 + best.reps / 30)
    }

    static let presets = ["Squat","Bench Press","Deadlift","Power Clean","RDL","Pull-up","Overhead Press","Hip Thrust","Lunge"]
}

struct ExerciseSet: Codable, Identifiable {
    var id: UUID = UUID()
    var reps: Double = 0
    var weightKg: Double = 0
}
