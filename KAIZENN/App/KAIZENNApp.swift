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
    @StateObject private var healthStore: HealthStore
    @StateObject private var ingestion: HealthIngestionService
    @StateObject private var baselineProvider = ReadinessBaselineProvider()

    private let connectivity = WatchConnectivityManager.shared
    private let notifications = NotificationManager.shared

    init() {
        let store = HealthStore()
        _healthStore = StateObject(wrappedValue: store)
        let svc = HealthIngestionService(store: store, source: HealthKitDataSource())
        _ingestion = StateObject(wrappedValue: svc)

        WatchConnectivityManager.shared.onAddWater = { ml in
            NutritionStore.shared.addWater(ml: ml)
        }

        // Register the daily background sync handler at launch (Apple requires
        // registration before launch completes). Capture svc and store; hop to
        // the main actor for @MainActor-isolated work.
        BackgroundSyncScheduler.register {
            await svc.syncNow()
            await MainActor.run { store.objectWillChange.send() }
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
                .task {
                    await healthKitManager.requestAuthorization()
                    await ingestion.syncNow()
                    baselineProvider.refresh(from: healthStore)
                    BackgroundSyncScheduler.schedule()
                }
                .onChange(of: scheduleStore.habits) { _, habits in
                    notifications.rescheduleAll(habits: habits)
                }
        }
    }
}
