import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var nutritionStore: NutritionStore
    @EnvironmentObject var loadStore: LoadStore

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
        guard calorieTarget > 0 else { return 50 }
        let ratio = consumedCalories / Double(calorieTarget)
        return min(ratio, 1.0) * 100
    }

    // MARK: - Readiness
    var readinessScore: Int {
        Int(sleepScore * 0.33 + loadScore * 0.33 + fuelScore * 0.34)
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

    // MARK: - Body
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: KTheme.Spacing.lg) {
                headerSection
                scoreHeroCard
                statRow
                edgeCard
                Color.clear.frame(height: 100)
            }
            .padding(.horizontal, KTheme.Spacing.md)
            .padding(.top, KTheme.Spacing.md)
        }
        .background(Color(hex: "080810").ignoresSafeArea())
        .task { await healthKitManager.fetchAllTodayData() }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(sport.seasonPhase.displayName.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "7C6FFF"))
                    .tracking(1.5)

                Text("Hi, \(appState.userProfile.name.isEmpty ? "Athlete" : appState.userProfile.name)")
                    .font(KTheme.Typography.displaySmall)
                    .foregroundColor(KTheme.Colors.textPrimary)
            }
            Spacer()
            if sport.daysUntilPerformance <= 7 {
                matchCountdownChip(days: sport.daysUntilPerformance)
            }
        }
    }

    private func matchCountdownChip(days: Int) -> some View {
        Text("\(days)D TO MATCH")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(Color(hex: "FF6B8A"))
            .tracking(1)
            .padding(.horizontal, KTheme.Spacing.sm)
            .padding(.vertical, KTheme.Spacing.xs)
            .background(
                Capsule()
                    .fill(Color(hex: "FF6B8A").opacity(0.15))
                    .overlay(Capsule().stroke(Color(hex: "FF6B8A").opacity(0.4), lineWidth: 1))
            )
    }

    // MARK: - Score Hero Card
    private var scoreHeroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "0C0C16"))
                .shadow(color: readinessColor.opacity(0.25), radius: 20, x: 0, y: 8)

            VStack(spacing: KTheme.Spacing.lg) {
                scoreDisplay
                pillarsRow
            }
            .padding(KTheme.Spacing.lg)
        }
    }

    private var scoreDisplay: some View {
        VStack(spacing: KTheme.Spacing.xs) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(readinessScore)")
                    .font(.system(size: 80, weight: .black))
                    .foregroundColor(readinessColor)
                Text("/100")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(KTheme.Colors.textSecondary)
            }
            Text(readinessLabel)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(readinessColor)
                .tracking(2)
        }
    }

    private var pillarsRow: some View {
        HStack(spacing: KTheme.Spacing.md) {
            PillarBlock(
                label: "SLEEP",
                value: String(format: "%.1fh", sleepHours),
                score: sleepScore,
                color: Color(hex: "7C6FFF")
            )
            PillarBlock(
                label: "LOAD",
                value: String(format: "%.0f", acuteLoad),
                score: loadScore,
                color: Color(hex: "4ECDC4")
            )
            PillarBlock(
                label: "FUEL",
                value: "\(Int(consumedCalories))kcal",
                score: fuelScore,
                color: Color(hex: "FFB347")
            )
            PillarBlock(
                label: "ACWR",
                value: String(format: "%.2f", acwr),
                score: acwr == 0 ? 75 : (0.8...1.3).contains(acwr) ? 100 : max(0, 100 - (abs(acwr < 0.8 ? 0.8 - acwr : acwr - 1.3) * 100)),
                color: Color(hex: "FF6B8A")
            )
        }
    }

    // MARK: - Stat Row
    private var statRow: some View {
        HStack(spacing: KTheme.Spacing.sm) {
            StatMiniCard(
                icon: "bolt.fill",
                label: "GPS LOAD",
                value: String(format: "%.0f", acuteLoad),
                color: Color(hex: "4ECDC4")
            )
            StatMiniCard(
                icon: "calendar",
                label: "SESSIONS",
                value: "\(sessionsThisWeek)",
                color: Color(hex: "7C6FFF")
            )
            StatMiniCard(
                icon: "fork.knife",
                label: "CALORIES",
                value: "\(Int(consumedCalories))",
                color: Color(hex: "FFB347")
            )
        }
    }

    // MARK: - Edge Card
    private var edgeCard: some View {
        HStack(spacing: KTheme.Spacing.md) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(readinessColor)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(readinessColor.opacity(0.15))
                )

            Text(edgePrompt)
                .font(KTheme.Typography.bodyMedium)
                .foregroundColor(KTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(KTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: KTheme.Radius.md)
                .fill(Color(hex: "1A1A28"))
                .overlay(
                    RoundedRectangle(cornerRadius: KTheme.Radius.md)
                        .stroke(readinessColor.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - PillarBlock
private struct PillarBlock: View {
    let label: String
    let value: String
    let score: Double
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            // Vertical bar
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "1A1A28"))
                        .frame(width: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: 6, height: geo.size.height * CGFloat(min(score, 100) / 100))
                }
                .frame(maxWidth: .infinity)
            }
            .frame(height: 40)

            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(KTheme.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(KTheme.Colors.textSecondary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - StatMiniCard
private struct StatMiniCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.xs) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundColor(KTheme.Colors.textSecondary)
                    .tracking(0.5)
            }
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(KTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: KTheme.Radius.sm)
                .fill(Color(hex: "0C0C16"))
                .overlay(
                    RoundedRectangle(cornerRadius: KTheme.Radius.sm)
                        .stroke(Color(hex: "1A1A28"), lineWidth: 1)
                )
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
