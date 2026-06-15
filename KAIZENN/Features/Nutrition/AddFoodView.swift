import SwiftUI

struct AddFoodView: View {
    @EnvironmentObject var nutritionStore: NutritionStore
    @Environment(\.dismiss) var dismiss

    var mealType: MealEntry.MealType
    @State private var searchText = ""
    @State private var selectedFood: FoodItem? = nil
    @State private var grams: String = ""
    @State private var selectedMealType: MealEntry.MealType
    @State private var showCreateCustomFood = false
    @State private var showBarcodeScanner = false
    @State private var isLookingUpBarcode = false
    @State private var barcodeErrorMessage: String? = nil

    init(mealType: MealEntry.MealType) {
        self.mealType = mealType
        _selectedMealType = State(initialValue: mealType)
    }

    private var searchResults: [FoodItem] { nutritionStore.searchFoods(query: searchText) }
    private var preview: (calories: Double, protein: Double, carbs: Double, fat: Double)? {
        guard let food = selectedFood, let g = Double(grams), g > 0 else { return nil }
        return (food.calories(forGrams: g), food.protein(forGrams: g), food.carbs(forGrams: g), food.fat(forGrams: g))
    }

    var body: some View {
        NavigationView {
            ZStack {
                KTheme.Colors.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: KTheme.Spacing.sm) {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(KTheme.Colors.textSecondary)
                            TextField("Search foods...", text: $searchText)
                                .foregroundColor(KTheme.Colors.textPrimary)
                        }
                        .padding(KTheme.Spacing.md)
                        .background(KTheme.Colors.card)
                        .cornerRadius(KTheme.Radius.md)

                        Button {
                            showBarcodeScanner = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(KTheme.Colors.brandGradient)
                                .cornerRadius(KTheme.Radius.md)
                        }
                    }
                    .padding(KTheme.Spacing.md)

                    if let food = selectedFood {
                        // Food selected — show entry form
                        foodEntryForm(food: food)
                    } else {
                        // Show search results
                        List {
                            let favorites = nutritionStore.favoriteFoods.filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
                            if !favorites.isEmpty {
                                Section(header: Text("Favorites").foregroundColor(KTheme.Colors.textSecondary)) {
                                    ForEach(favorites) { food in
                                        FoodSearchRow(food: food, isFavorite: nutritionStore.favoriteFoods.contains(food)) {
                                            selectedFood = food; grams = String(Int(food.servingSizeG))
                                        } onToggleFavorite: {
                                            nutritionStore.toggleFavorite(food)
                                        }
                                    }
                                }
                            }
                            Section(header: Text("All Foods").foregroundColor(KTheme.Colors.textSecondary)) {
                                ForEach(searchResults) { food in
                                    FoodSearchRow(food: food, isFavorite: nutritionStore.favoriteFoods.contains(food)) {
                                        selectedFood = food; grams = String(Int(food.servingSizeG))
                                    } onToggleFavorite: {
                                        nutritionStore.toggleFavorite(food)
                                    }
                                }
                            }
                            Section {
                                Button {
                                    showCreateCustomFood = true
                                } label: {
                                    HStack {
                                        Image(systemName: "plus.circle.fill").foregroundColor(KTheme.Colors.accentPrimary)
                                        Text("Create Custom Food")
                                            .font(KTheme.Typography.bodyMedium)
                                            .foregroundColor(KTheme.Colors.accentPrimary)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(KTheme.Colors.card)
                            }
                        }
                        .listStyle(.plain)
                        .background(KTheme.Colors.background)
                        .scrollContentBackground(.hidden)
                    }
                }

                if isLookingUpBarcode {
                    barcodeLookupOverlay
                }
            }
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
                if selectedFood != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Back") { selectedFood = nil }
                            .foregroundColor(KTheme.Colors.accentPrimary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCreateCustomFood) {
            CreateCustomFoodView { food in
                nutritionStore.addCustomFood(food)
                selectedFood = food
                grams = String(Int(food.servingSizeG))
            }
        }
        .fullScreenCover(isPresented: $showBarcodeScanner) {
            BarcodeScannerSheet { barcode in
                lookUpBarcode(barcode)
            }
        }
        .alert("Couldn't Find Product", isPresented: Binding(
            get: { barcodeErrorMessage != nil },
            set: { if !$0 { barcodeErrorMessage = nil } }
        )) {
            Button("Add Manually") { showCreateCustomFood = true }
            Button("OK", role: .cancel) {}
        } message: {
            Text(barcodeErrorMessage ?? "")
        }
    }

