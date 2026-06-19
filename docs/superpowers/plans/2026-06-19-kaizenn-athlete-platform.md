# KAIZENN Athlete Platform Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform KAIZENN from a general fitness tracker into a universal athlete performance platform personalised by sport, with GPS load management, ACWR, Claude Vision food/training scanning, and sport-aware AI coaching.

**Architecture:** New models (SportProfile, GPSSession, StrengthSession) stored via UserDefaults JSON Codable — same pattern as existing UserProfile. New stores (LoadStore, GPSSessionStore, StrengthSessionStore) added as @StateObject in KAIZENNApp and injected via .environmentObject(). All UI follows existing KTheme token system (KTheme.Colors, KTheme.Spacing, KTheme.Animation).

**Tech Stack:** SwiftUI iOS 17+, HealthKit, URLSession, Anthropic Claude Vision API (extend ClaudeService.swift), SwiftUI Charts, UIImagePickerController/PHPickerViewController, UserDefaults JSON

## Global Constraints

- iOS 17+ minimum deployment target
- SwiftUI only — no UIKit view controllers except for camera (UIImagePickerController wrapped in UIViewControllerRepresentable)
- UserDefaults JSON via Codable — no CoreData, no external DB
- No new Swift Package dependencies — use existing Apple frameworks only
- KTheme token system for all colours, spacing, animation (`KTheme.Colors.*`, `KTheme.Spacing.*`, `KTheme.Animation.*`)
- Dark-only UI — `.preferredColorScheme(.dark)` set globally in KAIZENNApp
- No emojis anywhere in UI — SVG/SF Symbol line icons only
- Design tokens: violet `#7C6FFF`, coral `#FF6B8A`, teal `#4ECDC4`, amber `#FFB347`, green `#5EFFB7`, background layers `#06060C` → `#080810` → `#0C0C16` → `#1A1A28`
- API key stays in Config.xcconfig (already set) — never hardcoded, never committed
- File naming: PascalCase for all Swift files, one type per file

---

### Task 1: Sport Profile Model

**Files:**
- Create: `KAIZENN/Data/Models/SportProfile.swift`
- Modify: `KAIZENN/Data/Models/UserProfile.swift`

**Interfaces:**
- Produces: `SportProfile` struct (Codable), `UserProfile.sportProfile: SportProfile`
- All downstream tasks consume `SportProfile` from `appState.userProfile.sportProfile`

- [ ] **Step 1: Create SportProfile.swift**

```swift
// KAIZENN/Data/Models/SportProfile.swift
import Foundation

struct SportProfile: Codable, Equatable {
    var sport: Sport = .other
    var position: String = ""
    var seasonPhase: SeasonPhase = .inSeason
    var performanceDayOfWeek: Int = 6  // 1=Sunday … 7=Saturday
    var wearable: Wearable = .appleWatch

    enum Sport: String, Codable, CaseIterable {
        case rugby, soccer, basketball, athletics, gym, swimming, cycling, other
        var displayName: String { rawValue.capitalized }
        var positions: [String] {
            switch self {
            case .rugby:      return ["Prop","Hooker","Lock","Flanker","No.8","Scrum-half","Fly-half","Centre","Wing","Fullback"]
            case .soccer:     return ["Goalkeeper","Defender","Midfielder","Winger","Striker"]
            case .basketball: return ["Point Guard","Shooting Guard","Small Forward","Power Forward","Centre"]
            case .athletics:  return ["Sprinter","Distance","Thrower","Jumper","Multi-event"]
            case .gym:        return ["Powerlifter","Bodybuilder","CrossFit","General Fitness"]
            case .swimming:   return ["Freestyle","Backstroke","Breaststroke","Butterfly","IM"]
            case .cycling:    return ["Road","Track","MTB","Triathlon"]
            case .other:      return ["Athlete"]
            }
        }
        var acwrTarget: ClosedRange<Double> { 0.8...1.3 }
        var proteinPerKg: Double {
            switch self {
            case .rugby, .gym: return 2.0
            case .basketball, .soccer: return 1.8
            default: return 1.6
            }
        }
    }

    enum SeasonPhase: String, Codable, CaseIterable {
        case preSeason, inSeason, offSeason
        var displayName: String {
            switch self {
            case .preSeason: return "Pre-Season"
            case .inSeason:  return "In-Season"
            case .offSeason: return "Off-Season"
            }
        }
    }

    enum Wearable: String, Codable, CaseIterable {
        case whoop, garmin, polar, appleWatch, none
        var displayName: String {
            switch self {
            case .whoop:      return "Whoop"
            case .garmin:     return "Garmin"
            case .polar:      return "Polar"
            case .appleWatch: return "Apple Watch"
            case .none:       return "None"
            }
        }
    }

    var daysUntilPerformance: Int {
        let today = Calendar.current.component(.weekday, from: Date())
        let diff = performanceDayOfWeek - today
        return diff >= 0 ? diff : diff + 7
    }
}
```

- [ ] **Step 2: Add sportProfile to UserProfile.swift**

Open `KAIZENN/Data/Models/UserProfile.swift`. Add this property inside the `struct UserProfile` body (after `var profileImageURL: String? = nil`):

```swift
var sportProfile: SportProfile = SportProfile()
```

Because `UserProfile` is already `Codable` and `SportProfile` is `Codable`, this persists automatically with the existing `save()`/`load()` methods. No other changes needed.

- [ ] **Step 3: Build — Cmd+B in Xcode**

Expected: no errors. `UserProfile.load()` returns a profile with default `SportProfile` for existing users.

- [ ] **Step 4: Commit**

```bash
git add "KAIZENN/Data/Models/SportProfile.swift" "KAIZENN/Data/Models/UserProfile.swift"
git commit -m "feat: add SportProfile model with sport/position/phase/wearable"
```

---

### Task 2: GPS Session and Strength Session Models

**Files:**
- Create: `KAIZENN/Data/Models/GPSSession.swift`
- Create: `KAIZENN/Data/Models/StrengthSession.swift`

**Interfaces:**
- Produces: `GPSSession` (Codable, Identifiable), `StrengthSession` (Codable, Identifiable), `StrengthExercise`, `ExerciseSet`
- Consumed by: Task 3 (LoadStore), Task 4 (GPSSessionStore), Task 5 (StrengthSessionStore)

- [ ] **Step 1: Create GPSSession.swift**

```swift
// KAIZENN/Data/Models/GPSSession.swift
import Foundation

struct GPSSession: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var source: Source = .manual
    var distanceMeters: Double = 0
    var playerLoad: Double = 0
    var sprintCount: Int = 0
    var highSpeedRunningPercent: Double = 0  // 0–100
    var durationSeconds: Double = 0
    var notes: String = ""

    enum Source: String, Codable {
        case catapultCSV, garminSync, manual
        var displayName: String {
            switch self {
            case .catapultCSV: return "Catapult"
            case .garminSync:  return "Garmin"
            case .manual:      return "Manual"
            }
        }
    }

    // Load unit for ACWR: arbitrary units combining distance and intensity
    var sessionLoad: Double {
        let kmLoad = (distanceMeters / 1000) * 10
        let intensityFactor = 1.0 + (highSpeedRunningPercent / 100)
        return kmLoad * intensityFactor
    }

    static let storageKey = "kaizenn_gps_sessions"
}
```

- [ ] **Step 2: Create StrengthSession.swift**

```swift
// KAIZENN/Data/Models/StrengthSession.swift
import Foundation

struct StrengthSession: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var exercises: [StrengthExercise] = []

    var totalVolumeKg: Double {
        exercises.flatMap(\.sets).reduce(0) { $0 + ($1.reps * $1.weightKg) }
    }

    // Load unit for ACWR: volume / 1000 gives comparable units to GPS
    var sessionLoad: Double { totalVolumeKg / 1000 }

    static let storageKey = "kaizenn_strength_sessions"
}

struct StrengthExercise: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var sets: [ExerciseSet] = []

    var totalVolumeKg: Double {
        sets.reduce(0) { $0 + ($1.reps * $1.weightKg) }
    }

    var estimated1RM: Double {
        guard let best = sets.max(by: { $0.weightKg < $1.weightKg }) else { return 0 }
        guard best.reps > 0 else { return best.weightKg }
        return best.weightKg * (1 + Double(best.reps) / 30)
    }

    static let presets = ["Squat","Bench Press","Deadlift","Power Clean","RDL","Pull-up","Overhead Press","Hip Thrust","Lunge"]
}

struct ExerciseSet: Codable, Identifiable {
    var id: UUID = UUID()
    var reps: Double = 0
    var weightKg: Double = 0
}
```

