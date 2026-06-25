// KAIZENNTests/LoadStoreWorkoutTests.swift
import XCTest
@testable import KAIZENN

@MainActor
final class LoadStoreWorkoutTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: GPSSession.storageKey)
        UserDefaults.standard.removeObject(forKey: StrengthSession.storageKey)
    }
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: GPSSession.storageKey)
        UserDefaults.standard.removeObject(forKey: StrengthSession.storageKey)
        super.tearDown()
    }

    private func workout(uuid: String, daysAgo: Int, energy: Double) -> WorkoutRecord {
        let start = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return WorkoutRecord(hkUUID: uuid, type: "running", start: start,
            durationMinutes: 30, activeEnergy: energy, distanceMeters: 5000, source: "Watch")
    }

    func test_nonOverlappingWorkout_addsToAcuteLoad() {
        let store = LoadStore()
        let before = store.acuteLoad
        store.setHealthWorkouts([workout(uuid: "A", daysAgo: 1, energy: 500)])  // 500/100 = 5
        XCTAssertEqual(store.acuteLoad, before + 5, accuracy: 0.0001)
    }

    func test_workoutOverlappingManualSession_isDeduped() {
        let store = LoadStore()
        var gps = GPSSession()
        gps.date = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        store.addGPSSession(gps)                                   // manual session
        let baseline = store.acuteLoad

        // Watch workout within ±30 min of the manual session → should NOT add.
        let overlap = WorkoutRecord(hkUUID: "B", type: "running",
            start: gps.date.addingTimeInterval(10 * 60),
            durationMinutes: 30, activeEnergy: 500, distanceMeters: 5000, source: "Watch")
        store.setHealthWorkouts([overlap])
        XCTAssertEqual(store.acuteLoad, baseline, accuracy: 0.0001)  // deduped, manual wins
    }
}
