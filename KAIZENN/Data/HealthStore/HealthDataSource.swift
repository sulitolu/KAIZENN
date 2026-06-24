import Foundation

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
