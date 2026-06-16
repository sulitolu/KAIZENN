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
                .preferredColorScheme(.dark)
                .task { await notifications.requestPermission() }
                .onChange(of: scheduleStore.habits) { habits in
                    notifications.rescheduleAll(habits: habits)
                }
        }
    }
}