- [ ] **Step 3: Build — Cmd+B**

Expected: clean build.

- [ ] **Step 4: Commit**

```bash
git add "KAIZENN/Data/Models/GPSSession.swift" "KAIZENN/Data/Models/StrengthSession.swift"
git commit -m "feat: add GPSSession and StrengthSession models"
```

---

### Task 3: LoadStore (ACWR Engine)

**Files:**
- Create: `KAIZENN/Data/Stores/LoadStore.swift`

**Interfaces:**
- Consumes: `GPSSession.sessionLoad`, `StrengthSession.sessionLoad`, `SportProfile.acwrTarget`
- Produces: `@Published var acwr: Double`, `@Published var acuteLoad: Double`, `@Published var chronicLoad: Double`, `func addGPSSession(_:)`, `func addStrengthSession(_:)`, `var gpsSessions: [GPSSession]`, `var strengthSessions: [StrengthSession]`

- [ ] **Step 1: Create LoadStore.swift**

```swift
// KAIZENN/Data/Stores/LoadStore.swift
import Foundation
import Combine

class LoadStore: ObservableObject {
    @Published private(set) var gpsSessions: [GPSSession] = []
    @Published private(set) var strengthSessions: [StrengthSession] = []
    @Published private(set) var acuteLoad: Double = 0
    @Published private(set) var chronicLoad: Double = 0
    @Published private(set) var acwr: Double = 0

    init() {
        gpsSessions = (try? JSONDecoder().decode([GPSSession].self,
            from: UserDefaults.standard.data(forKey: GPSSession.storageKey) ?? Data())) ?? []
        strengthSessions = (try? JSONDecoder().decode([StrengthSession].self,
            from: UserDefaults.standard.data(forKey: StrengthSession.storageKey) ?? Data())) ?? []
        recalculate()
    }

    func addGPSSession(_ session: GPSSession) {
        gpsSessions.insert(session, at: 0)
        save()
        recalculate()
    }

    func addStrengthSession(_ session: StrengthSession) {
        strengthSessions.insert(session, at: 0)
        save()
        recalculate()
    }

    func deleteGPSSession(id: UUID) {
        gpsSessions.removeAll { $0.id == id }
        save()
        recalculate()
    }

    func deleteStrengthSession(id: UUID) {
        strengthSessions.removeAll { $0.id == id }
        save()
        recalculate()
    }

    private func allSessions() -> [(date: Date, load: Double)] {
        let gps = gpsSessions.map { (date: $0.date, load: $0.sessionLoad) }
        let str = strengthSessions.map { (date: $0.date, load: $0.sessionLoad) }
        return gps + str
    }

    private func recalculate() {
        let now = Date()
        let sessions = allSessions()

        let sevenDaysAgo  = now.addingTimeInterval(-7 * 86400)
        let twentyEightDaysAgo = now.addingTimeInterval(-28 * 86400)

        acuteLoad = sessions.filter { $0.date >= sevenDaysAgo }.reduce(0) { $0 + $1.load }
        chronicLoad = sessions.filter { $0.date >= twentyEightDaysAgo }.reduce(0) { $0 + $1.load } / 4
        acwr = chronicLoad > 0 ? acuteLoad / chronicLoad : 0
    }

    private func save() {
        if let d = try? JSONEncoder().encode(gpsSessions) {
            UserDefaults.standard.set(d, forKey: GPSSession.storageKey)
        }
        if let d = try? JSONEncoder().encode(strengthSessions) {
            UserDefaults.standard.set(d, forKey: StrengthSession.storageKey)
        }
    }
}
```

- [ ] **Step 2: Build — Cmd+B**

Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add "KAIZENN/Data/Stores/LoadStore.swift"
git commit -m "feat: add LoadStore with ACWR calculation (acute/chronic rolling load)"
```

---

### Task 4: App Wiring — LoadStore + New Tab

**Files:**
- Modify: `KAIZENN/App/KAIZENNApp.swift`
- Modify: `KAIZENN/App/AppState.swift`

**Interfaces:**
- Produces: `loadStore` available via `.environmentObject` on all views
- `AppState.Tab` gets `.hub` case replacing `.weight` or added as 6th tab

- [ ] **Step 1: Add LoadStore @StateObject to KAIZENNApp.swift**

In `KAIZENN/App/KAIZENNApp.swift`, add after `@StateObject private var activityStore = ActivityStore()`:

```swift
@StateObject private var loadStore = LoadStore()
```

Then add `.environmentObject(loadStore)` after `.environmentObject(activityStore)`:

```swift
.environmentObject(loadStore)
```

- [ ] **Step 2: Add hub tab to AppState.swift**

Replace the `Tab` enum in `KAIZENN/App/AppState.swift` with:

```swift
enum Tab: Int, CaseIterable {
    case dashboard, nutrition, hub, coach, schedule, weight

    var title: String {
        switch self {
        case .dashboard: return "Home"
        case .nutrition: return "Fuel"
        case .hub:       return "Hub"
        case .coach:     return "Kai"
        case .schedule:  return "Schedule"
        case .weight:    return "Weight"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "bolt.circle.fill"
        case .nutrition: return "fork.knife"
        case .hub:       return "antenna.radiowaves.left.and.right"
        case .coach:     return "brain.head.profile"
        case .schedule:  return "calendar"
        case .weight:    return "scalemass.fill"
        }
    }
}
```

- [ ] **Step 3: Build — Cmd+B**

Expected: clean. The app will show the updated tab bar.

- [ ] **Step 4: Commit**

```bash
git add "KAIZENN/App/KAIZENNApp.swift" "KAIZENN/App/AppState.swift"
git commit -m "feat: wire LoadStore into app, add Wearable Hub tab"
```

---

### Task 5: Onboarding — Sport Profile Steps

**Files:**
- Create: `KAIZENN/Features/Onboarding/SportProfileSetupView.swift`
- Modify: `KAIZENN/Features/Onboarding/OnboardingFlowView.swift`

**Interfaces:**
- Consumes: `SportProfile` (Task 1)
- Produces: Completed `sportProfile` merged into `UserProfile` before `appState.completeOnboarding(profile:)`

- [ ] **Step 1: Create SportProfileSetupView.swift**

```swift
// KAIZENN/Features/Onboarding/SportProfileSetupView.swift
import SwiftUI

struct SportProfileSetupView: View {
    @Binding var sportProfile: SportProfile
    let onNext: () -> Void

    @State private var step = 0  // 0=sport, 1=position, 2=phase, 3=day, 4=wearable

    var body: some View {
        VStack(spacing: KTheme.Spacing.xl) {
            Text(stepTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, KTheme.Spacing.lg)

            switch step {
            case 0: sportGrid
            case 1: positionPicker
            case 2: phasePicker
            case 3: dayPicker
            default: wearablePicker
            }

            Spacer()

            Button(step < 4 ? "Continue" : "Done") {
                if step < 4 { step += 1 } else { onNext() }
            }
            .buttonStyle(KPrimaryButtonStyle())
            .padding(.horizontal, KTheme.Spacing.lg)
        }
        .padding(.top, KTheme.Spacing.xl)
    }

    private var stepTitle: String {
        ["Your Sport","Your Position","Season Phase","Performance Day","Your Wearable"][step]
    }

    private var sportGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(SportProfile.Sport.allCases, id: \.self) { sport in
                Button(action: { sportProfile.sport = sport }) {
                    Text(sport.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(sportProfile.sport == sport ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(sportProfile.sport == sport ? Color(hex: "#7C6FFF") : Color(hex: "#1A1A28"))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#7C6FFF").opacity(0.4), lineWidth: 0.5))
                }
            }
        }
        .padding(.horizontal, KTheme.Spacing.lg)
    }

