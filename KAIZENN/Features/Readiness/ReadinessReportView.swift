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

    private var inputs: ReadinessInputs {
        ReadinessInputs(
            sleepHours: healthKitManager.sleepHoursLast,
            acwr: loadStore.acwr,
            consumedCalories: nutritionStore.dailyNutrition(for: Date()).totalCalories,
            calorieTarget: Double(appState.userProfile.dailyCalorieTarget),
            proteinConsumed: nutritionStore.dailyNutrition(for: Date()).totalProteinG,
            proteinTarget: Double(appState.userProfile.macroTargets.proteinG),
            hrvLatestMs: healthKitManager.hrvLatestMs,
            hrvBaselineMs: healthKitManager.hrvBaselineMs
        )
    }
    private var b: ReadinessBreakdown { ReadinessEngine.breakdown(for: inputs) }

    var body: some View {
        VStack(spacing: KTheme.Spacing.md) {
            heroCard
            pillarRow("Sleep", contribution: b.sleepScore,
                      value: String(format: "%.1fh", inputs.sleepHours), tint: KTheme.Colors.accentTertiary)
            pillarRow("Load", contribution: b.loadScore,
                      value: inputs.acwr == 0 ? "—" : String(format: "ACWR %.2f", inputs.acwr), tint: KTheme.Colors.accentPrimary)
            pillarRow("Fuel", contribution: b.fuelScore,
                      value: "\(Int(inputs.consumedCalories)) / \(Int(inputs.calorieTarget)) kcal", tint: KTheme.Colors.accentAmber)
            pillarRow("HRV", contribution: b.hrvScore,
                      value: hrvText, tint: KTheme.Colors.accentSecondary)
        }
    }

    private var hrvText: String {
        guard let latest = inputs.hrvLatestMs else { return "—" }
        if let base = inputs.hrvBaselineMs, base > 0 {
            return String(format: "%.0fms (%+.0f vs base)", latest, latest - base)
        }
        return String(format: "%.0fms", latest)
    }

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

    private func pillarRow(_ name: String, contribution: Double, value: String, tint: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 15, weight: .semibold)).foregroundColor(KTheme.Colors.textPrimary)
                Text(value).font(.system(size: 13)).foregroundColor(KTheme.Colors.textTertiary)
            }
            Spacer()
            Text("\(Int(contribution))")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(tint)
        }
        .padding(KTheme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: 14).fill(KTheme.Colors.card))
    }
}

// Placeholder body — fleshed out in Task 5.
struct ReadinessWeeklyView: View {
    var body: some View { Text("Weekly").foregroundColor(.white) }
}
