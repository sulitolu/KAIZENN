import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var nutritionStore: NutritionStore
    @EnvironmentObject var weightStore: WeightStore
    @EnvironmentObject var scheduleStore: ScheduleStore
    @EnvironmentObject var activityStore: ActivityStore

    @State private var greeting: String = ""
    @State private var showQuickLog = false
    @State private var animateRings = false
    @State private var activeSheet: QuickLogSheet?
    @State private var selectedWorkout: WorkoutSession?

    var body: some View {
        ZStack {
            KTheme.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: KTheme.Spacing.lg) {
                    // Header
                    headerSection

                    // Activity Rings — Apple Watch style
                    activityRingsSection

                    // Calorie Summary
                    calorieSummarySection

                    // Today's Habits
                    habitsSection

                    // Quick Stats Row
                    quickStatsRow

                    // Water Tracker
                    waterSection

                    // Recent Workouts
                    if !healthKitManager.recentWorkouts.isEmpty || !activityStore.recentWorkouts.isEmpty {
                        recentWorkoutsSection
                    }

                    // Sleep Card
                    sleepCard

                    // Motivational Quote
                    motivationCard

                    Color.clear.frame(height: 100) // tab bar space
                }
                .padding(.horizontal, KTheme.Spacing.md)
                .padding(.top, KTheme.Spacing.md)
            }
            .refreshable {
                await healthKitManager.fetchAllTodayData()
            }

            if showQuickLog {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(KTheme.Animation.snappy) { showQuickLog = false }
                    }
            }
        }
        .overlay(alignment: .bottomTrailing) { quickLogMenu }
        .onAppear {
            setGreeting()
            withAnimation(KTheme.Animation.spring.delay(0.3)) { animateRings = true }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .food:    AddFoodView(mealType: .current)
            case .workout: LogWorkoutView()
            case .weight:  LogWeightView()
            case .task:    AddTaskView()
            }
        }
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailView(workout: workout, onDelete: workout.source == .manual ? {
                activityStore.removeWorkout(id: workout.id)
            } : nil)
        }
    }

    // MARK: Quick Log FAB
    private var quickLogMenu: some View {
        VStack(alignment: .trailing, spacing: KTheme.Spacing.sm) {
            if showQuickLog {
                QuickLogOption(icon: "fork.knife", label: "Log Food", color: KTheme.Colors.accentSecondary) {
                    openSheet(.food)
                }
                QuickLogOption(icon: "flame.fill", label: "Log Workout", color: KTheme.Colors.accentTertiary) {
                    openSheet(.workout)
                }
                QuickLogOption(icon: "scalemass.fill", label: "Log Weight", color: KTheme.Colors.accentAmber) {
                    openSheet(.weight)
                }
                QuickLogOption(icon: "checklist", label: "Add Task", color: KTheme.Colors.accentPrimary) {
                    openSheet(.task)
                }
            }

            Button {
                withAnimation(KTheme.Animation.bounce) { showQuickLog.toggle() }
            } label: {
                ZStack {
                    Circle()
                        .fill(KTheme.Colors.brandGradient)
                        .frame(width: 56, height: 56)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(showQuickLog ? 45 : 0))
                }
                .kGlow(color: KTheme.Colors.accentPrimary, radius: 14)
            }
            .buttonStyle(KScaleButtonStyle())
        }
        .padding(.trailing, KTheme.Spacing.md)
        .padding(.bottom, 110)
    }

    private func openSheet(_ sheet: QuickLogSheet) {
        withAnimation(KTheme.Animation.snappy) { showQuickLog = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            activeSheet = sheet
        }
    }

    // MARK: Header
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(KTheme.Typography.bodyMedium)
                    .foregroundColor(KTheme.Colors.textSecondary)
                Text(appState.userProfile.name.isEmpty ? "Champion" : appState.userProfile.name)
                    .font(KTheme.Typography.displaySmall)
                    .foregroundColor(KTheme.Colors.textPrimary)
                Text(formattedDate)
                    .font(KTheme.Typography.caption)
                    .foregroundColor(KTheme.Colors.textTertiary)
            }
            Spacer()
            Button {
                appState.selectedTab = .coach
            } label: {
                ZStack {
                    Circle()
                        .fill(KTheme.Colors.accentPrimary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20))
                        .foregroundColor(KTheme.Colors.accentPrimary)
                }
                .kGlow(color: KTheme.Colors.accentPrimary, radius: 10)
            }
        }
    }

    // MARK: Activity Rings
    private var activityRingsSection: some View {
        KCard(elevated: true) {
            HStack(spacing: KTheme.Spacing.lg) {
                // Three rings
                ZStack {
                    // Move ring (calories)
                    KProgressRing(
                        progress: healthKitManager.todayActiveCalories,
                        total: Double(appState.userProfile.macroTargets.calories) * 0.5,
                        size: 110,
                        lineWidth: 10,
                        color: KTheme.Colors.accentSecondary
                    )
                    // Exercise ring
                    KProgressRing(
                        progress: Double(healthKitManager.todayExerciseMinutes),
                        total: 30,
                        size: 84,
                        lineWidth: 9,
                        color: KTheme.Colors.accentTertiary
                    )
                    // Stand ring
                    KProgressRing(
                        progress: Double(healthKitManager.todayStandHours),
                        total: 12,
                        size: 58,
                        lineWidth: 8,
                        color: KTheme.Colors.accentAmber
                    )
                }
                .scaleEffect(animateRings ? 1.0 : 0.7)
                .opacity(animateRings ? 1.0 : 0)

                // Ring stats
                VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                    RingStatRow(color: KTheme.Colors.accentSecondary, label: "MOVE", value: "\(Int(healthKitManager.todayActiveCalories))", unit: "CAL")
                    RingStatRow(color: KTheme.Colors.accentTertiary, label: "EXERCISE", value: "\(healthKitManager.todayExerciseMinutes)", unit: "MIN")
                    RingStatRow(color: KTheme.Colors.accentAmber, label: "STAND", value: "\(healthKitManager.todayStandHours)", unit: "HRS")
                }

                Spacer()
            }
        }
    }

    // MARK: Calorie Summary
    private var calorieSummarySection: some View {
        let nutrition = nutritionStore.dailyNutrition(for: Date())
        let targets = appState.userProfile.macroTargets
        let remaining = targets.calories - Int(nutrition.totalCalories)

        return KCard {
            VStack(spacing: KTheme.Spacing.md) {
                HStack {
                    Text("Today's Nutrition")
                        .font(KTheme.Typography.headingSmall)
                        .foregroundColor(KTheme.Colors.textPrimary)
                    Spacer()
                    KBadge(text: "\(remaining > 0 ? remaining : 0) cal left",
                           color: remaining > 0 ? KTheme.Colors.success : KTheme.Colors.danger)
                }

                // Calorie bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(KTheme.Colors.border)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(calorieBarGradient(consumed: nutrition.totalCalories, target: Double(targets.calories)))
                            .frame(width: min(geo.size.width * CGFloat(nutrition.totalCalories / Double(targets.calories)), geo.size.width), height: 6)
                            .animation(KTheme.Animation.spring, value: nutrition.totalCalories)
                    }
                }
                .frame(height: 6)

                // Macros
                HStack {
                    MacroMini(label: "Protein", value: Int(nutrition.totalProteinG), target: targets.proteinG, color: KTheme.Colors.accentSecondary)
                    Spacer()
                    MacroMini(label: "Carbs", value: Int(nutrition.totalCarbsG), target: targets.carbsG, color: KTheme.Colors.accentAmber)
                    Spacer()
                    MacroMini(label: "Fat", value: Int(nutrition.totalFatG), target: targets.fatG, color: KTheme.Colors.accentTertiary)
                }
            }
        }
    }

    private func calorieBarGradient(consumed: Double, target: Double) -> LinearGradient {
        let ratio = consumed / target
        if ratio < 0.8 { return LinearGradient(colors: [KTheme.Colors.accentPrimary, KTheme.Colors.accentSecondary], startPoint: .leading, endPoint: .trailing) }
        if ratio < 1.0 { return LinearGradient(colors: [KTheme.Colors.accentAmber, KTheme.Colors.accentSecondary], startPoint: .leading, endPoint: .trailing) }
        return LinearGradient(colors: [KTheme.Colors.danger, KTheme.Colors.danger.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
    }

    // MARK: Habits
    private var habitsSection: some View {
        KSection(title: "Today's Habits",
                 trailing: AnyView(Text("\(scheduleStore.completedTodayCount)/\(scheduleStore.todayHabits.count)").font(KTheme.Typography.label).foregroundColor(KTheme.Colors.textSecondary))) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: KTheme.Spacing.sm) {
                ForEach(scheduleStore.todayHabits) { habit in
                    HabitMiniCard(habit: habit) {
                        scheduleStore.toggleHabit(id: habit.id)
                    }
                }
            }
        }
    }

    // MARK: Quick Stats
    private var quickStatsRow: some View {
        HStack(spacing: KTheme.Spacing.sm) {
            KStatCard(
                title: "Steps",
                value: healthKitManager.todaySteps.formatted(.number),
                unit: "steps",
                trend: nil,
                color: KTheme.Colors.accentPrimary,
                icon: "figure.walk"
            )
            KStatCard(
                title: "Heart Rate",
                value: healthKitManager.heartRateCurrent.map { String(Int($0)) } ?? "—",
                unit: "bpm",
                color: KTheme.Colors.accentSecondary,
                icon: "heart.fill"
            )
        }
    }

    // MARK: Water
    private var waterSection: some View {
        let consumed = nutritionStore.waterConsumedMl(for: Date())
        let target: Double = 2500

        return KCard {
            HStack {
                VStack(alignment: .leading, spacing: KTheme.Spacing.xs) {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundColor(KTheme.Colors.accentPrimary)
                        Text("Hydration")
                            .font(KTheme.Typography.headingSmall)
                            .foregroundColor(KTheme.Colors.textPrimary)
                    }
                    Text(String(format: "%.0f / %.0f ml", consumed, target))
                        .font(KTheme.Typography.bodySmall)
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
                Spacer()
                // Water bubbles
                HStack(spacing: 4) {
                    ForEach(0..<8) { i in
                        Circle()
                            .fill(Double(i) < (consumed / target * 8) ? KTheme.Colors.accentPrimary : KTheme.Colors.border)
                            .frame(width: 12, height: 12)
                    }
                }
                Button {
                    nutritionStore.addWater(ml: 250)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(KTheme.Colors.accentPrimary)
                }
                .padding(.leading, KTheme.Spacing.sm)
            }
        }
    }

    // MARK: Recent Workouts
    private var recentWorkoutsSection: some View {
        let workouts = (healthKitManager.recentWorkouts + activityStore.recentWorkouts)
            .sorted { $0.startDate > $1.startDate }
            .prefix(3)
        return KSection(title: "Recent Workouts") {
            VStack(spacing: KTheme.Spacing.sm) {
                ForEach(Array(workouts)) { workout in
                    WorkoutRowCard(workout: workout) {
                        selectedWorkout = workout
                    }
                }
            }
        }
    }

    // MARK: Sleep
    private var sleepCard: some View {
        KCard {
            HStack {
                VStack(alignment: .leading, spacing: KTheme.Spacing.xs) {
                    HStack {
                        Image(systemName: "moon.stars.fill")
                            .foregroundColor(KTheme.Colors.accentPrimary)
                        Text("Last Night's Sleep")
                            .font(KTheme.Typography.headingSmall)
                            .foregroundColor(KTheme.Colors.textPrimary)
                    }
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(String(format: "%.1f", healthKitManager.sleepHoursLast))
                            .font(KTheme.Typography.displaySmall)
                            .foregroundColor(sleepColor)
                        Text("hours")
                            .font(KTheme.Typography.caption)
                            .foregroundColor(KTheme.Colors.textSecondary)
                    }
                    Text(sleepQualityLabel)
                        .font(KTheme.Typography.caption)
                        .foregroundColor(sleepColor)
                }
                Spacer()
                KProgressRing(progress: healthKitManager.sleepHoursLast, total: 8, size: 64, lineWidth: 6, color: sleepColor, label: nil)
            }
        }
    }

    private var sleepColor: Color {
        switch healthKitManager.sleepHoursLast {
        case 7...: return KTheme.Colors.success
        case 5..<7: return KTheme.Colors.warning
        default:   return KTheme.Colors.danger
        }
    }
    private var sleepQualityLabel: String {
        switch healthKitManager.sleepHoursLast {
        case 7...: return "Well rested 💪"
        case 5..<7: return "Could be better"
        default:   return "Need more sleep"
        }
    }

    // MARK: Motivation
    private var motivationCard: some View {
        let quotes = [
            ("Kaizen — 1% better every day.", "The philosophy"),
            ("Progress, not perfection.", "KAIZENN"),
            ("Every rep, every meal, every step counts.", "Stay consistent"),
            ("Your future self is watching. Make them proud.", "Daily truth"),
            ("Rest is part of the process. So is showing up.", "Balance"),
        ]
        let quote = quotes[Calendar.current.component(.weekday, from: Date()) % quotes.count]

        return ZStack {
            RoundedRectangle(cornerRadius: KTheme.Radius.lg)
                .fill(KTheme.Colors.brandGradient)
            VStack(spacing: KTheme.Spacing.xs) {
                Text("\"\(quote.0)\"")
                    .font(KTheme.Typography.headingSmall)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("— \(quote.1)")
                    .font(KTheme.Typography.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(KTheme.Spacing.lg)
        }
    }

    // MARK: Helpers
    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    private func setGreeting() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: greeting = "Good morning,"
        case 12..<17: greeting = "Good afternoon,"
        default: greeting = "Good evening,"
        }
    }
}

