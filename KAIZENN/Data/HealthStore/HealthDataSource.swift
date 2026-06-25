import Foundation
import HealthKit

enum HealthMetric: CaseIterable {
    case hrvSDNN, restingHR, sleepMinutes, steps, activeEnergy
}

struct DailyMetricSample {
    let date: Date
    let value: Double
}

struct WorkoutSampleDTO {
    let uuid: String
    let type: String
    let start: Date
    let durationMinutes: Double
    let activeEnergy: Double
    let distanceMeters: Double
    let source: String
}

protocol HealthDataSource {
    /// One value per day for `metric` over the last `days` days (gap days simply omitted).
    func dailyValues(_ metric: HealthMetric, days: Int) async throws -> [DailyMetricSample]
    func workouts(since: Date) async throws -> [WorkoutSampleDTO]
}

// MARK: - HealthKitDataSource

final class HealthKitDataSource: HealthDataSource {
    private let store = HKHealthStore()

    /// Mirrors HealthStore.dayKey — duplicated here to avoid calling
    /// the @MainActor-isolated HealthStore.dayKey from a non-isolated context.
    private static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    func dailyValues(_ metric: HealthMetric, days: Int) async throws -> [DailyMetricSample] {
        switch metric {
        case .hrvSDNN:      return try await dailyQuantity(.heartRateVariabilitySDNN,
                                unit: .secondUnit(with: .milli), options: .discreteAverage, days: days)
        case .restingHR:    return try await dailyQuantity(.restingHeartRate,
                                unit: HKUnit.count().unitDivided(by: .minute()), options: .discreteAverage, days: days)
        case .steps:        return try await dailyQuantity(.stepCount,
                                unit: .count(), options: .cumulativeSum, days: days)
        case .activeEnergy: return try await dailyQuantity(.activeEnergyBurned,
                                unit: .kilocalorie(), options: .cumulativeSum, days: days)
        case .sleepMinutes: return try await dailySleepMinutes(days: days)
        }
    }

    private func dailyQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit,
                               options: HKStatisticsOptions, days: Int) async throws -> [DailyMetricSample] {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return [] }
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -days, to: end) else { return [] }
        var comps = DateComponents(); comps.day = 1

        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: nil,
                options: options, anchorDate: start, intervalComponents: comps)
            q.initialResultsHandler = { _, results, error in
                if let error { cont.resume(throwing: error); return }
                var out: [DailyMetricSample] = []
                results?.enumerateStatistics(from: start, to: end) { stat, _ in
                    let qty = options.contains(.cumulativeSum) ? stat.sumQuantity() : stat.averageQuantity()
                    if let qty { out.append(DailyMetricSample(date: stat.startDate, value: qty.doubleValue(for: unit))) }
                }
                cont.resume(returning: out)
            }
            store.execute(q)
        }
    }

    private func dailySleepMinutes(days: Int) async throws -> [DailyMetricSample] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let cal = Calendar.current
        let end = Date()
        guard let start = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: end)) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: nil) { _, results, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(q)
        }

        let asleep: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
        ]
        var perDay: [String: Double] = [:]
        var dateForKey: [String: Date] = [:]
        for s in samples where asleep.contains(s.value) {
            let key = Self.dayKey(for: s.endDate)
            perDay[key, default: 0] += s.endDate.timeIntervalSince(s.startDate) / 60.0
            dateForKey[key] = cal.startOfDay(for: s.endDate)
        }
        return perDay.map { DailyMetricSample(date: dateForKey[$0.key]!, value: $0.value) }
    }

    func workouts(since: Date) async throws -> [WorkoutSampleDTO] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date())
        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: .workoutType(), predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            store.execute(q)
        }
        return workouts.map { w in
            WorkoutSampleDTO(
                uuid: w.uuid.uuidString,
                type: "\(w.workoutActivityType.rawValue)",
                start: w.startDate,
                durationMinutes: w.duration / 60.0,
                activeEnergy: w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                distanceMeters: w.totalDistance?.doubleValue(for: .meter()) ?? 0,
                source: w.sourceRevision.source.name)
        }
    }
}
