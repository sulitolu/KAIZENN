import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject var appState: AppState

    @State private var currentStep = 0
    @State private var name = ""
    @State private var age = 25
    @State private var gender: UserProfile.Gender = .male
    @State private var heightCm = 175.0
    @State private var currentWeight = 80.0
    @State private var goalWeight = 70.0
    @State private var activityLevel: UserProfile.ActivityLevel = .moderatelyActive
    @State private var goal: UserProfile.Goal = .loseFat
    @State private var weeklyGoalKg = 0.5
    @State private var showHealthRequest = false

    private let totalSteps = 5

    var body: some View {
        ZStack {
            KTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(KTheme.Colors.border).frame(height: 2)
                        Rectangle()
                            .fill(KTheme.Colors.brandGradient)
                            .frame(width: geo.size.width * CGFloat(currentStep + 1) / CGFloat(totalSteps), height: 2)
                            .animation(KTheme.Animation.smooth, value: currentStep)
                    }
                }
                .frame(height: 2)

                // Step content
                TabView(selection: $currentStep) {
                    welcomeStep.tag(0)
                    personalStep.tag(1)
                    bodyStep.tag(2)
                    goalStep.tag(3)
                    activityStep.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(KTheme.Animation.smooth, value: currentStep)
            }
        }
    }

    // MARK: Step 1 — Welcome
    private var welcomeStep: some View {
        VStack(spacing: KTheme.Spacing.xl) {
            Spacer()

            // Logo
            ZStack {
                Circle()
                    .fill(KTheme.Colors.brandGradient)
                    .frame(width: 120, height: 120)
                    .kGlow(color: KTheme.Colors.accentPrimary, radius: 30)
                Text("改")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(spacing: KTheme.Spacing.sm) {
                Text("KAIZENN")
                    .font(KTheme.Typography.displayLarge)
                    .foregroundColor(KTheme.Colors.textPrimary)
                    .kerning(4)
                Text("改善")
                    .font(KTheme.Typography.headingMedium)
                    .foregroundColor(KTheme.Colors.accentPrimary)
                Text("Continuous improvement, every day.")
                    .font(KTheme.Typography.bodyMedium)
                    .foregroundColor(KTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                FeatureRow(icon: "heart.fill", color: KTheme.Colors.accentSecondary, text: "Full Apple Watch + HealthKit integration")
                FeatureRow(icon: "brain.head.profile", color: KTheme.Colors.accentPrimary, text: "AI-powered coaching & recommendations")
                FeatureRow(icon: "fork.knife", color: KTheme.Colors.accentTertiary, text: "Smart nutrition & calorie tracking")
                FeatureRow(icon: "dumbbell.fill", color: KTheme.Colors.accentAmber, text: "Activity & workout tracking")
                FeatureRow(icon: "star.fill", color: KTheme.Colors.success, text: "Habit building & daily scheduling")
            }
            .padding(KTheme.Spacing.lg)
            .background(KTheme.Colors.card.cornerRadius(KTheme.Radius.xl))

            KTextField(placeholder: "What's your name?", text: $name, icon: "person.fill")
                .padding(.horizontal, KTheme.Spacing.md)

            Spacer()

            nextButton(title: "Get Started", enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, KTheme.Spacing.lg)
    }

    // MARK: Step 2 — Personal
    private var personalStep: some View {
        VStack(spacing: KTheme.Spacing.xl) {
            stepHeader(step: "1 / 4", title: "About You", subtitle: "This helps us calculate your exact calorie targets")

            VStack(spacing: KTheme.Spacing.lg) {
                // Age
                KCard {
                    VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                        Text("Age").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                        HStack {
                            Text("\(age)")
                                .font(KTheme.Typography.displaySmall)
                                .foregroundColor(KTheme.Colors.accentPrimary)
                                .frame(width: 60)
                            Slider(value: Binding(get: { Double(age) }, set: { age = Int($0) }),
                                   in: 16...80, step: 1)
                                .tint(KTheme.Colors.accentPrimary)
                        }
                    }
                }

                // Gender
                KCard {
                    VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                        Text("Biological Sex").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                        Text("Used for accurate BMR calculation").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                        HStack(spacing: KTheme.Spacing.md) {
                            ForEach(UserProfile.Gender.allCases, id: \.self) { g in
                                Button {
                                    withAnimation(KTheme.Animation.snappy) { gender = g }
                                } label: {
                                    HStack {
                                        Image(systemName: g == .male ? "person.fill" : "person.fill")
                                        Text(g.rawValue.capitalized)
                                    }
                                    .font(KTheme.Typography.bodyMedium)
                                    .foregroundColor(gender == g ? .white : KTheme.Colors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(KTheme.Spacing.md)
                                    .background(gender == g ? KTheme.Colors.accentPrimary : KTheme.Colors.card)
                                    .cornerRadius(KTheme.Radius.md)
                                }
                            }
                        }
                    }
                }

                // Height
                KCard {
                    VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                        HStack {
                            Text("Height").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                            Spacer()
                            Text(String(format: "%.0f cm  (%.0f'%.0f\")", heightCm, floor(heightCm / 30.48), (heightCm / 2.54).truncatingRemainder(dividingBy: 12)))
                                .font(KTheme.Typography.label)
                                .foregroundColor(KTheme.Colors.accentPrimary)
                        }
                        Slider(value: $heightCm, in: 140...220, step: 0.5)
                            .tint(KTheme.Colors.accentPrimary)
                    }
                }
            }

            Spacer()
            HStack {
                backButton
                nextButton(title: "Continue", enabled: true)
            }
        }
        .padding(.horizontal, KTheme.Spacing.lg)
    }

    // MARK: Step 3 — Body
    private var bodyStep: some View {
        VStack(spacing: KTheme.Spacing.xl) {
            stepHeader(step: "2 / 4", title: "Your Body", subtitle: "Current and goal weight let us map your journey")

            VStack(spacing: KTheme.Spacing.lg) {
                weightPicker(title: "Current Weight", value: $currentWeight, range: 40...200)
                weightPicker(title: "Goal Weight", value: $goalWeight, range: 40...200)

                // Difference preview
                let diff = currentWeight - goalWeight
                KCard(elevated: true) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(diff >= 0 ? "Weight to Lose" : "Weight to Gain")
                                .font(KTheme.Typography.headingSmall)
                                .foregroundColor(KTheme.Colors.textPrimary)
                            Text("At 0.5kg/week, that's ~\(Int(abs(diff) / 0.5)) weeks")
                                .font(KTheme.Typography.caption)
                                .foregroundColor(KTheme.Colors.textSecondary)
                        }
                        Spacer()
                        Text(String(format: "%.1f kg", abs(diff)))
                            .font(KTheme.Typography.displaySmall)
                            .foregroundColor(diff >= 0 ? KTheme.Colors.accentSecondary : KTheme.Colors.accentTertiary)
                    }
                }
            }

            Spacer()
            HStack {
                backButton
                nextButton(title: "Continue", enabled: abs(goalWeight - currentWeight) > 0.1)
            }
        }
        .padding(.horizontal, KTheme.Spacing.lg)
    }

    // MARK: Step 4 — Goal
    private var goalStep: some View {
        VStack(spacing: KTheme.Spacing.xl) {
            stepHeader(step: "3 / 4", title: "Your Goal", subtitle: "Choose your primary focus — you can change this later")

            VStack(spacing: KTheme.Spacing.sm) {
                ForEach(UserProfile.Goal.allCases, id: \.self) { g in
                    Button {
                        withAnimation(KTheme.Animation.snappy) { goal = g }
                    } label: {
                        HStack(spacing: KTheme.Spacing.md) {
                            Text(goalIcon(g)).font(.title)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.displayName).font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                                Text(goalDescription(g)).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                            }
                            Spacer()
                            if goal == g {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(KTheme.Colors.accentPrimary)
                            }
                        }
                        .padding(KTheme.Spacing.md)
                        .background(goal == g ? KTheme.Colors.accentPrimary.opacity(0.1) : KTheme.Colors.card)
                        .cornerRadius(KTheme.Radius.md)
                        .overlay(RoundedRectangle(cornerRadius: KTheme.Radius.md).stroke(goal == g ? KTheme.Colors.accentPrimary : KTheme.Colors.border.opacity(0.4), lineWidth: 1))
                    }
                }
            }

            // Weekly goal pace
            if goal == .loseFat || goal == .buildMuscle {
                KCard {
                    VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                        HStack {
                            Text("Weekly Pace").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                            Spacer()
                            Text(String(format: "%.1f kg/week", weeklyGoalKg)).font(KTheme.Typography.label).foregroundColor(KTheme.Colors.accentPrimary)
                        }
                        Slider(value: $weeklyGoalKg, in: 0.25...1.0, step: 0.25).tint(KTheme.Colors.accentPrimary)
                        Text(weeklyGoalKg <= 0.5 ? "✅ Sustainable — ideal for long-term results" : weeklyGoalKg <= 0.75 ? "⚡ Moderate — requires discipline" : "🔥 Aggressive — ensure adequate protein")
                            .font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                    }
                }
            }

            Spacer()
            HStack {
                backButton
                nextButton(title: "Continue", enabled: true)
            }
        }
        .padding(.horizontal, KTheme.Spacing.lg)
    }

    // MARK: Step 5 — Activity
    private var activityStep: some View {
        VStack(spacing: KTheme.Spacing.xl) {
            stepHeader(step: "4 / 4", title: "Activity Level", subtitle: "Your daily activity affects your calorie needs significantly")

            VStack(spacing: KTheme.Spacing.sm) {
                ForEach(UserProfile.ActivityLevel.allCases, id: \.self) { level in
                    Button {
                        withAnimation(KTheme.Animation.snappy) { activityLevel = level }
                    } label: {
                        HStack(spacing: KTheme.Spacing.md) {
                            Text(activityIcon(level)).font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.displayName).font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                                Text(activityDescription(level)).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                            }
                            Spacer()
                            if activityLevel == level {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(KTheme.Colors.accentPrimary)
                            }
                        }
                        .padding(KTheme.Spacing.md)
                        .background(activityLevel == level ? KTheme.Colors.accentPrimary.opacity(0.1) : KTheme.Colors.card)
                        .cornerRadius(KTheme.Radius.md)
                        .overlay(RoundedRectangle(cornerRadius: KTheme.Radius.md).stroke(activityLevel == level ? KTheme.Colors.accentPrimary : KTheme.Colors.border.opacity(0.4), lineWidth: 1))
                    }
                }
            }

            // Preview calorie estimate
            let previewProfile = UserProfile(name: name, age: age, gender: gender,
                                              heightCm: heightCm, currentWeightKg: currentWeight,
                                              goalWeightKg: goalWeight, activityLevel: activityLevel,
                                              goal: goal, weeklyGoalKg: weeklyGoalKg)
            KCard(elevated: true) {
                VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                    Text("Your Daily Calorie Target").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(previewProfile.macroTargets.calories)")
                            .font(KTheme.Typography.displaySmall)
                            .foregroundColor(KTheme.Colors.accentPrimary)
                        Text("kcal / day").font(KTheme.Typography.bodyMedium).foregroundColor(KTheme.Colors.textSecondary)
                    }
                    HStack(spacing: KTheme.Spacing.md) {
                        MacroPreview(label: "Protein", grams: previewProfile.macroTargets.proteinG, color: KTheme.Colors.accentSecondary)
                        MacroPreview(label: "Carbs", grams: previewProfile.macroTargets.carbsG, color: KTheme.Colors.accentAmber)
                        MacroPreview(label: "Fat", grams: previewProfile.macroTargets.fatG, color: KTheme.Colors.accentTertiary)
                    }
                }
            }

            Spacer()
            HStack {
                backButton
                KButton(title: "Start My Journey 🚀") {
                    completeOnboarding()
                }
            }
        }
        .padding(.horizontal, KTheme.Spacing.lg)
    }

    // MARK: Helpers
    private func stepHeader(step: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.xs) {
            Text(step).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textTertiary).padding(.top, KTheme.Spacing.lg)
            Text(title).font(KTheme.Typography.displaySmall).foregroundColor(KTheme.Colors.textPrimary)
            Text(subtitle).font(KTheme.Typography.bodyMedium).foregroundColor(KTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weightPicker(title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        KCard {
            VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                HStack {
                    Text(title).font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                    Spacer()
                    Text(String(format: "%.1f kg", value.wrappedValue)).font(KTheme.Typography.headingMedium).foregroundColor(KTheme.Colors.accentPrimary)
                }
                Slider(value: value, in: range, step: 0.5).tint(KTheme.Colors.accentPrimary)
            }
        }
    }

    private var backButton: some View {
        Button {
            withAnimation(KTheme.Animation.smooth) { currentStep -= 1 }
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(KTheme.Colors.textSecondary)
                .frame(width: 50, height: 50)
                .background(KTheme.Colors.card.cornerRadius(KTheme.Radius.md))
        }
    }

    private func nextButton(title: String, enabled: Bool) -> some View {
        KButton(title: title, style: .primary) {
            withAnimation(KTheme.Animation.smooth) { currentStep += 1 }
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }

    private func completeOnboarding() {
        let profile = UserProfile(name: name, age: age, gender: gender,
                                   heightCm: heightCm, currentWeightKg: currentWeight,
                                   goalWeightKg: goalWeight, activityLevel: activityLevel,
                                   goal: goal, weeklyGoalKg: weeklyGoalKg)
        appState.completeOnboarding(profile: profile)
    }

    private func goalIcon(_ g: UserProfile.Goal) -> String {
        switch g {
        case .loseFat: return "🔥"
        case .buildMuscle: return "💪"
        case .maintainWeight: return "⚖️"
        case .improveHealth: return "❤️"
        case .increaseEndurance: return "🏃"
        }
    }

    private func goalDescription(_ g: UserProfile.Goal) -> String {
        switch g {
        case .loseFat: return "Reduce body fat with a calorie deficit"
        case .buildMuscle: return "Gain muscle with a calorie surplus + training"
        case .maintainWeight: return "Stay at current weight, optimize composition"
        case .improveHealth: return "Focus on overall wellness and longevity"
        case .increaseEndurance: return "Build cardiovascular fitness and stamina"
        }
    }

    private func activityIcon(_ level: UserProfile.ActivityLevel) -> String {
        switch level {
        case .sedentary: return "🪑"
        case .lightlyActive: return "🚶"
        case .moderatelyActive: return "🏃"
        case .veryActive: return "⚡"
        case .extraActive: return "🔥"
        }
    }

    private func activityDescription(_ level: UserProfile.ActivityLevel) -> String {
        switch level {
        case .sedentary: return "Desk job, little to no exercise"
        case .lightlyActive: return "Light exercise 1-3x per week"
        case .moderatelyActive: return "Moderate exercise 3-5x per week"
        case .veryActive: return "Hard exercise 6-7x per week"
        case .extraActive: return "Very hard training, physical job"
        }
    }
}

// MARK: — Supporting Views
struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: KTheme.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 16))
                .frame(width: 28)
            Text(text)
                .font(KTheme.Typography.bodyMedium)
                .foregroundColor(KTheme.Colors.textPrimary)
        }
    }
}

struct MacroPreview: View {
    let label: String
    let grams: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(grams)g").font(KTheme.Typography.headingSmall).foregroundColor(color)
            Text(label).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