// MARK: — Quick Log
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

struct QuickLogOption: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KTheme.Spacing.sm) {
                Text(label)
                    .font(KTheme.Typography.label)
                    .foregroundColor(KTheme.Colors.textPrimary)
                    .padding(.horizontal, KTheme.Spacing.sm)
                    .padding(.vertical, 6)
                    .background(KTheme.Colors.cardElevated.cornerRadius(KTheme.Radius.sm))

                ZStack {
                    Circle().fill(color).frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(KScaleButtonStyle())
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
}

// MARK: — Supporting Views
struct RingStatRow: View {
    let color: Color
    let label: String
    let value: String
    let unit: String

    var body: some View {
        HStack(spacing: KTheme.Spacing.xs) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value).font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                    Text(unit).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                }
            }
        }
    }
}

struct MacroMini: View {
    let label: String
    let value: Int
    let target: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)g").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
            Text("\(label)").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(KTheme.Colors.border).frame(height: 3)
                    RoundedRectangle(cornerRadius: 2).fill(color).frame(width: min(geo.size.width * CGFloat(value) / CGFloat(max(target, 1)), geo.size.width), height: 3)
                }
            }.frame(height: 3)
            Text("/ \(target)g").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HabitMiniCard: View {
    let habit: Habit
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: KTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(habit.isCompletedToday ? Color(hex: habit.color) : Color(hex: habit.color).opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: habit.isCompletedToday ? "checkmark" : habit.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(habit.isCompletedToday ? .white : Color(hex: habit.color))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(habit.title)
                        .font(KTheme.Typography.bodySmall)
                        .foregroundColor(habit.isCompletedToday ? KTheme.Colors.textSecondary : KTheme.Colors.textPrimary)
                        .lineLimit(1)
                        .strikethrough(habit.isCompletedToday, color: KTheme.Colors.textSecondary)
                    if habit.streak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("\(habit.streak)")
                                .font(KTheme.Typography.caption)
                        }
                        .foregroundColor(KTheme.Colors.accentAmber)
                    } else {
                        Text(habit.frequency.displayName)
                            .font(KTheme.Typography.caption)
                            .foregroundColor(KTheme.Colors.textTertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(KTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: KTheme.Radius.md)
                    .fill(habit.isCompletedToday ? Color(hex: habit.color).opacity(0.08) : KTheme.Colors.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: KTheme.Radius.md)
                            .stroke(habit.isCompletedToday ? Color(hex: habit.color).opacity(0.3) : KTheme.Colors.border.opacity(0.4), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(KScaleButtonStyle())
    }
}

struct WorkoutRowCard: View {
    let workout: WorkoutSession
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: KTheme.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: KTheme.Radius.sm)
                        .fill(KTheme.Colors.accentPrimary.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: workout.type.icon)
                        .foregroundColor(KTheme.Colors.accentPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.type.displayName)
                        .font(KTheme.Typography.headingSmall)
                        .foregroundColor(KTheme.Colors.textPrimary)
                    Text(workout.startDate, style: .date)
                        .font(KTheme.Typography.caption)
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(workout.caloriesBurned)) cal")
                        .font(KTheme.Typography.headingSmall)
                        .foregroundColor(KTheme.Colors.accentSecondary)
                    Text(workout.durationFormatted)
                        .font(KTheme.Typography.caption)
                        .foregroundColor(KTheme.Colors.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(KTheme.Colors.textTertiary)
            }
            .padding(KTheme.Spacing.sm)
            .background(KTheme.Colors.card.cornerRadius(KTheme.Radius.md))
        }
        .buttonStyle(KScaleButtonStyle())
    }
}
