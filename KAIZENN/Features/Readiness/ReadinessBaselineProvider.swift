import Foundation

/// Pulls durable HealthStore snapshots and computes the rolling baselines the ReadinessEngine needs.
/// Keeps the engine pure: it owns the HealthKit dependency, the engine just consumes the result.
@MainActor
final class ReadinessBaselineProvider: ObservableObject {
    @Published var baseline = ReadinessBaseline(hrvLnSDNN: nil, restingHR: nil, sleepHours: nil)
    @Published var hrvLnSDNNToday: Double?
    @Published var sleepDebtHours: Double = 0
    @Published var sleepRegularitySD: Double?

    func refresh(from store: HealthStore) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        let snaps = store.snapshots(since: cutoff)
        baseline = BaselineCalculator.baseline(from: snaps)
        hrvLnSDNNToday = BaselineCalculator.latestHRVLnSDNN(from: snaps)

        // Sleep debt + regularity from durable history (last 14 nights with sleep data),
        // same math as the retired refresh(health:) — only the source changed.
        let need = baseline.sleepNeed   // 8.0
        let nightlyHours = snaps.sorted { $0.date > $1.date }.prefix(14)
            .compactMap { $0.sleepDurationMinutes.map { $0 / 60.0 } }
        sleepDebtHours = nightlyHours.reduce(0.0) { $0 + max(need - $1, 0) }
        sleepRegularitySD = SignalBaseline.from(nightlyHours, minN: 3)?.sd
    }

    /// Build the engine inputs from the stores + current baselines. One place so Home, the
    /// readiness report, and the Coach tab all score identically (single source of truth).
    func inputs(health: HealthKitManager, loadStore: LoadStore,
                nutrition: NutritionStore, profile: UserProfile) -> ReadinessInputs {
        let today = nutrition.dailyNutrition(for: Date())
        return ReadinessInputs(
            hrvLnSDNNToday: hrvLnSDNNToday,
            restingHRToday: health.heartRateResting,
            sleepHoursLast: health.sleepHoursLast > 0 ? health.sleepHoursLast : nil,
            sleepDebtHours: sleepDebtHours,
            sleepRegularitySD: sleepRegularitySD,
            acuteLoad: loadStore.acuteLoad,
            chronicLoad: loadStore.chronicLoad,
            consumedCalories: today.totalCalories,
            calorieTarget: Double(profile.dailyCalorieTarget),
            proteinConsumed: today.totalProteinG,
            proteinTarget: Double(profile.macroTargets.proteinG),
            baseline: baseline
        )
    }
}
