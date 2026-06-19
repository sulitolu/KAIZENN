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
                    searchBar
                    if let food = selectedFood {
                        foodEntryForm(food: food)
                    } else {
                        foodListView
                    }
                }

                if isLookingUpBarcode {
                    barcodeLookupOverlay
                }
            }
            .navigationTitle("LOG FOOD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
                if selectedFood != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Back") { selectedFood = nil }
                            .foregroundColor(KTheme.Colors.accentAmber)
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

    // MARK: Search Bar

    private var searchBar: some View {
        HStack(spacing: KTheme.Spacing.sm) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(KTheme.Colors.textSecondary)
                TextField("Search foods...", text: $searchText)
                    .foregroundColor(KTheme.Colors.textPrimary)
            }
            .padding(KTheme.Spacing.md)
            .background(KTheme.Colors.card)
            .cornerRadius(KTheme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: KTheme.Radius.md)
                    .stroke(KTheme.Colors.border.opacity(0.5), lineWidth: 0.5)
            )

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
    }

    // MARK: Food List

    private var foodListView: some View {
        List {
            let favorites = nutritionStore.favoriteFoods.filter {
                searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
            }
            if !favorites.isEmpty {
                Section(header: premiumSectionHeader("FAVORITES", icon: "star.fill")) {
                    ForEach(favorites) { food in
                        FoodSearchRow(food: food, isFavorite: nutritionStore.favoriteFoods.contains(food)) {
                            selectedFood = food; grams = String(Int(food.servingSizeG))
                        } onToggleFavorite: {
                            nutritionStore.toggleFavorite(food)
                        }
                    }
                }
            }
            Section(header: premiumSectionHeader("ALL FOODS", icon: "fork.knife")) {
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
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(KTheme.Colors.accentAmber)
                        Text("Create Custom Food")
                            .font(KTheme.Typography.bodyMedium)
                            .foregroundColor(KTheme.Colors.accentAmber)
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

    // MARK: Premium Section Header

    private func premiumSectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: KTheme.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(KTheme.Colors.accentAmber.opacity(0.8))
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(KTheme.Colors.accentAmber.opacity(0.8))
                .tracking(2)
        }
        .padding(.top, KTheme.Spacing.xs)
    }

    // MARK: Barcode Lookup Overlay

    private var barcodeLookupOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            KCard {
                VStack(spacing: KTheme.Spacing.md) {
                    ProgressView()
                        .tint(KTheme.Colors.accentAmber)
                    Text("Looking up product...")
                        .font(KTheme.Typography.bodyMedium)
                        .foregroundColor(KTheme.Colors.textPrimary)
                }
                .padding(KTheme.Spacing.lg)
            }
            .frame(width: 200)
        }
    }

    // MARK: Barcode Lookup

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

    // MARK: Food Entry Form

    @ViewBuilder
    private func foodEntryForm(food: FoodItem) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: KTheme.Spacing.lg) {

                // Hero calorie moment
                if let p = preview {
                    heroCard(p: p)
                } else {
                    heroCardPlaceholder(food: food)
                }

                // Serving size card
                servingCard

                // Meal type picker
                mealTypeCard

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

    // MARK: Hero Card (calorie + macro moment)

    private func heroCard(p: (calories: Double, protein: Double, carbs: Double, fat: Double)) -> some View {
        VStack(spacing: KTheme.Spacing.md) {
            // Food name + favorite
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: KTheme.Spacing.xs) {
                    Text(selectedFood?.name ?? "")
                        .font(KTheme.Typography.headingLarge)
                        .foregroundColor(KTheme.Colors.textPrimary)
                    if let brand = selectedFood?.brand {
                        Text(brand)
                            .font(KTheme.Typography.bodySmall)
                            .foregroundColor(KTheme.Colors.textSecondary)
                    }
                }
                Spacer()
                Button {
                    if let food = selectedFood { nutritionStore.toggleFavorite(food) }
                } label: {
                    Image(systemName: (selectedFood.map { nutritionStore.favoriteFoods.contains($0) } ?? false) ? "star.fill" : "star")
                        .font(.system(size: 18))
                        .foregroundColor(KTheme.Colors.accentAmber)
                }
            }

            Divider().background(KTheme.Colors.border)

            // Big calorie number
            VStack(spacing: KTheme.Spacing.xs) {
                Text("\(Int(p.calories))")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundColor(KTheme.Colors.textPrimary)
                    .contentTransition(.numericText())
                Text("KCAL")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(KTheme.Colors.accentAmber.opacity(0.8))
                    .tracking(1.5)
            }

            // Macro row
            HStack(spacing: KTheme.Spacing.sm) {
                premiumMacroCell(value: Int(p.protein), label: "PROTEIN", color: KTheme.Colors.accentSecondary)
                premiumMacroCell(value: Int(p.carbs),   label: "CARBS",   color: KTheme.Colors.accentAmber)
                premiumMacroCell(value: Int(p.fat),     label: "FAT",     color: KTheme.Colors.accentTertiary)
            }

            // Per 100g footnote
            if let food = selectedFood {
                Text("Per 100g: \(Int(food.caloriesPer100g)) kcal  •  P \(Int(food.proteinPer100g))g  C \(Int(food.carbsPer100g))g  F \(Int(food.fatPer100g))g")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(KTheme.Colors.textTertiary)
                    .tracking(0.5)
            }
        }
        .padding(KTheme.Spacing.lg)
        .background(KTheme.Colors.cardElevated)
        .cornerRadius(KTheme.Radius.lg)
        .overlay(amberBorderOverlay)
        .shadow(color: KTheme.Colors.accentAmber.opacity(0.15), radius: 20, x: 0, y: 0)
    }

    private func heroCardPlaceholder(food: FoodItem) -> some View {
        VStack(spacing: KTheme.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: KTheme.Spacing.xs) {
                    Text(food.name)
                        .font(KTheme.Typography.headingLarge)
                        .foregroundColor(KTheme.Colors.textPrimary)
                    if let brand = food.brand {
                        Text(brand)
                            .font(KTheme.Typography.bodySmall)
                            .foregroundColor(KTheme.Colors.textSecondary)
                    }
                    Text("Per 100g: \(Int(food.caloriesPer100g)) kcal  •  P \(Int(food.proteinPer100g))g  C \(Int(food.carbsPer100g))g  F \(Int(food.fatPer100g))g")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(KTheme.Colors.textTertiary)
                        .tracking(0.5)
                        .padding(.top, 2)
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

            Text("Enter grams below to see nutrition")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(KTheme.Colors.textTertiary)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(KTheme.Spacing.lg)
        .background(KTheme.Colors.card)
        .cornerRadius(KTheme.Radius.lg)
        .overlay(amberBorderOverlay)
    }

    // MARK: Amber border overlay (helper to avoid nested ternaries)

    private var amberBorderOverlay: some View {
        RoundedRectangle(cornerRadius: KTheme.Radius.lg)
            .stroke(KTheme.Colors.accentAmber.opacity(0.3), lineWidth: 0.5)
    }

    // MARK: Premium Macro Cell

    private func premiumMacroCell(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)g")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(0.8))
                .tracking(1.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, KTheme.Spacing.sm)
        .background(color.opacity(0.1))
        .cornerRadius(KTheme.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: KTheme.Radius.sm)
                .stroke(color.opacity(0.2), lineWidth: 0.5)
        )
    }

    // MARK: Serving Card

    private var servingCard: some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
            Text("GRAMS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(KTheme.Colors.accentAmber.opacity(0.8))
                .tracking(2)

            HStack(alignment: .lastTextBaseline, spacing: KTheme.Spacing.xs) {
                TextField("0", text: $grams)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(KTheme.Colors.textPrimary)
                    .frame(minWidth: 80, alignment: .leading)
                Text("g")
                    .font(KTheme.Typography.headingMedium)
                    .foregroundColor(KTheme.Colors.textSecondary)
            }

            // Quick-select buttons
            HStack(spacing: KTheme.Spacing.sm) {
                ForEach([50, 100, 150, 200, 250], id: \.self) { amount in
                    quickGramsButton(amount: amount)
                }
            }
        }
        .padding(KTheme.Spacing.md)
        .background(KTheme.Colors.card)
        .cornerRadius(KTheme.Radius.lg)
        .overlay(amberBorderOverlay)
        .shadow(color: KTheme.Colors.accentAmber.opacity(0.08), radius: 12, x: 0, y: 0)
    }

    private func quickGramsButton(amount: Int) -> some View {
        let isSelected = grams == String(amount)
        return Button {
            grams = String(amount)
        } label: {
            Text("\(amount)g")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(isSelected ? .white : KTheme.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(isSelected ? KTheme.Colors.accentAmber : KTheme.Colors.border)
                .cornerRadius(KTheme.Radius.sm)
        }
    }

    // MARK: Meal Type Card

    private var mealTypeCard: some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
            Text("MEAL")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(KTheme.Colors.accentAmber.opacity(0.8))
                .tracking(2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: KTheme.Spacing.sm) {
                    ForEach(MealEntry.MealType.allCases, id: \.self) { type in
                        mealTypeChip(type: type)
                    }
                }
            }
        }
        .padding(KTheme.Spacing.md)
        .background(KTheme.Colors.card)
        .cornerRadius(KTheme.Radius.lg)
        .overlay(amberBorderOverlay)
    }

    private func mealTypeChip(type: MealEntry.MealType) -> some View {
        let isSelected = selectedMealType == type
        return Button {
            selectedMealType = type
        } label: {
            HStack(spacing: 4) {
                Image(systemName: type.icon).font(.caption)
                Text(type.displayName)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(0.5)
            }
            .foregroundColor(isSelected ? .white : KTheme.Colors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? KTheme.Colors.accentAmber : KTheme.Colors.card)
            .cornerRadius(KTheme.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: KTheme.Radius.sm)
                    .stroke(isSelected ? Color.clear : KTheme.Colors.border, lineWidth: 0.5)
            )
        }
    }
}

