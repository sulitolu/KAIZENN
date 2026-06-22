# Readiness v2 — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. NOTE: in this environment subagents cannot run Bash; the controller runs builds/tests/commits inline.

**Goal:** Replace KAIZENN's readiness scoring with a baseline-relative model (Recovery/Sleep/Strain/Fuel) using existing HealthKit + load data.

**Architecture:** A pure, unit-tested `ReadinessEngine` v2 takes today's values plus a `ReadinessBaseline` (mean/SD per signal, computed from new HealthKit history fetches) and returns per-pillar sub-scores + a 0–100 composite. UI (Home card + report) renders the new pillars and a "Calibrating" cold-start state.

**Tech Stack:** Swift / SwiftUI, HealthKit, XCTest, `KTheme`, `xcodeproj` gem for file registration.

## Global Constraints
- Build: `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` then `xcodebuild -project KAIZENN.xcodeproj -scheme KAIZENN -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`. Tests: `xcodebuild test -project KAIZENN.xcodeproj -scheme KAIZENN -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO`. The xcodebuild result is the ONLY authority — ignore SourceKit single-file errors.
- New files MUST be registered in `project.pbxproj` via `docs/superpowers/plans/add_file.rb` (app files → target `KAIZENN`, tests → `KAIZENNTests`). Run with rbenv ruby: `export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH" && eval "$(rbenv init - bash)"`.
- HealthKit HRV is **SDNN** (Apple exposes no RMSSD). Use `ln(SDNN)` vs personal baseline — document in-code.
- Weights/penalty constants are tunable defaults — keep them as named `static let` constants, not inline magic numbers.
- `readinessScore` stays `Int` 0–100 so existing Home call sites keep working.
- `MIN_DAYS = 14` for the calibrating threshold. Score mapping: `sub = clamp(80 + 20·z, 0, 100)`.
- Branch: `feat/settings-notifications-i18n` (already checked out).

---

### Task 1: ReadinessBaseline + signal baseline math (pure, TDD)

**Files:**
- Create: `KAIZENN/Features/Readiness/ReadinessBaseline.swift`
- Test: `KAIZENNTests/ReadinessBaselineTests.swift`

**Interfaces — Produces:**
- `struct SignalBaseline: Equatable { let mean: Double; let sd: Double; let n: Int; static func from(_ series: [Double], minN: Int = 2) -> SignalBaseline? }`
- `struct ReadinessBaseline { let hrvLnSDNN: SignalBaseline?; let restingHR: SignalBaseline?; let sleepHours: SignalBaseline?; let sleepNeed: Double; var isCalibrating: Bool; static let minDays: Int }`

- [ ] **Step 1: Write the failing test** — create `KAIZENNTests/ReadinessBaselineTests.swift`:

```swift
import XCTest
@testable import KAIZENN

final class ReadinessBaselineTests: XCTestCase {

    func testSignalBaselineMeanAndSD() {
        let b = SignalBaseline.from([2, 4, 4, 4, 5, 5, 7, 9])!
        XCTAssertEqual(b.mean, 5, accuracy: 0.001)
        XCTAssertEqual(b.sd, 2, accuracy: 0.001)   // population SD
        XCTAssertEqual(b.n, 8)
    }

    func testSignalBaselineNilBelowMinN() {
        XCTAssertNil(SignalBaseline.from([5], minN: 2))
        XCTAssertNil(SignalBaseline.from([], minN: 2))
    }

    func testSignalBaselineSDFloorAvoidsZero() {
        let b = SignalBaseline.from([5, 5, 5])!   // sd would be 0
        XCTAssertGreaterThan(b.sd, 0)             // floored, never 0 (no div-by-zero downstream)
    }

    func testCalibratingWhenBothHRVAndSleepBelowMinDays() {
        let few = SignalBaseline.from(Array(repeating: 3.9, count: 5).map { $0 + .random(in: 0...0.001) })
        let base = ReadinessBaseline(hrvLnSDNN: few, restingHR: nil, sleepHours: few, sleepNeed: 8, )
        XCTAssertTrue(base.isCalibrating)         // n=5 < 14 for both
    }

    func testNotCalibratingWhenSleepHasEnough() {
        let many = SignalBaseline(mean: 7.5, sd: 0.8, n: 20)
        let base = ReadinessBaseline(hrvLnSDNN: nil, restingHR: nil, sleepHours: many, sleepNeed: 8)
        XCTAssertFalse(base.isCalibrating)        // sleep n=20 >= 14
    }
}
```

