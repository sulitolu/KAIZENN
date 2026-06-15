import SwiftUI
import HealthKit

@main
struct KAIZENNApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var nutritionStore = NutritionStore()
    @StateObject private var weightStore = WeightStore()
    @StateObject private var scheduleStore = ScheduleStore()
    @StateObject private var activityStore = ActivityStore()

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
        }
    }
}
