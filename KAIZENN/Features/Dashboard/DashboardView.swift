import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var nutritionStore: NutritionStore
    @EnvironmentObject var loadStore: LoadStore
    @EnvironmentObject var weightStore: WeightStore

    // MARK: - Sheet state
    @State private var showLogMeal = false
    @State private var showLogSession = false
    @State private var showLogWeight = false

    // MARK: - Raw values
    private var sleepHours: Double { healthKitManager.sleepHoursLast }
    private var consumedCalories: Double { nutritionStore.dailyNutrition(for: Date()).totalCalories }
    private var calorieTarget: Int { appState.userProfile.dailyCalorieTarget }
    private var acwr: Double { loadStore.acwr }
    private var acuteLoad: Double { loadStore.acuteLoad }
    private var sport: SportProfile { appState.userProfile.sportProfile }

    // MARK: - Pillar scores
    private var sleepScore: Double {
        min(sleepHours / 8.0, 1.0) * 100
    }

    private var loadScore: Double {
        guard acwr != 0 else { return 75 }
        let range: ClosedRange<Double> = 0.8...1.3
        if range.contains(acwr) { return 100 }
        let delta = acwr < range.lowerBound
            ? range.lowerBound - acwr
            : acwr - range.upperBound
        return max(0, 100 - (delta * 100))
    }

    private var fuelScore: Double {
        let proteinTarget = Double(appState.userProfile.macroTargets.proteinG)
        guard calorieTarget > 0, proteinTarget > 0 else { return 50 }
        let calorieRatio = min(consumedCalories / Double(calorieTarget), 1.0)
        let proteinConsumed = nutritionStore.dailyNutrition(for: Date()).totalProteinG
        let proteinRatio = min(proteinConsumed / proteinTarget, 1.0)
        return (calorieRatio * 0.5 + proteinRatio * 0.5) * 100
    }

    // HRV vs personal baseline: at/above baseline scores well, below penalises.
    private var hrvAvailable: Bool { healthKitManager.hrvLatestMs != nil }

    private var hrvScore: Double {
        guard let latest = healthKitManager.hrvLatestMs else { return 75 }
        guard let base = healthKitManager.hrvBaselineMs, base > 0 else { return 75 }
        let ratio = latest / base
        return min(max(75 + (ratio - 1.0) * 150, 0), 100)
    }

    // MARK: - Readiness
    // Four pillars at 25% each once HRV data exists; until then, sleep/load/fuel.
    var readinessScore: Int {
        if hrvAvailable {
            return Int(sleepScore * 0.25 + loadScore * 0.25 + fuelScore * 0.25 + hrvScore * 0.25)
        }
        return Int(sleepScore * 0.33 + loadScore * 0.33 + fuelScore * 0.34)
    }

    private var readinessLabel: String {
        switch readinessScore {
        case 80...: return "PEAK CONDITION"
        case 60..<80: return "GAME READY"
        case 40..<60: return "BUILD DAY"
        default: return "RECOVERY DAY"
        }
    }

    private var readinessColor: Color {
        switch readinessScore {
        case 80...: return Color(hex: "5EFFB7")
        case 60..<80: return Color(hex: "7C6FFF")
        case 40..<60: return Color(hex: "FFB347")
        default: return Color(hex: "FF6B8A")
        }
    }

    private var edgePrompt: String {
        if sleepScore < 60 {
            return "Your edge: target 8hrs sleep tonight."
        } else if fuelScore < 60 {
            return "Your edge: hit protein target before training."
        } else if loadScore < 60 {
            return "Your edge: ease load — ACWR above sweet spot."
        } else {
            return "You are primed. Attack today's session."
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
        appState.userProfile.name.isEmpty ? "Athlete" : appState.userProfile.name
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
                edgeCard
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 100)
        }
        .background(KTheme.Colors.background.ignoresSafeArea())
        .task { await healthKitManager.fetchAllTodayData() }
        .refreshable { await healthKitManager.fetchAllTodayData() }
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
            avatarCircle
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
        Button {
            navigate(to: .coach)
        } label: {
            VStack(spacing: 11) {
                // Top row: left column + ring
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
                // Pillar tiles row
                pillarsRow
            }
            .padding(18)
            .background(scoreHeroBackground)
            .overlay(scoreHeroBorder)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var readinessMicroLabel: some View {
        Text("READINESS")
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
    private var pillarsRow: some View {
        HStack(spacing: 5) {
            Button { navigate(to: .coach) } label: {
                PillarTile(
                    iconSystemName: "moon.fill",
                    iconColor: KTheme.Colors.accentPrimary,
                    value: String(format: "%.1fh", sleepHours),
                    name: "SLEEP"
                )
            }
            .buttonStyle(.plain)

            Button { navigate(to: .hub) } label: {
                PillarTile(
                    iconSystemName: "bolt.fill",
                    iconColor: KTheme.Colors.accentTertiary,
                    value: String(format: "%.1f", acwr),
                    name: "LOAD"
                )
            }
            .buttonStyle(.plain)

            Button { navigate(to: .nutrition) } label: {
                PillarTile(
                    iconSystemName: "fork.knife",
                    iconColor: KTheme.Colors.accentAmber,
                    value: "\(Int(fuelScore))%",
                    name: "FUEL"
                )
            }
            .buttonStyle(.plain)

            Button { navigate(to: .coach) } label: {
                PillarTile(
                    iconSystemName: "waveform.path.ecg",
                    iconColor: KTheme.Colors.accentSecondary,
                    value: hrvDisplay,
                    name: "HRV"
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
