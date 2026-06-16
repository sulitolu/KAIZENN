import UserNotifications
import Foundation

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private let center = UNUserNotificationCenter.current()

    // MARK: Permission
    func requestPermission() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            if granted { scheduleMealReminders(); scheduleDailySummary() }
        } catch {}
    }

    // MARK: Habit reminders
    func scheduleHabitReminder(for habit: Habit) {
        guard let reminderTime = habit.reminderTime else { return }
        let id = "habit-\(habit.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = habit.title
        content.body = "Time to complete your habit and keep your streak going."
        content.sound = .default

        var components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        components.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelHabitReminder(habitId: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: ["habit-\(habitId.uuidString)"])
    }

    func rescheduleAll(habits: [Habit]) {
        let habitIds = habits.map { "habit-\($0.id.uuidString)" }
        center.getPendingNotificationRequests { pending in
            let toRemove = pending.map(\.identifier).filter { $0.hasPrefix("habit-") && !habitIds.contains($0) }
            self.center.removePendingNotificationRequests(withIdentifiers: toRemove)
        }
        habits.filter { $0.reminderTime != nil }.forEach { scheduleHabitReminder(for: $0) }
    }

    // MARK: Meal reminders
    func scheduleMealReminders() {
        let meals: [(String, String, Int, Int)] = [
            ("meal-breakfast", "Log Breakfast", 8, 0),
            ("meal-lunch",     "Log Lunch",     12, 30),
            ("meal-snack",     "Log Your Snack", 15, 0),
            ("meal-dinner",    "Log Dinner",     18, 30),
        ]
        for (id, title, hour, minute) in meals {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = "Track what you ate to stay on top of your nutrition goals."
            content.sound = .default
            var comps = DateComponents()
            comps.hour = hour; comps.minute = minute; comps.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    // MARK: Daily summary
    func scheduleDailySummary() {
        let content = UNMutableNotificationContent()
        content.title = "Daily Check-In"
        content.body = "Review today's progress and prepare for tomorrow."
        content.sound = .default
        var comps = DateComponents()
        comps.hour = 21; comps.minute = 0; comps.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: "daily-summary", content: content, trigger: trigger))
    }

    func cancelMealReminders() {
        center.removePendingNotificationRequests(withIdentifiers: [
            "meal-breakfast", "meal-lunch", "meal-snack", "meal-dinner", "daily-summary"
        ])
    }
}