    private var barcodeLookupOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            KCard {
                VStack(spacing: KTheme.Spacing.md) {
                    ProgressView()
                        .tint(KTheme.Colors.accentPrimary)
                    Text("Looking up product...")
                        .font(KTheme.Typography.bodyMedium)
                        .foregroundColor(KTheme.Colors.textPrimary)
                }
                .padding(KTheme.Spacing.lg)
            }
            .frame(width: 200)
        }
    }

    private func lookUpBarcode(_ barcode: String) {
        if let cached = (nutritionStore.customFoods + FoodItem.commonFoods).first(where: { $0.barcode == barcode }) {
            selectedFood = cached
            grams = String(Int(cached.servingSizeG))
            return
        }

        isLookingUpBarcode = true
        Task {
            do {
                let food = try await OpenFoodFactsService.fetchProduct(barcode: barcode)
                await MainActor.run {
                    nutritionStore.addCustomFood(food)
                    selectedFood = food
                    grams = String(Int(food.servingSizeG))
                    isLookingUpBarcode = false
                }
            } catch {
                await MainActor.run {
                    isLookingUpBarcode = false
                    barcodeErrorMessage = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder
    private func foodEntryForm(food: FoodItem) -> some View {
        ScrollView {
            VStack(spacing: KTheme.Spacing.lg) {
                // Food info
                KCard {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                            Text(food.name)
                                .font(KTheme.Typography.headingLarge)
                                .foregroundColor(KTheme.Colors.textPrimary)
                            if let brand = food.brand {
                                Text(brand).font(KTheme.Typography.bodySmall).foregroundColor(KTheme.Colors.textSecondary)
                            }
                            Text("Per 100g: \(Int(food.caloriesPer100g)) cal | P:\(Int(food.proteinPer100g))g C:\(Int(food.carbsPer100g))g F:\(Int(food.fatPer100g))g")
                                .font(KTheme.Typography.caption)
                                .foregroundColor(KTheme.Colors.textSecondary)
                        }
                        Spacer()
                        Button {
                            nutritionStore.toggleFavorite(food)
                        } label: {
                            Image(systemName: nutritionStore.favoriteFoods.contains(food) ? "star.fill" : "star")
                                .font(.system(size: 18))
                                .foregroundColor(KTheme.Colors.accentAmber)
                        }
                    }
                }

                // Serving size
                KCard {
                    VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                        Text("Serving Size").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                        HStack {
                            TextField("grams", text: $grams)
                                .keyboardType(.decimalPad)
                                .font(KTheme.Typography.displaySmall)
                                .foregroundColor(KTheme.Colors.textPrimary)
                            Text("g").font(KTheme.Typography.headingMedium).foregroundColor(KTheme.Colors.textSecondary)
                        }
                        // Quick buttons
                        HStack(spacing: KTheme.Spacing.sm) {
                            ForEach([50, 100, 150, 200, 250], id: \.self) { amount in
                                Button {
                                    grams = String(amount)
                                } label: {
                                    Text("\(amount)g")
                                        .font(KTheme.Typography.label)
                                        .foregroundColor(grams == String(amount) ? .white : KTheme.Colors.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(grams == String(amount) ? KTheme.Colors.accentPrimary : KTheme.Colors.border)
                                        .cornerRadius(KTheme.Radius.sm)
                                }
                            }
                        }
                    }
                }

                // Meal type picker
                KCard {
                    VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                        Text("Meal").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: KTheme.Spacing.sm) {
                                ForEach(MealEntry.MealType.allCases, id: \.self) { type in
                                    Button {
                                        selectedMealType = type
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: type.icon).font(.caption)
                                            Text(type.displayName).font(KTheme.Typography.label)
                                        }
                                        .foregroundColor(selectedMealType == type ? .white : KTheme.Colors.textSecondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedMealType == type ? KTheme.Colors.accentPrimary : KTheme.Colors.card)
                                        .cornerRadius(KTheme.Radius.sm)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: KTheme.Radius.sm)
                                                .stroke(KTheme.Colors.border, lineWidth: selectedMealType == type ? 0 : 0.5)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                // Nutrition preview
                if let p = preview {
                    KCard {
                        VStack(spacing: KTheme.Spacing.md) {
                            Text("Nutrition Preview").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                            HStack {
                                NutrientBubble(value: Int(p.calories), label: "CAL", color: KTheme.Colors.accentPrimary)
                                Spacer()
                                NutrientBubble(value: Int(p.protein), label: "PRO", color: KTheme.Colors.accentSecondary)
                                Spacer()
                                NutrientBubble(value: Int(p.carbs), label: "CARB", color: KTheme.Colors.accentAmber)
                                Spacer()
                                NutrientBubble(value: Int(p.fat), label: "FAT", color: KTheme.Colors.accentTertiary)
                            }
                        }
                    }
                }

                // Log button
                KButton(title: "Log Food", isLoading: false) {
                    guard let food = selectedFood, let g = Double(grams), g > 0 else { return }
                    let entry = MealEntry(mealType: selectedMealType, food: food, gramsConsumed: g)
                    nutritionStore.addEntry(entry)
                    dismiss()
                }
                .disabled(selectedFood == nil || Double(grams) == nil)
                .padding(.bottom, KTheme.Spacing.xxl)
            }
            .padding(KTheme.Spacing.md)
        }
    }
}

struct FoodSearchRow: View {
    let food: FoodItem
    var isFavorite: Bool = false
    let onSelect: () -> Void
    var onToggleFavorite: (() -> Void)? = nil

    var body: some View {
        HStack {
            Button(action: onSelect) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(food.name).font(KTheme.Typography.bodyMedium).foregroundColor(KTheme.Colors.textPrimary)
                        Text("\(Int(food.caloriesPer100g)) cal / 100g").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Text("P:\(Int(food.proteinPer100g)) C:\(Int(food.carbsPer100g)) F:\(Int(food.fatPer100g))")
                        .font(KTheme.Typography.caption)
                        .foregroundColor(KTheme.Colors.textTertiary)
                }
            }
            if let onToggleFavorite = onToggleFavorite {
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: 13))
                        .foregroundColor(KTheme.Colors.accentAmber)
                }
                .padding(.leading, KTheme.Spacing.sm)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(KTheme.Colors.card)
    }
}

