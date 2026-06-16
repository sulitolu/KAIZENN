import Foundation
import Combine

class NutritionStore: ObservableObject {
    static let shared = NutritionStore()

    @Published var entries: [MealEntry] = []
    @Published var waterEntries: [WaterEntry] = []
    @Published var customFoods: [FoodItem] = []
    @Published var favoriteFoods: [FoodItem] = []

    private let entriesKey  = "kaizenn_meal_entries"
    private let waterKey    = "kaizenn_water_entries"
    private let customKey   = "kaizenn_custom_foods"
    private let favKey      = "kaizenn_fav_foods"

    init() { load() }

    // MARK: Queries
    func entries(for date: Date) -> [MealEntry] {
        let cal = Calendar.current
        return entries.filter { cal.isDate($0.date, inSameDayAs: date) }
    }

    func dailyNutrition(for date: Date) -> DailyNutrition {
        DailyNutrition(date: date, entries: entries(for: date))
    }

    func waterConsumedMl(for date: Date) -> Double {
        let cal = Calendar.current
        return waterEntries
            .filter { cal.isDate($0.date, inSameDayAs: date) }
            .map(\.amountMl)
            .reduce(0, +)
    }

    struct DailyMacroSnapshot {
        let date: Date
        let calories: Double
        let proteinG: Double
        let carbsG: Double
        let fatG: Double
    }

    func weeklyNutrition(endingOn date: Date = Date()) -> [DailyMacroSnapshot] {
        (0..<7).reversed().compactMap { offset -> DailyMacroSnapshot? in
            guard let d = Calendar.current.date(byAdding: .day, value: -offset, to: date) else { return nil }
            let n = dailyNutrition(for: d)
            return DailyMacroSnapshot(date: d, calories: n.totalCalories, proteinG: n.totalProteinG, carbsG: n.totalCarbsG, fatG: n.totalFatG)
        }
    }

    func weeklyCalories(endingOn date: Date = Date()) -> [(Date, Double)] {
        (0..<7).reversed().compactMap { offset -> (Date, Double)? in
            guard let d = Calendar.current.date(byAdding: .day, value: -offset, to: date) else { return nil }
            return (d, dailyNutrition(for: d).totalCalories)
        }
    }

    // MARK: Mutations
    func addEntry(_ entry: MealEntry) {
        entries.append(entry)
        save()
    }

    func removeEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func addWater(ml: Double) {
        waterEntries.append(WaterEntry(amountMl: ml))
        save()
    }

    func addCustomFood(_ food: FoodItem) {
        customFoods.append(food)
        save()
    }

    func toggleFavorite(_ food: FoodItem) {
        if favoriteFoods.contains(food) {
            favoriteFoods.removeAll { $0.id == food.id }
        } else {
            favoriteFoods.append(food)
        }
        save()
    }

    func searchFoods(query: String) -> [FoodItem] {
        let all = FoodItem.commonFoods + customFoods
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) || ($0.brand?.localizedCaseInsensitiveContains(query) ?? false) }
    }

    // MARK: Persistence
    private func load() {
        entries       = decode([MealEntry].self, key: entriesKey) ?? []
        waterEntries  = decode([WaterEntry].self, key: waterKey) ?? []
        customFoods   = decode([FoodItem].self, key: customKey) ?? []
        favoriteFoods = decode([FoodItem].self, key: favKey) ?? []
    }

    private func save() {
        encode(entries, key: entriesKey)
        encode(waterEntries, key: waterKey)
        encode(customFoods, key: customKey)
        encode(favoriteFoods, key: favKey)
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    private func encode<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
