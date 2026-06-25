// KAIZENN/Data/HealthStore/HealthModels.swift
import Foundation
import SwiftData

@Model
final class DailyHealthSnapshot {
    @Attribute(.unique) var dayKey: String   // "yyyy-MM-dd", user's calendar
    var date: Date
    var hrvSDNN: Double?                      // ms
    var restingHR: Double?                    // bpm
    var sleepDurationMinutes: Double?
    var remMinutes: Double?
    var coreMinutes: Double?
    var deepMinutes: Double?
    var steps: Int?
    var activeEnergy: Double?                 // kcal

    init(dayKey: String, date: Date) {
        self.dayKey = dayKey
        self.date = date
    }
}

@Model
final class WorkoutRecord {
    @Attribute(.unique) var hkUUID: String
    var type: String
    var start: Date
    var durationMinutes: Double
    var activeEnergy: Double
    var distanceMeters: Double
    var source: String

    init(hkUUID: String, type: String, start: Date, durationMinutes: Double,
         activeEnergy: Double, distanceMeters: Double, source: String) {
        self.hkUUID = hkUUID
        self.type = type
        self.start = start
        self.durationMinutes = durationMinutes
        self.activeEnergy = activeEnergy
        self.distanceMeters = distanceMeters
        self.source = source
    }
}
