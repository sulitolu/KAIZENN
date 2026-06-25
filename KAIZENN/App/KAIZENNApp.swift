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
        // registration before launch completes). Capture the shared store + svc +
        // provider; hop to the main actor for the @MainActor work so the morning
        // sync recomputes readiness baselines.
        let provider = _baselineProvider.wrappedValue
        let loadStore = _loadStore.wrappedValue
        BackgroundSyncScheduler.register {
            await svc.syncNow()
            await MainActor.run {
                provider.refresh(from: store)
                let acwrCutoff = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
                loadStore.setHealthWorkouts(store.workouts(since: acwrCutoff))
            }
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
                    await ingestion.syncNow(days: 60)
                    baselineProvider.refresh(from: healthStore)
                    let acwrCutoff = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
                    loadStore.setHealthWorkouts(healthStore.workouts(since: acwrCutoff))
                    BackgroundSyncScheduler.schedule()
                }
                .onChange(of: scheduleStore.habits) { _, habits in
                    notifications.rescheduleAll(habits: habits)
                }
        }
    }
}
