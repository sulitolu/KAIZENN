import Foundation

// MARK: — Habit
struct Habit: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var icon: String
    var color: String           // hex
    var category: HabitCategory
    var frequency: Frequency
    var targetCount: Int = 1    // times per day/week
    var completedDates: Set<String> = [] // ISO date strings
    var streak: Int = 0
    var bestStreak: Int = 0
    var createdDate: Date = Date()
    var reminderTime: Date? = nil
    var notes: String? = nil

    enum HabitCategory: String, Codable, CaseIterable {
        case fitness, nutrition, sleep, mindfulness, hydration, health, custom
        var icon: String {
            switch self {
            case .fitness:      return "flame.fill"
            case .nutrition:    return "leaf.fill"
            case .sleep:        return "moon.fill"
            case .mindfulness:  return "brain.head.profile"
            case .hydration:    return "drop.fill"
            case .health:       return "heart.text.square.fill"
            case .custom:       return "star.fill"
            }
        }
    }

    enum Frequency: String, Codable, CaseIterable {
        case daily, weekdays, weekends, weekly, custom
        var displayName: String {
            switch self {
            case .daily:     return "Every day"
            case .weekdays:  return "Weekdays"
            case .weekends:  return "Weekends"
            case .weekly:    return "Once a week"
            case .custom:    return "Custom"
            }
        }
    }

    var isCompletedToday: Bool {
        let key = DateFormatter.isoDate.string(from: Date())
        return completedDates.contains(key)
    }

    mutating func toggleToday() {
        let key = DateFormatter.isoDate.string(from: Date())
        if completedDates.contains(key) {
            completedDates.remove(key)
            if streak > 0 { streak -= 1 }
        } else {
            completedDates.insert(key)
            streak += 1
            if streak > bestStreak { bestStreak = streak }
        }
    }
}

// MARK: — Task
struct KTask: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var notes: String? = nil
    var dueDate: Date?
    var dueTime: Date? = nil
    var priority: Priority = .medium
    var category: TaskCategory = .general
    var isCompleted: Bool = false
    var completedDate: Date? = nil
    var tags: [String] = []
    var subtasks: [Subtask] = []
    var reminderDate: Date? = nil
    var recurrence: Recurrence? = nil
    var createdDate: Date = Date()

    enum Priority: Int, Codable, CaseIterable {
        case low = 0, medium = 1, high = 2, critical = 3
        var displayName: String {
            switch self { case .low: return "Low"; case .medium: return "Medium"; case .high: return "High"; case .critical: return "Critical" }
        }
        var color: String {
            switch self { case .low: return "4ECDC4"; case .medium: return "FFB347"; case .high: return "FF6B8A"; case .critical: return "FF2D55" }
        }
        var icon: String {
            switch self { case .low: return "arrow.down"; case .medium: return "minus"; case .high: return "arrow.up"; case .critical: return "exclamationmark.2" }
        }
    }

    enum TaskCategory: String, Codable, CaseIterable {
        case general, fitness, nutrition, health, work, personal, recovery
        var icon: String {
            switch self {
            case .general:   return "circle"
            case .fitness:   return "figure.run"
            case .nutrition: return "fork.knife"
            case .health:    return "heart.fill"
            case .work:      return "briefcase.fill"
            case .personal:  return "person.fill"
            case .recovery:  return "zzz"
            }
        }
    }

    enum Recurrence: String, Codable { case daily, weekly, monthly }

    struct Subtask: Identifiable, Codable {
        var id: UUID = UUID()
        var title: String
        var isCompleted: Bool = false
    }

    var isOverdue: Bool {
        guard let due = dueDate, !isCompleted else { return false }
        return due < Date()
    }

    var completionPercentage: Double {
        guard !subtasks.isEmpty else { return isCompleted ? 1.0 : 0.0 }
        return Double(subtasks.filter(\.isCompleted).count) / Double(subtasks.count)
    }

}

// MARK: — Default Habits for Fitness Journey
extension Habit {
    static let fitnessDefaults: [Habit] = [
        Habit(title: "Morning Workout", icon: "flame.fill", color: "FF6B8A", category: .fitness, frequency: .weekdays),
        Habit(title: "10,000 Steps", icon: "figure.walk", color: "4ECDC4", category: .fitness, frequency: .daily),
        Habit(title: "Drink 2.5L Water", icon: "drop.fill", color: "7C6FFF", category: .hydration, frequency: .daily),
        Habit(title: "Log Every Meal", icon: "fork.knife", color: "FFB347", category: .nutrition, frequency: .daily),
        Habit(title: "8 Hours Sleep", icon: "moon.stars.fill", color: "7C6FFF", category: .sleep, frequency: .daily),
        Habit(title: "5 Min Meditation", icon: "brain.head.profile", color: "4ECDC4", category: .mindfulness, frequency: .daily),
        Habit(title: "Weigh Yourself", icon: "scalemass.fill", color: "FFB347", category: .health, frequency: .daily),
        Habit(title: "Mobility/Stretch", icon: "figure.flexibility", color: "FF6B8A", category: .fitness, frequency: .daily),
    ]
}

extension DateFormatter {
    static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