- [ ] **Step 2: Register the test, run RED**

```bash
ruby docs/superpowers/plans/add_file.rb KAIZENNTests/ReadinessBaselineTests.swift KAIZENNTests
```
Run the test command. Expected: FAIL (`SignalBaseline`/`ReadinessBaseline` undefined).

- [ ] **Step 3: Implement** — create `KAIZENN/Features/Readiness/ReadinessBaseline.swift`:

```swift
import Foundation

/// Mean/SD of one signal over a baseline window. SD is floored to avoid div-by-zero in z-scores.
struct SignalBaseline: Equatable {
    let mean: Double
    let sd: Double
    let n: Int

    static func from(_ series: [Double], minN: Int = 2) -> SignalBaseline? {
        guard series.count >= minN else { return nil }
        let mean = series.reduce(0, +) / Double(series.count)
        let variance = series.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(series.count)
        return SignalBaseline(mean: mean, sd: max(variance.squareRoot(), 1e-6), n: series.count)
    }
}

/// Per-athlete baselines for the readiness signals. `isCalibrating` is true until the athlete
/// has at least `minDays` of HRV OR sleep history (baseline-relative scoring needs history).
struct ReadinessBaseline {
    let hrvLnSDNN: SignalBaseline?
    let restingHR: SignalBaseline?
    let sleepHours: SignalBaseline?
    var sleepNeed: Double = 8.0

    static let minDays = 14

    var isCalibrating: Bool {
        (hrvLnSDNN?.n ?? 0) < ReadinessBaseline.minDays && (sleepHours?.n ?? 0) < ReadinessBaseline.minDays
    }
}
```

- [ ] **Step 4: Register source, run GREEN**

```bash
ruby docs/superpowers/plans/add_file.rb KAIZENN/Features/Readiness/ReadinessBaseline.swift KAIZENN
```
Run the test command. Expected: all `ReadinessBaselineTests` PASS.

- [ ] **Step 5: Commit**

```bash
git add KAIZENN/Features/Readiness/ReadinessBaseline.swift KAIZENNTests/ReadinessBaselineTests.swift KAIZENN.xcodeproj/project.pbxproj
git commit -m "feat(readiness): SignalBaseline + ReadinessBaseline value types (tested)"
```

---

### Task 2: ReadinessEngine v2 (pure, TDD)

**Files:**
- Modify (rewrite): `KAIZENN/Features/Readiness/ReadinessEngine.swift`
- Modify (rewrite): `KAIZENNTests/ReadinessEngineTests.swift`

**Interfaces — Consumes:** `ReadinessBaseline`, `SignalBaseline`. **Produces:**
- `struct ReadinessInputs { hrvLnSDNNToday: Double?; restingHRToday: Double?; sleepHoursLast: Double?; sleepDebtHours: Double; sleepRegularitySD: Double?; acuteLoad: Double; chronicLoad: Double; consumedCalories: Double; calorieTarget: Double; proteinConsumed: Double; proteinTarget: Double; baseline: ReadinessBaseline }`
- `enum ReadinessLabel { case primed, ready, moderate, caution, recover }` with `displayText: String`, `color: Color`
- `struct ReadinessBreakdown { recovery: Double?; sleep: Double?; strain: Double?; fuel: Double?; score: Int; label: ReadinessLabel; isCalibrating: Bool }`
- `enum ReadinessEngine` with `static func breakdown(for: ReadinessInputs) -> ReadinessBreakdown` and the sub-score statics below.

- [ ] **Step 1: Rewrite the test** — replace `KAIZENNTests/ReadinessEngineTests.swift` entirely:

