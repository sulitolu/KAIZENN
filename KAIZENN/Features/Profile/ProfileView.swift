import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var nutritionStore: NutritionStore
    @EnvironmentObject var weightStore: WeightStore
    @EnvironmentObject var activityStore: ActivityStore
    @EnvironmentObject var scheduleStore: ScheduleStore

    @State private var showEditProfile = false
    @State private var showResetAlert = false

    private let accent = KTheme.Colors.accentPrimary

    var body: some View {
        ZStack {
            KTheme.Colors.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: KTheme.Spacing.lg) {
                    profileHeroHeader
                    performanceStatsRow
                    sportProfileCard
                    bodyMetricsCard
                    healthPermissionsCard
                    settingsSection
                    dangerSection
                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, KTheme.Spacing.md)
                .padding(.top, KTheme.Spacing.md)
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .alert("Reset All Data", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetData() }
        } message: {
            Text("This will delete all your nutrition logs, weight history, and habits. This action cannot be undone.")
        }
    }

    // MARK: — Hero Profile Header
    private var profileHeroHeader: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: KTheme.Radius.xl)
                .fill(KTheme.Colors.brandGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: KTheme.Radius.xl)
                        .stroke(accent.opacity(0.4), lineWidth: 0.5)
                )
                .shadow(color: accent.opacity(0.25), radius: 24, x: 0, y: 0)

            VStack(spacing: KTheme.Spacing.md) {
                HStack(alignment: .top, spacing: KTheme.Spacing.lg) {
                    avatarView
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appState.userProfile.name.isEmpty ? "ATHLETE" : appState.userProfile.name.uppercased())
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        microLabel(appState.userProfile.goal.displayName.uppercased(), color: .white.opacity(0.85))
                        microLabel("KAIZENN MEMBER", color: .white.opacity(0.55))
                    }
                    Spacer()
                    Button {
                        showEditProfile = true
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(KTheme.Spacing.lg)
        }
    }

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
            Text(appState.userProfile.name.prefix(1).uppercased().isEmpty ? "K" : String(appState.userProfile.name.prefix(1)).uppercased())
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
    }

    // MARK: — Performance Stats Row (4 mini stat cards)
    private var performanceStatsRow: some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
            premiumSectionHeader("PERFORMANCE")
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: KTheme.Spacing.sm
            ) {
                PremiumStatCell(
                    label: "DAILY TARGET",
                    value: "\(appState.userProfile.macroTargets.calories)",
                    unit: "kcal",
                    icon: "flame.fill",
                    color: KTheme.Colors.accentSecondary
                )
                PremiumStatCell(
                    label: "PROTEIN",
                    value: "\(appState.userProfile.macroTargets.proteinG)",
                    unit: "g",
                    icon: "fork.knife",
                    color: accent
                )
                PremiumStatCell(
                    label: "WORKOUTS",
                    value: "\(activityStore.totalWorkoutsThisWeek)",
                    unit: "this week",
                    icon: "dumbbell.fill",
                    color: KTheme.Colors.accentTertiary
                )
                PremiumStatCell(
                    label: "HABIT STREAK",
                    value: "\(scheduleStore.longestStreak)",
                    unit: "days",
                    icon: "star.fill",
                    color: KTheme.Colors.accentAmber
                )
            }
        }
    }

    // MARK: — Sport Profile Card
    private var sportProfileCard: some View {
        let sp = appState.userProfile.sportProfile
        return VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
            premiumSectionHeader("SPORT PROFILE")
            VStack(spacing: 0) {
                sportRow(icon: "sportscourt.fill", label: "SPORT", value: sp.sport.displayName)
                sportDivider
                sportRow(icon: "person.fill", label: "POSITION", value: sp.position.isEmpty ? "—" : sp.position)
                sportDivider
                sportRow(icon: "calendar.badge.clock", label: "SEASON PHASE", value: sp.seasonPhase.displayName)
                sportDivider
                sportRow(icon: "applewatch", label: "WEARABLE", value: sp.wearable.displayName)
                sportDivider
                sportRow(
                    icon: "bolt.fill",
                    label: "NEXT PERFORMANCE",
                    value: sp.daysUntilPerformance == 0 ? "TODAY" : "\(sp.daysUntilPerformance) days"
                )
            }
            .padding(KTheme.Spacing.md)
            .background(sportCardBackground)
        }
    }

    private var sportCardBackground: some View {
        RoundedRectangle(cornerRadius: KTheme.Radius.lg)
            .fill(KTheme.Colors.card)
            .overlay(
                RoundedRectangle(cornerRadius: KTheme.Radius.lg)
                    .stroke(accent.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: accent.opacity(0.15), radius: 20, x: 0, y: 0)
    }

    private var sportDivider: some View {
        Divider().background(KTheme.Colors.border.opacity(0.6))
    }

    private func sportRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: KTheme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(accent.opacity(0.8))
                .frame(width: 20)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(accent.opacity(0.8))
                .tracking(1.5)
            Spacer()
            Text(value)
                .font(KTheme.Typography.bodyMedium)
                .foregroundColor(KTheme.Colors.textPrimary)
        }
        .padding(.vertical, KTheme.Spacing.sm)
    }

    // MARK: — Body Metrics Card
    private var bodyMetricsCard: some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
            premiumSectionHeader("BODY METRICS")
            VStack(spacing: 0) {
                premiumMetricRow(label: "AGE", value: "\(appState.userProfile.age) yrs")
                metricDivider
                premiumMetricRow(label: "HEIGHT", value: String(format: "%.0f cm", appState.userProfile.heightCm))
                metricDivider
                premiumMetricRow(label: "WEIGHT", value: String(format: "%.1f kg", weightStore.latestWeight ?? appState.userProfile.currentWeightKg))
                metricDivider
                premiumMetricRow(label: "GOAL WEIGHT", value: String(format: "%.1f kg", appState.userProfile.goalWeightKg))
                metricDivider
                premiumMetricRow(label: "BMI", value: String(format: "%.1f · \(appState.userProfile.bmiCategory)", appState.userProfile.bmi))
                metricDivider
                premiumMetricRow(label: "ACTIVITY LEVEL", value: appState.userProfile.activityLevel.displayName)
                metricDivider
                premiumMetricRow(label: "TDEE", value: "\(Int(appState.userProfile.tdee)) kcal")
            }
            .padding(KTheme.Spacing.md)
            .background(metricsCardBackground)
        }
    }

    private var metricDivider: some View {
        Divider().background(KTheme.Colors.border.opacity(0.6))
    }

    private var metricsCardBackground: some View {
        RoundedRectangle(cornerRadius: KTheme.Radius.lg)
            .fill(KTheme.Colors.card)
            .overlay(
                RoundedRectangle(cornerRadius: KTheme.Radius.lg)
                    .stroke(accent.opacity(0.25), lineWidth: 0.5)
            )
            .shadow(color: accent.opacity(0.1), radius: 16, x: 0, y: 0)
    }

    private func premiumMetricRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(accent.opacity(0.8))
                .tracking(1.5)
            Spacer()
            Text(value)
                .font(KTheme.Typography.bodyMedium)
                .foregroundColor(KTheme.Colors.textPrimary)
        }
        .padding(.vertical, KTheme.Spacing.sm)
    }

    // MARK: — Health Permissions Card
    private var healthPermissionsCard: some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
            premiumSectionHeader("APPLE HEALTH")
            KCard {
                VStack(spacing: KTheme.Spacing.md) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HealthKit Connected")
                                .font(KTheme.Typography.headingSmall)
                                .foregroundColor(KTheme.Colors.textPrimary)
                            Text("Steps, heart rate, sleep, workouts")
                                .font(KTheme.Typography.caption)
                                .foregroundColor(KTheme.Colors.textSecondary)
                        }
                        Spacer()
                        Circle()
                            .fill(KTheme.Colors.success)
                            .frame(width: 8, height: 8)
                    }

                    Divider().background(KTheme.Colors.border)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TODAY'S STEPS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(KTheme.Colors.accentTertiary.opacity(0.8))
                                .tracking(1.5)
                            Text("\(healthKitManager.todaySteps)")
                                .font(KTheme.Typography.headingSmall)
                                .foregroundColor(KTheme.Colors.textPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("HEART RATE")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(KTheme.Colors.accentSecondary.opacity(0.8))
                                .tracking(1.5)
                            Text("\(Int(healthKitManager.heartRateCurrent ?? 0)) bpm")
                                .font(KTheme.Typography.headingSmall)
                                .foregroundColor(KTheme.Colors.textPrimary)
                        }
                    }

                    Button {
                        Task { await healthKitManager.requestAuthorization() }
                    } label: {
                        Label("Re-authorize Health Access", systemImage: "arrow.clockwise")
                            .font(KTheme.Typography.label)
                            .foregroundColor(accent)
                    }
                }
            }
        }
    }

    // MARK: — Settings Section
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
            premiumSectionHeader("PREFERENCES")
            KCard {
                VStack(spacing: 0) {
                    SettingsRow(icon: "bell.fill", color: accent, title: "Notifications") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Divider().background(KTheme.Colors.border)
                    SettingsRow(icon: "moon.fill", color: accent, title: "Dark Mode") {}
                    Divider().background(KTheme.Colors.border)
                    SettingsRow(icon: "scalemass.fill", color: KTheme.Colors.accentTertiary, title: "Units: Metric (kg / cm)") {}
                    Divider().background(KTheme.Colors.border)
                    SettingsRow(icon: "info.circle.fill", color: KTheme.Colors.textSecondary, title: "App Version: 1.0.0") {}
                }
            }
        }
    }

    // MARK: — Danger Zone
    private var dangerSection: some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
            premiumSectionHeader("ACCOUNT")
            VStack(spacing: KTheme.Spacing.sm) {
                KButton(title: "Edit Profile", style: .secondary) {
                    showEditProfile = true
                }
                KButton(title: "Reset All Data", style: .danger) {
                    showResetAlert = true
                }
            }
        }
    }

    // MARK: — Helpers
    private func premiumSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(accent)
            .tracking(2)
    }

    private func microLabel(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .tracking(1.5)
    }

    private func resetData() {
        appState.hasCompletedOnboarding = false
        UserDefaults.standard.removeObject(forKey: "kaizenn_nutrition_entries")
        UserDefaults.standard.removeObject(forKey: "kaizenn_water_entries")
        UserDefaults.standard.removeObject(forKey: "kaizenn_weight_measurements")
        UserDefaults.standard.removeObject(forKey: "kaizenn_habits")
        UserDefaults.standard.removeObject(forKey: "kaizenn_tasks")
        UserDefaults.standard.removeObject(forKey: "kaizenn_workouts")
    }
}

