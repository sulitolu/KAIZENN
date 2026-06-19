import SwiftUI

// MARK: — AI Coach Screen
// This is the intelligence hub of KAIZENN. It analyzes all user data
// and provides personalized, science-backed recommendations.

struct CoachView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var nutritionStore: NutritionStore
    @EnvironmentObject var weightStore: WeightStore
    @EnvironmentObject var scheduleStore: ScheduleStore
    @EnvironmentObject var activityStore: ActivityStore
    @EnvironmentObject var loadStore: LoadStore

    @StateObject private var coach = KAICoach()
    @State private var chatMessages: [ChatMessage] = []
    @State private var userInput = ""
    @State private var isThinking = false
    @State private var activeAction: CoachActionType?

    var body: some View {
        ZStack {
            KTheme.Colors.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: KTheme.Spacing.lg) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Kai Coach")
                                .font(KTheme.Typography.displaySmall)
                                .foregroundColor(KTheme.Colors.textPrimary)
                            sportContextSubtitle
                                .font(KTheme.Typography.bodySmall)
                                .foregroundColor(KTheme.Colors.textSecondary)
                        }
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(KTheme.Colors.brandGradient)
                                .frame(width: 50, height: 50)
                                .kGlow(color: KTheme.Colors.accentPrimary, radius: 16)
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                        }
                    }

                    // Daily Insight Card
                    dailyInsightCard

                    // Today's Recommendations
                    recommendationsSection

                    // Weekly Report
                    weeklyReportCard

                    // Chat with Coach
                    coachChatSection

                    // Science-backed tips
                    scienceTipsSection

                    Color.clear.frame(height: 100)
                }
                .padding(.horizontal, KTheme.Spacing.md)
                .padding(.top, KTheme.Spacing.md)
            }
        }
        .onAppear {
            coach.analyze(
                profile: appState.userProfile,
                nutrition: nutritionStore,
                weight: weightStore,
                activity: activityStore,
                health: healthKitManager,
                schedule: scheduleStore
            )
            loadChatHistory()
        }
        .sheet(item: $activeAction) { action in
            switch action {
            case .logMeal:     AddFoodView(mealType: .current)
            case .logWalk:     LogWorkoutView(initialType: .walking)
            case .logWorkout:  LogWorkoutView(initialType: .weightTraining)
            case .addSleepTask: AddTaskView(initialTitle: "Wind down for bed", initialCategory: .recovery)
            }
        }
    }

    // MARK: Daily Insight
    private var dailyInsightCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KTheme.Radius.xl)
                .fill(KTheme.Colors.brandGradient)
                .shadow(color: KTheme.Colors.accentPrimary.opacity(0.3), radius: 20)

            VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                HStack {
                    Label("Today's Insight", systemImage: "sparkles")
                        .font(KTheme.Typography.label)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Text(Date(), style: .date)
                        .font(KTheme.Typography.caption)
                        .foregroundColor(.white.opacity(0.6))
                }

                Text(coach.dailyInsight)
                    .font(KTheme.Typography.headingMedium)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if let action = coach.primaryAction {
                    Button {
                        activeAction = coach.primaryActionType
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text(action)
                                .font(KTheme.Typography.label)
                        }
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, KTheme.Spacing.md)
                        .padding(.vertical, KTheme.Spacing.sm)
                        .background(Color.white.opacity(0.15).cornerRadius(KTheme.Radius.pill))
                    }
                    .disabled(coach.primaryActionType == nil)
                }
            }
            .padding(KTheme.Spacing.lg)
        }
    }

    // MARK: Recommendations
    private var recommendationsSection: some View {
        KSection(title: "Recommendations") {
            VStack(spacing: KTheme.Spacing.sm) {
                ForEach(coach.recommendations) { rec in
                    RecommendationCard(recommendation: rec) {
                        activeAction = rec.actionType
                    }
                }
            }
        }
    }

    // MARK: Weekly Report
    private var weeklyReportCard: some View {
        KCard(elevated: true) {
            VStack(alignment: .leading, spacing: KTheme.Spacing.md) {
                HStack {
                    Text("Weekly Report").font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                    Spacer()
                    KBadge(text: coach.weeklyScore > 75 ? "On Track 🎯" : "Keep Going 💪", color: coach.weeklyScore > 75 ? KTheme.Colors.success : KTheme.Colors.accentAmber)
                }

                // Score ring
                HStack(spacing: KTheme.Spacing.xl) {
                    ZStack {
                        KProgressRing(progress: Double(coach.weeklyScore), total: 100, size: 90, lineWidth: 8, color: scoreColor(coach.weeklyScore))
                        VStack(spacing: 0) {
                            Text("\(coach.weeklyScore)").font(KTheme.Typography.headingLarge).foregroundColor(KTheme.Colors.textPrimary)
                            Text("/ 100").font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                        ForEach(coach.scoreBreakdown) { item in
                            HStack {
                                Circle().fill(item.color).frame(width: 8, height: 8)
                                Text(item.label).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textSecondary)
                                Spacer()
                                Text("\(item.score)/\(item.maxScore)").font(KTheme.Typography.label).foregroundColor(KTheme.Colors.textPrimary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Chat Section
    private var coachChatSection: some View {
        KSection(title: "Ask Your Coach") {
            VStack(spacing: KTheme.Spacing.sm) {
                // Quick prompts
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: KTheme.Spacing.sm) {
                        ForEach(KAICoach.quickPrompts, id: \.self) { prompt in
                            Button {
                                askCoach(prompt)
                            } label: {
                                Text(prompt)
                                    .font(KTheme.Typography.label)
                                    .foregroundColor(KTheme.Colors.accentPrimary)
                                    .padding(.horizontal, KTheme.Spacing.md)
                                    .padding(.vertical, KTheme.Spacing.sm)
                                    .background(KTheme.Colors.accentPrimary.opacity(0.1))
                                    .cornerRadius(KTheme.Radius.pill)
                                    .overlay(RoundedRectangle(cornerRadius: KTheme.Radius.pill).stroke(KTheme.Colors.accentPrimary.opacity(0.3), lineWidth: 1))
                            }
                        }
                    }
                }

                // Chat messages
                if !chatMessages.isEmpty || isThinking {
                    VStack(spacing: KTheme.Spacing.sm) {
                        ForEach(chatMessages) { msg in
                            ChatBubble(message: msg)
                        }
                        if isThinking {
                            CoachTypingBubble()
                        }
                    }
                }

                // Input
                HStack(spacing: KTheme.Spacing.sm) {
                    TextField("Ask anything about your health...", text: $userInput)
                        .foregroundColor(KTheme.Colors.textPrimary)
                        .font(KTheme.Typography.bodyMedium)
                        .padding(KTheme.Spacing.md)
                        .background(KTheme.Colors.card.cornerRadius(KTheme.Radius.md))
                    Button {
                        let q = userInput
                        userInput = ""
                        askCoach(q)
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(userInput.isEmpty ? KTheme.Colors.textTertiary : KTheme.Colors.accentPrimary)
                    }
                    .disabled(userInput.isEmpty || isThinking)
                }
            }
        }
    }

    // MARK: Science Tips
    private var scienceTipsSection: some View {
        KSection(title: "Science-Backed Tips") {
            VStack(spacing: KTheme.Spacing.sm) {
                ForEach(ScienceTip.all) { tip in
                    ScienceTipCard(tip: tip)
                }
            }
        }
    }

    private func askCoach(_ question: String) {
        guard !question.isEmpty else { return }
        chatMessages.append(ChatMessage(text: question, isUser: true))
        saveChatHistory()
        isThinking = true

        Task {
            do {
                let reply = try await ClaudeService.chat(
                    messages: chatMessages,
                    systemPrompt: buildSystemPrompt()
                )
                await MainActor.run {
                    chatMessages.append(ChatMessage(text: reply, isUser: false))
                    saveChatHistory()
                    isThinking = false
                }
            } catch {
                await MainActor.run {
                    chatMessages.append(ChatMessage(
                        text: "I couldn't connect right now. Check your internet and try again.",
                        isUser: false
                    ))
                    saveChatHistory()
                    isThinking = false
                }
            }
        }
    }

    private var sportContextSubtitle: Text {
        let sp = appState.userProfile.sportProfile
        let sport = sp.sport.displayName
        let phase = sp.seasonPhase.displayName
        let position = sp.position
        if position.isEmpty {
            return Text("\(sport) · \(phase)")
        } else {
            return Text("\(sport) · \(position) · \(phase)")
        }
    }

    private func buildSystemPrompt() -> String {
        let profile = appState.userProfile
        let sp = profile.sportProfile
        let todayNutrition = nutritionStore.dailyNutrition(for: Date())
        let caloriesLeft = profile.macroTargets.calories - Int(todayNutrition.totalCalories)
        let stepsToday = healthKitManager.todaySteps
        let workoutsThisWeek = activityStore.totalWorkoutsThisWeek
        let sleepHours = healthKitManager.sleepHoursLast
        let acwr = String(format: "%.2f", loadStore.acwr)
        let athleteName = profile.name.isEmpty ? "Athlete" : profile.name
        let position = sp.position.isEmpty ? "athlete" : sp.position

        return """
        You are Kai Coach, a world-class performance AI for athletes. \
        You are sport-intelligent, direct, and science-backed. \
        Always reference the athlete's actual numbers and frame everything around performance, not aesthetics.

        Athlete Context:
        - Name: \(athleteName)
        - Sport: \(sp.sport.displayName)
        - Position: \(position)
        - Season Phase: \(sp.seasonPhase.displayName)
        - Days Until Next Performance: \(sp.daysUntilPerformance)
        - Protein Target: \(String(format: "%.1f", sp.sport.proteinPerKg))g per kg body weight

        Today's Training Load:
        - ACWR (Acute:Chronic Workload Ratio): \(acwr) (sweet spot 0.8-1.3)
        - Sleep last night: \(String(format: "%.1f", sleepHours)) hours
        - Steps today: \(stepsToday)
        - Workouts this week: \(workoutsThisWeek)

        Today's Nutrition:
        - Calories remaining: \(caloriesLeft) kcal (target: \(profile.macroTargets.calories) kcal)
        - Protein consumed: \(Int(todayNutrition.totalProteinG))g of \(profile.macroTargets.proteinG)g target

        Coaching Style:
        - Use \(sp.sport.displayName)-specific language and context
        - Be direct, specific, and sport-intelligent
        - Reference the athlete's actual numbers in every reply
        - Keep replies under 200 words
        - When asked what to do, give numbered action items (1, 2, 3)
        - Frame everything around performance, not aesthetics
        """
    }

    private static let chatHistoryURL: URL? =
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("kai_chat_history.json")

    private func loadChatHistory() {
        guard let url = CoachView.chatHistoryURL,
              let data = try? Data(contentsOf: url),
              let messages = try? JSONDecoder().decode([ChatMessage].self, from: data)
        else { return }
        chatMessages = messages
    }

    private func saveChatHistory() {
        guard let url = CoachView.chatHistoryURL,
              let data = try? JSONEncoder().encode(Array(chatMessages.suffix(50)))
        else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: return KTheme.Colors.success
        case 60..<80: return KTheme.Colors.accentAmber
        default: return KTheme.Colors.danger
        }
    }
}

// MARK: — AI Coach Engine
@MainActor
class KAICoach: ObservableObject {
    @Published var dailyInsight: String = "Loading your personalized insight..."
    @Published var primaryAction: String? = nil
    @Published var primaryActionType: CoachActionType? = nil
    @Published var recommendations: [Recommendation] = []
    @Published var weeklyScore: Int = 0
    @Published var scoreBreakdown: [ScoreItem] = []

    struct Recommendation: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let icon: String
        let color: Color
        let priority: Priority
        var actionLabel: String? = nil
        var actionType: CoachActionType? = nil
        enum Priority { case high, medium, low }
    }

    struct ScoreItem: Identifiable {
        let id = UUID()
        let label: String
        let score: Int
        let maxScore: Int
        let color: Color
    }

    static let quickPrompts = [
        "What should I eat today?",
        "How can I break my plateau?",
        "Recommend a workout",
        "Help me sleep better",
        "How many calories do I burn?",
        "Best time to work out?",
    ]

    func analyze(profile: UserProfile, nutrition: NutritionStore, weight: WeightStore,
                 activity: ActivityStore, health: HealthKitManager, schedule: ScheduleStore) {
        // Daily insight based on data
        let todayNutrition = nutrition.dailyNutrition(for: Date())
        let caloriesLeft = profile.macroTargets.calories - Int(todayNutrition.totalCalories)
        let stepsToday = health.todaySteps
        let weightChange = weight.weightChange(lastDays: 7)
        let habitProgress = schedule.todayHabitProgress
        let sleepHours = health.sleepHoursLast

        // Generate insight
        if sleepHours < 6 {
            dailyInsight = "You're running on \(String(format: "%.1f", sleepHours)) hours of sleep. Prioritize rest tonight — sleep is when your body rebuilds muscle and resets hunger hormones."
            primaryAction = "Schedule 8 hours tonight"
            primaryActionType = .addSleepTask
        } else if stepsToday < 3000 {
            dailyInsight = "Only \(stepsToday) steps so far. A 20-minute walk after your next meal will kickstart your metabolism and help with digestion."
            primaryAction = "Take a 20-min walk"
            primaryActionType = .logWalk
        } else if caloriesLeft < 0 {
            dailyInsight = "You've exceeded your calorie target by \(abs(caloriesLeft)) calories. Make your next meal protein-heavy and veggie-forward to balance out."
            primaryAction = "Log a high-protein meal"
            primaryActionType = .logMeal
        } else if habitProgress > 0.8 {
            dailyInsight = "You're crushing it — \(Int(habitProgress * 100))% of habits done today! Consistency is the secret weapon of every athlete. Keep going."
            primaryAction = nil
            primaryActionType = nil
        } else {
            dailyInsight = "You have \(caloriesLeft) calories remaining and \(10000 - stepsToday) steps to your daily goal. You're on the right track, \(profile.name.isEmpty ? "champion" : profile.name)."
            primaryAction = "Log your next meal"
            primaryActionType = .logMeal
        }

        // Recommendations
        var recs: [Recommendation] = []

        if health.sleepHoursLast < 7 {
            recs.append(Recommendation(title: "Optimize Sleep", description: "Sleep 7-9 hours to maximize fat loss, muscle recovery, and hormone balance. Set a consistent bedtime.", icon: "moon.stars.fill", color: KTheme.Colors.accentPrimary, priority: .high, actionLabel: "Schedule wind-down", actionType: .addSleepTask))
        }
        if stepsToday < 7500 {
            recs.append(Recommendation(title: "Hit 10K Steps", description: "Daily walking is the most underrated fat-loss tool. It's low-stress and burns significant calories without spiking cortisol.", icon: "figure.walk", color: KTheme.Colors.accentTertiary, priority: .high, actionLabel: "Log a walk", actionType: .logWalk))
        }
        if todayNutrition.totalProteinG < Double(profile.macroTargets.proteinG) * 0.7 {
            recs.append(Recommendation(title: "Increase Protein Intake", description: "You're under your protein target. Protein keeps you full, preserves muscle during weight loss, and has the highest thermic effect.", icon: "fork.knife", color: KTheme.Colors.accentSecondary, priority: .high, actionLabel: "Log a meal", actionType: .logMeal))
        }
        if activity.totalWorkoutsThisWeek < 3 {
            recs.append(Recommendation(title: "Strength Train 3x/Week", description: "Building muscle increases your resting metabolic rate, meaning you burn more calories doing nothing. Even 30 minutes counts.", icon: "dumbbell.fill", color: KTheme.Colors.accentAmber, priority: .medium, actionLabel: "Log a workout", actionType: .logWorkout))
        }
        if let change = weightChange, change > 1.5 {
            recs.append(Recommendation(title: "Moderate Deficit", description: "You're losing weight fast — which can cause muscle loss. Aim for 0.5-1kg/week. Eat more protein and add resistance training.", icon: "scalemass.fill", color: KTheme.Colors.warning, priority: .high, actionLabel: "Log a workout", actionType: .logWorkout))
        }

        // Default tips if under 3
        if recs.count < 3 {
            recs.append(Recommendation(title: "Drink More Water", description: "Dehydration mimics hunger. Drink 2.5-3L per day, especially before meals. It can reduce calorie intake by 75-90 cal per meal.", icon: "drop.fill", color: KTheme.Colors.accentPrimary, priority: .low))
            recs.append(Recommendation(title: "Time Your Meals", description: "Eating within a 10-hour window (time-restricted eating) can improve metabolic health without counting calories.", icon: "clock.fill", color: KTheme.Colors.accentTertiary, priority: .low))
        }

        recommendations = recs

        // Score calculation
        var nutritionScore = 0
        if todayNutrition.totalCalories > 0 { nutritionScore += 15 }
        if todayNutrition.totalProteinG >= Double(profile.macroTargets.proteinG) * 0.8 { nutritionScore += 10 }
        if nutrition.waterConsumedMl(for: Date()) >= 2000 { nutritionScore += 5 }

        let activityScore = min(30, (stepsToday / 333) + (health.todayExerciseMinutes > 30 ? 10 : 0))
        let habitScoreVal = Int(habitProgress * 20)
        let sleepScore = sleepHours >= 7 ? 20 : sleepHours >= 6 ? 10 : 0

        weeklyScore = min(100, nutritionScore + activityScore + habitScoreVal + sleepScore)

        scoreBreakdown = [
            ScoreItem(label: "Nutrition", score: nutritionScore, maxScore: 30, color: KTheme.Colors.accentSecondary),
            ScoreItem(label: "Activity", score: activityScore, maxScore: 30, color: KTheme.Colors.accentTertiary),
            ScoreItem(label: "Habits", score: habitScoreVal, maxScore: 20, color: KTheme.Colors.accentAmber),
            ScoreItem(label: "Sleep", score: sleepScore, maxScore: 20, color: KTheme.Colors.accentPrimary),
        ]
    }

    func answer(question: String, profile: UserProfile, nutrition: NutritionStore,
                weight: WeightStore, activity: ActivityStore, health: HealthKitManager) -> String {
        let q = question.lowercased()
        let name = profile.name.isEmpty ? "you" : profile.name

        if q.contains("eat") || q.contains("food") || q.contains("meal") {
            let remaining = profile.macroTargets.calories - Int(nutrition.dailyNutrition(for: Date()).totalCalories)
            return "Based on your data, \(name) have \(max(0, remaining)) calories left today. Prioritize lean protein (chicken, fish, eggs), complex carbs (oats, sweet potato), and healthy fats (avocado, nuts). Aim to hit \(profile.macroTargets.proteinG)g protein."
        }
        if q.contains("workout") || q.contains("exercise") || q.contains("train") {
            let workoutsThisWeek = activity.totalWorkoutsThisWeek
            if workoutsThisWeek < 3 {
                return "You've done \(workoutsThisWeek) workouts this week. I recommend: a 30-min strength session today (compound lifts: squats, deadlifts, push/pull), then a 20-min HIIT or steady-state cardio tomorrow. Rest = growth."
            } else {
                return "Great job with \(workoutsThisWeek) workouts this week! Consider a lighter recovery session: 30 min yoga, mobility work, or a zone-2 walk. Recovery is when adaptation happens."
            }
        }
        if q.contains("sleep") || q.contains("rest") || q.contains("tired") {
            return "For better sleep: dim lights 2 hours before bed, keep room at 65-68°F (18-20°C), no caffeine after 2pm, and try 4-7-8 breathing to fall asleep faster. Sleep deprivation spikes ghrelin (hunger hormone) by 24%."
        }
        if q.contains("plateau") || q.contains("stuck") || q.contains("not losing") {
            return "Plateaus are normal — your body adapts. Break it by: 1) Adding a refeed day (eat at maintenance) to reset leptin, 2) Shifting to strength training to build metabolic muscle, 3) Cutting carbs for 1 week then cycling them back, 4) Getting a DEXA scan to check body composition."
        }
        if q.contains("calori") || q.contains("burn") {
            return "Your estimated TDEE is \(profile.macroTargets.calories + 500) calories. With your current activity, you're burning roughly \(Int(health.todayActiveCalories + health.todayRestingCalories)) calories today. Your deficit target is ~\(500) cal/day for \(String(format: "%.1f", profile.weeklyGoalKg))kg/week loss."
        }
        if q.contains("motivation") || q.contains("give up") || q.contains("hard") {
            return "Remember why you started. Every workout you didn't want to do but did — that's where real progress lives. Kaizen: 1% better every day. You don't have to be perfect, you just have to keep showing up."
        }
        return "Based on your profile and goals, focus on consistency over perfection. Hit your protein target, stay in a moderate calorie deficit, move daily, and prioritize sleep. These four things, done consistently, will change your body. What specific area can I help you dive deeper into?"
    }
}

// MARK: — Science Tips
struct ScienceTip: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let source: String
    let icon: String

    static let all: [ScienceTip] = [
        ScienceTip(title: "Protein Timing", body: "Distributing protein across 4-5 meals maximizes muscle protein synthesis better than eating it all at once.", source: "Journal of Nutrition, 2014", icon: "timer"),
        ScienceTip(title: "Zone 2 Cardio", body: "Low-intensity cardio (60-70% max HR) trains your fat-burning mitochondria without spiking cortisol that blunts fat loss.", source: "Peter Attia / Andrew Huberman", icon: "heart.circle"),
        ScienceTip(title: "Morning Sunlight", body: "10 min of sunlight within 30 min of waking sets your circadian rhythm, improves sleep, and boosts morning cortisol (the good kind).", source: "Huberman Lab, 2022", icon: "sun.max.fill"),
        ScienceTip(title: "Cold Exposure", body: "Cold showers increase norepinephrine by 300% and brown fat activation, boosting metabolism and mood.", source: "NEJM, 2021", icon: "snowflake"),
        ScienceTip(title: "Muscle = Metabolism", body: "Each kg of muscle burns ~13 calories/day at rest. Gaining 5kg of muscle = 65 extra calories burned daily without moving.", source: "European Journal of Clinical Nutrition", icon: "dumbbell.fill"),
    ]
}

// MARK: — Supporting Views
struct RecommendationCard: View {
    let recommendation: KAICoach.Recommendation
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if recommendation.actionType != nil {
                Button {
                    onTap?()
                } label: {
                    content
                }
                .buttonStyle(KScaleButtonStyle())
            } else {
                content
            }
        }
        .padding(KTheme.Spacing.md)
        .background(KTheme.Colors.card.cornerRadius(KTheme.Radius.md))
    }

    private var content: some View {
        HStack(alignment: .top, spacing: KTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: KTheme.Radius.sm)
                    .fill(recommendation.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: recommendation.icon)
                    .foregroundColor(recommendation.color)
                    .font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recommendation.title).font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                    if recommendation.priority == .high {
                        KBadge(text: "Priority", color: KTheme.Colors.accentSecondary)
                    }
                }
                Text(recommendation.description).font(KTheme.Typography.bodySmall).foregroundColor(KTheme.Colors.textSecondary).fixedSize(horizontal: false, vertical: true)
                if let actionLabel = recommendation.actionLabel {
                    HStack(spacing: 4) {
                        Text(actionLabel).font(KTheme.Typography.caption.bold())
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(recommendation.color)
                    .padding(.top, 2)
                }
            }
            if recommendation.actionType != nil {
                Spacer()
            }
        }
    }
}

