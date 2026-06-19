import SwiftUI

struct WeightView: View {
    @EnvironmentObject var weightStore: WeightStore
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var appState: AppState

    @State private var showLogWeight = false
    @State private var historyWeights: [BodyMeasurement] = []
    @State private var selectedRange: Int = 30 // days

    var body: some View {
        ZStack {
            KTheme.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: KTheme.Spacing.lg) {

                    // Header
                    HStack {
                        Text("WEIGHT")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(KTheme.Colors.accentPrimary)
                            .tracking(2)
                        Spacer()
                        KButton(title: "Log Weight", style: .primary, size: .small) {
                            showLogWeight = true
                        }
                    }

                    // Hero current weight
                    heroWeightCard

                    // Current Stats Row
                    currentStatsRow

                    // Chart
                    weightChartCard

                    // Progress to Goal
                    goalProgressCard

                    // BMI Card
                    bmiCard

                    // History list
                    historySection

                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, KTheme.Spacing.md)
                .padding(.top, KTheme.Spacing.md)
            }
        }
        .sheet(isPresented: $showLogWeight) {
            LogWeightView()
        }
        .task {
            historyWeights = await healthKitManager.fetchWeightHistory(days: 90)
        }
    }

    // MARK: Hero

    /// Color for a delta value (down = success, up = danger, none = secondary).
    private func deltaColor(_ change: Double?) -> Color {
        guard let change = change else { return KTheme.Colors.textSecondary }
        return change <= 0 ? KTheme.Colors.success : KTheme.Colors.danger
    }

    private func deltaIcon(_ change: Double?) -> String {
        guard let change = change else { return "minus" }
        return change <= 0 ? "arrow.down.right" : "arrow.up.right"
    }

    private var heroWeightCard: some View {
        let latest = weightStore.latestWeight
        let change7 = weightStore.weightChange(lastDays: 7)

        return KCard(elevated: true) {
            VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                Text("CURRENT WEIGHT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(KTheme.Colors.accentPrimary.opacity(0.8))
                    .tracking(1.5)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(latest.map { String(format: "%.1f", $0) } ?? "—")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundColor(KTheme.Colors.textPrimary)
                    Text("kg")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(KTheme.Colors.textSecondary)
                    Spacer()
                    deltaChip(change7)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: KTheme.Radius.lg)
                .stroke(KTheme.Colors.accentPrimary.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: KTheme.Colors.accentPrimary.opacity(0.15), radius: 20, x: 0, y: 0)
    }

    private func deltaChip(_ change: Double?) -> some View {
        let color = deltaColor(change)
        let label = change.map { String(format: "%+.1f kg", $0) } ?? "—"
        return HStack(spacing: 4) {
            Image(systemName: deltaIcon(change))
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(KTheme.Radius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: KTheme.Radius.sm)
                .stroke(color.opacity(0.3), lineWidth: 0.5)
        )
    }

    // MARK: Section header helper
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(KTheme.Colors.accentPrimary)
            .tracking(2)
    }

    // MARK: Stats Row
    private var currentStatsRow: some View {
        let change7 = weightStore.weightChange(lastDays: 7)
        let change30 = weightStore.weightChange(lastDays: 30)

        return HStack(spacing: KTheme.Spacing.sm) {
            WeightStatMini(label: "7 DAYS", value: change7.map { String(format: "%+.1f kg", $0) } ?? "—", color: deltaColor(change7))
            WeightStatMini(label: "30 DAYS", value: change30.map { String(format: "%+.1f kg", $0) } ?? "—", color: deltaColor(change30))
            WeightStatMini(label: "BMI", value: String(format: "%.1f", appState.userProfile.bmi), color: KTheme.Colors.accentPrimary)
        }
    }

    // MARK: Chart
    private var weightChartCard: some View {
        KCard(elevated: true) {
            VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                HStack {
                    sectionHeader("WEIGHT HISTORY")
                    Spacer()
                    // Range picker
                    HStack(spacing: 4) {
                        ForEach([7, 30, 90], id: \.self) { days in
                            Button {
                                withAnimation(KTheme.Animation.smooth) { selectedRange = days }
                            } label: {
                                Text("\(days)D")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(selectedRange == days ? .white : KTheme.Colors.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(selectedRange == days ? KTheme.Colors.accentPrimary : Color.clear)
                                    .cornerRadius(KTheme.Radius.sm)
                            }
                        }
                    }
                    .background(KTheme.Colors.border.cornerRadius(KTheme.Radius.sm))
                }

                // Weight line chart
                let local = weightStore.measurements(lastDays: selectedRange)
                let healthKitOnly = historyWeights.filter { hk in
                    hk.date >= Calendar.current.date(byAdding: .day, value: -selectedRange, to: Date())!
                        && !local.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: hk.date) })
                }
                let allMeasurements = (local + healthKitOnly).sorted { $0.date < $1.date }

                if allMeasurements.count > 1 {
                    WeightLineChart(measurements: allMeasurements, goal: appState.userProfile.goalWeightKg)
                        .frame(height: 160)
                } else {
                    Text("Log your weight to see your progress chart")
                        .font(KTheme.Typography.bodyMedium)
                        .foregroundColor(KTheme.Colors.textSecondary)
                        .frame(height: 80)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: KTheme.Radius.lg)
                .stroke(KTheme.Colors.accentPrimary.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: KTheme.Colors.accentPrimary.opacity(0.15), radius: 20, x: 0, y: 0)
    }

    // MARK: Goal Progress
    private var goalProgressCard: some View {
        let profile = appState.userProfile
        let current = weightStore.latestWeight ?? profile.currentWeightKg
        let start = profile.currentWeightKg
        let goal = profile.goalWeightKg
        let totalToLose = abs(start - goal)
        let lost = abs(start - current)
        let progress = totalToLose > 0 ? min(lost / totalToLose, 1.0) : 0

        return KCard {
            VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                HStack {
                    sectionHeader("GOAL PROGRESS")
                    Spacer()
                    KBadge(text: "\(Int(progress * 100))%", color: KTheme.Colors.success)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6).fill(KTheme.Colors.border).frame(height: 10)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(KTheme.Colors.brandGradient)
                            .frame(width: geo.size.width * CGFloat(progress), height: 10)
                            .animation(KTheme.Animation.spring, value: progress)
                    }
                }.frame(height: 10)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("START")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(KTheme.Colors.textSecondary).tracking(1.5)
                        Text(String(format: "%.1f kg", start)).font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .center, spacing: 4) {
                        Text("LOST")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(KTheme.Colors.textSecondary).tracking(1.5)
                        Text(String(format: "%.1f kg", lost)).font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.success)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("GOAL")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(KTheme.Colors.textSecondary).tracking(1.5)
                        Text(String(format: "%.1f kg", goal)).font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.accentPrimary)
                    }
                }

                if profile.weeksToGoal > 0 {
                    HStack {
                        Image(systemName: "calendar").foregroundColor(KTheme.Colors.textSecondary).font(.caption)
                        Text("At \(String(format: "%.1f", profile.weeklyGoalKg))kg/week, estimated \(Int(ceil(profile.weeksToGoal - profile.weeksToGoal * progress))) weeks to goal")
                            .font(KTheme.Typography.caption)
                            .foregroundColor(KTheme.Colors.textSecondary)
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: KTheme.Radius.lg)
                .stroke(KTheme.Colors.accentPrimary.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: KTheme.Colors.accentPrimary.opacity(0.15), radius: 20, x: 0, y: 0)
    }

    // MARK: BMI
    private var bmiColor: Color {
        let bmi = appState.userProfile.bmi
        switch bmi {
        case ..<18.5: return KTheme.Colors.warning
        case 18.5..<25: return KTheme.Colors.success
        case 25..<30: return KTheme.Colors.warning
        default: return KTheme.Colors.danger
        }
    }

    private var bmiCard: some View {
        let bmi = appState.userProfile.bmi
        let color = bmiColor

        return KCard {
            HStack {
                VStack(alignment: .leading, spacing: KTheme.Spacing.xs) {
                    sectionHeader("BMI")
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", bmi))
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(color)
                        Text(appState.userProfile.bmiCategory).font(KTheme.Typography.caption).foregroundColor(color)
                    }
                    Text("Healthy range: 18.5 – 24.9").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textTertiary)
                }
                Spacer()
                ZStack {
                    KProgressRing(progress: min(bmi, 40), total: 40, size: 70, lineWidth: 6, color: color)
                    Text(String(format: "%.1f", bmi)).font(KTheme.Typography.headingSmall).foregroundColor(color)
                }
            }
        }
    }

    // MARK: History
    private var historySection: some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
            sectionHeader("WEIGHT LOG")

            let sorted = weightStore.measurements.sorted { $0.date > $1.date }.prefix(20)
            if sorted.isEmpty {
                KEmptyState(icon: "scalemass", title: "No entries yet", subtitle: "Tap 'Log Weight' to start tracking")
            } else {
                KCard {
                    VStack(spacing: 0) {
                        ForEach(Array(sorted)) { m in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.date, style: .date).font(KTheme.Typography.bodyMedium).foregroundColor(KTheme.Colors.textPrimary)
                                    Text(m.date, style: .time).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                                }
                                Spacer()
                                Text(String(format: "%.1f kg", m.weightKg))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(KTheme.Colors.textPrimary)
                                if let fat = m.bodyFatPercentage {
                                    Text(String(format: "%.1f%%", fat)).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary).padding(.leading, 8)
                                }
                                Button {
                                    withAnimation(KTheme.Animation.smooth) {
                                        weightStore.removeMeasurement(id: m.id)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(KTheme.Colors.textTertiary)
                                        .padding(.leading, KTheme.Spacing.xs)
                                }
                            }
                            .padding(KTheme.Spacing.sm)
                            if m.id != sorted.last?.id {
                                Divider().background(KTheme.Colors.border)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: — Weight Line Chart
struct WeightLineChart: View {
    let measurements: [BodyMeasurement]
    let goal: Double

    var body: some View {
        GeometryReader { geo in
            let weights = measurements.map(\.weightKg)
            let minW = min(weights.min() ?? goal, goal) - 1
            let maxW = (weights.max() ?? goal) + 1
            let range = maxW - minW

            ZStack {
                // Goal line
                let goalY = geo.size.height * (1 - CGFloat((goal - minW) / range))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: goalY))
                    path.addLine(to: CGPoint(x: geo.size.width, y: goalY))
                }
                .stroke(KTheme.Colors.success.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                Text("Goal").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.success).offset(x: 0, y: goalY - 14)

                // Weight line
                let points: [CGPoint] = measurements.enumerated().map { i, m in
                    let x = geo.size.width * CGFloat(i) / CGFloat(max(measurements.count - 1, 1))
                    let y = geo.size.height * (1 - CGFloat((m.weightKg - minW) / range))
                    return CGPoint(x: x, y: y)
                }

                if points.count > 1 {
                    // Fill
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                        path.addLine(to: points[0])
                        for p in points.dropFirst() { path.addLine(to: p) }
                        path.addLine(to: CGPoint(x: points.last!.x, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [KTheme.Colors.accentPrimary.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom))

                    Path { path in
                        path.move(to: points[0])
                        for p in points.dropFirst() { path.addLine(to: p) }
                    }
                    .stroke(KTheme.Colors.accentPrimary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    // Data points
                    ForEach(points.indices, id: \.self) { i in
                        Circle().fill(KTheme.Colors.accentPrimary).frame(width: 6, height: 6)
                            .offset(x: points[i].x - 3, y: points[i].y - 3)
                    }
                }
            }
        }
    }
}

struct WeightStatMini: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        KCard {
            VStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(KTheme.Colors.textSecondary)
                    .tracking(1.5)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.6))
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
