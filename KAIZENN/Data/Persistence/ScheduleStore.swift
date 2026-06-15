import Foundation
import Combine

class ScheduleStore: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var tasks: [KTask] = []

    private let habitsKey = "kaizenn_habits"
    private let tasksKey  = "kaizenn_tasks"

    init() {
        load()
        if habits.isEmpty { habits = Habit.fitnessDefaults }
    }

    // MARK: Habit Queries
    var todayHabits: [Habit] { habits.filter { isHabitDueToday($0) } }
    var completedTodayCount: Int { todayHabits.filter(\.isCompletedToday).count }
    var todayHabitProgress: Double {
        guard !todayHabits.isEmpty else { return 0 }
        return Double(completedTodayCount) / Double(todayHabits.count)
    }
    var longestStreak: Int { habits.map(\.streak).max() ?? 0 }

    private func isHabitDueToday(_ habit: Habit) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: Date()) // 1=Sun
        switch habit.frequency {
        case .daily:    return true
        case .weekdays: return (2...6).contains(weekday)
        case .weekends: return weekday == 1 || weekday == 7
        case .weekly:   return true // simplified
        case .custom:   return true
        }
    }

    // MARK: Task Queries
    func tasks(for date: Date) -> [KTask] {
        let cal = Calendar.current
        return tasks.filter { task in
            guard let due = task.dueDate else { return false }
            return cal.isDate(due, inSameDayAs: date)
        }.sorted { ($0.priority.rawValue, $0.dueDate ?? Date()) > ($1.priority.rawValue, $1.dueDate ?? Date()) }
    }

    var overdueTasks: [KTask] { tasks.filter(\.isOverdue) }
    var todayTasks: [KTask] { tasks(for: Date()) }
    var upcomingTasks: [KTask] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        return tasks.filter { task in
            guard let due = task.dueDate, !task.isCompleted else { return false }
            return due >= tomorrow && due <= nextWeek
        }.sorted { $0.dueDate! < $1.dueDate! }
    }

    // MARK: Habit Mutations
    func toggleHabit(id: UUID) {
        guard let i = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[i].toggleToday()
        save()
    }

    func addHabit(_ habit: Habit) {
        habits.append(habit)
        save()
    }

    func removeHabit(id: UUID) {
        habits.removeAll { $0.id == id }
        save()
    }

    // MARK: Task Mutations
    func addTask(_ task: KTask) {
        tasks.append(task)
        save()
    }

    func toggleTaskCompletion(id: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].isCompleted.toggle()
        tasks[i].completedDate = tasks[i].isCompleted ? Date() : nil
        save()
    }

    func removeTask(id: UUID) {
        tasks.removeAll { $0.id == id }
        save()
    }

    func updateTask(_ task: KTask) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[i] = task
        save()
    }

    // MARK: Persistence
    private func load() {
        if let data = UserDefaults.standard.data(forKey: habitsKey),
           let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decoded
        }
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([KTask].self, from: data) {
            tasks = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(habits) { UserDefaults.standard.set(data, forKey: habitsKey) }
        if let data = try? JSONEncoder().encode(tasks)  { UserDefaults.standard.set(data, forKey: tasksKey) }
    }
}
