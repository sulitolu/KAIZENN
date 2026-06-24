import XCTest
@testable import KAIZENN

@MainActor
final class HealthIngestionServiceTests: XCTestCase {
    /// Fake that returns canned values and can be told to throw for one metric (per-type isolation test).
    final class FakeSource: HealthDataSource {
        var values: [HealthMetric: [DailyMetricSample]] = [:]
        var workoutList: [WorkoutSampleDTO] = []
        var throwingMetric: HealthMetric?

        func dailyValues(_ metric: HealthMetric, days: Int) async throws -> [DailyMetricSample] {
            if metric == throwingMetric { throw NSError(domain: "test", code: 1) }
            return values[metric] ?? []
        }
        func workouts(since: Date) async throws -> [WorkoutSampleDTO] { workoutList }
    }

    func test_syncNow_writesSnapshotsAndWorkouts() async {
        let store = HealthStore(inMemory: true)
        let source = FakeSource()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        source.values[.hrvSDNN] = [DailyMetricSample(date: day, value: 48)]
        source.values[.restingHR] = [DailyMetricSample(date: day, value: 53)]
        source.workoutList = [WorkoutSampleDTO(uuid: "W1", type: "running", start: day,
            durationMinutes: 30, activeEnergy: 320, distanceMeters: 6000, source: "Watch")]

        let service = HealthIngestionService(store: store, source: source)
        await service.syncNow(days: 14)

        let snaps = store.snapshots(since: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(snaps.count, 1)
        XCTAssertEqual(snaps.first?.hrvSDNN, 48)
        XCTAssertEqual(snaps.first?.restingHR, 53)
        XCTAssertEqual(store.workouts(since: Date(timeIntervalSince1970: 0)).count, 1)
    }

    func test_syncNow_oneMetricFailing_doesNotAbortOthers() async {
        let store = HealthStore(inMemory: true)
        let source = FakeSource()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        source.throwingMetric = .hrvSDNN
        source.values[.restingHR] = [DailyMetricSample(date: day, value: 53)]

        let service = HealthIngestionService(store: store, source: source)
        await service.syncNow(days: 14)

        let snaps = store.snapshots(since: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(snaps.first?.restingHR, 53)   // RHR survived despite HRV throwing
        XCTAssertNil(snaps.first?.hrvSDNN)
    }
}
