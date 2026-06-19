import Foundation

struct GPSSession: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var source: Source = .manual
    var distanceMeters: Double = 0
    var playerLoad: Double = 0
    var sprintCount: Int = 0
    var highSpeedRunningPercent: Double = 0  // 0–100
    var durationSeconds: Double = 0
    var notes: String = ""

    enum Source: String, Codable {
        case catapultCSV, garminSync, manual
        var displayName: String {
            switch self {
            case .catapultCSV: return "Catapult"
            case .garminSync:  return "Garmin"
            case .manual:      return "Manual"
            }
        }
    }

    var sessionLoad: Double {
        let kmLoad = (distanceMeters / 1000) * 10
        let intensityFactor = 1.0 + (highSpeedRunningPercent / 100)
        return kmLoad * intensityFactor
    }

    static let storageKey = "kaizenn_gps_sessions"
}
