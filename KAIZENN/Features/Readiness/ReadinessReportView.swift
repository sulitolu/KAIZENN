import SwiftUI

enum ReadinessReportMode: String, CaseIterable { case daily = "Daily", weekly = "Weekly" }

struct ReadinessReportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var nutritionStore: NutritionStore
    @EnvironmentObject var loadStore: LoadStore
    @EnvironmentObject var weightStore: WeightStore

    @State private var mode: ReadinessReportMode = .daily

    var body: some View {
        ZStack {
            KTheme.Colors.background.ignoresSafeArea()
            VStack(spacing: KTheme.Spacing.md) {
                header
                modePicker
                ScrollView(showsIndicators: false) {
                    Group {
                        switch mode {
                        case .daily:  ReadinessDailyView()
                        case .weekly: ReadinessWeeklyView()
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .padding(.horizontal, KTheme.Spacing.md)
            .padding(.top, KTheme.Spacing.md)
        }
    }

    private var header: some View {
        HStack {
            Text("Readiness")
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(KTheme.Colors.textPrimary)
            Spacer()
            Button("Done") { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(KTheme.Colors.accentPrimary)
        }
    }

    private var modePicker: some View {
        HStack(spacing: 6) {
            ForEach(ReadinessReportMode.allCases, id: \.self) { m in
                let selected = mode == m
                Button { withAnimation(KTheme.Animation.snappy) { mode = m } } label: {
                    Text(m.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selected ? .white : KTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selected ? KTheme.Colors.accentPrimary : KTheme.Colors.cardElevated)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ReadinessDailyView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var nutritionStore: NutritionStore
    @EnvironmentObject var loadStore: LoadStore
    @EnvironmentObject var readinessBaseline: ReadinessBaselineProvider

    private var inputs: ReadinessInputs {
        readinessBaseline.inputs(health: healthKitManager, loadStore: loadStore,
                                 nutrition: nutritionStore, profile: appState.userProfile)
    }
    private var b: ReadinessBreakdown { ReadinessEngine.breakdown(for: inputs) }

    var body: some View {
        VStack(spacing: KTheme.Spacing.md) {
            heroCard
            Text(b.isCalibrating
                 ? "Calibrating — learning your baseline (first \(ReadinessBaseline.minDays) days)"
                 : "Scored vs your 60-day normal")
                .font(.system(size: 11))
                .foregroundColor(KTheme.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
            pillarRow("Recovery", contribution: b.recovery, detail: recoveryDetail, tint: KTheme.Colors.accentSecondary)
            pillarRow("Sleep",    contribution: b.sleep,    detail: sleepDetail,    tint: KTheme.Colors.accentPrimary)
            pillarRow("Strain",   contribution: b.strain,   detail: strainDetail,   tint: KTheme.Colors.accentTertiary)
            pillarRow("Fuel",     contribution: b.fuel,     detail: fuelDetail,     tint: KTheme.Colors.accentAmber)
        }
    }

    private var recoveryDetail: String {
        guard let rhr = healthKitManager.heartRateResting else { return "HRV + resting HR" }
        return String(format: "RHR %.0f bpm", rhr)
    }
    private var sleepDetail: String { inputs.sleepHoursLast.map { String(format: "%.1fh", $0) } ?? "—" }
    private var strainDetail: String {
        inputs.chronicLoad > 0 ? String(format: "%.0f%% of normal load", inputs.acuteLoad / inputs.chronicLoad * 100) : "—"
    }
    private var fuelDetail: String { "\(Int(inputs.consumedCalories)) / \(Int(inputs.calorieTarget)) kcal" }

    private var heroCard: some View {
        VStack(spacing: 4) {
            Text("\(b.score)")
                .font(.system(size: 56, weight: .heavy))
                .foregroundColor(b.label.color)
            Text(b.label.displayText)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(b.label.color)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(KTheme.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: 18).fill(KTheme.Colors.card))
    }

    private func pillarRow(_ name: String, contribution: Double?, detail: String, tint: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 15, weight: .semibold)).foregroundColor(KTheme.Colors.textPrimary)
                Text(detail).font(.system(size: 13)).foregroundColor(KTheme.Colors.textTertiary)
            }
            Spacer()
            Text(contribution.map { "\(Int($0))" } ?? "—")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(tint)
        }
        .padding(KTheme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: 14).fill(KTheme.Colors.card))
    }
}

struct Sparkline: View {
    let values: [Double]
    var tint: Color
    var body: some View {
        GeometryReader { geo in
            let maxV = (values.max() ?? 1)
            let minV = (values.min() ?? 0)
            let span = max(maxV - minV, 0.0001)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tint.opacity(0.85))
                        .frame(height: max(4, CGFloat((v - minV) / span) * geo.size.height))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 44)
    }
}

struct ReadinessWeeklyView: View {
    @EnvironmentObject var nutritionStore: NutritionStore
    @EnvironmentObject var weightStore: WeightStore
    @EnvironmentObject var loadStore: LoadStore

    private var calorieSeries: [Double] { nutritionStore.weeklyCalories().map { $0.1 } }
    private var weightSeries: [Double] { weightStore.trendLine(lastDays: 7) }

    private var loadSeries: [Double] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: Date())!
            return loadStore.gpsSessions
                .filter { cal.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.sessionLoad }
        }
    }

    var body: some View {
        VStack(spacing: KTheme.Spacing.md) {
            summaryCard
            trendCard("Fuel — 7-day calories", series: calorieSeries, tint: KTheme.Colors.accentAmber, empty: "No nutrition logged this week")
            trendCard("Training load — 7 days", series: loadSeries, tint: KTheme.Colors.accentPrimary, empty: "No sessions this week")
            trendCard("Weight trend", series: weightSeries, tint: KTheme.Colors.accentTertiary, empty: "No weight entries yet")
            Text("Sleep, HRV and a full readiness trend arrive with HealthKit history (next update).")
                .font(.system(size: 11))
                .foregroundColor(KTheme.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var summaryCard: some View {
        let sessions = loadSeries.filter { $0 > 0 }.count
        let avgCal = calorieSeries.isEmpty ? 0 : Int(calorieSeries.reduce(0, +) / Double(calorieSeries.count))
        let wChange = weightStore.weightChange(lastDays: 7)
        return HStack(spacing: KTheme.Spacing.md) {
            summaryStat("\(sessions)", "sessions")
            summaryStat(avgCal == 0 ? "—" : "\(avgCal)", "avg kcal")
            summaryStat(wChange == nil ? "—" : String(format: "%+.1f", wChange!), "kg Δ")
        }
        .padding(KTheme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: 16).fill(KTheme.Colors.card))
    }

    private func summaryStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .heavy)).foregroundColor(KTheme.Colors.textPrimary)
            Text(label).font(.system(size: 11)).foregroundColor(KTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func trendCard(_ title: String, series: [Double], tint: Color, empty: String) -> some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(KTheme.Colors.textSecondary)
            if series.contains(where: { $0 > 0 }) {
                Sparkline(values: series, tint: tint)
            } else {
                Text(empty).font(.system(size: 12)).foregroundColor(KTheme.Colors.textTertiary).frame(height: 44)
            }
        }
        .padding(KTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(KTheme.Colors.card))
    }
}
