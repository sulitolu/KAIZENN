// KAIZENN/Data/HealthStore/HealthStore.swift
import Foundation
import SwiftData

@MainActor
final class HealthStore: ObservableObject {
    let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(inMemory: Bool = false) {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(
                for: DailyHealthSnapshot.self, WorkoutRecord.self,
                configurations: config)
        } catch {
            fatalError("HealthStore ModelContainer failed: \(error)")
        }
    }

    // Configured once and only ever read (string(from:)) — safe to share across
    // isolation domains, so dayKey(for:) can be nonisolated.
    nonisolated private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    nonisolated static func dayKey(for date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    func upsertSnapshot(date: Date, _ mutate: (DailyHealthSnapshot) -> Void) {
        let key = Self.dayKey(for: date)
        let descriptor = FetchDescriptor<DailyHealthSnapshot>(
            predicate: #Predicate { $0.dayKey == key })
        let existing = (try? context.fetch(descriptor))?.first
        let snapshot = existing ?? DailyHealthSnapshot(dayKey: key, date: date)
        if existing == nil { context.insert(snapshot) }
        mutate(snapshot)
        try? context.save()
    }

    func snapshots(since: Date) -> [DailyHealthSnapshot] {
        let descriptor = FetchDescriptor<DailyHealthSnapshot>(
            predicate: #Predicate { $0.date >= since },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func upsertWorkout(uuid: String, type: String, start: Date, durationMinutes: Double,
                       activeEnergy: Double, distanceMeters: Double, source: String) {
        let descriptor = FetchDescriptor<WorkoutRecord>(
            predicate: #Predicate { $0.hkUUID == uuid })
        let existing = (try? context.fetch(descriptor))?.first
        if let w = existing {
            w.type = type; w.start = start; w.durationMinutes = durationMinutes
            w.activeEnergy = activeEnergy; w.distanceMeters = distanceMeters; w.source = source
        } else {
            context.insert(WorkoutRecord(hkUUID: uuid, type: type, start: start,
                durationMinutes: durationMinutes, activeEnergy: activeEnergy,
                distanceMeters: distanceMeters, source: source))
        }
        try? context.save()
    }

    func workouts(since: Date) -> [WorkoutRecord] {
        let descriptor = FetchDescriptor<WorkoutRecord>(
            predicate: #Predicate { $0.start >= since },
            sortBy: [SortDescriptor(\.start, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