    private var positionPicker: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(sportProfile.sport.positions, id: \.self) { pos in
                    Button(action: { sportProfile.position = pos }) {
                        HStack {
                            Text(pos).foregroundColor(.white)
                            Spacer()
                            if sportProfile.position == pos {
                                Image(systemName: "checkmark").foregroundColor(Color(hex: "#7C6FFF"))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(sportProfile.position == pos ? Color(hex: "#1A1A28") : Color(hex: "#0C0C16"))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#7C6FFF").opacity(sportProfile.position == pos ? 0.8 : 0.2), lineWidth: 0.5))
                    }
                }
            }
            .padding(.horizontal, KTheme.Spacing.lg)
        }
    }

    private var phasePicker: some View {
        VStack(spacing: 12) {
            ForEach(SportProfile.SeasonPhase.allCases, id: \.self) { phase in
                Button(action: { sportProfile.seasonPhase = phase }) {
                    HStack {
                        Text(phase.displayName).foregroundColor(.white).font(.system(size: 17, weight: .medium))
                        Spacer()
                        if sportProfile.seasonPhase == phase {
                            Image(systemName: "checkmark").foregroundColor(Color(hex: "#7C6FFF"))
                        }
                    }
                    .padding(16)
                    .background(sportProfile.seasonPhase == phase ? Color(hex: "#1A1A28") : Color(hex: "#0C0C16"))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#7C6FFF").opacity(sportProfile.seasonPhase == phase ? 0.8 : 0.2), lineWidth: 0.5))
                }
            }
        }
        .padding(.horizontal, KTheme.Spacing.lg)
    }

    private var dayPicker: some View {
        let days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        return VStack(spacing: 12) {
            Text("What day is your match or race?")
                .foregroundColor(Color(.systemGray))
                .padding(.horizontal, KTheme.Spacing.lg)

            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.0) { idx, day in
                    Button(action: { sportProfile.performanceDayOfWeek = idx + 1 }) {
                        Text(day)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(sportProfile.performanceDayOfWeek == idx + 1 ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(sportProfile.performanceDayOfWeek == idx + 1 ? Color(hex: "#7C6FFF") : Color(hex: "#1A1A28"))
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal, KTheme.Spacing.lg)
        }
    }

    private var wearablePicker: some View {
        VStack(spacing: 12) {
            ForEach(SportProfile.Wearable.allCases, id: \.self) { w in
                Button(action: { sportProfile.wearable = w }) {
                    HStack {
                        Text(w.displayName).foregroundColor(.white).font(.system(size: 17, weight: .medium))
                        Spacer()
                        if sportProfile.wearable == w {
                            Image(systemName: "checkmark").foregroundColor(Color(hex: "#7C6FFF"))
                        }
                    }
                    .padding(16)
                    .background(sportProfile.wearable == w ? Color(hex: "#1A1A28") : Color(hex: "#0C0C16"))
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#7C6FFF").opacity(sportProfile.wearable == w ? 0.8 : 0.2), lineWidth: 0.5))
                }
            }
        }
        .padding(.horizontal, KTheme.Spacing.lg)
    }
}

struct KPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(LinearGradient(colors: [Color(hex: "#7C6FFF"), Color(hex: "#9B91FF")],
                                       startPoint: .leading, endPoint: .trailing))
            .cornerRadius(14)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
```

- [ ] **Step 2: Add Sport Profile step to OnboardingFlowView.swift**

In `KAIZENN/Features/Onboarding/OnboardingFlowView.swift`:

Add state property after existing `@State` properties (before `private let totalSteps`):
```swift
@State private var sportProfile = SportProfile()
```

Change `private let totalSteps = 5` to:
```swift
private let totalSteps = 6
```

In the `TabView` body, add after `activityStep.tag(4)`:
```swift
SportProfileSetupView(sportProfile: $sportProfile) { currentStep += 1 }.tag(5)
```

In `completeOnboarding()` (or wherever `appState.completeOnboarding(profile:)` is called — search for that call in `OnboardingFlowView.swift`), build the profile with sport:

Replace the existing complete call with:
```swift
var profile = UserProfile()
profile.name = name
profile.age = age
profile.gender = gender
profile.heightCm = heightCm
profile.currentWeightKg = currentWeight
profile.goalWeightKg = goalWeight
profile.activityLevel = activityLevel
profile.goal = goal
profile.weeklyGoalKg = weeklyGoalKg
profile.sportProfile = sportProfile
appState.completeOnboarding(profile: profile)
```

- [ ] **Step 3: Build — Cmd+B, run in Simulator**

Reset simulator data (Device → Erase All Content), run app, step through onboarding. Sport profile step must appear as step 6. Selecting a sport should update positions in step 2.

- [ ] **Step 4: Commit**

```bash
git add "KAIZENN/Features/Onboarding/SportProfileSetupView.swift" "KAIZENN/Features/Onboarding/OnboardingFlowView.swift"
git commit -m "feat: add sport profile onboarding steps (sport/position/phase/day/wearable)"
```

---

### Task 6: Dashboard — Readiness Hero

**Files:**
- Modify: `KAIZENN/Features/Dashboard/DashboardView.swift` (full rewrite)

**Interfaces:**
- Consumes: `@EnvironmentObject var appState: AppState`, `@EnvironmentObject var healthKitManager: HealthKitManager`, `@EnvironmentObject var nutritionStore: NutritionStore`, `@EnvironmentObject var loadStore: LoadStore`
- Produces: Visual readiness score 0–100 with four pillars, stat row, action prompts

- [ ] **Step 1: Rewrite DashboardView.swift**

Replace the entire file with:

```swift
// KAIZENN/Features/Dashboard/DashboardView.swift
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var nutritionStore: NutritionStore
    @EnvironmentObject var loadStore: LoadStore

    private var sport: SportProfile { appState.userProfile.sportProfile }

    private var sleepScore: Double {
        let hours = healthKitManager.lastNightSleepHours
        return min(hours / 8.0, 1.0) * 100
    }

    private var loadScore: Double {
        let acwr = loadStore.acwr
        if acwr == 0 { return 75 }
        let ideal: ClosedRange<Double> = 0.8...1.3
        if ideal.contains(acwr) { return 100 }
        let delta = acwr < 0.8 ? 0.8 - acwr : acwr - 1.3
        return max(0, 100 - (delta * 100))
    }

    private var fuelScore: Double {
        let target = nutritionStore.dailyCalorieTarget
        guard target > 0 else { return 50 }
        let ratio = Double(nutritionStore.todayCalories) / target
        return min(ratio, 1.0) * 100
    }

    private var readinessScore: Int {
        Int((sleepScore * 0.33 + loadScore * 0.33 + fuelScore * 0.34))
    }

    private var readinessLabel: String {
        switch readinessScore {
        case 80...100: return "PEAK CONDITION"
        case 60..<80:  return "GAME READY"
        case 40..<60:  return "BUILD DAY"
        default:       return "RECOVERY DAY"
        }
    }

    private var readinessColor: Color {
        switch readinessScore {
        case 80...100: return Color(hex: "#5EFFB7")
        case 60..<80:  return Color(hex: "#7C6FFF")
        case 40..<60:  return Color(hex: "#FFB347")
        default:       return Color(hex: "#FF6B8A")
        }
    }

    private var edgePrompt: String {
        if sleepScore < 60 { return "Your edge: target 8hrs sleep tonight." }
        if fuelScore < 60  { return "Your edge: hit protein target before training." }
        if loadScore < 60  { return "Your edge: ease load — ACWR above sweet spot." }
        return "You are primed. Attack today's session."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                scoreHero
                statRow
                edgeCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(hex: "#080810").ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(sport.seasonPhase.displayName.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#7C6FFF"))
                    .tracking(2)
                Text("Hi, \(appState.userProfile.name.isEmpty ? "Athlete" : appState.userProfile.name)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
            Spacer()
            if sport.daysUntilPerformance <= 7 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(sport.daysUntilPerformance)D")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(Color(hex: "#FF6B8A"))
                    Text("TO MATCH")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: "#FF6B8A").opacity(0.7))
                        .tracking(1)
                }
            }
        }
    }

    private var scoreHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "#0C0C16"))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(readinessColor.opacity(0.3), lineWidth: 0.5)
                )
                .shadow(color: readinessColor.opacity(0.15), radius: 20, x: 0, y: 0)

            VStack(spacing: 20) {
                HStack(alignment: .bottom, spacing: 4) {
                    Text("\(readinessScore)")
                        .font(.system(size: 80, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("/100")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(.systemGray))
                        .padding(.bottom, 12)
                }

                Text(readinessLabel)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(readinessColor)
                    .tracking(3)

                HStack(spacing: 12) {
                    pillarBlock(label: "SLEEP", value: "\(String(format: "%.1f", healthKitManager.lastNightSleepHours))h", color: Color(hex: "#7C6FFF"), score: sleepScore)
                    pillarBlock(label: "LOAD", value: String(format: "%.2f", loadStore.acwr), color: Color(hex: "#4ECDC4"), score: loadScore)
                    pillarBlock(label: "FUEL", value: "\(Int(fuelScore))%", color: Color(hex: "#FFB347"), score: fuelScore)
                    pillarBlock(label: "ACWR", value: loadStore.acwr == 0 ? "—" : String(format: "%.1f", loadStore.acwr), color: Color(hex: "#5EFFB7"), score: loadScore)
                }
            }
            .padding(24)
        }
    }

    private func pillarBlock(label: String, value: String, color: Color, score: Double) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.15)).frame(width: 4, height: 40)
                RoundedRectangle(cornerRadius: 4).fill(color).frame(width: 4, height: CGFloat(score / 100) * 40)
            }
            Text(value).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
            Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(color.opacity(0.8)).tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.2), lineWidth: 0.5))
    }

    private var statRow: some View {
        HStack(spacing: 12) {
            statCard(title: "GPS LOAD", value: String(format: "%.0f", loadStore.acuteLoad), unit: "AU", color: Color(hex: "#4ECDC4"))
            statCard(title: "SESSIONS", value: "\(loadStore.gpsSessions.filter { Calendar.current.isDateInThisWeek($0.date) }.count)", unit: "this week", color: Color(hex: "#7C6FFF"))
            statCard(title: "CALORIES", value: "\(nutritionStore.todayCalories)", unit: "kcal", color: Color(hex: "#FFB347"))
        }
    }

    private func statCard(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(color.opacity(0.8))
                .tracking(1)
            Text(value)
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.white)
            Text(unit)
                .font(.system(size: 11))
                .foregroundColor(Color(.systemGray))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(hex: "#0C0C16"))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(color.opacity(0.2), lineWidth: 0.5))
    }

    private var edgeCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#7C6FFF"))
            Text(edgePrompt)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(16)
        .background(Color(hex: "#0C0C16"))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#7C6FFF").opacity(0.3), lineWidth: 0.5))
    }
}

