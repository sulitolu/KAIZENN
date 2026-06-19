import SwiftUI

struct WearableHubView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loadStore: LoadStore

    @State private var showGPSImport = false
    @State private var showStrengthLogger = false
    @State private var showTrainingMenu = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KTheme.Spacing.lg) {
                    acwrCard
                    gpsSessionsSection
                    strengthSessionsSection
                    trainingMenuCard
                }
                .padding(KTheme.Spacing.md)
                .padding(.bottom, 100) // clear tab bar
            }
            .background(KTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Wearable Hub")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showGPSImport) {
            GPSImportView().environmentObject(loadStore)
        }
        .sheet(isPresented: $showStrengthLogger) {
            StrengthLoggerView().environmentObject(loadStore)
        }
        .sheet(isPresented: $showTrainingMenu) {
            TrainingMenuScanView()
                .environmentObject(appState)
                .environmentObject(loadStore)
        }
    }

    // MARK: ACWR Card

    private var acwrCard: some View {
        KCard(elevated: true) {
            VStack(spacing: KTheme.Spacing.md) {
                acwrHeader
                acwrLoadBar
                acwrLoadSummary
            }
        }
    }

    private var acwrHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: KTheme.Spacing.xs) {
                Text("Acute:Chronic Workload Ratio")
                    .font(KTheme.Typography.caption)
                    .foregroundColor(KTheme.Colors.textSecondary)
                Text(String(format: "%.2f", loadStore.acwr))
                    .font(KTheme.Typography.displayMedium)
                    .foregroundColor(acwrColor)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: KTheme.Spacing.xs) {
                Image(systemName: acwrIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(acwrColor)
                Text(acwrStatusLabel)
                    .font(KTheme.Typography.caption)
                    .foregroundColor(acwrColor)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var acwrLoadBar: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let clampedRatio = min(loadStore.acwr, 2.0)
            let fillWidth = totalWidth * (clampedRatio / 2.0)
            let sweetStart = totalWidth * (0.8 / 2.0)
            let sweetEnd = totalWidth * (1.3 / 2.0)

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(KTheme.Colors.card)
                    .frame(height: 8)

                // Sweet-spot highlight
                Rectangle()
                    .fill(KTheme.Colors.success.opacity(0.2))
                    .frame(width: sweetEnd - sweetStart, height: 8)
                    .offset(x: sweetStart)

                // Fill bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(acwrBarGradient)
                    .frame(width: max(fillWidth, 0), height: 8)
                    .animation(KTheme.Animation.spring, value: loadStore.acwr)

                // Sweet-spot markers
                Rectangle()
                    .fill(KTheme.Colors.success.opacity(0.6))
                    .frame(width: 1.5, height: 12)
                    .offset(x: sweetStart)
                Rectangle()
                    .fill(KTheme.Colors.success.opacity(0.6))
                    .frame(width: 1.5, height: 12)
                    .offset(x: sweetEnd)
            }
            .frame(height: 12)
        }
        .frame(height: 12)
    }

    private var acwrLoadSummary: some View {
        HStack {
            loadPill(label: "Acute (7d)", value: String(format: "%.1f", loadStore.acuteLoad))
            Spacer()
            Text("Sweet spot 0.8 – 1.3")
                .font(KTheme.Typography.caption)
                .foregroundColor(KTheme.Colors.textTertiary)
            Spacer()
            loadPill(label: "Chronic (28d)", value: String(format: "%.1f", loadStore.chronicLoad))
        }
    }

    private func loadPill(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(KTheme.Typography.caption)
                .foregroundColor(KTheme.Colors.textSecondary)
            Text(value)
                .font(KTheme.Typography.label)
                .foregroundColor(KTheme.Colors.textPrimary)
        }
    }

    // MARK: GPS Sessions Section

    private var gpsSessionsSection: some View {
        KSection(
            title: "GPS Sessions",
            trailing: AnyView(
                Button {
                    showGPSImport = true
                } label: {
                    HStack(spacing: KTheme.Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Import")
                            .font(KTheme.Typography.label)
                    }
                    .foregroundColor(KTheme.Colors.accentPrimary)
                }
            )
        ) {
            if loadStore.gpsSessions.isEmpty {
                KEmptyState(
                    icon: "location.slash",
                    title: "No GPS Sessions",
                    subtitle: "Import a Catapult CSV or enter session data manually."
                )
            } else {
                VStack(spacing: KTheme.Spacing.sm) {
                    ForEach(loadStore.gpsSessions.prefix(3)) { session in
                        gpsSessionRow(session: session)
                    }
                }
            }
        }
    }

    private func gpsSessionRow(session: GPSSession) -> some View {
        KCard {
            HStack {
                VStack(alignment: .leading, spacing: KTheme.Spacing.xs) {
                    Text(session.date, style: .date)
                        .font(KTheme.Typography.label)
                        .foregroundColor(KTheme.Colors.textPrimary)
                    Text(session.source.displayName)
                        .font(KTheme.Typography.caption)
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: KTheme.Spacing.xs) {
                    Text(String(format: "%.2f km", session.distanceMeters / 1000))
                        .font(KTheme.Typography.headingSmall)
                        .foregroundColor(KTheme.Colors.accentPrimary)
                    if session.sprintCount > 0 {
                        Text("\(session.sprintCount) sprints")
                            .font(KTheme.Typography.caption)
                            .foregroundColor(KTheme.Colors.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: Strength Sessions Section

    private var strengthSessionsSection: some View {
        KSection(
            title: "Strength Sessions",
            trailing: AnyView(
                Button {
                    showStrengthLogger = true
                } label: {
                    HStack(spacing: KTheme.Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Log")
                            .font(KTheme.Typography.label)
                    }
                    .foregroundColor(KTheme.Colors.accentPrimary)
                }
            )
        ) {
            if loadStore.strengthSessions.isEmpty {
                KEmptyState(
                    icon: "dumbbell",
                    title: "No Strength Sessions",
                    subtitle: "Log a strength session to track your training volume."
                )
            } else {
                VStack(spacing: KTheme.Spacing.sm) {
                    ForEach(loadStore.strengthSessions.prefix(3)) { session in
                        strengthSessionRow(session: session)
                    }
                }
            }
        }
    }

    private func strengthSessionRow(session: StrengthSession) -> some View {
        KCard {
            HStack {
                VStack(alignment: .leading, spacing: KTheme.Spacing.xs) {
                    Text(session.date, style: .date)
                        .font(KTheme.Typography.label)
                        .foregroundColor(KTheme.Colors.textPrimary)
                    Text("\(session.exercises.count) exercise\(session.exercises.count == 1 ? "" : "s")")
                        .font(KTheme.Typography.caption)
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: KTheme.Spacing.xs) {
                    Text(String(format: "%.0f kg", session.totalVolumeKg))
                        .font(KTheme.Typography.headingSmall)
                        .foregroundColor(KTheme.Colors.accentSecondary)
                    Text("total volume")
                        .font(KTheme.Typography.caption)
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: Training Menu Card

    private var trainingMenuCard: some View {
        Button {
            showTrainingMenu = true
        } label: {
            KCard {
                HStack(spacing: KTheme.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(KTheme.Colors.accentPrimary.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(KTheme.Colors.accentPrimary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scan Training Program")
                            .font(KTheme.Typography.label)
                            .foregroundColor(KTheme.Colors.textPrimary)
                        Text("Photo your whiteboard or printed plan — Kai fills in the session")
                            .font(KTheme.Typography.caption)
                            .foregroundColor(KTheme.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(KTheme.Colors.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: ACWR Computed Helpers

    private var acwrStatus: ACWRStatus {
        let v = loadStore.acwr
        if v == 0 { return .noData }
        if v < 0.8 { return .undertraining }
        if v <= 1.3 { return .sweetSpot }
        if v <= 1.5 { return .elevated }
        return .danger
    }

    private var acwrStatusLabel: String {
        switch acwrStatus {
        case .noData:       return "No data yet"
        case .undertraining: return "Undertraining"
        case .sweetSpot:    return "Sweet spot"
        case .elevated:     return "Elevated risk"
        case .danger:       return "High risk"
        }
    }

    private var acwrColor: Color {
        switch acwrStatus {
        case .noData:       return KTheme.Colors.textTertiary
        case .undertraining: return KTheme.Colors.accentAmber
        case .sweetSpot:    return KTheme.Colors.success
        case .elevated:     return KTheme.Colors.warning
        case .danger:       return KTheme.Colors.danger
        }
    }

    private var acwrIcon: String {
        switch acwrStatus {
        case .noData:       return "chart.bar.xaxis"
        case .undertraining: return "arrow.down.circle"
        case .sweetSpot:    return "checkmark.circle.fill"
        case .elevated:     return "exclamationmark.triangle"
        case .danger:       return "exclamationmark.octagon.fill"
        }
    }

    private var acwrBarGradient: LinearGradient {
        switch acwrStatus {
        case .noData, .undertraining:
            return LinearGradient(colors: [KTheme.Colors.accentAmber, KTheme.Colors.accentAmber], startPoint: .leading, endPoint: .trailing)
        case .sweetSpot:
            return LinearGradient(colors: [KTheme.Colors.success, KTheme.Colors.accentPrimary], startPoint: .leading, endPoint: .trailing)
        case .elevated:
            return LinearGradient(colors: [KTheme.Colors.success, KTheme.Colors.warning], startPoint: .leading, endPoint: .trailing)
        case .danger:
            return LinearGradient(colors: [KTheme.Colors.success, KTheme.Colors.danger], startPoint: .leading, endPoint: .trailing)
        }
    }

    // MARK: ACWRStatus

    private enum ACWRStatus {
        case noData, undertraining, sweetSpot, elevated, danger
    }
}
