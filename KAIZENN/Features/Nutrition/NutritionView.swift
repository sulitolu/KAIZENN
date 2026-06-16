import SwiftUI

struct NutritionView: View {
    @EnvironmentObject var nutritionStore: NutritionStore
    @EnvironmentObject var appState: AppState

    @State private var showAddFood = false
    @State private var selectedMealType: MealEntry.MealType = .breakfast
    @State private var selectedDate = Date()
    @State private var chartMetric: ChartMetric = .calories

    enum ChartMetric: String, CaseIterable {
        case calories = "Calories"
        case protein  = "Protein"
        case carbs    = "Carbs"
        case fat      = "Fat"

        var color: Color {
            switch self {
            case .calories: return KTheme.Colors.accentPrimary
            case .protein:  return KTheme.Colors.accentSecondary
            case .carbs:    return KTheme.Colors.accentAmber
            case .fat:      return KTheme.Colors.accentTertiary
            }
        }
        var unit: String { self == .calories ? "kcal" : "g" }
    }

    private var todayNutrition: DailyNutrition { nutritionStore.dailyNutrition(for: selectedDate) }
    private var targets: MacroTargets { appState.userProfile.macroTargets }

    var body: some View {
        ZStack {
            KTheme.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: KTheme.Spacing.lg) {

                    // Page Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nutrition")
                                .font(KTheme.Typography.displaySmall)
                                .foregroundColor(KTheme.Colors.textPrimary)
                            dateNavigator
                        }
                        Spacer()
                        Button {
                            showAddFood = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Log Food")
                            }
                            .font(KTheme.Typography.label)
                            .foregroundColor(.white)
                            .padding(.horizontal, KTheme.Spacing.md)
                            .padding(.vertical, KTheme.Spacing.sm)
                            .background(KTheme.Colors.brandGradient.cornerRadius(KTheme.Radius.pill))
                        }
                    }

                    // Calorie Ring + Macros
                    calorieRingCard

                    // Water tracker
                    waterTracker

                    // Meal sections
                    ForEach(MealEntry.MealType.allCases, id: \.self) { mealType in
                        MealSectionView(
                            mealType: mealType,
                            entries: todayNutrition.entries(for: mealType),
                            onDelete: { id in nutritionStore.removeEntry(id: id) },
                            onAddFood: {
                                selectedMealType = mealType
                                showAddFood = true
                            }
                        )
                    }

                    // Weekly chart
                    weeklyCalorieChart

                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, KTheme.Spacing.md)
                .padding(.top, KTheme.Spacing.md)
            }
        }
        .sheet(isPresented: $showAddFood) {
            AddFoodView(mealType: selectedMealType)
        }
    }

    // MARK: Calorie Ring Card
    private var calorieRingCard: some View {
        KCard(elevated: true) {
            HStack(spacing: KTheme.Spacing.xl) {
                ZStack {
                    KProgressRing(
                        progress: todayNutrition.totalCalories,
                        total: Double(targets.calories),
                        size: 120,
                        lineWidth: 10,
                        color: KTheme.Colors.accentPrimary
                    )
                    VStack(spacing: 2) {
                        Text("\(Int(todayNutrition.totalCalories))")
                            .font(KTheme.Typography.displaySmall)
                            .foregroundColor(KTheme.Colors.textPrimary)
                        Text("of \(targets.calories)")
                            .font(KTheme.Typography.caption)
                            .foregroundColor(KTheme.Colors.textSecondary)
                        Text("kcal")
                            .font(KTheme.Typography.caption)
                            .foregroundColor(KTheme.Colors.textTertiary)
                    }
                }

                VStack(spacing: KTheme.Spacing.md) {
                    MacroBar(label: "Protein", current: todayNutrition.totalProteinG, target: Double(targets.proteinG), color: KTheme.Colors.accentSecondary)
                    MacroBar(label: "Carbs", current: todayNutrition.totalCarbsG, target: Double(targets.carbsG), color: KTheme.Colors.accentAmber)
                    MacroBar(label: "Fat", current: todayNutrition.totalFatG, target: Double(targets.fatG), color: KTheme.Colors.accentTertiary)
                    MacroBar(label: "Fiber", current: todayNutrition.totalFiberG, target: 30, color: KTheme.Colors.success)
                }
            }
        }
    }

    // MARK: Water
    private var waterTracker: some View {
        let consumed = nutritionStore.waterConsumedMl(for: selectedDate)
        let target: Double = 2500
        let glasses: [Double] = [250, 250, 250, 500, 500, 500, 250]

        return KCard {
            VStack(spacing: KTheme.Spacing.md) {
                HStack {
                    Image(systemName: "drop.fill").foregroundColor(Color(hex: "4FC3F7"))
                    Text("Water Intake")
                        .font(KTheme.Typography.headingSmall)
                        .foregroundColor(KTheme.Colors.textPrimary)
                    Spacer()
                    Text(String(format: "%.0f / %.0fml", consumed, target))
                        .font(KTheme.Typography.bodySmall)
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
                HStack(spacing: KTheme.Spacing.sm) {
                    ForEach(glasses.indices, id: \.self) { i in
                        Button {
                            nutritionStore.addWater(ml: glasses[i])
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: consumed > (glasses[0..<i+1].reduce(0, +) - 1) ? "drop.fill" : "drop")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(hex: "4FC3F7").opacity(consumed >= glasses[0...i].reduce(0, +) ? 1 : 0.3))
                                Text("+\(Int(glasses[i]))ml").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textTertiary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Weekly Chart
    private var weeklyCalorieChart: some View {
        KSection(title: "This Week") {
            KCard {
                let data = nutritionStore.weeklyNutrition()

                VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                    // Metric picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: KTheme.Spacing.sm) {
                            ForEach(ChartMetric.allCases, id: \.self) { metric in
                                Button { withAnimation(KTheme.Animation.snappy) { chartMetric = metric } } label: {
                                    Text(metric.rawValue)
                                        .font(KTheme.Typography.label)
                                        .foregroundColor(chartMetric == metric ? .white : KTheme.Colors.textSecondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(chartMetric == metric ? metric.color : KTheme.Colors.border)
                                        .cornerRadius(KTheme.Radius.pill)
                                }
                            }
                        }
                    }

                    // Bar chart
                    let values: [Double] = data.map { snap in
                        switch chartMetric {
                        case .calories: return snap.calories
                        case .protein:  return snap.proteinG
                        case .carbs:    return snap.carbsG
                        case .fat:      return snap.fatG
                        }
                    }
                    let maxVal = values.max() ?? 1
                    let target: Double = {
                        switch chartMetric {
                        case .calories: return Double(targets.calories)
                        case .protein:  return Double(targets.proteinG)
                        case .carbs:    return Double(targets.carbsG)
                        case .fat:      return Double(targets.fatG)
                        }
                    }()
                    let chartHeight: CGFloat = 90

                    ZStack(alignment: .topLeading) {
                        // Target dashed line
                        let targetY = chartHeight - CGFloat(min(target, maxVal) / max(maxVal, 1)) * chartHeight
                        Rectangle()
                            .fill(chartMetric.color.opacity(0.4))
                            .frame(height: 1)
                            .offset(y: targetY)

                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(Array(zip(data, values)), id: \.0.date) { snap, val in
                                VStack(spacing: 4) {
                                    let h = CGFloat(val / max(maxVal, 1)) * chartHeight
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Calendar.current.isDateInToday(snap.date)
                                              ? AnyShapeStyle(chartMetric.color)
                                              : AnyShapeStyle(chartMetric.color.opacity(0.35)))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: max(h, 4))
                                    Text(dayLabel(snap.date))
                                        .font(KTheme.Typography.caption)
                                        .foregroundColor(Calendar.current.isDateInToday(snap.date)
                                                         ? chartMetric.color
                                                         : KTheme.Colors.textTertiary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: chartHeight)
                    }
                    .frame(height: chartHeight)

                    // Stats row
                    let avg = values.reduce(0, +) / max(Double(values.count), 1)
                    HStack {
                        Text("Avg: \(Int(avg)) \(chartMetric.unit)")
                            .font(KTheme.Typography.caption)
                            .foregroundColor(KTheme.Colors.textSecondary)
                        Spacer()
                        HStack(spacing: 4) {
                            Rectangle().fill(chartMetric.color.opacity(0.4)).frame(width: 16, height: 1)
                            Text("Target: \(Int(target)) \(chartMetric.unit)")
                                .font(KTheme.Typography.caption)
                                .foregroundColor(KTheme.Colors.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EE"
        return f.string(from: date)
    }

    // MARK: Date Navigator
    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    private var dateNavigator: some View {
        HStack(spacing: KTheme.Spacing.xs) {
            Button {
                withAnimation(KTheme.Animation.smooth) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(KTheme.Colors.textSecondary)
            }

            Text(isToday ? "Today" : selectedDateLabel)
                .font(KTheme.Typography.bodySmall)
                .foregroundColor(KTheme.Colors.textSecondary)
                .frame(minWidth: 70)

            Button {
                withAnimation(KTheme.Animation.smooth) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isToday ? KTheme.Colors.textTertiary : KTheme.Colors.textSecondary)
            }
            .disabled(isToday)
        }
    }

    private var selectedDateLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return f.string(from: selectedDate)
    }
}

// MARK: — Macro Bar
struct MacroBar: View {
    let label: String
    let current: Double
    let target: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                Spacer()
                Text(String(format: "%.0fg / %.0fg", current, target)).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(KTheme.Colors.border).frame(height: 5)
                    RoundedRectangle(cornerRadius: 3).fill(color).frame(width: min(geo.size.width * CGFloat(current / max(target, 1)), geo.size.width), height: 5)
                }
            }.frame(height: 5)
        }
    }
}

// MARK: — Meal Section
struct MealSectionView: View {
    let mealType: MealEntry.MealType
    let entries: [MealEntry]
    let onDelete: (UUID) -> Void
    let onAddFood: () -> Void

    private var mealCalories: Double { entries.map(\.calories).reduce(0, +) }
    @State private var isExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(KTheme.Animation.smooth) { isExpanded.toggle() }
            } label: {
                HStack {
                    HStack(spacing: KTheme.Spacing.sm) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: mealType.color).opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: mealType.icon)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: mealType.color))
                        }
                        Text(mealType.displayName)
                            .font(KTheme.Typography.headingSmall)
                            .foregroundColor(KTheme.Colors.textPrimary)
                    }
                    Spacer()
                    Text("\(Int(mealCalories)) cal")
                        .font(KTheme.Typography.label)
                        .foregroundColor(KTheme.Colors.textSecondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(KTheme.Colors.textTertiary)
                        .padding(.leading, 4)
                }
                .padding(KTheme.Spacing.md)
                .background(KTheme.Colors.card.cornerRadius(entries.isEmpty || !isExpanded ? KTheme.Radius.md : 0))
                .cornerRadius(KTheme.Radius.md, corners: isExpanded ? [.topLeft, .topRight] : .allCorners)
            }

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(entries) { entry in
                        FoodEntryRow(entry: entry) { onDelete(entry.id) }
                        if entry.id != entries.last?.id {
                            Divider().background(KTheme.Colors.border).padding(.horizontal, KTheme.Spacing.md)
                        }
                    }
                    Button(action: onAddFood) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(KTheme.Colors.accentPrimary)
                            Text("Add Food")
                                .font(KTheme.Typography.label)
                                .foregroundColor(KTheme.Colors.accentPrimary)
                            Spacer()
                        }
                        .padding(KTheme.Spacing.md)
                    }
                }
                .background(KTheme.Colors.card)
                .cornerRadius(KTheme.Radius.md, corners: [.bottomLeft, .bottomRight])
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: KTheme.Radius.md))
    }
}

struct FoodEntryRow: View {
    let entry: MealEntry
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.food.name).font(KTheme.Typography.bodyMedium).foregroundColor(KTheme.Colors.textPrimary)
                Text(String(format: "%.0fg", entry.gramsConsumed)).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.calories)) kcal").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                HStack(spacing: 6) {
                    Text("P:\(Int(entry.proteinG))").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.accentSecondary)
                    Text("C:\(Int(entry.carbsG))").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.accentAmber)
                    Text("F:\(Int(entry.fatG))").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.accentTertiary)
                }
            }
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(KTheme.Colors.textTertiary)
                    .padding(8)
            }
        }
        .padding(.horizontal, KTheme.Spacing.md)
        .padding(.vertical, KTheme.Spacing.sm)
    }
}

// MARK: Corner Radius Helper
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