```swift
import XCTest
@testable import KAIZENN

final class ReadinessEngineTests: XCTestCase {

    private func baseline(hrvN: Int = 60, sleepN: Int = 60) -> ReadinessBaseline {
        ReadinessBaseline(
            hrvLnSDNN: SignalBaseline(mean: 3.8, sd: 0.2, n: hrvN),       // ln(SDNN) ~ ln(45ms)
            restingHR: SignalBaseline(mean: 55, sd: 4, n: hrvN),
            sleepHours: SignalBaseline(mean: 7.5, sd: 0.8, n: sleepN),
            sleepNeed: 8.0
        )
    }

    private func inputs(hrv: Double? = 3.8, rhr: Double? = 55, sleep: Double? = 7.5,
                        debt: Double = 0, reg: Double? = 0.5,
                        acute: Double = 50, chronic: Double = 50,
                        base: ReadinessBaseline? = nil) -> ReadinessInputs {
        ReadinessInputs(hrvLnSDNNToday: hrv, restingHRToday: rhr, sleepHoursLast: sleep,
                        sleepDebtHours: debt, sleepRegularitySD: reg,
                        acuteLoad: acute, chronicLoad: chronic,
                        consumedCalories: 2000, calorieTarget: 2000, proteinConsumed: 150, proteinTarget: 150,
                        baseline: base ?? baseline())
    }

    func testZSubMapping() {
        XCTAssertEqual(ReadinessEngine.sub(z: 0), 80, accuracy: 0.001)
        XCTAssertEqual(ReadinessEngine.sub(z: 1), 100, accuracy: 0.001)   // capped
        XCTAssertEqual(ReadinessEngine.sub(z: -2), 40, accuracy: 0.001)
        XCTAssertEqual(ReadinessEngine.sub(z: -5), 0, accuracy: 0.001)    // floored
    }

    func testAtBaselineScoresAroundEighty() {
        let b = ReadinessEngine.breakdown(for: inputs())
        XCTAssertFalse(b.isCalibrating)
        XCTAssertGreaterThanOrEqual(b.score, 74)
        XCTAssertLessThanOrEqual(b.score, 86)
        XCTAssertEqual(b.label, .ready)
    }

    func testLowHRVDropsRecovery() {
        // HRV 2 SD below baseline -> recovery should fall well below 80
        let low = ReadinessEngine.breakdown(for: inputs(hrv: 3.8 - 2 * 0.2))
        XCTAssertNotNil(low.recovery)
        XCTAssertLessThan(low.recovery!, 70)
    }

    func testHighRestingHRIsPenalised() {
        // RHR 2 SD ABOVE baseline is bad -> recovery lower than at-baseline
        let normal = ReadinessEngine.breakdown(for: inputs())
        let highRHR = ReadinessEngine.breakdown(for: inputs(rhr: 55 + 2 * 4))
        XCTAssertLessThan(highRHR.recovery!, normal.recovery!)
    }

    func testStrainPenalisesAcuteSpike() {
        // acute 2x chronic -> strain sub well below 80, NOT an ACWR sweet-spot
        let spike = ReadinessEngine.strainScore(inputs(acute: 100, chronic: 50))!
        XCTAssertLessThan(spike, 60)
    }

    func testMissingPillarRenormalises() {
        // No HRV and no RHR -> recovery nil; score still computed from sleep/strain/fuel
        let b = ReadinessEngine.breakdown(for: inputs(hrv: nil, rhr: nil))
        XCTAssertNil(b.recovery)
        XCTAssertGreaterThan(b.score, 0)
    }

    func testCalibratingUsesFallbackAndFlags() {
        let cal = ReadinessEngine.breakdown(for: inputs(base: baseline(hrvN: 5, sleepN: 5)))
        XCTAssertTrue(cal.isCalibrating)
        XCTAssertGreaterThan(cal.score, 0)          // produces a bounded provisional score
        XCTAssertLessThanOrEqual(cal.score, 100)
    }

    func testLabelBoundaries() {
        XCTAssertEqual(ReadinessEngine.label(for: 85), .primed)
        XCTAssertEqual(ReadinessEngine.label(for: 84), .ready)
        XCTAssertEqual(ReadinessEngine.label(for: 70), .ready)
        XCTAssertEqual(ReadinessEngine.label(for: 69), .moderate)
        XCTAssertEqual(ReadinessEngine.label(for: 55), .moderate)
        XCTAssertEqual(ReadinessEngine.label(for: 54), .caution)
        XCTAssertEqual(ReadinessEngine.label(for: 40), .caution)
        XCTAssertEqual(ReadinessEngine.label(for: 39), .recover)
    }
}
```

- [ ] **Step 2: Run RED** — run the test command. Expected: FAIL (v2 symbols undefined / old API gone).

- [ ] **Step 3: Implement** — replace `KAIZENN/Features/Readiness/ReadinessEngine.swift` entirely:

