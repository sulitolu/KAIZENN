# Readiness Report Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tapping the Home readiness ring/number opens a read-only Readiness Report with a Daily and a Weekly view of the athlete's own data — distinct from Kai.

**Architecture:** Extract the readiness scoring out of `DashboardView` into a pure `ReadinessEngine` (unit-tested). `DashboardView` and a new `ReadinessReportView` (sheet with a Daily/Weekly toggle) both consume the engine. Weekly per-pillar trends come from existing store history APIs; the full 7-day readiness-score line is a follow-up (Task 6) because it needs new HealthKit history fetches.

**Tech Stack:** Swift / SwiftUI, XCTest, `KTheme` design system, UserDefaults-backed stores, `xcodeproj` Ruby gem for registering new files.

## Global Constraints

- Build (simulator): `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` then `xcodebuild -project KAIZENN.xcodeproj -scheme KAIZENN -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`. The xcodebuild result is the ONLY authority — ignore SourceKit "Cannot find type/No such module" single-file errors.
- Tests: `xcodebuild test -project KAIZENN.xcodeproj -scheme KAIZENN -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO`.
- **Project uses explicit file references (no synchronized folders).** Every NEW file must be registered in `project.pbxproj` via the Ruby helper below, or it won't compile. Verify by building.
- Design tokens only from `KAIZENN/Core/DesignSystem/` (`KTheme.Colors/Spacing/Animation`, `Color(hex:)`). No new theme tokens.
- The Report is **read-only**: no AI text, recommendations, chat, logging, export. That is Kai's job, not this surface.
- New report UI uses plain English `Text` for v1 (localization of the report is out of scope; tracked as follow-up — consistent with the app's current partial localization).
- Branch: `feat/readiness-report` (already checked out).

### File-registration helper (used by several tasks)

Save as `docs/superpowers/plans/add_file.rb` once (Task 1, Step 1) and reuse:

```ruby
# Usage: ruby add_file.rb <project-relative-file-path> <target-name>
require 'xcodeproj'
path, target_name = ARGV[0], ARGV[1]
proj = Xcodeproj::Project.open('KAIZENN.xcodeproj')
target = proj.targets.find { |t| t.name == target_name } or abort("no target #{target_name}")
# Skip if already referenced
if proj.files.any? { |f| f.real_path.to_s.end_with?(path) }
  puts "already referenced: #{path}"; exit 0
end
group = proj.main_group.find_subpath(File.dirname(path), true)
group.set_source_tree('SOURCE_ROOT')
ref = group.new_reference(path)
ref.source_tree = 'SOURCE_ROOT'
target.source_build_phase.add_file_reference(ref)
proj.save
puts "added #{path} to #{target_name}"
```

Run it with the rbenv Ruby:
```bash
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH" && eval "$(rbenv init - bash)"
cd "/Users/suli/Desktop/Dev Projects/KAIZENN"
ruby docs/superpowers/plans/add_file.rb <path> <target>
```

---

### Task 1: ReadinessEngine (pure scoring + label/color mapping)

**Files:**
- Create: `KAIZENN/Features/Readiness/ReadinessEngine.swift`
- Test: `KAIZENNTests/ReadinessEngineTests.swift`
- Modify: `docs/superpowers/plans/add_file.rb` (create the helper above)

**Interfaces:**
- Produces:
  - `struct ReadinessInputs { var sleepHours: Double; var acwr: Double; var consumedCalories: Double; var calorieTarget: Double; var proteinConsumed: Double; var proteinTarget: Double; var hrvLatestMs: Double?; var hrvBaselineMs: Double? }`
  - `enum ReadinessLabel { case peak, gameReady, build, recovery }` with `var displayText: String` and `var color: Color`
  - `struct ReadinessBreakdown { let sleepScore, loadScore, fuelScore, hrvScore: Double; let hrvAvailable: Bool; let score: Int; let label: ReadinessLabel }`
  - `enum ReadinessEngine` with `static func sleepScore(_:) -> Double`, `loadScore(_:) -> Double`, `fuelScore(consumedCalories:calorieTarget:proteinConsumed:proteinTarget:) -> Double`, `hrvScore(latest:baseline:) -> Double`, `label(for:) -> ReadinessLabel`, `breakdown(for:) -> ReadinessBreakdown`

- [ ] **Step 1: Create the file-registration helper**

Create `docs/superpowers/plans/add_file.rb` with the exact content from the "File-registration helper" section above.

- [ ] **Step 2: Write the failing test**

Create `KAIZENNTests/ReadinessEngineTests.swift`:

```swift
import XCTest
@testable import KAIZENN

final class ReadinessEngineTests: XCTestCase {

    func testSleepScoreCapsAtEightHours() {
        XCTAssertEqual(ReadinessEngine.sleepScore(8), 100, accuracy: 0.001)
        XCTAssertEqual(ReadinessEngine.sleepScore(4), 50, accuracy: 0.001)
        XCTAssertEqual(ReadinessEngine.sleepScore(10), 100, accuracy: 0.001) // capped
    }

    func testLoadScoreSweetSpotAndPenalty() {
        XCTAssertEqual(ReadinessEngine.loadScore(0), 75, accuracy: 0.001)   // unknown
        XCTAssertEqual(ReadinessEngine.loadScore(1.0), 100, accuracy: 0.001) // in 0.8...1.3
        // acwr 1.4 -> delta 0.1 -> 100 - 10 = 90
        XCTAssertEqual(ReadinessEngine.loadScore(1.4), 90, accuracy: 0.001)
    }

    func testFuelScoreHalfCaloriesHalfProtein() {
        // full calories, zero protein -> 50
        XCTAssertEqual(ReadinessEngine.fuelScore(consumedCalories: 2300, calorieTarget: 2300, proteinConsumed: 0, proteinTarget: 150), 50, accuracy: 0.001)
        // invalid targets -> 50 fallback
        XCTAssertEqual(ReadinessEngine.fuelScore(consumedCalories: 100, calorieTarget: 0, proteinConsumed: 10, proteinTarget: 0), 50, accuracy: 0.001)
    }

    func testHRVScoreAbsentReturns75() {
        XCTAssertEqual(ReadinessEngine.hrvScore(latest: nil, baseline: 50), 75, accuracy: 0.001)
        XCTAssertEqual(ReadinessEngine.hrvScore(latest: 50, baseline: nil), 75, accuracy: 0.001)
        XCTAssertEqual(ReadinessEngine.hrvScore(latest: 50, baseline: 50), 75, accuracy: 0.001) // at baseline
    }

    func testLabelBoundaries() {
        XCTAssertEqual(ReadinessEngine.label(for: 80), .peak)
        XCTAssertEqual(ReadinessEngine.label(for: 79), .gameReady)
        XCTAssertEqual(ReadinessEngine.label(for: 60), .gameReady)
        XCTAssertEqual(ReadinessEngine.label(for: 40), .build)
        XCTAssertEqual(ReadinessEngine.label(for: 39), .recovery)
    }

    func testBreakdownDropsHRVWeightingWhenAbsent() {
        // No HRV -> 3-pillar 0.33/0.33/0.34. All pillars 100 -> ~100.
        let inputs = ReadinessInputs(sleepHours: 8, acwr: 1.0,
            consumedCalories: 2300, calorieTarget: 2300,
            proteinConsumed: 150, proteinTarget: 150,
            hrvLatestMs: nil, hrvBaselineMs: nil)
        let b = ReadinessEngine.breakdown(for: inputs)
        XCTAssertFalse(b.hrvAvailable)
        XCTAssertEqual(b.score, 100)
        XCTAssertEqual(b.label, .peak)
    }
}
```

- [ ] **Step 3: Register the test file, run to verify it fails**

```bash
export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH" && eval "$(rbenv init - bash)"
cd "/Users/suli/Desktop/Dev Projects/KAIZENN"
ruby docs/superpowers/plans/add_file.rb KAIZENNTests/ReadinessEngineTests.swift KAIZENNTests
```
Then run the test command from Global Constraints. Expected: FAIL (compile error — `ReadinessEngine` not defined).

- [ ] **Step 4: Write the implementation**

Create `KAIZENN/Features/Readiness/ReadinessEngine.swift`:

```swift
import SwiftUI

struct ReadinessInputs {
    var sleepHours: Double
    var acwr: Double
    var consumedCalories: Double
    var calorieTarget: Double
    var proteinConsumed: Double
    var proteinTarget: Double
    var hrvLatestMs: Double?
    var hrvBaselineMs: Double?
}

enum ReadinessLabel {
    case peak, gameReady, build, recovery

    var displayText: String {
        switch self {
        case .peak:      return "PEAK CONDITION"
        case .gameReady: return "GAME READY"
        case .build:     return "BUILD DAY"
        case .recovery:  return "RECOVERY DAY"
        }
    }

    var color: Color {
        switch self {
        case .peak:      return Color(hex: "5EFFB7")
        case .gameReady: return Color(hex: "7C6FFF")
        case .build:     return Color(hex: "FFB347")
        case .recovery:  return Color(hex: "FF6B8A")
        }
    }
}

struct ReadinessBreakdown {
    let sleepScore: Double
    let loadScore: Double
    let fuelScore: Double
    let hrvScore: Double
    let hrvAvailable: Bool
    let score: Int
    let label: ReadinessLabel
}

enum ReadinessEngine {

    static func sleepScore(_ hours: Double) -> Double {
        min(hours / 8.0, 1.0) * 100
    }

    static func loadScore(_ acwr: Double) -> Double {
        guard acwr != 0 else { return 75 }
        let range: ClosedRange<Double> = 0.8...1.3
        if range.contains(acwr) { return 100 }
        let delta = acwr < range.lowerBound ? range.lowerBound - acwr : acwr - range.upperBound
        return max(0, 100 - (delta * 100))
    }

    static func fuelScore(consumedCalories: Double, calorieTarget: Double,
                          proteinConsumed: Double, proteinTarget: Double) -> Double {
        guard calorieTarget > 0, proteinTarget > 0 else { return 50 }
        let calorieRatio = min(consumedCalories / calorieTarget, 1.0)
        let proteinRatio = min(proteinConsumed / proteinTarget, 1.0)
        return (calorieRatio * 0.5 + proteinRatio * 0.5) * 100
    }

    static func hrvScore(latest: Double?, baseline: Double?) -> Double {
        guard let latest else { return 75 }
        guard let base = baseline, base > 0 else { return 75 }
        let ratio = latest / base
        return min(max(75 + (ratio - 1.0) * 150, 0), 100)
    }

    static func label(for score: Int) -> ReadinessLabel {
        switch score {
        case 80...:   return .peak
        case 60..<80: return .gameReady
        case 40..<60: return .build
        default:      return .recovery
        }
    }

    static func breakdown(for i: ReadinessInputs) -> ReadinessBreakdown {
        let s = sleepScore(i.sleepHours)
        let l = loadScore(i.acwr)
        let f = fuelScore(consumedCalories: i.consumedCalories, calorieTarget: i.calorieTarget,
                          proteinConsumed: i.proteinConsumed, proteinTarget: i.proteinTarget)
        let hrvAvailable = i.hrvLatestMs != nil
        let h = hrvScore(latest: i.hrvLatestMs, baseline: i.hrvBaselineMs)
        let raw = hrvAvailable
            ? s * 0.25 + l * 0.25 + f * 0.25 + h * 0.25
            : s * 0.33 + l * 0.33 + f * 0.34
        let score = Int(raw)
        return ReadinessBreakdown(sleepScore: s, loadScore: l, fuelScore: f, hrvScore: h,
                                  hrvAvailable: hrvAvailable, score: score, label: label(for: score))
    }
}
```

- [ ] **Step 5: Register the source file and run tests to verify they pass**

```bash
ruby docs/superpowers/plans/add_file.rb KAIZENN/Features/Readiness/ReadinessEngine.swift KAIZENN
```
Run the test command. Expected: all `ReadinessEngineTests` PASS.

- [ ] **Step 6: Commit**

```bash
git add KAIZENN/Features/Readiness/ReadinessEngine.swift KAIZENNTests/ReadinessEngineTests.swift docs/superpowers/plans/add_file.rb KAIZENN.xcodeproj/project.pbxproj
git commit -m "feat(readiness): add tested ReadinessEngine (scoring + label/color)"
```

---

### Task 2: Refactor DashboardView to use ReadinessEngine

**Files:**
- Modify: `KAIZENN/Features/Dashboard/DashboardView.swift` (the readiness computed properties, ~lines 28-90)

**Interfaces:**
- Consumes: `ReadinessEngine.breakdown(for:)`, `ReadinessInputs`, `ReadinessBreakdown`, `ReadinessLabel`

- [ ] **Step 1: Add a breakdown accessor and rewrite the score properties**

In `DashboardView.swift`, replace the `// MARK: - Pillar scores` and `// MARK: - Readiness` blocks (the `sleepScore`, `loadScore`, `fuelScore`, `hrvAvailable`, `hrvScore`, `readinessScore`, `readinessLabel`, `readinessColor` computed properties) with a single inputs builder + breakdown, keeping the same public-facing values used elsewhere in the view:

```swift
    // MARK: - Readiness (delegated to ReadinessEngine)
    private var readinessInputs: ReadinessInputs {
        ReadinessInputs(
            sleepHours: sleepHours,
            acwr: acwr,
            consumedCalories: consumedCalories,
            calorieTarget: Double(calorieTarget),
            proteinConsumed: nutritionStore.dailyNutrition(for: Date()).totalProteinG,
            proteinTarget: Double(appState.userProfile.macroTargets.proteinG),
            hrvLatestMs: healthKitManager.hrvLatestMs,
            hrvBaselineMs: healthKitManager.hrvBaselineMs
        )
    }

    private var readinessBreakdown: ReadinessBreakdown { ReadinessEngine.breakdown(for: readinessInputs) }

    var readinessScore: Int { readinessBreakdown.score }
    private var readinessLabel: String { readinessBreakdown.label.displayText }
    private var readinessColor: Color { readinessBreakdown.label.color }
    private var hrvAvailable: Bool { readinessBreakdown.hrvAvailable }
```

NOTE: If any pillar sub-score (`sleepScore`/`loadScore`/`fuelScore`/`hrvScore`) is referenced elsewhere in `DashboardView` (e.g. by `edgePrompt`, `pillarsRow`), keep thin shims so those call sites compile unchanged:

```swift
    private var sleepScore: Double { readinessBreakdown.sleepScore }
    private var loadScore: Double { readinessBreakdown.loadScore }
    private var fuelScore: Double { readinessBreakdown.fuelScore }
    private var hrvScore: Double { readinessBreakdown.hrvScore }
```

Before editing, grep to see which sub-scores are still used and keep exactly those shims:
```bash
grep -nE "\b(sleepScore|loadScore|fuelScore|hrvScore)\b" KAIZENN/Features/Dashboard/DashboardView.swift
```

IMPORTANT: `readinessLabel` currently localizes via `L.t(...)`. Preserve localization by mapping the engine label to the existing keys instead of `displayText` if the localized Home label must stay translated:
```swift
    private var readinessLabel: String {
        switch readinessBreakdown.label {
        case .peak:      return L.t("dashboard.readiness.peak", lang)
        case .gameReady: return L.t("dashboard.readiness.gameReady", lang)
        case .build:     return L.t("dashboard.readiness.build", lang)
        case .recovery:  return L.t("dashboard.readiness.recovery", lang)
        }
    }
```

- [ ] **Step 2: Build to verify the refactor compiles and is behavior-preserving**

Run the build command. Expected: `** BUILD SUCCEEDED **`. The Home readiness card must render an identical score/label/color to before (pure extraction — no formula change).

- [ ] **Step 3: Run the engine tests again (regression guard)**

Run the test command. Expected: `ReadinessEngineTests` still PASS.

- [ ] **Step 4: Commit**

```bash
git add KAIZENN/Features/Dashboard/DashboardView.swift
git commit -m "refactor(dashboard): score readiness via ReadinessEngine (no behavior change)"
```

---

### Task 3: ReadinessReportView shell + change the ring/number to open it

**Files:**
- Create: `KAIZENN/Features/Readiness/ReadinessReportView.swift`
- Modify: `KAIZENN/Features/Dashboard/DashboardView.swift` (sheet state + the `scoreHeroCard` top button + add `.sheet`)

**Interfaces:**
- Produces: `struct ReadinessReportView: View` (reads the same `@EnvironmentObject` stores as Dashboard); internal `enum ReadinessReportMode { case daily, weekly }`
- Consumes: `ReadinessEngine`, the app's stores

- [ ] **Step 1: Create the report shell with the Daily/Weekly toggle**

Create `KAIZENN/Features/Readiness/ReadinessReportView.swift`:

```swift
import SwiftUI

enum ReadinessReportMode: String, CaseIterable { case daily = "Daily", weekly = "Weekly" }

struct ReadinessReportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var nutritionStore: NutritionStore
    @EnvironmentObject var loadStore: LoadStore
    @EnvironmentObject var weightStore: WeightStore

    @State private var mode: ReadinessReportMode = .daily

    var body: some View {
        ZStack {
            KTheme.Colors.background.ignoresSafeArea()
            VStack(spacing: KTheme.Spacing.md) {
                header
                modePicker
                ScrollView(showsIndicators: false) {
                    Group {
                        switch mode {
                        case .daily:  ReadinessDailyView()
                        case .weekly: ReadinessWeeklyView()
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .padding(.horizontal, KTheme.Spacing.md)
            .padding(.top, KTheme.Spacing.md)
        }
    }

    private var header: some View {
        HStack {
            Text("Readiness")
                .font(.system(size: 26, weight: .heavy))
                .foregroundColor(KTheme.Colors.textPrimary)
            Spacer()
            Button("Done") { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(KTheme.Colors.accentPrimary)
        }
    }

    private var modePicker: some View {
        HStack(spacing: 6) {
            ForEach(ReadinessReportMode.allCases, id: \.self) { m in
                let selected = mode == m
                Button { withAnimation(KTheme.Animation.snappy) { mode = m } } label: {
                    Text(m.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selected ? .white : KTheme.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selected ? KTheme.Colors.accentPrimary : KTheme.Colors.cardElevated)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// Placeholder bodies — fleshed out in Tasks 4 and 5.
struct ReadinessDailyView: View {
    var body: some View { Text("Daily").foregroundColor(.white) }
}
struct ReadinessWeeklyView: View {
    var body: some View { Text("Weekly").foregroundColor(.white) }
}
```

- [ ] **Step 2: Register the file**

```bash
ruby docs/superpowers/plans/add_file.rb KAIZENN/Features/Readiness/ReadinessReportView.swift KAIZENN
```

- [ ] **Step 3: Wire the entry point in DashboardView**

In `DashboardView.swift`, add sheet state near the other `@State` flags:
```swift
    @State private var showReadinessReport = false
```
Change the `scoreHeroCard` top button action from `navigate(to: .coach)` to:
```swift
            Button {
                showReadinessReport = true
            } label: {
```
Add a `.sheet` alongside the others in `body`:
```swift
        .sheet(isPresented: $showReadinessReport) {
            ReadinessReportView()
                .environmentObject(appState)
                .environmentObject(healthKitManager)
                .environmentObject(nutritionStore)
                .environmentObject(loadStore)
                .environmentObject(weightStore)
        }
```

- [ ] **Step 4: Build and verify**

Run the build command. Expected: `** BUILD SUCCEEDED **`. Manually (or on device): tapping the readiness ring/number opens the sheet with a working Daily/Weekly toggle (placeholder text for now); the pillar tiles still navigate as before.

- [ ] **Step 5: Commit**

```bash
git add KAIZENN/Features/Readiness/ReadinessReportView.swift KAIZENN/Features/Dashboard/DashboardView.swift KAIZENN.xcodeproj/project.pbxproj
git commit -m "feat(readiness): report sheet shell + open it from the Home ring"
```

---

### Task 4: Daily view — score hero + pillar breakdown

**Files:**
- Modify: `KAIZENN/Features/Readiness/ReadinessReportView.swift` (replace the `ReadinessDailyView` placeholder)

**Interfaces:**
- Consumes: `ReadinessEngine.breakdown(for:)`, stores

- [ ] **Step 1: Implement ReadinessDailyView**

Replace the `ReadinessDailyView` placeholder struct with:

```swift
struct ReadinessDailyView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var nutritionStore: NutritionStore
    @EnvironmentObject var loadStore: LoadStore

    private var inputs: ReadinessInputs {
        ReadinessInputs(
            sleepHours: healthKitManager.sleepHoursLast,
            acwr: loadStore.acwr,
            consumedCalories: nutritionStore.dailyNutrition(for: Date()).totalCalories,
            calorieTarget: Double(appState.userProfile.dailyCalorieTarget),
            proteinConsumed: nutritionStore.dailyNutrition(for: Date()).totalProteinG,
            proteinTarget: Double(appState.userProfile.macroTargets.proteinG),
            hrvLatestMs: healthKitManager.hrvLatestMs,
            hrvBaselineMs: healthKitManager.hrvBaselineMs
        )
    }
    private var b: ReadinessBreakdown { ReadinessEngine.breakdown(for: inputs) }

    var body: some View {
        VStack(spacing: KTheme.Spacing.md) {
            heroCard
            pillarRow("Sleep", contribution: b.sleepScore,
                      value: String(format: "%.1fh", inputs.sleepHours), tint: KTheme.Colors.accentTertiary)
            pillarRow("Load", contribution: b.loadScore,
                      value: inputs.acwr == 0 ? "—" : String(format: "ACWR %.2f", inputs.acwr), tint: KTheme.Colors.accentPrimary)
            pillarRow("Fuel", contribution: b.fuelScore,
                      value: "\(Int(inputs.consumedCalories)) / \(Int(inputs.calorieTarget)) kcal", tint: KTheme.Colors.accentAmber)
            pillarRow("HRV", contribution: b.hrvScore,
                      value: hrvText, tint: KTheme.Colors.accentSecondary)
        }
    }

    private var hrvText: String {
        guard let latest = inputs.hrvLatestMs else { return "—" }
        if let base = inputs.hrvBaselineMs, base > 0 {
            return String(format: "%.0fms (%+.0f vs base)", latest, latest - base)
        }
        return String(format: "%.0fms", latest)
    }

    private var heroCard: some View {
        VStack(spacing: 4) {
            Text("\(b.score)")
                .font(.system(size: 56, weight: .heavy))
                .foregroundColor(b.label.color)
            Text(b.label.displayText)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(b.label.color)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(KTheme.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: 18).fill(KTheme.Colors.card))
    }

    private func pillarRow(_ name: String, contribution: Double, value: String, tint: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 15, weight: .semibold)).foregroundColor(KTheme.Colors.textPrimary)
                Text(value).font(.system(size: 13)).foregroundColor(KTheme.Colors.textTertiary)
            }
            Spacer()
            Text("\(Int(contribution))")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(tint)
        }
        .padding(KTheme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: 14).fill(KTheme.Colors.card))
    }
}
```

- [ ] **Step 2: Build and verify**

Run the build command. Expected: `** BUILD SUCCEEDED **`. The Daily tab shows the score hero + four pillar rows with real values matching the Home card.

- [ ] **Step 3: Commit**

```bash
git add KAIZENN/Features/Readiness/ReadinessReportView.swift
git commit -m "feat(readiness): daily view — score hero + pillar breakdown"
```

---

### Task 5: Weekly view — per-pillar trends + weekly summary

**Files:**
- Modify: `KAIZENN/Features/Readiness/ReadinessReportView.swift` (replace the `ReadinessWeeklyView` placeholder; add a small `Sparkline` view)

**Interfaces:**
- Consumes: `NutritionStore.weeklyCalories(endingOn:)` → `[(Date, Double)]`, `WeightStore.trendLine(lastDays:)` → `[Double]`, `WeightStore.weightChange(lastDays:)` → `Double?`, `LoadStore.gpsSessions` (each `GPSSession` has `.date: Date`, `.sessionLoad: Double`)

NOTE: The full 7-day **readiness-score** line is deferred to Task 6 (needs per-day sleep/HRV history). This task ships the per-pillar trends that already have real history, so nothing is fabricated.

- [ ] **Step 1: Add a reusable Sparkline and implement ReadinessWeeklyView**

Append a `Sparkline` view and replace the `ReadinessWeeklyView` placeholder:

```swift
struct Sparkline: View {
    let values: [Double]
    var tint: Color
    var body: some View {
        GeometryReader { geo in
            let maxV = (values.max() ?? 1)
            let minV = (values.min() ?? 0)
            let span = max(maxV - minV, 0.0001)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tint.opacity(0.85))
                        .frame(height: max(4, CGFloat((v - minV) / span) * geo.size.height))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 44)
    }
}

struct ReadinessWeeklyView: View {
    @EnvironmentObject var nutritionStore: NutritionStore
    @EnvironmentObject var weightStore: WeightStore
    @EnvironmentObject var loadStore: LoadStore

    private var calorieSeries: [Double] { nutritionStore.weeklyCalories().map { $0.1 } }
    private var weightSeries: [Double] { weightStore.trendLine(lastDays: 7) }

    private var loadSeries: [Double] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: Date())!
            return loadStore.gpsSessions
                .filter { cal.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.sessionLoad }
        }
    }

    var body: some View {
        VStack(spacing: KTheme.Spacing.md) {
            summaryCard
            trendCard("Fuel — 7-day calories", series: calorieSeries, tint: KTheme.Colors.accentAmber, empty: "No nutrition logged this week")
            trendCard("Training load — 7 days", series: loadSeries, tint: KTheme.Colors.accentPrimary, empty: "No sessions this week")
            trendCard("Weight trend", series: weightSeries, tint: KTheme.Colors.accentTertiary, empty: "No weight entries yet")
            Text("Sleep, HRV and a full readiness trend arrive with HealthKit history (next update).")
                .font(.system(size: 11))
                .foregroundColor(KTheme.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var summaryCard: some View {
        let sessions = loadSeries.filter { $0 > 0 }.count
        let avgCal = calorieSeries.isEmpty ? 0 : Int(calorieSeries.reduce(0, +) / Double(calorieSeries.count))
        let wChange = weightStore.weightChange(lastDays: 7)
        return HStack(spacing: KTheme.Spacing.md) {
            summaryStat("\(sessions)", "sessions")
            summaryStat(avgCal == 0 ? "—" : "\(avgCal)", "avg kcal")
            summaryStat(wChange == nil ? "—" : String(format: "%+.1f", wChange!), "kg Δ")
        }
        .padding(KTheme.Spacing.md)
        .background(RoundedRectangle(cornerRadius: 16).fill(KTheme.Colors.card))
    }

    private func summaryStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .heavy)).foregroundColor(KTheme.Colors.textPrimary)
            Text(label).font(.system(size: 11)).foregroundColor(KTheme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func trendCard(_ title: String, series: [Double], tint: Color, empty: String) -> some View {
        VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(KTheme.Colors.textSecondary)
            if series.contains(where: { $0 > 0 }) {
                Sparkline(values: series, tint: tint)
            } else {
                Text(empty).font(.system(size: 12)).foregroundColor(KTheme.Colors.textTertiary).frame(height: 44)
            }
        }
        .padding(KTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(KTheme.Colors.card))
    }
}
```

- [ ] **Step 2: Build and verify**

Run the build command. Expected: `** BUILD SUCCEEDED **`. The Weekly tab shows a summary row + three trend cards (fuel, load, weight) with sparklines or empty states; the note about sleep/HRV/readiness trend is visible.

VERIFY store API names before building — if `weeklyCalories`, `trendLine(lastDays:)`, `weightChange(lastDays:)`, or `GPSSession.sessionLoad`/`.date` differ, adjust the call sites:
```bash
grep -nE "func weeklyCalories|func trendLine|func weightChange|var sessionLoad|var date" KAIZENN/Data/Persistence/NutritionStore.swift KAIZENN/Data/Persistence/WeightStore.swift KAIZENN/Data/Models/*GPS* 2>/dev/null
```

- [ ] **Step 3: Commit**

```bash
git add KAIZENN/Features/Readiness/ReadinessReportView.swift
git commit -m "feat(readiness): weekly view — per-pillar trends + summary"
```

---

### Task 6 (follow-up): HealthKit 7-day sleep/HRV + full readiness trend

**Files:**
- Modify: `KAIZENN/Core/Health/HealthKitManager.swift` (add `fetchSleepHistory(days:) async -> [Date: Double]` and `fetchHRVHistory(days:) async -> [Date: Double]`)
- Modify: `KAIZENN/Features/Readiness/ReadinessReportView.swift` (add a readiness-score 7-day trend built by calling `ReadinessEngine.breakdown(for:)` per day with reconstructed inputs; show gaps for days missing data)

**Interfaces:**
- Produces: `HealthKitManager.fetchSleepHistory(days:) -> [Date: Double]`, `fetchHRVHistory(days:) -> [Date: Double]`

- [ ] **Step 1:** Add the two HealthKit history queries (HKSampleQuery / statistics collection per day) returning a date-keyed dictionary of daily sleep hours and daily HRV ms. Match the existing query style in `HealthKitManager.swift`.
- [ ] **Step 2:** In the weekly view, for each of the last 7 days build `ReadinessInputs` from: that day's sleep (from `fetchSleepHistory`), HRV (from `fetchHRVHistory`), fuel (`nutritionStore.dailyNutrition(for: day)`), and per-day ACWR (compute from `loadStore.gpsSessions` up to that day). Call `ReadinessEngine.breakdown(for:)` per day. Render a readiness-score sparkline + weekly average + best/worst day; render a gap where a day lacks sleep AND hrv data.
- [ ] **Step 3:** Build, verify on device, commit.

(Task 6 is optional for the first release — Tasks 1-5 ship a working Daily + Weekly report on their own.)

---

## Self-Review

- **Spec coverage:** Entry point (Task 3) ✓; sheet + Daily/Weekly toggle (Task 3) ✓; daily score breakdown + raw values (Task 4) ✓; weekly per-pillar trends (Task 5) ✓; ReadinessEngine extraction (Tasks 1-2) ✓; weekly readiness-trend honest-gap handling + HealthKit follow-up (Task 6) ✓; read-only / no-AI / no-new-files-without-pbxproj constraints captured in Global Constraints ✓.
- **Placeholder scan:** Task 3 intentionally ships placeholder view bodies that Tasks 4-5 replace — these are real, compilable code, not plan placeholders. No "TBD"/"add error handling"-style gaps.
- **Type consistency:** `ReadinessInputs`/`ReadinessBreakdown`/`ReadinessLabel`/`ReadinessEngine.breakdown(for:)` names match across Tasks 1, 2, 3, 4. `ReadinessReportMode` defined in Task 3 and used there only.
- **Risk note:** Tasks 4-5 reference store API names (`weeklyCalories`, `trendLine(lastDays:)`, `weightChange(lastDays:)`, `GPSSession.sessionLoad`/`.date`) confirmed by grep during exploration; each build step includes a verify-and-adjust grep in case a signature differs.
