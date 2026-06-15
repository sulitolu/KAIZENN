import Foundation
import Combine

class WeightStore: ObservableObject {
    @Published var measurements: [BodyMeasurement] = []

    private let key = "kaizenn_weight_measurements"

    init() { load() }

    // MARK: Queries
    var latestWeight: Double? { measurements.sorted { $0.date > $1.date }.first?.weightKg }
    var latestMeasurement: BodyMeasurement? { measurements.sorted { $0.date > $1.date }.first }

    func measurements(lastDays days: Int) -> [BodyMeasurement] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        return measurements.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    func weightChange(lastDays days: Int) -> Double? {
        let recent = measurements(lastDays: days)
        guard let first = recent.first?.weightKg, let last = recent.last?.weightKg else { return nil }
        return last - first
    }

    func trendLine(lastDays days: Int) -> [Double] {
        measurements(lastDays: days).map(\.weightKg)
    }

    // MARK: Mutations
    func addMeasurement(_ m: BodyMeasurement) {
        measurements.append(m)
        save()
    }

    func removeMeasurement(id: UUID) {
        measurements.removeAll { $0.id == id }
        save()
    }

    // MARK: Persistence
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([BodyMeasurement].self, from: data) else { return }
        measurements = decoded
    }

    private func save() {
        if let data = try? JSONEncoder().encode(measurements) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