```swift
import SwiftUI

struct ReadinessInputs {
    var hrvLnSDNNToday: Double?     // ln of the 7-day rolling SDNN (nil if no HRV)
    var restingHRToday: Double?
    var sleepHoursLast: Double?
    var sleepDebtHours: Double      // cumulative 14-night deficit, >= 0
    var sleepRegularitySD: Double?  // SD of nightly hours (lower = more regular)
    var acuteLoad: Double
    var chronicLoad: Double
    var consumedCalories: Double
    var calorieTarget: Double
    var proteinConsumed: Double
    var proteinTarget: Double
    var baseline: ReadinessBaseline
}

enum ReadinessLabel {
    case primed, ready, moderate, caution, recover

    var displayText: String {
        switch self {
        case .primed:   return "PRIMED"
        case .ready:    return "READY"
        case .moderate: return "MODERATE"
        case .caution:  return "CAUTION"
        case .recover:  return "RECOVER"
        }
    }
    var color: Color {
        switch self {
        case .primed:   return Color(hex: "5EFFB7")
        case .ready:    return Color(hex: "7C6FFF")
        case .moderate: return Color(hex: "FFD166")
        case .caution:  return Color(hex: "FF9F45")
        case .recover:  return Color(hex: "FF6B8A")
        }
    }
}

struct ReadinessBreakdown {
    let recovery: Double?
    let sleep: Double?
    let strain: Double?
    let fuel: Double?
    let score: Int
    let label: ReadinessLabel
    let isCalibrating: Bool
}

enum ReadinessEngine {
    // Tunable defaults (see research spec). Weights for the full model; renormalised over present pillars.
    static let wRecovery = 0.45, wSleep = 0.30, wStrain = 0.18, wFuel = 0.07
    static let wHRV = 0.30, wRHR = 0.15         // within-Recovery weights
    static let sleepDebtPenaltyPerHour = 3.0, sleepDebtPenaltyCap = 30.0
    static let sleepRegPenaltyPerHour = 10.0, sleepRegPenaltyCap = 20.0, sleepRegTolerance = 1.0
    static let strainSlope = 40.0               // sub drop per unit (acute/chronic - 1)

    static func sub(z: Double) -> Double { min(max(80 + 20 * z, 0), 100) }
    static func zScore(_ value: Double, _ b: SignalBaseline) -> Double { (value - b.mean) / b.sd }

    static func recoveryScore(_ i: ReadinessInputs) -> Double? {
        var parts: [(Double, Double)] = []
        if let hrv = i.hrvLnSDNNToday, let b = i.baseline.hrvLnSDNN { parts.append((sub(z: zScore(hrv, b)), wHRV)) }
        if let rhr = i.restingHRToday, let b = i.baseline.restingHR { parts.append((sub(z: -zScore(rhr, b)), wRHR)) } // inverted
        guard !parts.isEmpty else { return nil }
        let wsum = parts.reduce(0) { $0 + $1.1 }
        return parts.reduce(0) { $0 + $1.0 * $1.1 } / wsum
    }

    static func sleepScore(_ i: ReadinessInputs) -> Double? {
        guard let hours = i.sleepHoursLast else { return nil }
        let durSub: Double
        if let b = i.baseline.sleepHours { durSub = sub(z: zScore(hours, b)) }
        else { durSub = min(hours / i.baseline.sleepNeed, 1.0) * 100 }
        let debtPenalty = min(i.sleepDebtHours * sleepDebtPenaltyPerHour, sleepDebtPenaltyCap)
        let regPenalty = i.sleepRegularitySD.map { min(max($0 - sleepRegTolerance, 0) * sleepRegPenaltyPerHour, sleepRegPenaltyCap) } ?? 0
        return min(max(durSub - debtPenalty - regPenalty, 0), 100)
    }

    static func strainScore(_ i: ReadinessInputs) -> Double? {
        guard i.chronicLoad > 0 else { return i.acuteLoad == 0 ? 80 : nil }
        let ratio = i.acuteLoad / i.chronicLoad
        return min(max(80 - (ratio - 1.0) * strainSlope, 0), 100)   // higher acute-vs-chronic = more fatigue, NOT an injury gate
    }

    static func fuelScore(_ i: ReadinessInputs) -> Double? {
        guard i.calorieTarget > 0, i.proteinTarget > 0 else { return 50 }
        let cal = min(i.consumedCalories / i.calorieTarget, 1.0)
        let pro = min(i.proteinConsumed / i.proteinTarget, 1.0)
        return (cal * 0.5 + pro * 0.5) * 100
    }

    static func label(for score: Int) -> ReadinessLabel {
        switch score {
        case 85...:   return .primed
        case 70..<85: return .ready
        case 55..<70: return .moderate
        case 40..<55: return .caution
        default:      return .recover
        }
    }

    static func breakdown(for i: ReadinessInputs) -> ReadinessBreakdown {
        if i.baseline.isCalibrating { return calibrating(i) }
        let rec = recoveryScore(i), slp = sleepScore(i), str = strainScore(i), fue = fuelScore(i)
        let weighted: [(Double?, Double)] = [(rec, wRecovery), (slp, wSleep), (str, wStrain), (fue, wFuel)]
        let present = weighted.compactMap { s, w in s.map { ($0, w) } }
        guard rec != nil || slp != nil, !present.isEmpty else {
            return ReadinessBreakdown(recovery: rec, sleep: slp, strain: str, fuel: fue, score: 0, label: .recover, isCalibrating: true)
        }
        let wsum = present.reduce(0) { $0 + $1.1 }
        let score = Int((present.reduce(0) { $0 + $1.0 * $1.1 } / wsum).rounded())
        return ReadinessBreakdown(recovery: rec, sleep: slp, strain: str, fuel: fue, score: score, label: label(for: score), isCalibrating: false)
    }

    /// Cold-start: gentle absolute fallback (HRV neutral until a baseline exists), clearly flagged.
    static func calibrating(_ i: ReadinessInputs) -> ReadinessBreakdown {
        let rec: Double? = i.hrvLnSDNNToday != nil ? 75 : nil
        let slp: Double? = i.sleepHoursLast.map { min($0 / i.baseline.sleepNeed, 1.0) * 100 }
        let str = strainScore(i)
        let fue = fuelScore(i)
        let weighted: [(Double?, Double)] = [(rec, 0.30), (slp, 0.40), (str, 0.20), (fue, 0.10)]
        let present = weighted.compactMap { s, w in s.map { ($0, w) } }
        let score = present.isEmpty ? 0 : Int((present.reduce(0) { $0 + $1.0 * $1.1 } / present.reduce(0) { $0 + $1.1 }).rounded())
        return ReadinessBreakdown(recovery: rec, sleep: slp, strain: str, fuel: fue, score: score, label: label(for: score), isCalibrating: true)
    }
}
```

