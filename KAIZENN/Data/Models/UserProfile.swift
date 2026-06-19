import Foundation

struct UserProfile: Codable {
    var name: String = ""
    var age: Int = 25
    var gender: Gender = .other
    var heightCm: Double = 175
    var currentWeightKg: Double = 80
    var goalWeightKg: Double = 72
    var activityLevel: ActivityLevel = .moderatelyActive
    var goal: Goal = .loseFat
    var weeklyGoalKg: Double = 0.5 // kg per week
    var profileImageURL: String? = nil
    var sportProfile: SportProfile = SportProfile()

    enum Gender: String, Codable, CaseIterable {
        case male, female, other
        var displayName: String { rawValue.capitalized }
    }

    enum ActivityLevel: String, Codable, CaseIterable {
        case sedentary, lightlyActive, moderatelyActive, veryActive, extraActive
        var displayName: String {
            switch self {
            case .sedentary:        return "Sedentary"
            case .lightlyActive:    return "Lightly Active"
            case .moderatelyActive: return "Moderately Active"
            case .veryActive:       return "Very Active"
            case .extraActive:      return "Athlete"
            }
        }
        var multiplier: Double {
            switch self {
            case .sedentary:        return 1.2
            case .lightlyActive:    return 1.375
            case .moderatelyActive: return 1.55
            case .veryActive:       return 1.725
            case .extraActive:      return 1.9
            }
        }
    }

    enum Goal: String, Codable, CaseIterable {
        case loseFat, buildMuscle, maintainWeight, improveHealth, increaseEndurance
        var displayName: String {
            switch self {
            case .loseFat:           return "Lose Weight"
            case .buildMuscle:       return "Build Muscle"
            case .maintainWeight:    return "Stay Fit"
            case .improveHealth:     return "General Health"
            case .increaseEndurance: return "Build Endurance"
            }
        }
        var icon: String {
            switch self {
            case .loseFat:           return "arrow.down.circle.fill"
            case .buildMuscle:       return "dumbbell.fill"
            case .maintainWeight:    return "equal.circle.fill"
            case .improveHealth:     return "star.circle.fill"
            case .increaseEndurance: return "heart.circle.fill"
            }
        }
    }

    // MARK: Computed
    var bmi: Double {
        let heightM = heightCm / 100
        return currentWeightKg / (heightM * heightM)
    }

    var bmiCategory: String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Healthy"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }

    /// Mifflin-St Jeor BMR
    var bmr: Double {
        switch gender {
        case .male:
            return (10 * currentWeightKg) + (6.25 * heightCm) - (5 * Double(age)) + 5
        case .female:
            return (10 * currentWeightKg) + (6.25 * heightCm) - (5 * Double(age)) - 161
        case .other:
            return (10 * currentWeightKg) + (6.25 * heightCm) - (5 * Double(age)) - 78
        }
    }

    var tdee: Double { bmr * activityLevel.multiplier }

    var dailyCalorieTarget: Int {
        let deficit: Double
        switch goal {
        case .loseFat:           deficit = weeklyGoalKg * 1100 // ~500-1100 cal/day for 0.5-1kg/week
        case .buildMuscle:       deficit = -300               // caloric surplus
        case .maintainWeight, .improveHealth: deficit = 0
        case .increaseEndurance: deficit = -100
        }
        return max(1200, Int(tdee - deficit))
    }

    var macroTargets: MacroTargets {
        let protein = currentWeightKg * (goal == .buildMuscle ? 2.2 : 1.8)
        let fat = Double(dailyCalorieTarget) * 0.25 / 9
        let carbCal = Double(dailyCalorieTarget) - (protein * 4) - (fat * 9)
        let carbs = max(50, carbCal / 4)
        return MacroTargets(
            calories: dailyCalorieTarget,
            proteinG: Int(protein),
            carbsG: Int(carbs),
            fatG: Int(fat)
        )
    }

    var weightToLose: Double { currentWeightKg - goalWeightKg }
    var weeksToGoal: Double { weeklyGoalKg > 0 ? abs(weightToLose / weeklyGoalKg) : 0 }

    // MARK: Persistence
    static let storageKey = "kaizenn_user_profile"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    static func load() -> UserProfile {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return UserProfile() }
        return profile
    }
}

struct MacroTargets {
    let calories: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
}