// MARK: — Edit Profile Sheet
struct EditProfileView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var age: Int = 25
    @State private var heightCm: Double = 175
    @State private var goalWeight: Double = 70
    @State private var activityLevel: UserProfile.ActivityLevel = .moderatelyActive
    @State private var goal: UserProfile.Goal = .loseFat

    var body: some View {
        NavigationView {
            ZStack {
                KTheme.Colors.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: KTheme.Spacing.lg) {
                        KTextField(placeholder: "Your name", text: $name, icon: "person.fill")

                        KCard {
                            HStack {
                                Text("Age").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                                Spacer()
                                Text("\(age) years").foregroundColor(KTheme.Colors.accentPrimary)
                                Stepper("", value: $age, in: 16...80).labelsHidden()
                            }
                        }

                        KCard {
                            VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                                HStack {
                                    Text("Height").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                                    Spacer()
                                    Text(String(format: "%.0f cm", heightCm)).foregroundColor(KTheme.Colors.accentPrimary)
                                }
                                Slider(value: $heightCm, in: 140...220, step: 0.5).tint(KTheme.Colors.accentPrimary)
                            }
                        }

                        KCard {
                            VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                                HStack {
                                    Text("Goal Weight").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                                    Spacer()
                                    Text(String(format: "%.1f kg", goalWeight)).foregroundColor(KTheme.Colors.accentPrimary)
                                }
                                Slider(value: $goalWeight, in: 40...200, step: 0.5).tint(KTheme.Colors.accentPrimary)
                            }
                        }

                        KButton(title: "Save Changes") {
                            var updated = appState.userProfile
                            updated.name = name
                            updated.age = age
                            updated.heightCm = heightCm
                            updated.goalWeightKg = goalWeight
                            updated.activityLevel = activityLevel
                            updated.goal = goal
                            updated.save()
                            appState.userProfile = updated
                            dismiss()
                        }
                        .padding(.bottom, KTheme.Spacing.xxl)
                    }
                    .padding(KTheme.Spacing.md)
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(KTheme.Colors.textSecondary)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            name = appState.userProfile.name
            age = appState.userProfile.age
            heightCm = appState.userProfile.heightCm
            goalWeight = appState.userProfile.goalWeightKg
            activityLevel = appState.userProfile.activityLevel
            goal = appState.userProfile.goal
        }
    }
}