- [ ] **Step 4: Run GREEN** — run the test command. Expected: all `ReadinessEngineTests` + `ReadinessBaselineTests` PASS. NOTE: the build will now FAIL in `DashboardView`/`ReadinessReportView` because they reference the old engine API — that is expected and fixed in Tasks 4–5. Confirm GREEN by the **test** target compiling the engine + tests; if the app target blocks the test run, proceed to Task 4 and treat Task 2+4+5 as one red→green arc, committing Task 2's engine first.

- [ ] **Step 5: Commit**

```bash
git add KAIZENN/Features/Readiness/ReadinessEngine.swift KAIZENNTests/ReadinessEngineTests.swift
git commit -m "feat(readiness): ReadinessEngine v2 — baseline-relative pillars (tested)"
```

---

### Task 3: HealthKit history fetches

**Files:**
- Modify: `KAIZENN/Data/HealthKit/HealthKitManager.swift` (add two methods near the other fetchers, ~line 165)

**Interfaces — Produces:**
- `func fetchDailySeries(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> [Double]`
- `func fetchSleepHistory(nights: Int) async -> [Double]`

- [ ] **Step 1: Add the methods** — insert into `HealthKitManager`:

```swift
    /// One value per day (daily average) over the last `days` days, chronological. Missing days omitted.
    func fetchDailySeries(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> [Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return [] }
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -days, to: anchor)!
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await withCheckedContinuation { cont in
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: pred,
                                                options: .discreteAverage, anchorDate: anchor,
                                                intervalComponents: DateComponents(day: 1))
            q.initialResultsHandler = { _, results, _ in
                var values: [Double] = []
                results?.enumerateStatistics(from: start, to: Date()) { stats, _ in
                    if let v = stats.averageQuantity()?.doubleValue(for: unit) { values.append(v) }
                }
                cont.resume(returning: values)
            }
            store.execute(q)
        }
    }

    /// Asleep hours per night for the last `nights` nights (each night = the 24h window ending that morning).
    func fetchSleepHistory(nights: Int) async -> [Double] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let cal = Calendar.current
        var out: [Double] = []
        let asleep: Set<Int> = [HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                                HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                                HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                                HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue]
        for offset in stride(from: nights, through: 1, by: -1) {
            let morning = cal.startOfDay(for: cal.date(byAdding: .day, value: -(offset - 1), to: Date())!)
            let prev = cal.date(byAdding: .hour, value: -24, to: morning)!
            let pred = HKQuery.predicateForSamples(withStart: prev, end: morning)
            let hours: Double = await withCheckedContinuation { cont in
                let q = HKSampleQuery(sampleType: type, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                    let secs = (samples as? [HKCategorySample])?.filter { asleep.contains($0.value) }
                        .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } ?? 0
                    cont.resume(returning: secs / 3600)
                }
                self.store.execute(q)
            }
            if hours > 0 { out.append(hours) }
        }
        return out
    }
```

