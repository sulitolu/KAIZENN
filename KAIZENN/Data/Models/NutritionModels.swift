import Foundation

// MARK: — Food Item
struct FoodItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var brand: String? = nil
    var servingSizeG: Double = 100
    var servingDescription: String = "100g"
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var fiberPer100g: Double = 0
    var sugarPer100g: Double = 0
    var sodiumMgPer100g: Double = 0
    var barcode: String? = nil

    func calories(forGrams grams: Double)   -> Double { (caloriesPer100g / 100) * grams }
    func protein(forGrams grams: Double)    -> Double { (proteinPer100g / 100) * grams }
    func carbs(forGrams grams: Double)      -> Double { (carbsPer100g / 100) * grams }
    func fat(forGrams grams: Double)        -> Double { (fatPer100g / 100) * grams }
    func fiber(forGrams grams: Double)      -> Double { (fiberPer100g / 100) * grams }
}

// MARK: — Meal Log Entry
struct MealEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var mealType: MealType
    var food: FoodItem
    var gramsConsumed: Double
    var notes: String? = nil

    enum MealType: String, Codable, CaseIterable {
        case breakfast, lunch, dinner, snack, preworkout, postworkout
        var displayName: String {
            switch self {
            case .breakfast:    return "Breakfast"
            case .lunch:        return "Lunch"
            case .dinner:       return "Dinner"
            case .snack:        return "Snack"
            case .preworkout:   return "Pre-Workout"
            case .postworkout:  return "Post-Workout"
            }
        }
        var icon: String {
            switch self {
            case .breakfast:   return "sun.horizon.fill"
            case .lunch:       return "sun.max.fill"
            case .dinner:      return "moon.stars.fill"
            case .snack:       return "leaf.fill"
            case .preworkout:  return "bolt.fill"
            case .postworkout: return "checkmark.seal.fill"
            }
        }
        var color: String {
            switch self {
            case .breakfast:   return "FFB347"
            case .lunch:       return "4ECDC4"
            case .dinner:      return "7C6FFF"
            case .snack:       return "FF6B8A"
            case .preworkout:  return "FFB347"
            case .postworkout: return "4ECDC4"
            }
        }

        /// Best-guess meal type based on the current time of day.
        static var current: MealType {
            switch Calendar.current.component(.hour, from: Date()) {
            case 4..<11:  return .breakfast
            case 11..<15: return .lunch
            case 15..<18: return .snack
            default:      return .dinner
            }
        }
    }

    var calories:  Double { food.calories(forGrams: gramsConsumed) }
    var proteinG:  Double { food.protein(forGrams: gramsConsumed) }
    var carbsG:    Double { food.carbs(forGrams: gramsConsumed) }
    var fatG:      Double { food.fat(forGrams: gramsConsumed) }
    var fiberG:    Double { food.fiber(forGrams: gramsConsumed) }
}

// MARK: — Daily Nutrition Summary
struct DailyNutrition {
    let date: Date
    let entries: [MealEntry]

    var totalCalories: Double { entries.map(\.calories).reduce(0, +) }
    var totalProteinG:  Double { entries.map(\.proteinG).reduce(0, +) }
    var totalCarbsG:    Double { entries.map(\.carbsG).reduce(0, +) }
    var totalFatG:      Double { entries.map(\.fatG).reduce(0, +) }
    var totalFiberG:    Double { entries.map(\.fiberG).reduce(0, +) }

    func entries(for mealType: MealEntry.MealType) -> [MealEntry] {
        entries.filter { $0.mealType == mealType }
    }
}

// MARK: — Water Log
struct WaterEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var amountMl: Double
}

// MARK: — Common Foods Database (bundled starter data)
extension FoodItem {
    static let commonFoods: [FoodItem] = [
        FoodItem(name: "Chicken Breast", servingDescription: "100g", caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6),
        FoodItem(name: "Brown Rice (cooked)", servingDescription: "100g", caloriesPer100g: 122, proteinPer100g: 2.6, carbsPer100g: 26, fatPer100g: 0.9, fiberPer100g: 1.8),
        FoodItem(name: "Egg", servingSizeG: 50, servingDescription: "1 large egg", caloriesPer100g: 155, proteinPer100g: 13, carbsPer100g: 1.1, fatPer100g: 11),
        FoodItem(name: "Oats (dry)", servingDescription: "100g", caloriesPer100g: 389, proteinPer100g: 17, carbsPer100g: 66, fatPer100g: 7, fiberPer100g: 10.6),
        FoodItem(name: "Banana", servingSizeG: 120, servingDescription: "1 medium", caloriesPer100g: 89, proteinPer100g: 1.1, carbsPer100g: 23, fatPer100g: 0.3, fiberPer100g: 2.6),
        FoodItem(name: "Greek Yogurt (0% fat)", servingDescription: "100g", caloriesPer100g: 57, proteinPer100g: 10, carbsPer100g: 3.6, fatPer100g: 0.4),
        FoodItem(name: "Salmon (cooked)", servingDescription: "100g", caloriesPer100g: 208, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 13),
        FoodItem(name: "Sweet Potato (cooked)", servingDescription: "100g", caloriesPer100g: 90, proteinPer100g: 2, carbsPer100g: 21, fatPer100g: 0.1, fiberPer100g: 3.3),
        FoodItem(name: "Almonds", servingSizeG: 28, servingDescription: "1 oz (28g)", caloriesPer100g: 579, proteinPer100g: 21, carbsPer100g: 22, fatPer100g: 50, fiberPer100g: 12.5),
        FoodItem(name: "Avocado", servingSizeG: 136, servingDescription: "½ avocado", caloriesPer100g: 160, proteinPer100g: 2, carbsPer100g: 9, fatPer100g: 15, fiberPer100g: 7),
        FoodItem(name: "Broccoli", servingDescription: "100g", caloriesPer100g: 34, proteinPer100g: 2.8, carbsPer100g: 7, fatPer100g: 0.4, fiberPer100g: 2.6),
        FoodItem(name: "Whole Milk", servingSizeG: 240, servingDescription: "1 cup", caloriesPer100g: 61, proteinPer100g: 3.2, carbsPer100g: 4.8, fatPer100g: 3.3),
        FoodItem(name: "Whey Protein Powder", servingSizeG: 30, servingDescription: "1 scoop", caloriesPer100g: 373, proteinPer100g: 80, carbsPer100g: 7, fatPer100g: 5),
        FoodItem(name: "Olive Oil", servingSizeG: 14, servingDescription: "1 tbsp", caloriesPer100g: 884, proteinPer100g: 0, carbsPer100g: 0, fatPer100g: 100),
        FoodItem(name: "Apple", servingSizeG: 182, servingDescription: "1 medium", caloriesPer100g: 52, proteinPer100g: 0.3, carbsPer100g: 14, fatPer100g: 0.2, fiberPer100g: 2.4),
    ]
}
