import Foundation
import Combine

class ActivityStore: ObservableObject {
    @Published var workouts: [WorkoutSession] = []
    @Published var dailyActivities: [DailyActivity] = []

    private let workoutsKey = "kaizenn_workouts"
    private let activitiesKey = "kaizenn_daily_activities"

    init() { load() }

    // MARK: Queries
    var recentWorkouts: [WorkoutSession] {
        workouts.sorted { $0.startDate > $1.startDate }.prefix(20).map { $0 }
    }

    func workouts(lastDays days: Int) -> [WorkoutSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return workouts.filter { $0.startDate >= cutoff }.sorted { $0.startDate > $1.startDate }
    }

    var totalWorkoutsThisWeek: Int { workouts(lastDays: 7).count }
    var totalCaloriesBurnedThisWeek: Double { workouts(lastDays: 7).map(\.caloriesBurned).reduce(0, +) }
    var totalMinutesThisWeek: Double { workouts(lastDays: 7).map(\.duration).reduce(0, +) / 60 }

    func todayActivity() -> DailyActivity {
        let today = Date()
        return dailyActivities.first { Calendar.current.isDateInToday($0.date) } ?? DailyActivity(date: today)
    }

    // MARK: Mutations
    func addWorkout(_ workout: WorkoutSession) {
        workouts.append(workout)
        save()
    }

    func removeWorkout(id: UUID) {
        workouts.removeAll { $0.id == id }
        save()
    }

    func updateDailyActivity(_ activity: DailyActivity) {
        if let i = dailyActivities.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: activity.date) }) {
            dailyActivities[i] = activity
        } else {
            dailyActivities.append(activity)
        }
        save()
    }

    func syncFromHealthKit(steps: Int, activeCalories: Double, restingCalories: Double, distance: Double) {
        var activity = todayActivity()
        activity.steps = steps
        activity.activeCalories = activeCalories
        activity.restingCalories = restingCalories
        activity.distanceMeters = distance
        updateDailyActivity(activity)
    }

    // MARK: Persistence
    private func load() {
        if let data = UserDefaults.standard.data(forKey: workoutsKey),
           let decoded = try? JSONDecoder().decode([WorkoutSession].self, from: data) { workouts = decoded }
        if let data = UserDefaults.standard.data(forKey: activitiesKey),
           let decoded = try? JSONDecoder().decode([DailyActivity].self, from: data) { dailyActivities = decoded }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(workouts) { UserDefaults.standard.set(data, forKey: workoutsKey) }
        if let data = try? JSONEncoder().encode(dailyActivities) { UserDefaults.standard.set(data, forKey: activitiesKey) }
    }
}
