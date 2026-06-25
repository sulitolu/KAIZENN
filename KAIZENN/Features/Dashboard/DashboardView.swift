import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var nutritionStore: NutritionStore
    @EnvironmentObject var loadStore: LoadStore
    @EnvironmentObject var weightStore: WeightStore
    @EnvironmentObject var activityStore: ActivityStore
    @EnvironmentObject var scheduleStore: ScheduleStore

    // Reading the language in-body makes localized header strings re-render live.
    @AppStorage("app_language") private var lang = "en"

    // MARK: - Sheet state
    @State private var showLogMeal = false
    @State private var showLogSession = false
    @State private var showLogWeight = false
    @State private var showProfile = false
    @State private var showSettings = false
    @State private var showWeightHistory = false
    @State private var showReadinessReport = false
    @EnvironmentObject var readinessBaseline: ReadinessBaselineProvider
    @EnvironmentObject var healthStore: HealthStore

    // MARK: - Raw values
    private var sleepHours: Double { healthKitManager.sleepHoursLast }
    private var consumedCalories: Double { nutritionStore.dailyNutrition(for: Date()).totalCalories }
    private var calorieTarget: Int { appState.userProfile.dailyCalorieTarget }
    private var acwr: Double { loadStore.acwr }
    private var acuteLoad: Double { loadStore.acuteLoad }
    private var sport: SportProfile { appState.userProfile.sportProfile }

    // MARK: - Readiness (delegated to ReadinessEngine v2, baseline-relative)
    private var readinessBreakdown: ReadinessBreakdown {
        ReadinessEngine.breakdown(for: readinessBaseline.inputs(
            health: healthKitManager, loadStore: loadStore,
            nutrition: nutritionStore, profile: appState.userProfile))
    }

    var readinessScore: Int { readinessBreakdown.score }

    private var readinessLabel: String {
        switch readinessBreakdown.label {
        case .primed:   return L.t("readiness.primed", lang)
        case .ready:    return L.t("readiness.ready", lang)
        case .moderate: return L.t("readiness.moderate", lang)
        case .caution:  return L.t("readiness.caution", lang)
        case .recover:  return L.t("readiness.recover", lang)
        }
    }

    private var readinessColor: Color { readinessBreakdown.label.color }

    private var edgePrompt: String {
        let b = readinessBreakdown
        if (b.sleep ?? 100) < 60 {
            return L.t("dashboard.edge.sleep", lang)
        } else if (b.fuel ?? 100) < 60 {
            return L.t("dashboard.edge.fuel", lang)
        } else if (b.strain ?? 100) < 60 {
            return L.t("dashboard.edge.load", lang)
        } else {
            return L.t("dashboard.edge.primed", lang)
        }
    }

    // MARK: - Sessions this week
    private var sessionsThisWeek: Int {
        loadStore.gpsSessions.filter {
            Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
    }

    // MARK: - Computed header strings
    private var greetingLabel: String {
        let weekday = Date().formatted(.dateTime.weekday(.wide)).uppercased()
        let phase = sport.seasonPhase.displayName.uppercased()
        return "\(weekday) · \(phase)"
    }

    private var athleteName: String {
        appState.userProfile.name.isEmpty ? L.t("dashboard.athlete", lang) : appState.userProfile.name
    }

    // MARK: - HRV display
    // Shows the delta vs baseline ("+4ms") when a baseline exists, else the raw value, else "—".
    private var hrvDisplay: String {
        guard let latest = healthKitManager.hrvLatestMs else { return "—" }
        if let delta = healthKitManager.hrvDeltaMs, abs(delta) >= 0.5 {
            return String(format: "%+.0fms", delta)
        }
        return String(format: "%.0fms", latest)
    }

    // MARK: - Tab navigation helper
    private func navigate(to tab: AppState.Tab) {
        withAnimation(KTheme.Animation.snappy) {
            appState.selectedTab = tab
        }
    }

    // MARK: - Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                headerSection
                quickActionRow
                scoreHeroCard
                statsRow
                weightTrendCard
                edgeCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 100)
        }
        .background(KTheme.Colors.background.ignoresSafeArea())
        .task {
            await healthKitManager.fetchAllTodayData()
            readinessBaseline.refresh(from: healthStore)
        }
        .refreshable {
            await healthKitManager.fetchAllTodayData()
            readinessBaseline.refresh(from: healthStore)
        }
        .sheet(isPresented: $showLogMeal) {
            FoodPhotoScanView(mealType: .snack)
                .environmentObject(appState)
                .environmentObject(nutritionStore)
        }
        .sheet(isPresented: $showLogSession) {
            StrengthLoggerView()
                .environmentObject(loadStore)
        }
        .sheet(isPresented: $showLogWeight) {
            LogWeightView()
                .environmentObject(weightStore)
                .environmentObject(healthKitManager)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .environmentObject(appState)
                .environmentObject(healthKitManager)
                .environmentObject(nutritionStore)
                .environmentObject(weightStore)
                .environmentObject(activityStore)
                .environmentObject(scheduleStore)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showReadinessReport) {
            ReadinessReportView()
                .environmentObject(appState)
                .environmentObject(healthKitManager)
                .environmentObject(nutritionStore)
                .environmentObject(loadStore)
                .environmentObject(weightStore)
                .environmentObject(readinessBaseline)
        }
        .sheet(isPresented: $showWeightHistory) {
            WeightView()
                .environmentObject(weightStore)
                .environmentObject(healthKitManager)
                .environmentObject(appState)
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greetingLabel)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(KTheme.Colors.textTertiary)
                    .tracking(1)
                Text(athleteName)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(KTheme.Colors.textPrimary)
                    .tracking(-0.3)
            }
            Spacer()
            HStack(spacing: 12) {
                Button { showSettings = true } label: { settingsGear }
                    .buttonStyle(HeaderControlButtonStyle())
                Button { showProfile = true } label: { avatarCircle }
                    .buttonStyle(HeaderControlButtonStyle())
            }
        }
    }

    private var settingsGear: some View {
        ZStack {
            Circle()
                .fill(KTheme.Colors.card)
                .overlay(Circle().stroke(KTheme.Colors.cardElevated, lineWidth: 0.5))
                .frame(width: 40, height: 40)
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(KTheme.Colors.textSecondary)
        }
    }

    private var avatarCircle: some View {
        ZStack {
            Circle()
                .fill(KTheme.Colors.brandGradient)
                .frame(width: 44, height: 44)
                .shadow(color: KTheme.Colors.accentPrimary.opacity(0.4), radius: 7, x: 0, y: 0)
            Image(systemName: "person.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white)
        }
    }

    // Press feedback shared by the header gear + avatar so they read as a matched pair.
    private struct HeaderControlButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
                .opacity(configuration.isPressed ? 0.85 : 1.0)
                .animation(KTheme.Animation.snappy, value: configuration.isPressed)
        }
    }

    // MARK: - Quick Action Row
    private var quickActionRow: some View {
        HStack(spacing: 8) {
            quickActionButton(
                icon: "camera.viewfinder",
                label: "Log Meal",
                tint: KTheme.Colors.accentAmber,
                action: { showLogMeal = true }
            )
            quickActionButton(
                icon: "dumbbell.fill",
                label: "Log Session",
                tint: KTheme.Colors.accentPrimary,
                action: { showLogSession = true }
            )
            quickActionButton(
                icon: "scalemass.fill",
                label: "Log Weight",
                tint: KTheme.Colors.accentTertiary,
                action: { showLogWeight = true }
            )
        }
    }

    private func quickActionButton(
        icon: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tint.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(tint)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(KTheme.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(quickActionBackground)
        }
        .buttonStyle(.plain)
    }

    private var quickActionBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(KTheme.Colors.card)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(KTheme.Colors.cardElevated, lineWidth: 0.5)
            )
    }

    // MARK: - Score Hero Card
    private var scoreHeroCard: some View {
        // The top row (score + ring) opens the Readiness Report. It's a SEPARATE button
        // from the pillar tiles below — nesting them inside one outer Button made the
        // pillars' own destinations (Load→Hub, Fuel→Nutrition) unreachable.
        VStack(spacing: 11) {
            Button {
                showReadinessReport = true
            } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        readinessMicroLabel
                        scoreGradientNumber
                        Text(readinessLabel)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(readinessColor)
                            .tracking(0.3)
                    }
                    Spacer()
                    scoreRingEcho
                }
            }
            .buttonStyle(.plain)

            // Pillar tiles row — each tile is its own button (Sleep/Load/Fuel/HRV).
            pillarsRow
        }
        .padding(18)
        .background(scoreHeroBackground)
        .overlay(scoreHeroBorder)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var readinessMicroLabel: some View {
        Text(L.t("dashboard.readiness", lang))
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundColor(KTheme.Colors.textTertiary)
            .tracking(1.5)
    }

    private var scoreGradientNumber: some View {
        Text("\(readinessScore)")
            .font(.system(size: 88, weight: .black))
            .tracking(-2)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: "A89FFF"), KTheme.Colors.accentSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var scoreRingEcho: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "0F0F1E"))
                .frame(width: 84, height: 84)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [KTheme.Colors.accentPrimary, KTheme.Colors.accentSecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .frame(width: 84, height: 84)
            Text("\(readinessScore)")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(Color(hex: "A89FFF"))
        }
    }

    private var scoreHeroBackground: some View {
        LinearGradient(
            colors: [Color(hex: "0F0F1E"), Color(hex: "12121F")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var scoreHeroBorder: some View {
        RoundedRectangle(cornerRadius: 18)
            .stroke(KTheme.Colors.accentPrimary.opacity(0.12), lineWidth: 0.5)
    }

    // MARK: - Pillar Tiles
    // Pillar tiles show the baseline-relative sub-score (0–100), or "—" when that signal is unavailable.
    private func pillarValue(_ v: Double?) -> String { v.map { "\(Int($0))" } ?? "—" }

    private var pillarsRow: some View {
        let b = readinessBreakdown
        return HStack(spacing: 5) {
            Button { showReadinessReport = true } label: {
                PillarTile(
                    iconSystemName: "waveform.path.ecg",
                    iconColor: KTheme.Colors.accentSecondary,
                    value: pillarValue(b.recovery),
                    name: "RECOVERY"
                )
            }
            .buttonStyle(.plain)

            Button { showReadinessReport = true } label: {
                PillarTile(
                    iconSystemName: "moon.fill",
                    iconColor: KTheme.Colors.accentPrimary,
                    value: pillarValue(b.sleep),
                    name: "SLEEP"
                )
            }
            .buttonStyle(.plain)

            Button { navigate(to: .hub) } label: {
                PillarTile(
                    iconSystemName: "bolt.fill",
                    iconColor: KTheme.Colors.accentTertiary,
                    value: pillarValue(b.strain),
                    name: "STRAIN"
                )
            }
            .buttonStyle(.plain)

            Button { navigate(to: .nutrition) } label: {
                PillarTile(
                    iconSystemName: "fork.knife",
                    iconColor: KTheme.Colors.accentAmber,
                    value: pillarValue(b.fuel),
                    name: "FUEL"
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 5) {
            Button { navigate(to: .hub) } label: { gpsLoadCard }
                .buttonStyle(.plain)
            Button { navigate(to: .hub) } label: { restHRCard }
                .buttonStyle(.plain)
            Button { navigate(to: .schedule) } label: { matchCard }
                .buttonStyle(.plain)
        }
    }

    private var gpsLoadCard: some View {
        StatCard {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(String(format: "%.1f", acuteLoad / 1000))
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(KTheme.Colors.textPrimary)
                Text("km")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(KTheme.Colors.textTertiary)
                    .textCase(.uppercase)
            }
            Text("GPS Load")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(KTheme.Colors.textTertiary)
            miniBar(
                fill: LinearGradient(
                    colors: [KTheme.Colors.accentPrimary, KTheme.Colors.accentSecondary],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                fraction: 0.78
            )
        }
    }

    private var restHRCard: some View {
        StatCard {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(healthKitManager.heartRateResting.map { "\(Int($0))" } ?? "--")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(KTheme.Colors.textPrimary)
                Text("bpm")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(KTheme.Colors.textTertiary)
                    .textCase(.uppercase)
            }
            Text("Rest HR")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(KTheme.Colors.textTertiary)
            miniBar(
                fill: LinearGradient(
                    colors: [KTheme.Colors.accentTertiary, KTheme.Colors.accentTertiary],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                fraction: 0.55
            )
        }
    }

    private var matchCard: some View {
        StatCard {
            Text("MATCH")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(KTheme.Colors.accentSecondary)
            Text(matchDayName)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(KTheme.Colors.textPrimary)
            Text("\(sport.daysUntilPerformance) days out")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(KTheme.Colors.textTertiary)
            miniBar(
                fill: LinearGradient(
                    colors: [KTheme.Colors.accentSecondary, KTheme.Colors.accentSecondary],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                fraction: matchBarFraction
            )
        }
    }

    private static let matchDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private var matchDayName: String {
        // Compute the actual upcoming performance date from the day countdown.
        guard let date = Calendar.current.date(byAdding: .day, value: sport.daysUntilPerformance, to: Date()) else {
            return "Sat"
        }
        return Self.matchDayFormatter.string(from: date)
    }

    private var matchBarFraction: Double {
        let days = sport.daysUntilPerformance
        guard days > 0 else { return 1.0 }
        return 1.0 - (Double(days) / 7.0)
    }

    // MARK: - Weight Trend Card
    private var weightTrendCard: some View {
        Button { showWeightHistory = true } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("WEIGHT")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(KTheme.Colors.accentSecondary)
                        .tracking(1.5)
                    if let latest = weightStore.latestWeight {
                        Text(String(format: "%.1f kg", latest))
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundColor(KTheme.Colors.textPrimary)
                        weightChangeLabel
                    } else {
                        Text("No entries yet — tap to log")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(KTheme.Colors.textTertiary)
                    }
                }
                Spacer()
                weightSparkline
                    .frame(width: 84, height: 38)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(KTheme.Colors.textTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(KTheme.Colors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(KTheme.Colors.cardElevated, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var weightChangeLabel: some View {
        if let change = weightStore.weightChange(lastDays: 30) {
            let down = change <= 0
            HStack(spacing: 3) {
                Image(systemName: down ? "arrow.down.right" : "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                Text(String(format: "%.1f kg · 30d", abs(change)))
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(down ? KTheme.Colors.accentGreen : KTheme.Colors.accentAmber)
        }
    }

    @ViewBuilder
    private var weightSparkline: some View {
        let points = weightStore.trendLine(lastDays: 30)
        if points.count >= 2 {
            GeometryReader { geo in
                let minV = points.min() ?? 0
                let maxV = points.max() ?? 1
                let range = max(maxV - minV, 0.001)
                Path { path in
                    for (i, v) in points.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(points.count - 1)
                        let y = geo.size.height * (1 - CGFloat((v - minV) / range))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(
                    KTheme.Colors.accentSecondary,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    // MARK: - Edge Card
    private var edgeCard: some View {
        Button {
            navigate(to: .coach)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(KTheme.Colors.accentPrimary)
                Text(edgePrompt)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(KTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(KTheme.Colors.textTertiary)
            }
            .padding(16)
            .background(edgeCardBackground)
        }
        .buttonStyle(.plain)
    }

    private var edgeCardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(KTheme.Colors.card)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(KTheme.Colors.cardElevated, lineWidth: 0.5)
            )
    }

    // MARK: - Mini bar helper
    @ViewBuilder
    private func miniBar<F: ShapeStyle>(fill: F, fraction: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(KTheme.Colors.cardElevated)
                    .frame(height: 3)
                Capsule()
                    .fill(fill)
                    .frame(width: geo.size.width * CGFloat(min(max(fraction, 0), 1)), height: 3)
            }
        }
        .frame(height: 3)
        .padding(.top, 5)
    }
}

// MARK: - PillarTile
private struct PillarTile: View {
    let iconSystemName: String
    let iconColor: Color
    let value: String
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 24, height: 24)
                Image(systemName: iconSystemName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(iconColor)
            }
            .padding(.bottom, 4)

            Text(value)
                .font(.system(size: 17, weight: .heavy))
                .foregroundColor(KTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(KTheme.Colors.textTertiary)
                .tracking(0.7)
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
        .background(pillarTileBackground)
    }

    private var pillarTileBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.02))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
            )
    }
}

// MARK: - StatCard container
private struct StatCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(statCardBackground)
    }

    private var statCardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(KTheme.Colors.card)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(KTheme.Colors.cardElevated, lineWidth: 0.5)
            )
    }
}

// MARK: - Quick Log types preserved for other views that may reference them
enum QuickLogSheet: Identifiable {
    case food, workout, weight, task
    var id: Int {
        switch self {
        case .food:    return 0
        case .workout: return 1
        case .weight:  return 2
        case .task:    return 3
        }
    }
}
