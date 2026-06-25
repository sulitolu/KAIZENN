import Foundation
import Combine

class LoadStore: ObservableObject {
    @Published private(set) var gpsSessions: [GPSSession] = []
    @Published private(set) var strengthSessions: [StrengthSession] = []
    @Published private(set) var healthWorkouts: [WorkoutRecord] = []
    @Published private(set) var acuteLoad: Double = 0
    @Published private(set) var chronicLoad: Double = 0
    @Published private(set) var acwr: Double = 0

    init() {
        load()
        recalculate()
    }

    // MARK: Mutations

    func addGPSSession(_ session: GPSSession) {
        gpsSessions.insert(session, at: 0)
        save()
        recalculate()
    }

    func addStrengthSession(_ session: StrengthSession) {
        strengthSessions.insert(session, at: 0)
        save()
        recalculate()
    }

    func deleteGPSSession(id: UUID) {
        gpsSessions.removeAll { $0.id == id }
        save()
        recalculate()
    }

    func deleteStrengthSession(id: UUID) {
        strengthSessions.removeAll { $0.id == id }
        save()
        recalculate()
    }

    func setHealthWorkouts(_ workouts: [WorkoutRecord]) {
        healthWorkouts = workouts
        recalculate()
    }

    // MARK: Calculations

    private func recalculate() {
        let now = Date()
        guard let cutoff7 = Calendar.current.date(byAdding: .day, value: -7, to: now),
              let cutoff28 = Calendar.current.date(byAdding: .day, value: -28, to: now) else {
            acuteLoad = 0
            chronicLoad = 0
            acwr = 0
            return
        }

        let gpsAcute = gpsSessions.filter { $0.date >= cutoff7 }.map(\.sessionLoad).reduce(0, +)
        let strengthAcute = strengthSessions.filter { $0.date >= cutoff7 }.map(\.sessionLoad).reduce(0, +)
        acuteLoad = gpsAcute + strengthAcute + nonDuplicateWorkoutLoad(since: cutoff7)

        let gpsChronic28 = gpsSessions.filter { $0.date >= cutoff28 }.map(\.sessionLoad).reduce(0, +)
        let strengthChronic28 = strengthSessions.filter { $0.date >= cutoff28 }.map(\.sessionLoad).reduce(0, +)
        chronicLoad = (gpsChronic28 + strengthChronic28 + nonDuplicateWorkoutLoad(since: cutoff28)) / 4

        acwr = chronicLoad > 0 ? acuteLoad / chronicLoad : 0
    }

    /// A HealthKit workout counts toward load only if it does NOT overlap a manual
    /// session (±30 min of start). Manual sessions always win (richer GPS/load data).
    private func nonDuplicateWorkoutLoad(since cutoff: Date) -> Double {
        let window: TimeInterval = 30 * 60
        let manualDates = gpsSessions.map(\.date) + strengthSessions.map(\.date)
        return healthWorkouts
            .filter { $0.start >= cutoff }
            .filter { w in !manualDates.contains { abs($0.timeIntervalSince(w.start)) <= window } }
            .map { $0.activeEnergy / 100 }
            .reduce(0, +)
    }

    // MARK: Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: GPSSession.storageKey),
           let decoded = try? JSONDecoder().decode([GPSSession].self, from: data) {
            gpsSessions = decoded
        }
        if let data = UserDefaults.standard.data(forKey: StrengthSession.storageKey),
           let decoded = try? JSONDecoder().decode([StrengthSession].self, from: data) {
            strengthSessions = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(gpsSessions) {
            UserDefaults.standard.set(data, forKey: GPSSession.storageKey)
        }
        if let data = try? JSONEncoder().encode(strengthSessions) {
            UserDefaults.standard.set(data, forKey: StrengthSession.storageKey)
        }
    }
}