private extension Calendar {
    func isDateInThisWeek(_ date: Date) -> Bool {
        isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }
}
```

**Note:** `healthKitManager.lastNightSleepHours` and `nutritionStore.todayCalories` / `nutritionStore.dailyCalorieTarget` — check exact property names against `HealthKitManager.swift` and `NutritionStore.swift` and adjust if different.

- [ ] **Step 2: Add Color(hex:) extension if not already present**

Search the project: `grep -r "Color(hex:" KAIZENN/ --include="*.swift" -l`. If no results, create `KAIZENN/UI/Extensions/Color+Hex.swift`:

```swift
import SwiftUI
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

- [ ] **Step 3: Build — Cmd+B, run on Simulator**

Dashboard must show score number, four pillar bars, stat row, edge card.

- [ ] **Step 4: Commit**

```bash
git add "KAIZENN/Features/Dashboard/DashboardView.swift"
git commit -m "feat: replace dashboard with Readiness Hero layout (score, pillars, stat row)"
```

---

### Task 7: Claude Vision Extension

**Files:**
- Modify: `KAIZENN/Data/Network/ClaudeService.swift`

**Interfaces:**
- Produces: `static func chatWithImage(image: UIImage, systemPrompt: String) async throws -> String`
- Consumed by: Task 8 (FoodPhotoScanView), Task 10 (TrainingMenuScanView)

- [ ] **Step 1: Add UIKit import and chatWithImage to ClaudeService.swift**

At the top of `KAIZENN/Data/Network/ClaudeService.swift`, add:
```swift
import UIKit
```

After the closing brace of `static func chat(...)`, inside `struct ClaudeService`, add:

```swift
/// Send an image to Claude Vision and return the assistant's analysis.
/// image is base64-encoded and sent as a content block alongside the system prompt.
static func chatWithImage(image: UIImage, systemPrompt: String) async throws -> String {
    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
        throw ClaudeError.requestFailed("Failed to encode image")
    }
    let base64 = imageData.base64EncodedString()

    let body: [String: Any] = [
        "model":      model,
        "max_tokens": 1024,
        "system":     systemPrompt,
        "messages": [
            [
                "role": "user",
                "content": [
                    ["type": "image",
                     "source": ["type": "base64", "media_type": "image/jpeg", "data": base64]],
                    ["type": "text",
                     "text": "Analyse this image and respond with structured JSON only."]
                ]
            ]
        ]
    ]

    var request = URLRequest(url: baseURL)
    request.httpMethod = "POST"
    request.setValue(apiKey,             forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01",       forHTTPHeaderField: "anthropic-version")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse else { throw ClaudeError.invalidResponse }
    guard (200..<300).contains(http.statusCode) else {
        let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw ClaudeError.requestFailed("Vision API error \(http.statusCode): \(msg)")
    }

    let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
    guard let text = decoded.content.first?.text else { throw ClaudeError.noContent }
    return text
}
```

- [ ] **Step 2: Build — Cmd+B**

Expected: clean. `ClaudeResponse` and `ContentBlock` are already defined as private types in the same file.

- [ ] **Step 3: Commit**

```bash
git add "KAIZENN/Data/Network/ClaudeService.swift"
git commit -m "feat: add Claude Vision chatWithImage() for food and training menu scanning"
```

---

### Task 8: Food Photo AI — Scan Meal Flow

**Files:**
- Create: `KAIZENN/Features/Nutrition/FoodPhotoScanView.swift`
- Modify: `KAIZENN/Features/Nutrition/NutritionView.swift` (add Scan Meal button)

**Interfaces:**
- Consumes: `ClaudeService.chatWithImage()` (Task 7), `NutritionStore.addEntry(_:)`
- Produces: Parsed food items added to NutritionStore

- [ ] **Step 1: Create FoodPhotoScanView.swift**

```swift
// KAIZENN/Features/Nutrition/FoodPhotoScanView.swift
import SwiftUI
import PhotosUI

struct ScannedFoodItem: Identifiable {
    var id = UUID()
    var name: String
    var grams: Double
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double

    var scaledCalories: Double { calories * (grams / 100) }
    var scaledProtein: Double  { proteinG * (grams / 100) }
    var scaledCarbs: Double    { carbsG * (grams / 100) }
    var scaledFat: Double      { fatG * (grams / 100) }
}

struct FoodPhotoScanView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var nutritionStore: NutritionStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedImage: UIImage?
    @State private var showPicker = false
    @State private var isScanning = false
    @State private var scannedItems: [ScannedFoodItem] = []
    @State private var errorMessage: String?
    @State private var showResults = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#080810").ignoresSafeArea()

                if showResults {
                    resultsList
                } else {
                    scanPrompt
                }
            }
            .navigationTitle("Scan Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color(hex: "#7C6FFF"))
                }
            }
        }
    }

    private var scanPrompt: some View {
        VStack(spacing: 24) {
            Spacer()

            if let img = selectedImage {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 260, height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#7C6FFF").opacity(0.4), lineWidth: 0.5))
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "#1A1A28"))
                    .frame(width: 260, height: 260)
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill").font(.system(size: 40)).foregroundColor(Color(hex: "#7C6FFF"))
                            Text("Take a photo of your meal").foregroundColor(Color(.systemGray)).multilineTextAlignment(.center)
                        }
                    )
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#7C6FFF").opacity(0.3), lineWidth: 0.5))
            }

            if let err = errorMessage {
                Text(err).foregroundColor(Color(hex: "#FF6B8A")).font(.caption).multilineTextAlignment(.center).padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: { showPicker = true }) {
                    Label("Take Photo / Choose", systemImage: "camera")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [Color(hex: "#7C6FFF"), Color(hex: "#9B91FF")], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(14)
                }

                if selectedImage != nil {
                    Button(action: scanImage) {
                        Group {
                            if isScanning {
                                ProgressView().tint(.white)
                            } else {
                                Text("Analyse with Kai AI")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(Color(hex: "#7C6FFF"))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#7C6FFF").opacity(0.15))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#7C6FFF").opacity(0.4), lineWidth: 0.5))
                    }
                    .disabled(isScanning)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .sheet(isPresented: $showPicker) {
            ImagePickerView(image: $selectedImage)
        }
    }

    private var resultsList: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach($scannedItems) { $item in
                        ScannedItemRow(item: $item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            VStack(spacing: 12) {
                let totalKcal = scannedItems.reduce(0) { $0 + $1.scaledCalories }
                Text("Total: \(Int(totalKcal)) kcal")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)

                Button("Log Meal") { logMeal() }
                    .buttonStyle(KPrimaryButtonStyle())
            }
            .padding(20)
            .background(Color(hex: "#0C0C16"))
        }
    }

    private func scanImage() {
        guard let img = selectedImage else { return }
        isScanning = true
        errorMessage = nil

        let sport = appState.userProfile.sportProfile
        let systemPrompt = """
        You are a sports nutrition AI. Analyse the meal in the image.
        The athlete plays \(sport.sport.displayName) as \(sport.position.isEmpty ? "an athlete" : sport.position).
        Return ONLY valid JSON in this exact format:
        {"items":[{"name":"Food Name","grams":100,"calories_per_100g":200,"protein_per_100g":15,"carbs_per_100g":25,"fat_per_100g":5}]}
        Estimate realistic portion sizes in grams. Be accurate for athlete nutrition.
        """

        Task {
            do {
                let json = try await ClaudeService.chatWithImage(image: img, systemPrompt: systemPrompt)
                let cleaned = json.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")
                if let data = cleaned.data(using: .utf8),
                   let parsed = try? JSONDecoder().decode(VisionFoodResponse.self, from: data) {
                    scannedItems = parsed.items.map {
                        ScannedFoodItem(name: $0.name, grams: $0.grams,
                                        calories: $0.calories_per_100g,
                                        proteinG: $0.protein_per_100g,
                                        carbsG: $0.carbs_per_100g,
                                        fatG: $0.fat_per_100g)
                    }
                    showResults = true
                } else {
                    errorMessage = "Could not read meal data. Try a clearer photo."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isScanning = false
        }
    }

    private func logMeal() {
        for item in scannedItems {
            let entry = NutritionEntry(
                name: item.name,
                calories: Int(item.scaledCalories),
                proteinG: item.scaledProtein,
                carbsG: item.scaledCarbs,
                fatG: item.scaledFat
            )
            nutritionStore.addEntry(entry)
        }
        dismiss()
    }
}

struct ScannedItemRow: View {
    @Binding var item: ScannedFoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.name).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GRAMS").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(Color(.systemGray)).tracking(1)
                    HStack(spacing: 4) {
                        TextField("0", value: $item.grams, format: .number)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 60)
                        Text("g").foregroundColor(Color(.systemGray))
                    }
                }
                Spacer()
                macroChip(label: "KCAL", value: Int(item.scaledCalories), color: Color(hex: "#FFB347"))
                macroChip(label: "PRO", value: Int(item.scaledProtein), color: Color(hex: "#7C6FFF"))
                macroChip(label: "CARB", value: Int(item.scaledCarbs), color: Color(hex: "#4ECDC4"))
            }
        }
        .padding(14)
        .background(Color(hex: "#0C0C16"))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#7C6FFF").opacity(0.15), lineWidth: 0.5))
    }

    private func macroChip(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
            Text(label).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(color).tracking(1)
        }
    }
}

private struct VisionFoodResponse: Decodable {
    let items: [VisionFoodItem]
}
private struct VisionFoodItem: Decodable {
    let name: String
    let grams: Double
    let calories_per_100g: Double
    let protein_per_100g: Double
    let carbs_per_100g: Double
    let fat_per_100g: Double
}

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePickerView
        init(_ parent: ImagePickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
```