- [ ] **Step 2: Build to verify** — run the build command. Expected: `** BUILD SUCCEEDED **` (HealthKit code is not unit-tested; build is the gate). If the app target still references the old engine, this build runs as part of Task 4.

- [ ] **Step 3: Commit**

```bash
git add KAIZENN/Data/HealthKit/HealthKitManager.swift
git commit -m "feat(health): daily HRV/RHR series + multi-night sleep history fetches"
```

---

### Task 4: Baseline provider + wire DashboardView to v2

**Files:**
- Create: `KAIZENN/Features/Readiness/ReadinessBaselineProvider.swift`
- Modify: `KAIZENN/Features/Dashboard/DashboardView.swift` (readiness section + pillar tiles + label localization)
- Modify: `KAIZENN/Core/DesignSystem/KTheme.swift` (add 5 new label localization keys to the `L` table)

**Interfaces — Consumes:** `HealthKitManager.fetchDailySeries`, `fetchSleepHistory`, `ReadinessEngine`, `ReadinessBaseline`. **Produces:**
- `@MainActor final class ReadinessBaselineProvider: ObservableObject { @Published var baseline: ReadinessBaseline; @Published var hrvLnSDNNToday: Double?; @Published var sleepDebtHours: Double; @Published var sleepRegularitySD: Double?; func refresh(health: HealthKitManager) async }`

- [ ] **Step 1: Create the provider** — `KAIZENN/Features/Readiness/ReadinessBaselineProvider.swift`:

```swift
import Foundation
import HealthKit

@MainActor
final class ReadinessBaselineProvider: ObservableObject {
    @Published var baseline = ReadinessBaseline(hrvLnSDNN: nil, restingHR: nil, sleepHours: nil)
    @Published var hrvLnSDNNToday: Double?
    @Published var sleepDebtHours: Double = 0
    @Published var sleepRegularitySD: Double?

    func refresh(health: HealthKitManager) async {
        let sdnn = await health.fetchDailySeries(.heartRateVariabilitySDNN,
                                                 unit: .secondUnit(with: .milli), days: 60)
        let lnSDNN = sdnn.filter { $0 > 0 }.map { Foundation.log($0) }
        let rhr = await health.fetchDailySeries(.restingHeartRate,
                                                unit: HKUnit.count().unitDivided(by: .minute()), days: 60).filter { $0 > 0 }
        let sleep = await health.fetchSleepHistory(nights: 28)

        let need = 8.0
        let last7 = Array(lnSDNN.suffix(7))
        hrvLnSDNNToday = last7.isEmpty ? nil : last7.reduce(0, +) / Double(last7.count)

        let last14 = Array(sleep.suffix(14))
        sleepDebtHours = last14.reduce(0.0) { $0 + max(need - $1, 0) }
        sleepRegularitySD = SignalBaseline.from(last14, minN: 3)?.sd

        baseline = ReadinessBaseline(
            hrvLnSDNN: SignalBaseline.from(lnSDNN),
            restingHR: SignalBaseline.from(rhr),
            sleepHours: SignalBaseline.from(sleep),
            sleepNeed: need
        )
    }
}
```

