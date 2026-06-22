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

// Placeholder bodies — fleshed out in Tasks 4 and 5.
struct ReadinessDailyView: View {
    var body: some View { Text("Daily").foregroundColor(.white) }
}
struct ReadinessWeeklyView: View {
    var body: some View { Text("Weekly").foregroundColor(.white) }
}
