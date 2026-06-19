import Foundation

struct GPSSession: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var durationMinutes: Double = 0
    var distanceKm: Double = 0
    var averageHeartRate: Int? = nil
    var maxHeartRate: Int? = nil
    var rpe: Int = 5  // Rate of perceived exertion 1-10
    var notes: String = ""

    static let storageKey = "gps_sessions"

    /// Session load used for ACWR (Acute:Chronic Workload Ratio)
    /// Simplified formula: distance(km) × RPE
    var sessionLoad: Double {
        distanceKm * Double(rpe)
    }
}
