import Foundation
import Combine

class LoadStore: ObservableObject {
    @Published private(set) var gpsSessions: [GPSSession] = []
    @Published private(set) var strengthSessions: [StrengthSession] = []
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
        acuteLoad = gpsAcute + strengthAcute

        let gpsChronic28 = gpsSessions.filter { $0.date >= cutoff28 }.map(\.sessionLoad).reduce(0, +)
        let strengthChronic28 = strengthSessions.filter { $0.date >= cutoff28 }.map(\.sessionLoad).reduce(0, +)
        chronicLoad = (gpsChronic28 + strengthChronic28) / 4

        acwr = chronicLoad > 0 ? acuteLoad / chronicLoad : 0
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
