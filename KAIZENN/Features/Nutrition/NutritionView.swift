import SwiftUI

struct NutritionView: View {
    @EnvironmentObject var nutritionStore: NutritionStore
    @EnvironmentObject var appState: AppState

    @State private var showAddFood = false
    @State private var showFoodScan = false
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
    private var sport: SportProfile { appState.userProfile.sportProfile }

    // MARK: Helpers

    private var weekdayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: selectedDate).uppercased()
    }

    private var phaseLabel: String {
        sport.seasonPhase.displayName.uppercased().replacingOccurrences(of: "-", with: " ")
    }

    private var calProgress: Double {
        let cal = todayNutrition.totalCalories
        let target = Double(targets.calories)
        guard target > 0 else { return 0 }
        return min(cal / target, 1.0)
    }

    // MARK: Body

    var body: some View {
        ZStack {
            KTheme.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: KTheme.Spacing.md) {

                    // ── Header Row ──────────────────────────────────────────
                    nutritionHeader

                    // ── Calories Hero Card ───────────────────────────────────
                    caloriesHeroCard

                    // ── Scan Your Meal Card ──────────────────────────────────
                    scanMealCard

                    // ── Water Tracker ────────────────────────────────────────
                    waterTracker

                    // ── Meal Sections ────────────────────────────────────────
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

                    // ── Weekly Chart ─────────────────────────────────────────
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
        .sheet(isPresented: $showFoodScan) {
            FoodPhotoScanView(mealType: selectedMealType)
        }
    }

    // MARK: — Header Row

    private var nutritionHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                // Micro-label: "MATCH WEEK · THU" or phase + weekday
                Text("\(phaseLabel) · \(weekdayLabel)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(KTheme.Colors.textTertiary)
                    .tracking(1)

                // Title
                Text("Fuel")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(KTheme.Colors.textPrimary)
                    .tracking(-0.3)

                // Date navigator inline
                dateNavigator
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                // Amber "N DAYS OUT" chip
                daysOutChip

                // Log Food button (preserved)
                Button {
                    showAddFood = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Log Food")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(KTheme.Colors.brandGradient)
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: — Days Out Chip

    private var daysOutChip: some View {
        let days = sport.daysUntilPerformance
        let label = days == 0 ? "MATCH DAY" : "\(days) DAYS OUT"
        return Text(label)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(KTheme.Colors.accentAmber)
            .tracking(0.5)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(KTheme.Colors.accentAmber.opacity(0.1))
            .overlay(
                Capsule()
                    .stroke(KTheme.Colors.accentAmber.opacity(0.2), lineWidth: 0.5)
            )
            .clipShape(Capsule())
    }

    // MARK: — Calories Hero Card

    private var caloriesHeroCard: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Micro-label
            Text("CALORIES TODAY")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(KTheme.Colors.textTertiary)
                .tracking(1)

            // Big number row
            calorieNumberRow

            // Progress bar (3pt)
            calorieProgressBar

            // Macros row: Protein / Carbs / Fat
            macrosRow
        }
        .padding(16)
        .background(cardBackground)
    }

    // Split into helpers to avoid type-checker complexity
    private var calorieNumberRow: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(formattedCalories(todayNutrition.totalCalories))
                .font(.system(size: 48, weight: .black))
                .foregroundColor(KTheme.Colors.textPrimary)
                .tracking(-1)

            Text("/ \(targets.calories)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(KTheme.Colors.textTertiary)
        }
    }

    private var calorieProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(KTheme.Colors.background)
                    .frame(height: 3)
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "FFB347"), Color(hex: "FF6B8A")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(calProgress), height: 3)
            }
        }
        .frame(height: 3)
    }

    private var macrosRow: some View {
        HStack(spacing: 0) {
            MacroCell(
                value: "\(Int(todayNutrition.totalProteinG))g",
                label: "PROTEIN",
                color: KTheme.Colors.accentSecondary
            )
            Spacer()
            MacroCell(
                value: "\(Int(todayNutrition.totalCarbsG))g",
                label: "CARBS",
                color: KTheme.Colors.accentAmber
            )
            Spacer()
            MacroCell(
                value: "\(Int(todayNutrition.totalFatG))g",
                label: "FAT",
                color: KTheme.Colors.accentTertiary
            )
        }
    }

    // MARK: — Card Background Helper (avoids nested ternaries in .background)

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(KTheme.Colors.card)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(KTheme.Colors.border.opacity(0.5), lineWidth: 0.5)
            )
    }

    // MARK: — Scan Your Meal Card

    private var scanMealCard: some View {
        Button {
            showFoodScan = true
        } label: {
            scanMealCardContent
        }
        .buttonStyle(KScaleButtonStyle())
    }

    private var scanMealCardContent: some View {
        HStack(spacing: 14) {
            // Icon: 40pt rounded square with brandGradient + violet glow
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(KTheme.Colors.brandGradient)
                    .frame(width: 40, height: 40)
                    .kGlow(color: KTheme.Colors.accentPrimary, radius: 10)

                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Text block
            VStack(alignment: .leading, spacing: 3) {
                Text("Scan Your Meal")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(KTheme.Colors.textPrimary)

                Text("AI reads your plate — auto-logged")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(KTheme.Colors.textTertiary)
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(KTheme.Colors.textTertiary)
        }
        .padding(14)
        .background(scanMealBackground)
    }

    private var scanMealBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(KTheme.Colors.accentPrimary.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(KTheme.Colors.accentPrimary.opacity(0.18), lineWidth: 0.5)
            )
    }

    // MARK: Water Tracker
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

    // MARK: Helpers

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EE"
        return f.string(from: date)
    }

    private func formattedCalories(_ value: Double) -> String {
        let n = Int(value)
        if n >= 1000 {
            return "\(n / 1000),\(String(format: "%03d", n % 1000))"
        }
        return "\(n)"
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

// MARK: — Macro Cell (mockup-style: colored value + uppercase micro-label)

struct MacroCell: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(KTheme.Colors.textTertiary)
                .tracking(0.7)
        }
    }
}

// MARK: — Macro Bar (kept for legacy use in waterTracker area if needed)
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

    // Dot colors cycling: amber, teal, violet
    private func dotColor(for index: Int) -> Color {
        switch index % 3 {
        case 0: return KTheme.Colors.accentAmber
        case 1: return KTheme.Colors.accentTertiary
        default: return KTheme.Colors.accentPrimary
        }
    }

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
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        FoodEntryRow(entry: entry, dotColor: dotColor(for: index)) {
                            onDelete(entry.id)
                        }
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

// MARK: — Food Entry Row (mockup style: colored glowing dot + name + grams + kcal)

struct FoodEntryRow: View {
    let entry: MealEntry
    let dotColor: Color
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Colored glowing dot
            Circle()
                .fill(dotColor)
                .frame(width: 9, height: 9)
                .shadow(color: dotColor.opacity(0.5), radius: 3)

            // Name
            Text(entry.food.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "C8C8E0"))
                .lineLimit(1)

            Spacer()

            // Grams
            Text(String(format: "%.0fg", entry.gramsConsumed))
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(KTheme.Colors.textTertiary)
                .padding(.trailing, 4)

            // kcal
            Text("\(Int(entry.calories)) kcal")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(hex: "4A4A6A"))

            // Delete
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(KTheme.Colors.textTertiary)
                    .padding(6)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(entryBackground)
    }

    private var entryBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(KTheme.Colors.card)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "1A1A28"), lineWidth: 0.5)
            )
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
