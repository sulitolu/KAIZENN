import Foundation

@MainActor
final class HealthIngestionService: ObservableObject {
    private let store: HealthStore
    private let source: HealthDataSource

    init(store: HealthStore, source: HealthDataSource) {
        self.store = store
        self.source = source
    }

    /// Pull the last `days` of daily metrics + workouts and upsert. Per-metric isolation:
    /// one metric throwing does not abort the rest.
    func syncNow(days: Int = 14) async {
        for metric in HealthMetric.allCases {
            do {
                let samples = try await source.dailyValues(metric, days: days)
                for sample in samples {
                    store.upsertSnapshot(date: sample.date) { snap in
                        apply(metric, value: sample.value, to: snap)
                    }
                }
            } catch {
                // Log + continue; gap stays nil. (Logging hook intentionally minimal.)
                continue
            }
        }

        do {
            let since = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            for w in try await source.workouts(since: since) {
                store.upsertWorkout(uuid: w.uuid, type: w.type, start: w.start,
                    durationMinutes: w.durationMinutes, activeEnergy: w.activeEnergy,
                    distanceMeters: w.distanceMeters, source: w.source)
            }
        } catch {
            // ignore — workouts retried next sync
        }
    }

    private func apply(_ metric: HealthMetric, value: Double, to snap: DailyHealthSnapshot) {
        switch metric {
        case .hrvSDNN:      snap.hrvSDNN = value
        case .restingHR:    snap.restingHR = value
        case .sleepMinutes: snap.sleepDurationMinutes = value
        case .steps:        snap.steps = Int(value)
        case .activeEnergy: snap.activeEnergy = value
        }
    }
}
