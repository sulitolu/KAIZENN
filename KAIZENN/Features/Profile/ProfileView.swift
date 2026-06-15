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

    var body: some View {
        ZStack {
            KTheme.Colors.background.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: KTheme.Spacing.lg) {
                    // Profile Header
                    profileHeader

                    // Stats Overview
                    statsGrid

                    // Body Metrics
                    bodyMetricsCard

                    // Health Permissions
                    healthPermissionsCard

                    // App Settings
                    settingsSection

                    // Danger Zone
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

    // MARK: Profile Header
    private var profileHeader: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KTheme.Radius.xl)
                .fill(KTheme.Colors.brandGradient)
                .shadow(color: KTheme.Colors.accentPrimary.opacity(0.3), radius: 20)

            HStack(spacing: KTheme.Spacing.lg) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 80, height: 80)
                    Text(appState.userProfile.name.prefix(1).uppercased())
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.userProfile.name.isEmpty ? "Athlete" : appState.userProfile.name)
                        .font(KTheme.Typography.headingLarge)
                        .foregroundColor(.white)
                    Text(appState.userProfile.goal.displayName)
                        .font(KTheme.Typography.bodyMedium)
                        .foregroundColor(.white.opacity(0.8))
                    Text("KAIZENN Member")
                        .font(KTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.6))
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
            .padding(KTheme.Spacing.lg)
        }
    }

    // MARK: Stats Grid
    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: KTheme.Spacing.sm) {
            StatCell(label: "Daily Target", value: "\(appState.userProfile.macroTargets.calories)", unit: "kcal", icon: "flame.fill", color: KTheme.Colors.accentSecondary)
            StatCell(label: "Protein Target", value: "\(appState.userProfile.macroTargets.proteinG)", unit: "g", icon: "fork.knife", color: KTheme.Colors.accentPrimary)
            StatCell(label: "Workouts/Week", value: "\(activityStore.totalWorkoutsThisWeek)", unit: "this week", icon: "dumbbell.fill", color: KTheme.Colors.accentTertiary)
            StatCell(label: "Habit Streak", value: "\(scheduleStore.longestStreak)", unit: "days", icon: "star.fill", color: KTheme.Colors.accentAmber)
        }
    }

    // MARK: Body Metrics
    private var bodyMetricsCard: some View {
        KSection(title: "Body Metrics") {
            KCard {
                VStack(spacing: KTheme.Spacing.md) {
                    MetricRow(label: "Age", value: "\(appState.userProfile.age) years")
                    Divider().background(KTheme.Colors.border)
                    MetricRow(label: "Height", value: String(format: "%.0f cm", appState.userProfile.heightCm))
                    Divider().background(KTheme.Colors.border)
                    MetricRow(label: "Current Weight", value: String(format: "%.1f kg", weightStore.latestWeight ?? appState.userProfile.currentWeightKg))
                    Divider().background(KTheme.Colors.border)
                    MetricRow(label: "Goal Weight", value: String(format: "%.1f kg", appState.userProfile.goalWeightKg))
                    Divider().background(KTheme.Colors.border)
                    MetricRow(label: "BMI", value: String(format: "%.1f (\(appState.userProfile.bmiCategory))", appState.userProfile.bmi))
                    Divider().background(KTheme.Colors.border)
                    MetricRow(label: "Activity Level", value: appState.userProfile.activityLevel.displayName)
                    Divider().background(KTheme.Colors.border)
                    MetricRow(label: "TDEE", value: "\(appState.userProfile.tdee) kcal")
                }
            }
        }
    }

    // MARK: Health Permissions
    private var healthPermissionsCard: some View {
        KSection(title: "Apple Health") {
            KCard {
                VStack(spacing: KTheme.Spacing.md) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HealthKit Connected").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                            Text("Steps, heart rate, sleep, workouts").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                        }
                        Spacer()
                        Circle().fill(KTheme.Colors.success).frame(width: 8, height: 8)
                    }

                    Divider().background(KTheme.Colors.border)

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Today's Steps").font(KTheme.Typography.label).foregroundColor(KTheme.Colors.textSecondary)
                            Text("\(healthKitManager.todaySteps)").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Heart Rate").font(KTheme.Typography.label).foregroundColor(KTheme.Colors.textSecondary)
                            Text("\(Int(healthKitManager.heartRateCurrent ?? 0)) bpm").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                        }
                    }

                    Button {
                        Task { await healthKitManager.requestAuthorization() }
                    } label: {
                        Label("Re-authorize Health Access", systemImage: "arrow.clockwise")
                            .font(KTheme.Typography.label)
                            .foregroundColor(KTheme.Colors.accentPrimary)
                    }
                }
            }
        }
    }

    // MARK: Settings
    private var settingsSection: some View {
        KSection(title: "Preferences") {
            KCard {
                VStack(spacing: 0) {
                    SettingsRow(icon: "bell.fill", color: KTheme.Colors.accentPrimary, title: "Notifications") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Divider().background(KTheme.Colors.border)
                    SettingsRow(icon: "moon.fill", color: KTheme.Colors.accentPrimary, title: "Dark Mode") {}
                    Divider().background(KTheme.Colors.border)
                    SettingsRow(icon: "scalemass.fill", color: KTheme.Colors.accentTertiary, title: "Units: Metric (kg / cm)") {}
                    Divider().background(KTheme.Colors.border)
                    SettingsRow(icon: "info.circle.fill", color: KTheme.Colors.textSecondary, title: "App Version: 1.0.0") {}
                }
            }
        }
    }

    // MARK: Danger Zone
    private var dangerSection: some View {
        KSection(title: "Account") {
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

    private func resetData() {
        // Clear all data — only call this if explicitly confirmed
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

// MARK: — Small Components
struct StatCell: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        KCard {
            VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                Image(systemName: icon).foregroundColor(color).font(.title3)
                Text(value).font(KTheme.Typography.headingLarge).foregroundColor(KTheme.Colors.textPrimary)
                VStack(alignment: .leading, spacing: 0) {
                    Text(unit).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                    Text(label).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).font(KTheme.Typography.bodyMedium).foregroundColor(KTheme.Colors.textSecondary)
            Spacer()
            Text(value).font(KTheme.Typography.bodyMedium).foregroundColor(KTheme.Colors.textPrimary)
        }
    }
}

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
