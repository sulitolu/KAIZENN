import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var activityStore: ActivityStore
    @EnvironmentObject var appState: AppState

    @State private var showLogWorkout = false
    @State private var heartRateSamples: [HeartRateSample] = []
    @State private var selectedWorkout: WorkoutSession?

    var body: some View {
        ZStack {
            KTheme.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: KTheme.Spacing.lg) {

                    // Header
                    HStack {
                        Text("Activity")
                            .font(KTheme.Typography.displaySmall)
                            .foregroundColor(KTheme.Colors.textPrimary)
                        Spacer()
                        KButton(title: "Log Workout", style: .primary, size: .small) {
                            showLogWorkout = true
                        }
                    }

                    // Today's Overview Cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: KTheme.Spacing.sm) {
                        ActivityStatCard(icon: "figure.walk", label: "Steps", value: healthKitManager.todaySteps.formatted(.number), unit: "", color: KTheme.Colors.accentPrimary, progress: Double(healthKitManager.todaySteps) / 10000)
                        ActivityStatCard(icon: "flame.fill", label: "Active Cal", value: "\(Int(healthKitManager.todayActiveCalories))", unit: "kcal", color: KTheme.Colors.accentSecondary, progress: healthKitManager.todayActiveCalories / 500)
                        ActivityStatCard(icon: "figure.run", label: "Distance", value: String(format: "%.2f", healthKitManager.todayDistance / 1000), unit: "km", color: KTheme.Colors.accentTertiary, progress: healthKitManager.todayDistance / 5000)
                        ActivityStatCard(icon: "timer", label: "Exercise", value: "\(healthKitManager.todayExerciseMinutes)", unit: "min", color: KTheme.Colors.accentAmber, progress: Double(healthKitManager.todayExerciseMinutes) / 30)
                    }

                    // Heart Rate Card
                    heartRateCard

                    // Weekly Summary
                    weeklySummaryCard

                    // Workout Type Distribution
                    workoutTypesCard

                    // Recent Workouts List
                    recentWorkoutsSection

                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, KTheme.Spacing.md)
                .padding(.top, KTheme.Spacing.md)
            }
        }
        .sheet(isPresented: $showLogWorkout) {
            LogWorkoutView()
        }
        .sheet(item: $selectedWorkout) { workout in
            WorkoutDetailView(workout: workout, onDelete: workout.source == .manual ? {
                activityStore.removeWorkout(id: workout.id)
            } : nil)
        }
        .task {
            heartRateSamples = await healthKitManager.fetchHeartRateHistory(hours: 8)
        }
    }

    // MARK: Heart Rate Card
    private var heartRateCard: some View {
        KCard(elevated: true) {
            VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill").foregroundColor(KTheme.Colors.accentSecondary)
                        Text("Heart Rate").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                    }
                    Spacer()
                    if let hr = healthKitManager.heartRateCurrent {
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text("\(Int(hr))").font(KTheme.Typography.displaySmall).foregroundColor(KTheme.Colors.accentSecondary)
                            Text("bpm").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                        }
                    }
                }

                // Heart rate mini sparkline
                if !heartRateSamples.isEmpty {
                    HeartRateSparkline(samples: heartRateSamples)
                        .frame(height: 60)
                }

                if let rhr = healthKitManager.heartRateResting {
                    HStack {
                        Label("Resting HR: \(Int(rhr)) bpm", systemImage: "heart")
                            .font(KTheme.Typography.caption)
                            .foregroundColor(KTheme.Colors.textSecondary)
                        Spacer()
                        Text(heartRateZone(bpm: healthKitManager.heartRateCurrent ?? rhr, age: appState.userProfile.age))
                            .font(KTheme.Typography.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(KTheme.Colors.accentSecondary.opacity(0.15).cornerRadius(KTheme.Radius.sm))
                            .foregroundColor(KTheme.Colors.accentSecondary)
                    }
                }
            }
        }
    }

    // MARK: Weekly Summary
    private var weeklySummaryCard: some View {
        KCard {
            VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                Text("This Week").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                HStack(spacing: 0) {
                    WeeklyStatPill(value: "\(activityStore.totalWorkoutsThisWeek)", label: "Workouts", color: KTheme.Colors.accentPrimary)
                    Spacer()
                    WeeklyStatPill(value: "\(Int(activityStore.totalCaloriesBurnedThisWeek))", label: "Cal Burned", color: KTheme.Colors.accentSecondary)
                    Spacer()
                    WeeklyStatPill(value: "\(Int(activityStore.totalMinutesThisWeek))", label: "Min Active", color: KTheme.Colors.accentTertiary)
                }
            }
        }
    }

    // MARK: Workout Types Distribution
    private var workoutTypesCard: some View {
        let workouts = activityStore.workouts(lastDays: 30)
        guard !workouts.isEmpty else { return AnyView(EmptyView()) }
        let grouped = Dictionary(grouping: workouts, by: \.type)
        let sorted = grouped.sorted { $0.value.count > $1.value.count }.prefix(5)

        return AnyView(
            KSection(title: "30-Day Breakdown") {
                KCard {
                    VStack(spacing: KTheme.Spacing.sm) {
                        ForEach(sorted, id: \.key) { entry in
                            HStack {
                                Image(systemName: entry.key.icon).foregroundColor(KTheme.Colors.accentPrimary).frame(width: 20)
                                Text(entry.key.displayName).font(KTheme.Typography.bodyMedium).foregroundColor(KTheme.Colors.textPrimary)
                                Spacer()
                                Text("\(entry.value.count)x").font(KTheme.Typography.label).foregroundColor(KTheme.Colors.textSecondary)
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(KTheme.Colors.accentPrimary.opacity(0.5))
                                        .frame(width: geo.size.width * CGFloat(entry.value.count) / CGFloat(workouts.count), height: 6)
                                }
                                .frame(width: 60, height: 6)
                            }
                        }
                    }
                }
            }
        )
    }

    // MARK: Recent Workouts
    private var recentWorkoutsSection: some View {
        let all = (healthKitManager.recentWorkouts + activityStore.recentWorkouts)
            .sorted { $0.startDate > $1.startDate }
            .prefix(10)

        return KSection(title: "Recent Workouts") {
            VStack(spacing: KTheme.Spacing.sm) {
                ForEach(Array(all)) { workout in
                    WorkoutDetailCard(workout: workout, onDelete: workout.source == .manual ? {
                        activityStore.removeWorkout(id: workout.id)
                    } : nil, onTap: {
                        selectedWorkout = workout
                    })
                }
            }
        }
    }

    private func heartRateZone(bpm: Double, age: Int) -> String {
        let max = 220.0 - Double(age)
        let pct = bpm / max
        switch pct {
        case ..<0.5:  return "Rest"
        case 0.5..<0.6: return "Zone 1"
        case 0.6..<0.7: return "Zone 2"
        case 0.7..<0.8: return "Zone 3"
        case 0.8..<0.9: return "Zone 4"
        default:        return "Zone 5"
        }
    }
}