struct ScienceTipCard: View {
    let tip: ScienceTip

    var body: some View {
        HStack(alignment: .top, spacing: KTheme.Spacing.md) {
            Image(systemName: tip.icon)
                .font(.system(size: 20))
                .foregroundColor(KTheme.Colors.accentPrimary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title).font(KTheme.Typography.headingSmall).foregroundColor(KTheme.Colors.textPrimary)
                Text(tip.body).font(KTheme.Typography.bodySmall).foregroundColor(KTheme.Colors.textSecondary).fixedSize(horizontal: false, vertical: true)
                Text(tip.source).font(KTheme.Typography.caption).foregroundColor(KTheme.Colors.textTertiary).italic()
            }
        }
        .padding(KTheme.Spacing.md)
        .background(KTheme.Colors.card.cornerRadius(KTheme.Radius.md))
    }
}

// MARK: — Coach Primary Action
enum CoachActionType: Int, Identifiable {
    case logMeal, logWalk, logWorkout, addSleepTask
    var id: Int { rawValue }
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date

    init(text: String, isUser: Bool) {
        self.id = UUID()
        self.text = text
        self.isUser = isUser
        self.timestamp = Date()
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 40) }
            if !message.isUser {
                ZStack {
                    Circle().fill(KTheme.Colors.brandGradient).frame(width: 28, height: 28)
                    Image(systemName: "brain.head.profile").font(.system(size: 12)).foregroundColor(.white)
                }
            }
            Text(message.text)
                .font(KTheme.Typography.bodyMedium)
                .foregroundColor(message.isUser ? .white : KTheme.Colors.textPrimary)
                .padding(KTheme.Spacing.md)
                .background(message.isUser ? KTheme.Colors.accentPrimary : KTheme.Colors.card)
                .cornerRadius(KTheme.Radius.lg, corners: message.isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
            if !message.isUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: — Coach Typing Indicator
struct CoachTypingBubble: View {
    @State private var bounce = false

    var body: some View {
        HStack {
            ZStack {
                Circle().fill(KTheme.Colors.brandGradient).frame(width: 28, height: 28)
                Image(systemName: "brain.head.profile").font(.system(size: 12)).foregroundColor(.white)
            }
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(KTheme.Colors.textSecondary)
                        .frame(width: 6, height: 6)
                        .offset(y: bounce ? -3 : 0)
                        .animation(
                            KTheme.Animation.smooth.repeatForever().delay(Double(i) * 0.15),
                            value: bounce
                        )
                }
            }
            .padding(KTheme.Spacing.md)
            .background(KTheme.Colors.card)
            .cornerRadius(KTheme.Radius.lg, corners: [.topLeft, .topRight, .bottomRight])
            Spacer(minLength: 40)
        }
        .onAppear { bounce = true }
    }
}