**Note:** `NutritionEntry` and `nutritionStore.addEntry(_:)` — confirm exact type/method names against `NutritionModels.swift` and `NutritionStore.swift` before building.

- [ ] **Step 2: Add Scan Meal button to NutritionView.swift**

In `NutritionView.swift`, add `@State private var showFoodScan = false`, then add a scan button in the toolbar or near the top of the food log. Add sheet:

```swift
.sheet(isPresented: $showFoodScan) {
    FoodPhotoScanView()
        .environmentObject(appState)
        .environmentObject(nutritionStore)
}
```

Add a prominent button:
```swift
Button(action: { showFoodScan = true }) {
    Label("Scan Meal", systemImage: "camera.viewfinder")
        .font(.system(size: 16, weight: .bold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(LinearGradient(colors: [Color(hex: "#7C6FFF"), Color(hex: "#9B91FF")], startPoint: .leading, endPoint: .trailing))
        .cornerRadius(14)
}
```

- [ ] **Step 3: Add NSCameraUsageDescription to Info.plist**

In `KAIZENN/Info.plist` add key `NSCameraUsageDescription` with value `KAIZENN uses your camera to scan meals and training programs for AI analysis.`

- [ ] **Step 4: Build — Cmd+B, test on device (camera requires real device)**

- [ ] **Step 5: Commit**

```bash
git add "KAIZENN/Features/Nutrition/FoodPhotoScanView.swift" "KAIZENN/Features/Nutrition/NutritionView.swift" "KAIZENN/Info.plist"
git commit -m "feat: add food photo AI scanning via Claude Vision with editable gram breakdown"
```

---

### Task 9: Wearable Hub — GPS Import + Strength Logger

**Files:**
- Create: `KAIZENN/Features/Hub/WearableHubView.swift`
- Create: `KAIZENN/Features/Hub/GPSImportView.swift`
- Create: `KAIZENN/Features/Hub/StrengthLoggerView.swift`
- Create: `KAIZENN/Features/Hub/CatapultParser.swift`

**Interfaces:**
- Consumes: `LoadStore` (Task 3), `SportProfile` (Task 1)
- Produces: GPS sessions and strength sessions saved via `loadStore.addGPSSession(_:)` / `loadStore.addStrengthSession(_:)`

- [ ] **Step 1: Create CatapultParser.swift**

```swift
// KAIZENN/Features/Hub/CatapultParser.swift
import Foundation

struct CatapultParser {
    static func parse(csvString: String) -> GPSSession? {
        var session = GPSSession()
        session.source = .catapultCSV
        session.date = Date()

        let lines = csvString.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard lines.count > 1 else { return nil }

        let headers = lines[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        func colIndex(_ name: String) -> Int? { headers.firstIndex(where: { $0.contains(name) }) }

        let distIdx    = colIndex("distance")
        let loadIdx    = colIndex("player load")
        let sprintIdx  = colIndex("sprint")
        let hsrIdx     = colIndex("high speed")

        var totalDist   = 0.0
        var totalLoad   = 0.0
        var totalSprint = 0
        var totalHSR    = 0.0
        var rowCount    = 0

        for line in lines.dropFirst() {
            let cols = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard cols.count > 1 else { continue }
            if let i = distIdx,  i < cols.count { totalDist   += Double(cols[i]) ?? 0 }
            if let i = loadIdx,  i < cols.count { totalLoad   += Double(cols[i]) ?? 0 }
            if let i = sprintIdx, i < cols.count { totalSprint += Int(Double(cols[i]) ?? 0) }
            if let i = hsrIdx,   i < cols.count { totalHSR    += Double(cols[i]) ?? 0 }
            rowCount += 1
        }

        session.distanceMeters = totalDist
        session.playerLoad = totalLoad
        session.sprintCount = totalSprint
        session.highSpeedRunningPercent = rowCount > 0 ? totalHSR / Double(rowCount) : 0

        return session
    }
}
```

- [ ] **Step 2: Create GPSImportView.swift**

