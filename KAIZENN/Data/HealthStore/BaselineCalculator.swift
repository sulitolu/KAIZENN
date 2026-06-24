// KAIZENN/Data/HealthStore/BaselineCalculator.swift
import Foundation

enum BaselineCalculator {
    /// Sample mean + sample SD (n-1). Returns nil for empty input.
    static func signalBaseline(_ values: [Double]) -> SignalBaseline? {
        guard !values.isEmpty else { return nil }
        let n = values.count
        let mean = values.reduce(0, +) / Double(n)
        let sd: Double
        if n > 1 {
            let ss = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
            sd = (ss / Double(n - 1)).squareRoot()
        } else {
            sd = 0
        }
        return SignalBaseline(mean: mean, sd: max(sd, 1e-6), n: n)
    }

    /// Build rolling baselines from the most-recent `window` snapshots, skipping gap days.
    static func baseline(from snapshots: [DailyHealthSnapshot], window: Int = 60) -> ReadinessBaseline {
        let recent = snapshots.sorted { $0.date > $1.date }.prefix(window)
        let hrvLn = recent.compactMap { $0.hrvSDNN }.filter { $0 > 0 }.map { Foundation.log($0) }
        let rhr = recent.compactMap { $0.restingHR }
        let sleepHrs = recent.compactMap { $0.sleepDurationMinutes }.map { $0 / 60.0 }
        return ReadinessBaseline(
            hrvLnSDNN: signalBaseline(hrvLn),
            restingHR: signalBaseline(rhr),
            sleepHours: signalBaseline(sleepHrs))
    }

    /// ln of the average SDNN over the last `days` snapshots (today's signal for the engine).
    static func latestHRVLnSDNN(from snapshots: [DailyHealthSnapshot], days: Int = 7) -> Double? {
        let recent = snapshots.sorted { $0.date > $1.date }.prefix(days)
        let vals = recent.compactMap { $0.hrvSDNN }.filter { $0 > 0 }
        guard !vals.isEmpty else { return nil }
        return Foundation.log(vals.reduce(0, +) / Double(vals.count))
    }
}
