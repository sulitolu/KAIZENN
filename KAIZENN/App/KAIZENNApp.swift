import SwiftUI
import HealthKit

@main
struct KAIZENNApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var nutritionStore = NutritionStore.shared
    @StateObject private var weightStore = WeightStore()
    @StateObject private var scheduleStore = ScheduleStore()
    @StateObject private var activityStore = ActivityStore()
    @StateObject private var loadStore = LoadStore()
    @StateObject private var healthStore = HealthStore()
    @StateObject private var baselineProvider = ReadinessBaselineProvider()

    private let connectivity = WatchConnectivityManager.shared
    private let notifications = NotificationManager.shared

    init() {
        WatchConnectivityManager.shared.onAddWater = { ml in
            NutritionStore.shared.addWater(ml: ml)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(healthKitManager)
                .environmentObject(nutritionStore)
                .environmentObject(weightStore)
                .environmentObject(scheduleStore)
                .environmentObject(activityStore)
                .environmentObject(loadStore)
                .environmentObject(healthStore)
                .environmentObject(baselineProvider)
                .preferredColorScheme(.dark)
                .task {
                    await notifications.requestPermission()
                    if UserDefaults.standard.bool(forKey: "notifications_enabled") {
                        notifications.scheduleDailyReminders()
                    }
                }
                .onChange(of: scheduleStore.habits) { _, habits in
                    notifications.rescheduleAll(habits: habits)
                }
        }
    }
}