```swift
// KAIZENN/Features/Hub/GPSImportView.swift
import SwiftUI
import UniformTypeIdentifiers

struct GPSImportView: View {
    @EnvironmentObject var loadStore: LoadStore
    @Environment(\.dismiss) var dismiss

    @State private var showFilePicker = false
    @State private var importedSession: GPSSession?
    @State private var errorMessage: String?
    @State private var showManual = false

    // Manual entry fields
    @State private var distanceKm = ""
    @State private var playerLoad = ""
    @State private var sprintCount = ""
    @State private var hsrPercent = ""

    var body: some View {
        NavigationStack {
            ZStack { Color(hex: "#080810").ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        catapultSection
                        Divider().background(Color(hex: "#1A1A28"))
                        manualSection
                        if let session = importedSession { previewCard(session) }
                        if let err = errorMessage {
                            Text(err).foregroundColor(Color(hex: "#FF6B8A")).font(.caption)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Import GPS Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color(hex: "#7C6FFF"))
                }
            }
            .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.commaSeparatedText]) { result in
                handleFileImport(result)
            }
        }
    }

    private var catapultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Import Catapult CSV", systemImage: "doc.badge.arrow.up")
                .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
            Text("Export from your team's Catapult system and import here. Your GPS data, player load, and sprint metrics will be added to your load tracker.")
                .font(.caption).foregroundColor(Color(.systemGray))
            Button(action: { showFilePicker = true }) {
                Label("Choose CSV File", systemImage: "folder")
                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color(hex: "#4ECDC4").opacity(0.2)).cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#4ECDC4").opacity(0.5), lineWidth: 0.5))
            }
        }
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Manual Entry", systemImage: "pencil")
                .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
            inputRow(label: "Distance (km)", placeholder: "e.g. 6.5", value: $distanceKm)
            inputRow(label: "Player Load (AU)", placeholder: "e.g. 450", value: $playerLoad)
            inputRow(label: "Sprint Count", placeholder: "e.g. 12", value: $sprintCount)
            inputRow(label: "HSR %", placeholder: "e.g. 18", value: $hsrPercent)
            Button("Save Manual Session") { saveManual() }
                .buttonStyle(KPrimaryButtonStyle())
        }
    }

    private func inputRow(label: String, placeholder: String, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(Color(.systemGray))
            TextField(placeholder, text: value)
                .keyboardType(.decimalPad).foregroundColor(.white)
                .padding(12).background(Color(hex: "#1A1A28")).cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#4ECDC4").opacity(0.3), lineWidth: 0.5))
        }
    }

    private func previewCard(_ session: GPSSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PREVIEW").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "#4ECDC4")).tracking(2)
            HStack {
                statItem(label: "DISTANCE", value: String(format: "%.1f km", session.distanceMeters / 1000))
                statItem(label: "LOAD", value: String(format: "%.0f AU", session.playerLoad))
                statItem(label: "SPRINTS", value: "\(session.sprintCount)")
                statItem(label: "HSR%", value: String(format: "%.0f%%", session.highSpeedRunningPercent))
            }
            Button("Confirm & Save") {
                loadStore.addGPSSession(session)
                dismiss()
            }
            .buttonStyle(KPrimaryButtonStyle())
        }
        .padding(16).background(Color(hex: "#0C0C16")).cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#4ECDC4").opacity(0.4), lineWidth: 0.5))
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
            Text(label).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "#4ECDC4")).tracking(1)
        }.frame(maxWidth: .infinity)
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            guard url.startAccessingSecurityScopedResource() else { errorMessage = "Cannot access file."; return }
            defer { url.stopAccessingSecurityScopedResource() }
            let csv = try String(contentsOf: url, encoding: .utf8)
            if let session = CatapultParser.parse(csvString: csv) {
                importedSession = session
                errorMessage = nil
            } else {
                errorMessage = "Could not parse CSV. Check the file format."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveManual() {
        var session = GPSSession()
        session.source = .manual
        session.distanceMeters = (Double(distanceKm) ?? 0) * 1000
        session.playerLoad = Double(playerLoad) ?? 0
        session.sprintCount = Int(sprintCount) ?? 0
        session.highSpeedRunningPercent = Double(hsrPercent) ?? 0
        loadStore.addGPSSession(session)
        dismiss()
    }
}
```

- [ ] **Step 3: Create StrengthLoggerView.swift**

```swift
// KAIZENN/Features/Hub/StrengthLoggerView.swift
import SwiftUI

struct StrengthLoggerView: View {
    @EnvironmentObject var loadStore: LoadStore
    @Environment(\.dismiss) var dismiss

    @State private var exercises: [StrengthExercise] = []
    @State private var showExercisePicker = false
    @State private var newExerciseName = ""

    var body: some View {
        NavigationStack {
            ZStack { Color(hex: "#080810").ignoresSafeArea()
                VStack(spacing: 0) {
                    exerciseList
                    bottomBar
                }
            }
            .navigationTitle("Strength Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color(hex: "#7C6FFF"))
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showExercisePicker = true }) {
                        Image(systemName: "plus").foregroundColor(Color(hex: "#FFB347"))
                    }
                }
            }
            .sheet(isPresented: $showExercisePicker) { exercisePickerSheet }
        }
    }

    private var exerciseList: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach($exercises) { $exercise in
                    ExerciseCard(exercise: $exercise)
                }
                if exercises.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "dumbbell").font(.system(size: 40)).foregroundColor(Color(hex: "#FFB347").opacity(0.5))
                        Text("Tap + to add an exercise").foregroundColor(Color(.systemGray))
                    }
                    .padding(.top, 60)
                }
            }
            .padding(20)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            let vol = exercises.flatMap(\.sets).reduce(0.0) { $0 + ($1.reps * $1.weightKg) }
            if vol > 0 {
                Text("Total Volume: \(Int(vol)) kg")
                    .font(.system(size: 14, weight: .medium)).foregroundColor(Color(.systemGray))
            }
            Button("Save Session") {
                var session = StrengthSession()
                session.exercises = exercises.filter { !$0.sets.isEmpty }
                if !session.exercises.isEmpty {
                    loadStore.addStrengthSession(session)
                }
                dismiss()
            }
            .buttonStyle(KPrimaryButtonStyle())
        }
        .padding(20)
        .background(Color(hex: "#0C0C16"))
    }

    private var exercisePickerSheet: some View {
        NavigationStack {
            ZStack { Color(hex: "#080810").ignoresSafeArea()
                VStack(spacing: 16) {
                    HStack {
                        TextField("Custom exercise name", text: $newExerciseName)
                            .foregroundColor(.white).padding(12)
                            .background(Color(hex: "#1A1A28")).cornerRadius(10)
                        Button("Add") {
                            guard !newExerciseName.isEmpty else { return }
                            exercises.append(StrengthExercise(name: newExerciseName))
                            newExerciseName = ""
                            showExercisePicker = false
                        }
                        .foregroundColor(Color(hex: "#FFB347")).padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 20)

                    List(StrengthExercise.presets, id: \.self) { preset in
                        Button(preset) {
                            exercises.append(StrengthExercise(name: preset))
                            showExercisePicker = false
                        }
                        .foregroundColor(.white)
                        .listRowBackground(Color(hex: "#0C0C16"))
                    }
                    .listStyle(.plain)
                }
                .padding(.top, 16)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showExercisePicker = false }.foregroundColor(Color(hex: "#7C6FFF"))
                }
            }
        }
    }
}

struct ExerciseCard: View {
    @Binding var exercise: StrengthExercise

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise.name).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                Spacer()
                if exercise.estimated1RM > 0 {
                    Text("1RM ~\(Int(exercise.estimated1RM))kg").font(.system(size: 12)).foregroundColor(Color(hex: "#FFB347"))
                }
            }

            ForEach($exercise.sets) { $set in
                HStack(spacing: 16) {
                    numField(label: "Reps", value: $set.reps)
                    Text("×").foregroundColor(Color(.systemGray))
                    numField(label: "kg", value: $set.weightKg)
                    Spacer()
                    let vol = set.reps * set.weightKg
                    if vol > 0 { Text("\(Int(vol)) kg").font(.caption).foregroundColor(Color(.systemGray)) }
                }
            }

            Button(action: { exercise.sets.append(ExerciseSet()) }) {
                Label("Add Set", systemImage: "plus.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#FFB347"))
            }
        }
        .padding(16)
        .background(Color(hex: "#0C0C16"))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#FFB347").opacity(0.2), lineWidth: 0.5))
    }

    private func numField(label: String, value: Binding<Double>) -> some View {
        VStack(spacing: 2) {
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad).multilineTextAlignment(.center)
                .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                .frame(width: 60).padding(.vertical, 8)
                .background(Color(hex: "#1A1A28")).cornerRadius(8)
            Text(label).font(.system(size: 10)).foregroundColor(Color(.systemGray))
        }
    }
}
```

- [ ] **Step 4: Create WearableHubView.swift**

