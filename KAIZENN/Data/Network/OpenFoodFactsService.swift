import Foundation

// MARK: — Open Food Facts product lookup
enum OpenFoodFactsError: LocalizedError {
    case productNotFound
    case missingNutritionData
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .productNotFound:     return "No product found for this barcode."
        case .missingNutritionData: return "This product doesn't have enough nutrition info on file."
        case .requestFailed:       return "Couldn't reach Open Food Facts. Check your connection and try again."
        }
    }
}

struct OpenFoodFactsService {
    private static let fields = "product_name,brands,serving_size,serving_quantity,nutriments"

    static func fetchProduct(barcode: String) async throws -> FoodItem {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=\(fields)") else {
            throw OpenFoodFactsError.requestFailed
        }

        var request = URLRequest(url: url)
        request.setValue("KAIZENN-iOS-App - https://kaizenn.app", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OpenFoodFactsError.requestFailed
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw OpenFoodFactsError.requestFailed
        }

        let decoded: OFFResponse
        do {
            decoded = try JSONDecoder().decode(OFFResponse.self, from: data)
        } catch {
            throw OpenFoodFactsError.requestFailed
        }

        guard decoded.status == 1, let product = decoded.product, let nutriments = product.nutriments else {
            throw OpenFoodFactsError.productNotFound
        }

        let calories = nutriments.energyKcal100g ?? nutriments.energy100g.map { $0 / 4.184 } ?? 0
        let hasUsefulData = calories > 0
            || (nutriments.proteins100g ?? 0) > 0
            || (nutriments.carbohydrates100g ?? 0) > 0
            || (nutriments.fat100g ?? 0) > 0
        guard hasUsefulData else {
            throw OpenFoodFactsError.missingNutritionData
        }

        let sodiumMg = nutriments.sodium100g.map { $0 * 1000 }
            ?? nutriments.salt100g.map { ($0 / 2.5) * 1000 }
            ?? 0

        let trimmedName = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let servingG = product.servingQuantity ?? 100

        return FoodItem(
            name: (trimmedName?.isEmpty == false) ? trimmedName! : "Unknown Product",
            brand: product.brands?.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) },
            servingSizeG: servingG > 0 ? servingG : 100,
            servingDescription: product.servingSize ?? "100g",
            caloriesPer100g: calories,
            proteinPer100g: nutriments.proteins100g ?? 0,
            carbsPer100g: nutriments.carbohydrates100g ?? 0,
            fatPer100g: nutriments.fat100g ?? 0,
            fiberPer100g: nutriments.fiber100g ?? 0,
            sugarPer100g: nutriments.sugars100g ?? 0,
            sodiumMgPer100g: sodiumMg,
            barcode: barcode
        )
    }
}

// MARK: — Open Food Facts API response models
private struct OFFResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

private struct OFFProduct: Decodable {
    let productName: String?
    let brands: String?
    let servingSize: String?
    let servingQuantity: Double?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case nutriments
    }
}

private struct OFFNutriments: Decodable {
    let energyKcal100g: Double?
    let energy100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let fiber100g: Double?
    let sugars100g: Double?
    let sodium100g: Double?
    let salt100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case energy100g = "energy_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
        case sugars100g = "sugars_100g"
        case sodium100g = "sodium_100g"
        case salt100g = "salt_100g"
    }
}
