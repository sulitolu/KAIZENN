import Foundation
import HealthKit

/// Pulls HealthKit history and computes the rolling baselines the ReadinessEngine needs.
/// Keeps the engine pure: it owns the HealthKit dependency, the engine just consumes the result.
@MainActor
final class ReadinessBaselineProvider: ObservableObject {
    @Published var baseline = ReadinessBaseline(hrvLnSDNN: nil, restingHR: nil, sleepHours: nil)
    @Published var hrvLnSDNNToday: Double?
    @Published var sleepDebtHours: Double = 0
    @Published var sleepRegularitySD: Double?

    func refresh(health: HealthKitManager) async {
        let sdnn = await health.fetchDailySeries(.heartRateVariabilitySDNN,
                                                 unit: .secondUnit(with: .milli), days: 60)
        let lnSDNN = sdnn.filter { $0 > 0 }.map { Foundation.log($0) }
        let rhr = await health.fetchDailySeries(.restingHeartRate,
                                                unit: HKUnit.count().unitDivided(by: .minute()), days: 60).filter { $0 > 0 }
        let sleep = await health.fetchSleepHistory(nights: 28)

        let need = 8.0
        let last7 = Array(lnSDNN.suffix(7))
        hrvLnSDNNToday = last7.isEmpty ? nil : last7.reduce(0, +) / Double(last7.count)

        let last14 = Array(sleep.suffix(14))
        sleepDebtHours = last14.reduce(0.0) { $0 + max(need - $1, 0) }
        sleepRegularitySD = SignalBaseline.from(last14, minN: 3)?.sd

        baseline = ReadinessBaseline(
            hrvLnSDNN: SignalBaseline.from(lnSDNN),
            restingHR: SignalBaseline.from(rhr),
            sleepHours: SignalBaseline.from(sleep),
            sleepNeed: need
        )
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