```swift
// KAIZENN/Features/Hub/WearableHubView.swift
import SwiftUI

struct WearableHubView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loadStore: LoadStore

    @State private var showGPSImport = false
    @State private var showStrengthLogger = false
    @State private var showTrainingMenu = false

    private var recentGPS: [GPSSession] { Array(loadStore.gpsSessions.prefix(3)) }
    private var recentStrength: [StrengthSession] { Array(loadStore.strengthSessions.prefix(3)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    acwrCard
                    gpsSection
                    strengthSection
                    trainingMenuCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(hex: "#080810").ignoresSafeArea())
            .navigationTitle("Wearable Hub")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showGPSImport)       { GPSImportView().environmentObject(loadStore) }
        .sheet(isPresented: $showStrengthLogger)  { StrengthLoggerView().environmentObject(loadStore) }
        .sheet(isPresented: $showTrainingMenu)    { TrainingMenuScanView().environmentObject(appState) }
    }

    private var acwrCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ACWR").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "#4ECDC4")).tracking(2)
                    Text(loadStore.acwr == 0 ? "No data yet" : acwrLabel)
                        .font(.system(size: 14)).foregroundColor(.white)
                }
                Spacer()
                Text(loadStore.acwr == 0 ? "—" : String(format: "%.2f", loadStore.acwr))
                    .font(.system(size: 40, weight: .black)).foregroundColor(acwrColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#1A1A28")).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(acwrColor)
                        .frame(width: min(CGFloat(loadStore.acwr / 2.0), 1.0) * geo.size.width, height: 8)
                    // sweet spot markers
                    Rectangle().fill(Color(hex: "#5EFFB7").opacity(0.5)).frame(width: 1, height: 16)
                        .offset(x: 0.4 * geo.size.width, y: -4)
                    Rectangle().fill(Color(hex: "#5EFFB7").opacity(0.5)).frame(width: 1, height: 16)
                        .offset(x: 0.65 * geo.size.width, y: -4)
                }
            }
            .frame(height: 8)

            HStack {
                Text("0.8 OPTIMAL 1.3")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "#5EFFB7")).tracking(1)
                Spacer()
                Text("Acute: \(Int(loadStore.acuteLoad)) · Chronic: \(Int(loadStore.chronicLoad))")
                    .font(.system(size: 11)).foregroundColor(Color(.systemGray))
            }
        }
        .padding(16).background(Color(hex: "#0C0C16")).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#4ECDC4").opacity(0.3), lineWidth: 0.5))
    }

    private var acwrLabel: String {
        let v = loadStore.acwr
        if v < 0.8 { return "Undertraining — ramp up load" }
        if v <= 1.3 { return "Sweet spot — maintain" }
        if v <= 1.5 { return "Elevated — monitor fatigue" }
        return "Danger zone — reduce load"
    }

    private var acwrColor: Color {
        let v = loadStore.acwr
        if v < 0.8 { return Color(hex: "#FFB347") }
        if v <= 1.3 { return Color(hex: "#5EFFB7") }
        if v <= 1.5 { return Color(hex: "#FFB347") }
        return Color(hex: "#FF6B8A")
    }

    private var gpsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("GPS Sessions", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                Spacer()
                Button(action: { showGPSImport = true }) {
                    Label("Import", systemImage: "plus").font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "#4ECDC4"))
                }
            }

            if recentGPS.isEmpty {
                Text("No GPS sessions yet. Import from Catapult or enter manually.")
                    .font(.caption).foregroundColor(Color(.systemGray))
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 20)
            } else {
                ForEach(recentGPS) { session in
                    gpsRow(session)
                }
            }
        }
        .padding(16).background(Color(hex: "#0C0C16")).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#4ECDC4").opacity(0.2), lineWidth: 0.5))
    }

    private func gpsRow(_ session: GPSSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.date.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                Text(session.source.displayName).font(.system(size: 11)).foregroundColor(Color(hex: "#4ECDC4"))
            }
            Spacer()
            Text(String(format: "%.1f km", session.distanceMeters / 1000)).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
        }
        .padding(.vertical, 8)
        .overlay(Divider().background(Color(hex: "#1A1A28")), alignment: .bottom)
    }

    private var strengthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Strength Sessions", systemImage: "dumbbell.fill")
                    .font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                Spacer()
                Button(action: { showStrengthLogger = true }) {
                    Label("Log", systemImage: "plus").font(.system(size: 14, weight: .semibold)).foregroundColor(Color(hex: "#FFB347"))
                }
            }

            if recentStrength.isEmpty {
                Text("No strength sessions yet. Log your sets, reps, and weights.")
                    .font(.caption).foregroundColor(Color(.systemGray))
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 20)
            } else {
                ForEach(recentStrength) { session in
                    HStack {
                        Text(session.date.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                        Spacer()
                        Text("\(Int(session.totalVolumeKg)) kg total").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    }
                    .padding(.vertical, 8)
                    .overlay(Divider().background(Color(hex: "#1A1A28")), alignment: .bottom)
                }
            }
        }
        .padding(16).background(Color(hex: "#0C0C16")).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#FFB347").opacity(0.2), lineWidth: 0.5))
    }

    private var trainingMenuCard: some View {
        Button(action: { showTrainingMenu = true }) {
            HStack(spacing: 12) {
                Image(systemName: "camera.viewfinder").font(.system(size: 24)).foregroundColor(Color(hex: "#4ECDC4"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scan Training Program").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    Text("Photo your whiteboard or printed plan — Kai fills in the session").font(.caption).foregroundColor(Color(.systemGray))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundColor(Color(.systemGray))
            }
            .padding(16).background(Color(hex: "#0C0C16")).cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#4ECDC4").opacity(0.3), lineWidth: 0.5))
        }
    }
}
```

- [ ] **Step 5: Wire WearableHubView into MainTabView**

Find the file that renders tabs (likely `KAIZENN/App/RootView.swift` or `MainTabView.swift`). Add the hub tab:

```swift
case .hub:
    WearableHubView()
        .environmentObject(appState)
        .environmentObject(loadStore)
```

- [ ] **Step 6: Build — Cmd+B, run in Simulator**

Hub tab must appear. ACWR shows "—" with no sessions. GPS Import sheet must open.

- [ ] **Step 7: Commit**

```bash
git add "KAIZENN/Features/Hub/"
git commit -m "feat: add Wearable Hub with GPS import, ACWR display, and strength logger"
```

---

### Task 10: Training Menu Scanner

**Files:**
- Create: `KAIZENN/Features/Hub/TrainingMenuScanView.swift`

**Interfaces:**
- Consumes: `ClaudeService.chatWithImage()` (Task 7), `LoadStore.addStrengthSession(_:)`

- [ ] **Step 1: Create TrainingMenuScanView.swift**

```swift
// KAIZENN/Features/Hub/TrainingMenuScanView.swift
import SwiftUI

struct TrainingMenuScanView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var loadStore: LoadStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedImage: UIImage?
    @State private var showPicker = false
    @State private var isScanning = false
    @State private var parsedSession: StrengthSession?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack { Color(hex: "#080810").ignoresSafeArea()
                if let session = parsedSession {
                    parsedPreview(session)
                } else {
                    scanUI
                }
            }
            .navigationTitle("Scan Training Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color(hex: "#7C6FFF"))
                }
            }
            .sheet(isPresented: $showPicker) { ImagePickerView(image: $selectedImage) }
        }
    }

    private var scanUI: some View {
        VStack(spacing: 24) {
            Spacer()
            if let img = selectedImage {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 260, height: 200).clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16).fill(Color(hex: "#1A1A28")).frame(width: 260, height: 200)
                    .overlay(VStack(spacing: 8) {
                        Image(systemName: "doc.viewfinder").font(.system(size: 40)).foregroundColor(Color(hex: "#4ECDC4"))
                        Text("Photo your whiteboard, printed plan, or handwritten session").foregroundColor(Color(.systemGray)).multilineTextAlignment(.center).padding(.horizontal, 20)
                    })
            }
            if let err = errorMessage {
                Text(err).foregroundColor(Color(hex: "#FF6B8A")).font(.caption).multilineTextAlignment(.center).padding(.horizontal, 32)
            }
            Spacer()
            VStack(spacing: 12) {
                Button(action: { showPicker = true }) {
                    Label("Take Photo / Choose", systemImage: "camera")
                        .font(.system(size: 17, weight: .bold)).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(LinearGradient(colors: [Color(hex: "#4ECDC4"), Color(hex: "#6EE7E7")], startPoint: .leading, endPoint: .trailing)).cornerRadius(14)
                }
                if selectedImage != nil {
                    Button(action: scanImage) {
                        Group {
                            if isScanning { ProgressView().tint(.white) }
                            else { Text("Extract Session with Kai AI").font(.system(size: 17, weight: .bold)).foregroundColor(Color(hex: "#4ECDC4")) }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color(hex: "#4ECDC4").opacity(0.15)).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#4ECDC4").opacity(0.4), lineWidth: 0.5))
                    }
                    .disabled(isScanning)
                }
            }
            .padding(.horizontal, 20).padding(.bottom, 32)
        }
    }

    private func parsedPreview(_ session: StrengthSession) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("EXTRACTED SESSION").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "#4ECDC4")).tracking(2)
                    ForEach(session.exercises) { exercise in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(exercise.name).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            ForEach(exercise.sets) { set in
                                Text("\(Int(set.reps)) reps × \(Int(set.weightKg)) kg").font(.system(size: 14)).foregroundColor(Color(.systemGray))
                            }
                        }
                        .padding(12).background(Color(hex: "#0C0C16")).cornerRadius(10)
                    }
                }
                .padding(20)
            }
            VStack(spacing: 12) {
                Button("Save Session") { loadStore.addStrengthSession(session); dismiss() }.buttonStyle(KPrimaryButtonStyle())
                Button("Re-scan") { parsedSession = nil; selectedImage = nil }.foregroundColor(Color(.systemGray))
            }
            .padding(20).background(Color(hex: "#0C0C16"))
        }
    }

    private func scanImage() {
        guard let img = selectedImage else { return }
        isScanning = true
        errorMessage = nil
        let sport = appState.userProfile.sportProfile
        let systemPrompt = """
        You are a sports performance AI. Extract the training session from this image.
        The athlete plays \(sport.sport.displayName). Return ONLY valid JSON:
        {"exercises":[{"name":"Exercise Name","sets":[{"reps":5,"weight_kg":100}]}]}
        If no weight is shown, use 0. If reps are shown as ranges, use the lower number.
        """
        Task {
            do {
                let json = try await ClaudeService.chatWithImage(image: img, systemPrompt: systemPrompt)
                let cleaned = json.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
                if let data = cleaned.data(using: .utf8),
                   let raw = try? JSONDecoder().decode(TrainingMenuResponse.self, from: data) {
                    var session = StrengthSession()
                    session.exercises = raw.exercises.map { ex in
                        var e = StrengthExercise(name: ex.name)
                        e.sets = ex.sets.map { s in ExerciseSet(reps: s.reps, weightKg: s.weight_kg) }
                        return e
                    }
                    parsedSession = session
                } else {
                    errorMessage = "Could not read the training plan. Try a clearer photo."
                }
            } catch { errorMessage = error.localizedDescription }
            isScanning = false
        }
    }
}

private struct TrainingMenuResponse: Decodable {
    let exercises: [TRExercise]
    struct TRExercise: Decodable {
        let name: String
        let sets: [TRSet]
    }
    struct TRSet: Decodable {
        let reps: Double
        let weight_kg: Double
    }
}
```