- [ ] **Step 2: Add label keys to the L table** — in `KAIZENN/Core/DesignSystem/KTheme.swift`, add to the `L` table entries (en/ja) for keys `readiness.primed`, `readiness.ready`, `readiness.moderate`, `readiness.caution`, `readiness.recover`:

```swift
        "readiness.primed":   ["en": "PRIMED",   "ja": "絶好調"],
        "readiness.ready":    ["en": "READY",    "ja": "良好"],
        "readiness.moderate": ["en": "MODERATE", "ja": "普通"],
        "readiness.caution":  ["en": "CAUTION",  "ja": "注意"],
        "readiness.recover":  ["en": "RECOVER",  "ja": "回復優先"],
```

- [ ] **Step 3: Wire DashboardView** — in `DashboardView.swift`:
  1. Add `@StateObject private var readinessBaseline = ReadinessBaselineProvider()`.
  2. Replace `readinessInputs`/`readinessBreakdown` to build v2 `ReadinessInputs` from stores + `readinessBaseline`:

```swift
    private var readinessInputs: ReadinessInputs {
        ReadinessInputs(
            hrvLnSDNNToday: readinessBaseline.hrvLnSDNNToday,
            restingHRToday: healthKitManager.heartRateResting,
            sleepHoursLast: healthKitManager.sleepHoursLast > 0 ? healthKitManager.sleepHoursLast : nil,
            sleepDebtHours: readinessBaseline.sleepDebtHours,
            sleepRegularitySD: readinessBaseline.sleepRegularitySD,
            acuteLoad: loadStore.acuteLoad,
            chronicLoad: loadStore.chronicLoad,
            consumedCalories: consumedCalories,
            calorieTarget: Double(calorieTarget),
            proteinConsumed: nutritionStore.dailyNutrition(for: Date()).totalProteinG,
            proteinTarget: Double(appState.userProfile.macroTargets.proteinG),
            baseline: readinessBaseline.baseline
        )
    }
    private var readinessBreakdown: ReadinessBreakdown { ReadinessEngine.breakdown(for: readinessInputs) }
    var readinessScore: Int { readinessBreakdown.score }
    private var readinessLabel: String {
        switch readinessBreakdown.label {
        case .primed:   return L.t("readiness.primed", lang)
        case .ready:    return L.t("readiness.ready", lang)
        case .moderate: return L.t("readiness.moderate", lang)
        case .caution:  return L.t("readiness.caution", lang)
        case .recover:  return L.t("readiness.recover", lang)
        }
    }
    private var readinessColor: Color { readinessBreakdown.label.color }
```
  3. Remove the obsolete `sleepScore`/`loadScore`/`fuelScore` shims and any reference to the removed `dashboard.readiness.*` keys. Update `pillarsRow` tiles to the new pillars (Recovery/Sleep/Strain/Fuel) using `readinessBreakdown.recovery/sleep/strain/fuel` (show "—" when nil). Update `edgePrompt` to use `readinessBreakdown.sleep`/`.strain` instead of the removed shims (e.g. `if (readinessBreakdown.sleep ?? 100) < 60 { ... }`).
  4. Trigger `await readinessBaseline.refresh(health: healthKitManager)` in the existing `.task` after `fetchAllTodayData()`.

  Before editing, grep for every removed symbol so nothing dangles:
```bash
grep -nE "\b(sleepScore|loadScore|fuelScore|hrvScore|hrvAvailable|dashboard\.readiness)\b" KAIZENN/Features/Dashboard/DashboardView.swift
```

- [ ] **Step 4: Register provider + build**

```bash
ruby docs/superpowers/plans/add_file.rb KAIZENN/Features/Readiness/ReadinessBaselineProvider.swift KAIZENN
```
Run the build command. Expected: `** BUILD SUCCEEDED **`. Then run the test command — engine/baseline tests still PASS.

- [ ] **Step 5: Commit**

```bash
git add KAIZENN/Features/Readiness/ReadinessBaselineProvider.swift KAIZENN/Features/Dashboard/DashboardView.swift KAIZENN/Core/DesignSystem/KTheme.swift KAIZENN.xcodeproj/project.pbxproj
git commit -m "feat(readiness): baseline provider + Home wired to v2 engine + new pillar tiles"
```

---

