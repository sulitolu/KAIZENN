import Foundation

// MARK: — Workout Session
struct WorkoutSession: Identifiable, Codable {
    var id: UUID = UUID()
    var startDate: Date
    var endDate: Date?
    var type: WorkoutType
    var caloriesBurned: Double = 0
    var heartRateAvg: Double? = nil
    var heartRateMax: Double? = nil
    var heartRateMin: Double? = nil
    var distanceMeters: Double? = nil
    var stepCount: Int? = nil
    var notes: String? = nil
    var source: DataSource = .manual

    enum DataSource: String, Codable { case healthKit, manual, watch }

    var duration: TimeInterval { (endDate ?? Date()).timeIntervalSince(startDate) }
    var durationFormatted: String {
        let h = Int(duration) / 3600
        let m = Int(duration) % 3600 / 60
        let s = Int(duration) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

enum WorkoutType: String, Codable, CaseIterable {
    // Cardio
    case running, walking, cycling, swimming, rowing, elliptical, jumpRope, stairClimber
    // Strength
    case weightTraining, bodyweight, crossfit, pilates
    // Sports
    case basketball, soccer, tennis, volleyball, boxing, martialArts
    // Mind/Body
    case yoga, stretching, meditation
    // Other
    case hiit, other

    var displayName: String {
        switch self {
        case .running:      return "Running"
        case .walking:      return "Walking"
        case .cycling:      return "Cycling"
        case .swimming:     return "Swimming"
        case .rowing:       return "Rowing"
        case .elliptical:   return "Elliptical"
        case .jumpRope:     return "Jump Rope"
        case .stairClimber: return "Stair Climber"
        case .weightTraining: return "Weight Training"
        case .bodyweight:   return "Bodyweight"
        case .crossfit:     return "CrossFit"
        case .pilates:      return "Pilates"
        case .basketball:   return "Basketball"
        case .soccer:       return "Soccer"
        case .tennis:       return "Tennis"
        case .volleyball:   return "Volleyball"
        case .boxing:       return "Boxing"
        case .martialArts:  return "Martial Arts"
        case .yoga:         return "Yoga"
        case .stretching:   return "Stretching"
        case .meditation:   return "Meditation"
        case .hiit:         return "HIIT"
        case .other:        return "Other"
        }
    }
    var icon: String {
        switch self {
        case .running:        return "figure.run"
        case .walking:        return "figure.walk"
        case .cycling:        return "figure.outdoor.cycle"
        case .swimming:       return "figure.pool.swim"
        case .rowing:         return "figure.rowing"
        case .elliptical:     return "figure.elliptical"
        case .jumpRope:       return "figure.jumprope"
        case .stairClimber:   return "figure.stair.stepper"
        case .weightTraining: return "dumbbell.fill"
        case .bodyweight:     return "figure.strengthtraining.traditional"
        case .crossfit:       return "bolt.fill"
        case .pilates:        return "figure.pilates"
        case .basketball:     return "sportscourt.fill"
        case .soccer:         return "soccerball"
        case .tennis:         return "tennisball.fill"
        case .volleyball:     return "volleyball.fill"
        case .boxing:         return "figure.boxing"
        case .martialArts:    return "figure.martial.arts"
        case .yoga:           return "figure.yoga"
        case .stretching:     return "figure.flexibility"
        case .meditation:     return "brain.head.profile"
        case .hiit:           return "flame.fill"
        case .other:          return "star.fill"
        }
    }
    var category: Category {
        switch self {
        case .running, .walking, .cycling, .swimming, .rowing, .elliptical, .jumpRope, .stairClimber: return .cardio
        case .weightTraining, .bodyweight, .crossfit, .pilates: return .strength
        case .basketball, .soccer, .tennis, .volleyball, .boxing, .martialArts: return .sports
        case .yoga, .stretching, .meditation: return .mindBody
        case .hiit, .other: return .other
        }
    }
    enum Category { case cardio, strength, sports, mindBody, other }
}

// MARK: — Daily Activity
struct DailyActivity: Codable {
    var date: Date = Date()
    var steps: Int = 0
    var activeCalories: Double = 0
    var restingCalories: Double = 0
    var exerciseMinutes: Int = 0
    var standHours: Int = 0
    var distanceMeters: Double = 0
    var flightsClimbed: Int = 0
    var heartRateResting: Double? = nil
    var heartRateVariability: Double? = nil

    var totalCaloriesBurned: Double { activeCalories + restingCalories }
}

// MARK: — Heart Rate Sample
struct HeartRateSample: Identifiable, Codable {
    var id: UUID = UUID()
    var timestamp: Date
    var bpm: Double
    var context: HeartRateContext = .resting

    enum HeartRateContext: String, Codable {
        case resting, active, sleeping, workout
    }
}

// MARK: — Body Measurements
struct BodyMeasurement: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var weightKg: Double
    var bodyFatPercentage: Double? = nil
    var muscleMassKg: Double? = nil
    var waterPercentage: Double? = nil
    var waistCm: Double? = nil
    var hipCm: Double? = nil
    var chestCm: Double? = nil
    var armCm: Double? = nil
    var thighCm: Double? = nil
    var notes: String? = nil

    var bmi: Double? = nil // computed from profile height

    var waistHipRatio: Double? {
        guard let waist = waistCm, let hip = hipCm, hip > 0 else { return nil }
        return waist / hip
    }
}