- [ ] **Step 2: Build — Cmd+B**

- [ ] **Step 3: Commit**

```bash
git add "KAIZENN/Features/Hub/TrainingMenuScanView.swift"
git commit -m "feat: add training menu photo scanner via Claude Vision → strength session"
```

---

### Task 11: AI Coach Upgrade

**Files:**
- Modify: `KAIZENN/Features/Coach/CoachView.swift`

**Interfaces:**
- Consumes: `appState.userProfile.sportProfile`, `loadStore.acwr`, `healthKitManager.lastNightSleepHours`, `nutritionStore.todayCalories`

- [ ] **Step 1: Add @EnvironmentObject var loadStore: LoadStore to CoachView**

In `KAIZENN/Features/Coach/CoachView.swift`, add after existing @EnvironmentObject declarations:

```swift
@EnvironmentObject var loadStore: LoadStore
```

- [ ] **Step 2: Replace static system prompt with sport-aware dynamic prompt**

Find the existing `systemPrompt` string in CoachView. Replace it with:

```swift
private var systemPrompt: String {
    let sp = appState.userProfile.sportProfile
    let name = appState.userProfile.name.isEmpty ? "the athlete" : appState.userProfile.name
    let daysToMatch = sp.daysUntilPerformance
    let acwr = String(format: "%.2f", loadStore.acwr)
    let sleep = String(format: "%.1f", healthKitManager.lastNightSleepHours)
    let cals = nutritionStore.todayCalories
    let target = Int(nutritionStore.dailyCalorieTarget)

    return """
    You are Kai Coach, a world-class performance AI for \(name).
    
    ATHLETE CONTEXT:
    - Sport: \(sp.sport.displayName), Position: \(sp.position.isEmpty ? "athlete" : sp.position)
    - Season phase: \(sp.seasonPhase.displayName)
    - Days until next performance: \(daysToMatch)
    
    TODAY'S DATA:
    - Sleep last night: \(sleep) hours (target 8hrs)
    - ACWR (training load ratio): \(acwr) (sweet spot 0.8–1.3)
    - Calories today: \(cals) / \(target) kcal target
    
    COACHING STYLE:
    - Be direct, specific, and sport-intelligent. Use \(sp.sport.displayName)-specific language.
    - Never be vague. Reference actual numbers from the athlete's data.
    - Keep responses under 200 words unless asked for detail.
    - Give numbered action items (1, 2, 3) when the athlete asks what to do.
    - Frame everything around performance, not aesthetics.
    """
}
```

- [ ] **Step 3: Add proactive daily brief to CoachView**

Add a state property:
```swift
@State private var dailyBrief: String = ""
@State private var isLoadingBrief = false
```

Add `generateDailyBrief()` function:
```swift
private func generateDailyBrief() {
    guard dailyBrief.isEmpty else { return }
    isLoadingBrief = true
    let sp = appState.userProfile.sportProfile
    let briefPrompt = "Generate today's performance brief for this athlete in 3 numbered action items. Be specific about their ACWR, sleep, and nutrition data. Start with their readiness assessment in one sentence."
    Task {
        do {
            let response = try await ClaudeService.chat(
                messages: [ChatMessage(text: briefPrompt, isUser: true, timestamp: Date())],
                systemPrompt: systemPrompt
            )
            await MainActor.run { dailyBrief = response; isLoadingBrief = false }
        } catch {
            await MainActor.run { dailyBrief = "Tap below to ask Kai anything about today's training."; isLoadingBrief = false }
        }
    }
}
```

Add `.task { generateDailyBrief() }` to the view body.

Add a daily brief card above the chat messages section:

```swift
if !dailyBrief.isEmpty {
    VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 6) {
            Image(systemName: "bolt.circle.fill").foregroundColor(Color(hex: "#7C6FFF"))
            Text("TODAY'S BRIEF").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(Color(hex: "#7C6FFF")).tracking(2)
        }
        Text(dailyBrief).font(.system(size: 15)).foregroundColor(.white).lineSpacing(4)
    }
    .padding(16).background(Color(hex: "#0C0C16")).cornerRadius(16)
    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#7C6FFF").opacity(0.3), lineWidth: 0.5))
    .padding(.horizontal, 20)
} else if isLoadingBrief {
    ProgressView().tint(Color(hex: "#7C6FFF")).padding()
}
```

- [ ] **Step 4: Wire LoadStore into CoachView everywhere it's presented**

Search for where `CoachView()` is constructed (likely in RootView or MainTabView) and add `.environmentObject(loadStore)`.

- [ ] **Step 5: Build — Cmd+B, run in Simulator**

Coach tab must show loading spinner, then daily brief. Asking "What should I do today?" should return sport-specific numbered items.

- [ ] **Step 6: Commit**

```bash
git add "KAIZENN/Features/Coach/CoachView.swift"
git commit -m "feat: upgrade Kai Coach with sport-aware system prompt and proactive daily brief"
```

---

## Spec Coverage Checklist

- [x] Sport Profile model (Task 1)
- [x] GPS Session model (Task 2)
- [x] Strength Session model (Task 2)
- [x] ACWR calculation (Task 3)
- [x] LoadStore (Task 3)
- [x] App wiring (Task 4)
- [x] Onboarding sport profile steps (Task 5)
- [x] Dashboard Readiness Hero (Task 6)
- [x] Claude Vision extension (Task 7)
- [x] Food photo AI (Task 8)
- [x] Catapult CSV import (Task 9)
- [x] GPS manual entry (Task 9)
- [x] Strength logger (Task 9)
- [x] Wearable Hub tab (Task 9)
- [x] Training menu scanner (Task 10)
- [x] AI Coach sport-aware prompt + daily brief (Task 11)
- [ ] Barcode scanner (existing — not changed)
- [ ] HealthKit HRV (existing — connect to Readiness pillar in future iteration)

---

## Build Order Summary

| Task | What ships | Time estimate |
|------|-----------|---------------|
| 1 | SportProfile model | 15 min |
| 2 | GPS + Strength models | 15 min |
| 3 | LoadStore + ACWR | 20 min |
| 4 | App wiring + hub tab | 15 min |
| 5 | Onboarding sport steps | 30 min |
| 6 | Dashboard Readiness Hero | 45 min |
| 7 | Claude Vision extension | 15 min |
| 8 | Food photo AI | 45 min |
| 9 | Wearable Hub + GPS + Strength | 60 min |
| 10 | Training menu scanner | 20 min |
| 11 | AI Coach upgrade | 20 min |

Total: ~5 hours of focused build time.