// MARK: — Create Custom Food
struct CreateCustomFoodView: View {
    @Environment(\.dismiss) var dismiss
    let onCreate: (FoodItem) -> Void

    @State private var name = ""
    @State private var servingSizeG = "100"
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var fiber = ""

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && Double(servingSizeG) != nil
            && Double(calories) != nil
            && Double(protein) != nil
            && Double(carbs) != nil
            && Double(fat) != nil
    }

    var body: some View {
        NavigationView {
            ZStack {
                KTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: KTheme.Spacing.lg) {
                        KTextField(placeholder: "Food name", text: $name, icon: "fork.knife")

                        KCard {
                            VStack(spacing: KTheme.Spacing.md) {
                                Text("Serving size & nutrition (per serving)")
                                    .font(KTheme.Typography.headingSmall)
                                    .foregroundColor(KTheme.Colors.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                customFoodField("Serving size", suffix: "g", value: $servingSizeG)
                                Divider().background(KTheme.Colors.border)
                                customFoodField("Calories", suffix: "kcal", value: $calories)
                                Divider().background(KTheme.Colors.border)
                                customFoodField("Protein", suffix: "g", value: $protein)
                                Divider().background(KTheme.Colors.border)
                                customFoodField("Carbs", suffix: "g", value: $carbs)
                                Divider().background(KTheme.Colors.border)
                                customFoodField("Fat", suffix: "g", value: $fat)
                                Divider().background(KTheme.Colors.border)
                                customFoodField("Fiber (optional)", suffix: "g", value: $fiber)
                            }
                        }

                        KButton(title: "Create Food") {
                            createFood()
                        }
                        .disabled(!isValid)
                        .padding(.bottom, KTheme.Spacing.xxl)
                    }
                    .padding(KTheme.Spacing.md)
                }
            }
            .navigationTitle("Custom Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(KTheme.Colors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func customFoodField(_ label: String, suffix: String, value: Binding<String>) -> some View {
        HStack {
            Text(label).font(KTheme.Typography.label).foregroundColor(KTheme.Colors.textSecondary)
            Spacer()
            TextField("0", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(KTheme.Colors.textPrimary)
                .font(KTheme.Typography.headingSmall)
            Text(suffix).foregroundColor(KTheme.Colors.textSecondary)
        }
    }

    private func createFood() {
        guard let servingG = Double(servingSizeG),
              let cal = Double(calories),
              let pro = Double(protein),
              let carb = Double(carbs),
              let f = Double(fat),
              servingG > 0 else { return }

        // Macro values are entered per serving — normalize to per-100g for storage
        let scale = 100 / servingG
        let food = FoodItem(
            name: name.trimmingCharacters(in: .whitespaces),
            servingSizeG: servingG,
            servingDescription: "\(Int(servingG))g",
            caloriesPer100g: cal * scale,
            proteinPer100g: pro * scale,
            carbsPer100g: carb * scale,
            fatPer100g: f * scale,
            fiberPer100g: (Double(fiber) ?? 0) * scale
        )
        onCreate(food)
        dismiss()
    }
}

struct NutrientBubble: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)").font(KTheme.Typography.headingMedium).foregroundColor(color)
            Text(label).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
        }
        .frame(width: 60)
        .padding(.vertical, KTheme.Spacing.sm)
        .background(color.opacity(0.1).cornerRadius(KTheme.Radius.sm))
    }
}
