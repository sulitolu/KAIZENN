import Foundation

/// Mean/SD of one signal over a baseline window. SD is floored to avoid div-by-zero in z-scores.
struct SignalBaseline: Equatable {
    let mean: Double
    let sd: Double
    let n: Int

    static func from(_ series: [Double], minN: Int = 2) -> SignalBaseline? {
        guard series.count >= minN else { return nil }
        let mean = series.reduce(0, +) / Double(series.count)
        let variance = series.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(series.count)
        return SignalBaseline(mean: mean, sd: max(variance.squareRoot(), 1e-6), n: series.count)
    }
}

/// Per-athlete baselines for the readiness signals. `isCalibrating` is true until the athlete
/// has at least `minDays` of HRV OR sleep history (baseline-relative scoring needs history).
struct ReadinessBaseline {
    let hrvLnSDNN: SignalBaseline?
    let restingHR: SignalBaseline?
    let sleepHours: SignalBaseline?
    var sleepNeed: Double = 8.0

    static let minDays = 14

    var isCalibrating: Bool {
        (hrvLnSDNN?.n ?? 0) < ReadinessBaseline.minDays && (sleepHours?.n ?? 0) < ReadinessBaseline.minDays
    }
}