// MARK: — Supporting Views
struct ActivityStatCard: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color
    let progress: Double

    var body: some View {
        KCard {
            VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                HStack {
                    Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
                    Text(label).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                }
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(value).font(KTheme.Typography.headingLarge).foregroundColor(KTheme.Colors.textPrimary)
                    if !unit.isEmpty { Text(unit).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary) }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(KTheme.Colors.border).frame(height: 4)
                        RoundedRectangle(cornerRadius: 3).fill(color).frame(width: min(geo.size.width * CGFloat(min(progress, 1.0)), geo.size.width), height: 4)
                    }
                }.frame(height: 4)
            }
        }
    }
}

struct HeartRateSparkline: View {
    let samples: [HeartRateSample]

    var body: some View {
        GeometryReader { geo in
            let values = samples.map(\.bpm)
            let minVal = values.min() ?? 40
            let maxVal = max(values.max() ?? 200, minVal + 1)
            let points: [CGPoint] = samples.enumerated().map { i, sample in
                let x = geo.size.width * CGFloat(i) / CGFloat(max(samples.count - 1, 1))
                let y = geo.size.height * (1 - CGFloat((sample.bpm - minVal) / (maxVal - minVal)))
                return CGPoint(x: x, y: y)
            }

            ZStack {
                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(KTheme.Colors.accentSecondary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // Fill
                    Path { path in
                        path.move(to: CGPoint(x: points[0].x, y: geo.size.height))
                        path.addLine(to: points[0])
                        for point in points.dropFirst() { path.addLine(to: point) }
                        path.addLine(to: CGPoint(x: points.last!.x, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [KTheme.Colors.accentSecondary.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                }
            }
        }
    }
}

struct WeeklyStatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(KTheme.Typography.headingLarge).foregroundColor(color)
            Text(label).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WorkoutDetailCard: View {
    let workout: WorkoutSession
    var onDelete: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: KTheme.Spacing.md) {
            Button {
                onTap?()
            } label: {
                HStack(spacing: KTheme.Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: KTheme.Radius.sm)
                            .fill(KTheme.Colors.accentPrimary.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: workout.type.icon)
                            .foregroundColor(KTheme.Colors.accentPrimary)
                            .font(.system(size: 18))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(workout.type.displayName).font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                        HStack(spacing: KTheme.Spacing.sm) {
                            Label(workout.durationFormatted, systemImage: "timer").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                            if let dist = workout.distanceMeters {
                                Label(String(format: "%.1f km", dist/1000), systemImage: "mappin").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(Int(workout.caloriesBurned))")
                            .font(KTheme.Typography.headingMedium)
                            .foregroundColor(KTheme.Colors.accentSecondary)
                        Text("kcal").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                        Text(workout.startDate, style: .date).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textTertiary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(KTheme.Colors.textTertiary)
                }
            }
            .buttonStyle(KScaleButtonStyle())

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(KTheme.Colors.textTertiary)
                        .padding(.leading, KTheme.Spacing.xs)
                }
            }
        }
        .padding(KTheme.Spacing.sm)
        .background(KTheme.Colors.card.cornerRadius(KTheme.Radius.md))
    }
}

// MARK: — Workout Detail Sheet
struct WorkoutDetailView: View {
    let workout: WorkoutSession
    var onDelete: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                KTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: KTheme.Spacing.lg) {
                        VStack(spacing: KTheme.Spacing.sm) {
                            ZStack {
                                Circle().fill(KTheme.Colors.accentPrimary.opacity(0.15)).frame(width: 72, height: 72)
                                Image(systemName: workout.type.icon).font(.system(size: 28)).foregroundColor(KTheme.Colors.accentPrimary)
                            }
                            Text(workout.type.displayName).font(KTheme.Typography.headingLarge).foregroundColor(KTheme.Colors.textPrimary)
                            Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                                .font(KTheme.Typography.bodyMedium).foregroundColor(KTheme.Colors.textSecondary)
                        }
                        .padding(.top, KTheme.Spacing.md)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: KTheme.Spacing.sm) {
                            KStatCard(title: "Duration", value: workout.durationFormatted, unit: "", color: KTheme.Colors.accentPrimary, icon: "timer")
                            KStatCard(title: "Calories", value: "\(Int(workout.caloriesBurned))", unit: "kcal", color: KTheme.Colors.accentSecondary, icon: "flame.fill")
                            if let dist = workout.distanceMeters {
                                KStatCard(title: "Distance", value: String(format: "%.2f", dist / 1000), unit: "km", color: KTheme.Colors.accentTertiary, icon: "mappin.and.ellipse")
                            }
                            if let hr = workout.heartRateAvg {
                                KStatCard(title: "Avg Heart Rate", value: "\(Int(hr))", unit: "bpm", color: KTheme.Colors.danger, icon: "heart.fill")
                            }
                        }

                        if let notes = workout.notes, !notes.isEmpty {
                            KCard {
                                VStack(alignment: .leading, spacing: KTheme.Spacing.xs) {
                                    Text("Notes").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                                    Text(notes).font(KTheme.Typography.bodyMedium).foregroundColor(KTheme.Colors.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        HStack {
                            Text("Source").font(KTheme.Typography.bodyMedium).foregroundColor(KTheme.Colors.textSecondary)
                            Spacer()
                            KBadge(text: sourceLabel, color: KTheme.Colors.textSecondary)
                        }

                        if let onDelete = onDelete {
                            KButton(title: "Delete Workout", style: .danger) {
                                onDelete()
                                dismiss()
                            }
                            .padding(.top, KTheme.Spacing.md)
                        }
                    }
                    .padding(KTheme.Spacing.md)
                }
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(KTheme.Colors.accentPrimary)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var sourceLabel: String {
        switch workout.source {
        case .healthKit: return "Apple Health"
        case .manual:    return "Manual Entry"
        case .watch:     return "Apple Watch"
        }
    }
}