// MARK: — Food Search Row

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
                        Text(food.name)
                            .font(KTheme.Typography.bodyMedium)
                            .foregroundColor(KTheme.Colors.textPrimary)
                        Text("\(Int(food.caloriesPer100g)) kcal / 100g")
                            .font(KTheme.Typography.caption)
                            .foregroundColor(KTheme.Colors.textSecondary)
                    }
                    Spacer()
                    Text("P:\(Int(food.proteinPer100g)) C:\(Int(food.carbsPer100g)) F:\(Int(food.fatPer100g))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
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
                                Text("SERVING & NUTRITION")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(KTheme.Colors.accentAmber.opacity(0.8))
                                    .tracking(2)
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
                    Button("Cancel") { dismiss() }
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func customFoodField(_ label: String, suffix: String, value: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(KTheme.Typography.label)
                .foregroundColor(KTheme.Colors.textSecondary)
            Spacer()
            TextField("0", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundColor(KTheme.Colors.textPrimary)
                .font(KTheme.Typography.headingSmall)
            Text(suffix)
                .foregroundColor(KTheme.Colors.textSecondary)
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

// MARK: — Nutrient Bubble (kept for any callers outside this file)

struct NutrientBubble: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(KTheme.Typography.headingMedium)
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(0.8))
                .tracking(1.5)
        }
        .frame(width: 60)
        .padding(.vertical, KTheme.Spacing.sm)
        .background(color.opacity(0.1).cornerRadius(KTheme.Radius.sm))
    }
}