### Task 5: Update the Readiness Report (Daily pillars, Weekly, Calibrating)

**Files:**
- Modify: `KAIZENN/Features/Readiness/ReadinessReportView.swift`

**Interfaces — Consumes:** `ReadinessEngine`, `ReadinessBaselineProvider`, `ReadinessBreakdown`.

- [ ] **Step 1: Daily view → new pillars + calibrating + baseline context.** Rework `ReadinessDailyView` to build the same v2 `ReadinessInputs` (inject a `ReadinessBaselineProvider` via `@EnvironmentObject`; `DashboardView` passes it into the sheet's environment) and render **Recovery / Sleep / Strain / Fuel** rows from `breakdown.recovery/sleep/strain/fuel` (each `Int(value)` or "—" when nil). When `breakdown.isCalibrating`, show a banner: `Text("Calibrating — learning your baseline (first \(ReadinessBaseline.minDays) days)")` in `KTheme.Colors.textTertiary`, and a one-line "Scored vs your 60-day normal" caption otherwise.

```swift
// pillar rows (replace Sleep/Load/Fuel/HRV rows):
pillarRow("Recovery", value: b.recovery, detail: hrvText, tint: KTheme.Colors.accentPrimary)
pillarRow("Sleep",    value: b.sleep,    detail: String(format: "%.1fh", inputs.sleepHoursLast ?? 0), tint: KTheme.Colors.accentTertiary)
pillarRow("Strain",   value: b.strain,   detail: inputs.chronicLoad > 0 ? String(format: "%.0f%% of normal", inputs.acuteLoad / inputs.chronicLoad * 100) : "—", tint: KTheme.Colors.accentAmber)
pillarRow("Fuel",     value: b.fuel,     detail: "\(Int(inputs.consumedCalories)) / \(Int(inputs.calorieTarget)) kcal", tint: KTheme.Colors.accentSecondary)
// pillarRow takes value: Double? and renders "—" when nil.
```

- [ ] **Step 2: Weekly view labels.** Rename the weekly trend cards so they read against the new model: "Recovery — HRV trend" (keep the existing weight/load/fuel sparklines as-is; they remain valid data series). Update only the section title strings; no data-source change required.

- [ ] **Step 3: Build + on-device verify.** Run the build command → `** BUILD SUCCEEDED **`. Then deploy to Juls (device build per `reference_kaizenn_sim_verify` / device UDID `00008120-001C54C23423A01E`) and confirm: Home shows a Recovery-led score; tapping the ring shows the new pillar rows; a profile with <14 days of data shows the Calibrating banner.

- [ ] **Step 4: Commit**

```bash
git add KAIZENN/Features/Readiness/ReadinessReportView.swift
git commit -m "feat(readiness): report shows v2 pillars + calibrating state"
```

---

## Self-Review

- **Spec coverage:** new pillars (Tasks 2,4,5) ✓; baseline-relative z-scoring (Task 2) ✓; HRV ln(SDNN) 7-day rolling vs 60-day baseline (Tasks 3,4) ✓; RHR trend (Tasks 2,4) ✓; sleep debt+regularity (Tasks 3,4) ✓; Strain from existing external load, no ACWR gate (Task 2) ✓; Fuel demoted (Task 2 weights) ✓; missing-data renormalization (Task 2) ✓; Calibrating cold-start (Task 2 fallback + Task 5 banner) ✓; engine stays pure/HealthKit-free (baselines passed in) ✓; SDNN-not-RMSSD documented (Global Constraints + provider) ✓; tunable constants ✓.
- **Placeholder scan:** none — every step has real code or an exact command. The "fix call sites" parts (Task 4 Step 3) name each symbol + the grep to find them.
- **Type consistency:** `ReadinessInputs`/`ReadinessBreakdown`/`ReadinessLabel`/`SignalBaseline`/`ReadinessBaseline`/`ReadinessBaselineProvider` names + signatures match across Tasks 1→5. `sub(z:)`, `zScore(_:_:)`, `recoveryScore/sleepScore/strainScore/fuelScore`, `breakdown(for:)` consistent.
- **Cross-file build ordering note (called out in Task 2 Step 4):** rewriting the engine breaks the app target until Tasks 4–5; the test target validates the engine independently first. Tasks 2→4→5 form one red→green arc; commit per task but expect the app to compile green only at Task 4.