// MARK: — Premium Stat Cell
struct PremiumStatCell: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16, weight: .semibold))
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(KTheme.Colors.textPrimary)
            VStack(alignment: .leading, spacing: 1) {
                Text(unit)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(KTheme.Colors.textSecondary)
                    .tracking(1.0)
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(color.opacity(0.8))
                    .tracking(1.5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KTheme.Spacing.md)
        .background(premiumStatBackground(color: color))
    }

    private func premiumStatBackground(color: Color) -> some View {
        RoundedRectangle(cornerRadius: KTheme.Radius.lg)
            .fill(KTheme.Colors.card)
            .overlay(
                RoundedRectangle(cornerRadius: KTheme.Radius.lg)
                    .stroke(color.opacity(0.3), lineWidth: 0.5)
            )
            .shadow(color: color.opacity(0.12), radius: 16, x: 0, y: 0)
    }
}

// MARK: — Settings Row (unchanged)
struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KTheme.Spacing.md) {
                Image(systemName: icon).foregroundColor(color).frame(width: 24)
                Text(title).font(KTheme.Typography.bodyMedium).foregroundColor(KTheme.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(KTheme.Colors.textTertiary).font(.caption)
            }
            .padding(.vertical, KTheme.Spacing.sm)
        }
    }
}
