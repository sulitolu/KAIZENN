// KAIZENNTests/HealthStoreTests.swift
import XCTest
@testable import KAIZENN

@MainActor
final class HealthStoreTests: XCTestCase {
    func test_upsertSnapshot_isIdempotentPerDay() {
        let store = HealthStore(inMemory: true)
        let day = Date(timeIntervalSince1970: 1_700_000_000)

        store.upsertSnapshot(date: day) { $0.hrvSDNN = 45 }
        store.upsertSnapshot(date: day) { $0.restingHR = 52 }   // same day → update, not insert

        let rows = store.snapshots(since: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.hrvSDNN, 45)
        XCTAssertEqual(rows.first?.restingHR, 52)
    }

    func test_upsertWorkout_dedupsByUUID() {
        let store = HealthStore(inMemory: true)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        store.upsertWorkout(uuid: "A", type: "running", start: start,
                            durationMinutes: 30, activeEnergy: 300, distanceMeters: 5000, source: "Watch")
        store.upsertWorkout(uuid: "A", type: "running", start: start,
                            durationMinutes: 31, activeEnergy: 310, distanceMeters: 5100, source: "Watch")

        let rows = store.workouts(since: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.durationMinutes, 31)
    }
}
