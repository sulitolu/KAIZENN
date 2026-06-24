# HealthKit Data Ingestion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist daily HealthKit data (HRV/RHR/sleep/workouts) into a durable on-device store, refreshed automatically each day, so the existing Readiness engine and ACWR run on real rolling baselines instead of transient reads.

**Architecture:** A new SwiftData store (`HealthStore`) holds one `DailyHealthSnapshot` per day plus `WorkoutRecord`s. A `HealthIngestionService` reads HealthKit through a `HealthDataSource` protocol (real impl wraps `HKHealthStore`; a fake drives tests) and upserts into the store. A pure `BaselineCalculator` turns snapshot history into the existing `ReadinessBaseline`/`SignalBaseline` types feeding `ReadinessBaselineProvider`. `LoadStore` additionally consumes `WorkoutRecord`s for ACWR. A `BackgroundSyncScheduler` (BGTask) runs the sync each morning.

**Tech Stack:** Swift 5, SwiftUI, SwiftData (new to this project; iOS 17 target), HealthKit, BackgroundTasks, XCTest.

## Global Constraints

- iOS deployment target **17.0**; Swift version **5.0** (copied from project.pbxproj — do not raise).
- Tests use **XCTest** (`import XCTest` / `@testable import KAIZENN`), NOT Swift Testing.
- Persistence convention elsewhere is UserDefaults+Codable; SwiftData is introduced **only** for `HealthStore` and must not touch `ActivityStore`/`LoadStore`/`WeightStore` storage.
- HealthKit entitlements and `UIBackgroundModes` (`fetch`, `processing`) already exist — do not duplicate.
- All new HealthKit-facing types are `@MainActor` where they touch `HealthKitManager`/UI, matching `HealthKitManager` (`@MainActor class ... ObservableObject`).
- Missing data is `nil` (gap day = no snapshot row / nil field); never write `0` as a stand-in.

## Deviation from spec (intentional)

The spec (`docs/superpowers/specs/2026-06-24-healthkit-ingestion-design.md`) specified `HKAnchoredObjectQuery` + a `SyncAnchor` model. Daily metrics (HRV/RHR/sleep/steps/energy) are *aggregates*, not individual samples, so anchored queries are the wrong tool; the existing code already uses statistics-style reads. This plan instead does a **bounded re-read of the last N days + idempotent upsert keyed by `dayKey`**, which is simpler and self-healing (no anchor to corrupt). Workouts are deduped by HealthKit UUID. `SyncAnchor` is dropped. Everything else in the spec stands.

## File Structure

| File | Responsibility |
|---|---|
| `KAIZENN/Data/HealthStore/HealthModels.swift` (create) | SwiftData `@Model`s: `DailyHealthSnapshot`, `WorkoutRecord` |
| `KAIZENN/Data/HealthStore/HealthStore.swift` (create) | Owns `ModelContainer`; upsert/query for snapshots & workouts |
| `KAIZENN/Data/HealthStore/BaselineCalculator.swift` (create) | Pure: `[DailyHealthSnapshot]` → `ReadinessBaseline` |
| `KAIZENN/Data/HealthStore/HealthDataSource.swift` (create) | Protocol + DTOs + `HealthKitDataSource` real impl |
| `KAIZENN/Data/HealthStore/HealthIngestionService.swift` (create) | Pull via source → upsert into `HealthStore` |
| `KAIZENN/Data/HealthStore/BackgroundSyncScheduler.swift` (create) | Register/handle the daily `BGTask` |
| `KAIZENN/Data/Persistence/LoadStore.swift` (modify) | Fold `WorkoutRecord`s into ACWR with ±30-min dedup |
| `KAIZENN/Features/Readiness/ReadinessBaselineProvider.swift` (modify) | `refresh(from:)` builds baseline via `BaselineCalculator` |
| `KAIZENN/App/KAIZENNApp.swift` (modify) | Inject store/service; register BGTask; sync on launch |
| `KAIZENN/Info.plist` (modify) | Add `BGTaskSchedulerPermittedIdentifiers` |
| `KAIZENNTests/HealthStoreTests.swift` (create) | Store upsert/query tests |
| `KAIZENNTests/BaselineCalculatorTests.swift` (create) | Baseline math tests |
| `KAIZENNTests/HealthIngestionServiceTests.swift` (create) | Ingestion + fake source tests |
| `KAIZENNTests/LoadStoreWorkoutTests.swift` (create) | ACWR dedup tests |

---

### Task 1: HealthStore SwiftData models + store

**Files:**
- Create: `KAIZENN/Data/HealthStore/HealthModels.swift`
- Create: `KAIZENN/Data/HealthStore/HealthStore.swift`
- Test: `KAIZENNTests/HealthStoreTests.swift`

**Interfaces:**
- Produces:
  - `DailyHealthSnapshot` (`@Model`, fields below; `dayKey: String` unique)
  - `WorkoutRecord` (`@Model`; `hkUUID: String` unique)
  - `HealthStore` (`@MainActor`, `ObservableObject`): `init(inMemory: Bool = false)`, `func upsertSnapshot(date: Date, _ mutate: (DailyHealthSnapshot) -> Void)`, `func snapshots(since: Date) -> [DailyHealthSnapshot]`, `func upsertWorkout(_ dto: WorkoutSampleDTO)` *(DTO defined in Task 3; for this task add `upsertWorkout(uuid:type:start:durationMinutes:activeEnergy:distanceMeters:source:)`)*, `func workouts(since: Date) -> [WorkoutRecord]`, `static func dayKey(for date: Date) -> String`

- [ ] **Step 1: Write the models**

```swift
// KAIZENN/Data/HealthStore/HealthModels.swift
import Foundation
import SwiftData

@Model
final class DailyHealthSnapshot {
    @Attribute(.unique) var dayKey: String   // "yyyy-MM-dd", user's calendar
    var date: Date
    var hrvSDNN: Double?                      // ms
    var restingHR: Double?                    // bpm
    var sleepDurationMinutes: Double?
    var remMinutes: Double?
    var coreMinutes: Double?
    var deepMinutes: Double?
    var steps: Int?
    var activeEnergy: Double?                 // kcal

    init(dayKey: String, date: Date) {
        self.dayKey = dayKey
        self.date = date
    }
}

@Model
final class WorkoutRecord {
    @Attribute(.unique) var hkUUID: String
    var type: String
    var start: Date
    var durationMinutes: Double
    var activeEnergy: Double
    var distanceMeters: Double
    var source: String

    init(hkUUID: String, type: String, start: Date, durationMinutes: Double,
         activeEnergy: Double, distanceMeters: Double, source: String) {
        self.hkUUID = hkUUID
        self.type = type
        self.start = start
        self.durationMinutes = durationMinutes
        self.activeEnergy = activeEnergy
        self.distanceMeters = distanceMeters
        self.source = source
    }
}
```

- [ ] **Step 2: Write the failing test**

```swift
// KAIZENNTests/HealthStoreTests.swift
import XCTest
@testable import KAIZENN

@MainActor
final class HealthStoreTests: XCTestCase {
    func test_upsertSnapshot_isIdempotentPerDay() {
        let store = HealthStore(inMemory: true)
        let day = Date(timeIntervalSince1970: 1_700_000_000)

        store.upsertSnapshot(date: day) { $0.hrvSDNN = 45 }
        store.upsertSnapshot(date: day) { $0.restingHR = 52 }   // same day → update, not insert

        let rows = store.snapshots(since: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.hrvSDNN, 45)
        XCTAssertEqual(rows.first?.restingHR, 52)
    }

    func test_upsertWorkout_dedupsByUUID() {
        let store = HealthStore(inMemory: true)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        store.upsertWorkout(uuid: "A", type: "running", start: start,
                            durationMinutes: 30, activeEnergy: 300, distanceMeters: 5000, source: "Watch")
        store.upsertWorkout(uuid: "A", type: "running", start: start,
                            durationMinutes: 31, activeEnergy: 310, distanceMeters: 5100, source: "Watch")

        let rows = store.workouts(since: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.durationMinutes, 31)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run (Cmd-U in Xcode, or terminal):
```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN" && xcodebuild test -scheme KAIZENN -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:KAIZENNTests/HealthStoreTests 2>&1 | tail -20
```
Expected: FAIL — `cannot find 'HealthStore' in scope`.

- [ ] **Step 4: Write HealthStore**

```swift
// KAIZENN/Data/HealthStore/HealthStore.swift
import Foundation
import SwiftData

@MainActor
final class HealthStore: ObservableObject {
    let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(inMemory: Bool = false) {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(
                for: DailyHealthSnapshot.self, WorkoutRecord.self,
                configurations: config)
        } catch {
            fatalError("HealthStore ModelContainer failed: \(error)")
        }
    }

    static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    func upsertSnapshot(date: Date, _ mutate: (DailyHealthSnapshot) -> Void) {
        let key = Self.dayKey(for: date)
        let descriptor = FetchDescriptor<DailyHealthSnapshot>(
            predicate: #Predicate { $0.dayKey == key })
        let existing = (try? context.fetch(descriptor))?.first
        let snapshot = existing ?? DailyHealthSnapshot(dayKey: key, date: date)
        if existing == nil { context.insert(snapshot) }
        mutate(snapshot)
        try? context.save()
    }

    func snapshots(since: Date) -> [DailyHealthSnapshot] {
        let descriptor = FetchDescriptor<DailyHealthSnapshot>(
            predicate: #Predicate { $0.date >= since },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func upsertWorkout(uuid: String, type: String, start: Date, durationMinutes: Double,
                       activeEnergy: Double, distanceMeters: Double, source: String) {
        let descriptor = FetchDescriptor<WorkoutRecord>(
            predicate: #Predicate { $0.hkUUID == uuid })
        let existing = (try? context.fetch(descriptor))?.first
        if let w = existing {
            w.type = type; w.start = start; w.durationMinutes = durationMinutes
            w.activeEnergy = activeEnergy; w.distanceMeters = distanceMeters; w.source = source
        } else {
            context.insert(WorkoutRecord(hkUUID: uuid, type: type, start: start,
                durationMinutes: durationMinutes, activeEnergy: activeEnergy,
                distanceMeters: distanceMeters, source: source))
        }
        try? context.save()
    }

    func workouts(since: Date) -> [WorkoutRecord] {
        let descriptor = FetchDescriptor<WorkoutRecord>(
            predicate: #Predicate { $0.start >= since },
            sortBy: [SortDescriptor(\.start, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }
}
```

- [ ] **Step 5: Add both new files to the Xcode target**

The new files under `KAIZENN/Data/HealthStore/` must be members of the `KAIZENN` target (and the test must compile against them). In Xcode: select the files → File Inspector → Target Membership → check `KAIZENN`. (If using a project that auto-includes folder groups, confirm they appear in the target's Compile Sources.)

- [ ] **Step 6: Run test to verify it passes**

Run:
```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN" && xcodebuild test -scheme KAIZENN -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:KAIZENNTests/HealthStoreTests 2>&1 | tail -20
```
Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN" && git add KAIZENN/Data/HealthStore/HealthModels.swift KAIZENN/Data/HealthStore/HealthStore.swift KAIZENNTests/HealthStoreTests.swift && git commit -m "feat: SwiftData HealthStore for daily snapshots + workouts"
```

---

### Task 2: BaselineCalculator (pure rolling baselines)

**Files:**
- Create: `KAIZENN/Data/HealthStore/BaselineCalculator.swift`
- Test: `KAIZENNTests/BaselineCalculatorTests.swift`

**Interfaces:**
- Consumes: `DailyHealthSnapshot` (Task 1); `ReadinessBaseline`, `SignalBaseline` (existing — `SignalBaseline(mean:sd:n:)`, `ReadinessBaseline(hrvLnSDNN:restingHR:sleepHours:)`).
- Produces: `enum BaselineCalculator { static func signalBaseline(_ values: [Double]) -> SignalBaseline?; static func baseline(from snapshots: [DailyHealthSnapshot], window: Int = 60) -> ReadinessBaseline; static func latestHRVLnSDNN(from snapshots: [DailyHealthSnapshot], days: Int = 7) -> Double? }`

- [ ] **Step 1: Write the failing test**

```swift
// KAIZENNTests/BaselineCalculatorTests.swift
import XCTest
import Foundation
@testable import KAIZENN

@MainActor
final class BaselineCalculatorTests: XCTestCase {
    private func snap(_ daysAgo: Int, hrv: Double?, rhr: Double?, sleepMin: Double?) -> DailyHealthSnapshot {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let s = DailyHealthSnapshot(dayKey: HealthStore.dayKey(for: date), date: date)
        s.hrvSDNN = hrv; s.restingHR = rhr; s.sleepDurationMinutes = sleepMin
        return s
    }

    func test_signalBaseline_meanAndSD() {
        let b = BaselineCalculator.signalBaseline([2, 4, 6])
        XCTAssertEqual(b?.mean ?? 0, 4, accuracy: 0.0001)
        XCTAssertEqual(b?.sd ?? 0, 2, accuracy: 0.0001)   // sample SD, n-1
        XCTAssertEqual(b?.n, 3)
    }

    func test_signalBaseline_emptyIsNil() {
        XCTAssertNil(BaselineCalculator.signalBaseline([]))
    }

    func test_baseline_skipsGapDays_andLogsHRV() {
        let snaps = [
            snap(1, hrv: 50, rhr: 52, sleepMin: 420),
            snap(2, hrv: nil, rhr: nil, sleepMin: nil),   // gap day — ignored
            snap(3, hrv: 50, rhr: 54, sleepMin: 480),
        ]
        let base = BaselineCalculator.baseline(from: snaps)
        XCTAssertEqual(base.hrvLnSDNN?.n, 2)               // gap day excluded
        XCTAssertEqual(base.hrvLnSDNN?.mean ?? 0, log(50), accuracy: 0.0001)  // ln transform
        XCTAssertEqual(base.sleepHours?.mean ?? 0, 7.5, accuracy: 0.0001)     // (7+8)/2 hours
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN" && xcodebuild test -scheme KAIZENN -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:KAIZENNTests/BaselineCalculatorTests 2>&1 | tail -20
```
Expected: FAIL — `cannot find 'BaselineCalculator' in scope`.

- [ ] **Step 3: Write BaselineCalculator**

```swift
// KAIZENN/Data/HealthStore/BaselineCalculator.swift
import Foundation

enum BaselineCalculator {
    /// Sample mean + sample SD (n-1). Returns nil for empty input.
    static func signalBaseline(_ values: [Double]) -> SignalBaseline? {
        guard !values.isEmpty else { return nil }
        let n = values.count
        let mean = values.reduce(0, +) / Double(n)
        let sd: Double
        if n > 1 {
            let ss = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
            sd = (ss / Double(n - 1)).squareRoot()
        } else {
            sd = 0
        }
        return SignalBaseline(mean: mean, sd: sd, n: n)
    }

    /// Build rolling baselines from the most-recent `window` snapshots, skipping gap days.
    static func baseline(from snapshots: [DailyHealthSnapshot], window: Int = 60) -> ReadinessBaseline {
        let recent = snapshots.sorted { $0.date > $1.date }.prefix(window)
        let hrvLn = recent.compactMap { $0.hrvSDNN }.filter { $0 > 0 }.map { Foundation.log($0) }
        let rhr = recent.compactMap { $0.restingHR }
        let sleepHrs = recent.compactMap { $0.sleepDurationMinutes }.map { $0 / 60.0 }
        return ReadinessBaseline(
            hrvLnSDNN: signalBaseline(hrvLn),
            restingHR: signalBaseline(rhr),
            sleepHours: signalBaseline(sleepHrs))
    }

    /// ln of the average SDNN over the last `days` snapshots (today's signal for the engine).
    static func latestHRVLnSDNN(from snapshots: [DailyHealthSnapshot], days: Int = 7) -> Double? {
        let recent = snapshots.sorted { $0.date > $1.date }.prefix(days)
        let vals = recent.compactMap { $0.hrvSDNN }.filter { $0 > 0 }
        guard !vals.isEmpty else { return nil }
        return Foundation.log(vals.reduce(0, +) / Double(vals.count))
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN" && xcodebuild test -scheme KAIZENN -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:KAIZENNTests/BaselineCalculatorTests 2>&1 | tail -20
```
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN" && git add KAIZENN/Data/HealthStore/BaselineCalculator.swift KAIZENNTests/BaselineCalculatorTests.swift && git commit -m "feat: BaselineCalculator builds rolling ReadinessBaseline from snapshots"
```

---

### Task 3: HealthIngestionService (+ HealthDataSource protocol, DTOs, fake)

**Files:**
- Create: `KAIZENN/Data/HealthStore/HealthDataSource.swift`
- Create: `KAIZENN/Data/HealthStore/HealthIngestionService.swift`
- Test: `KAIZENNTests/HealthIngestionServiceTests.swift`

**Interfaces:**
- Consumes: `HealthStore` (Task 1).
- Produces:
  - `enum HealthMetric { case hrvSDNN, restingHR, sleepMinutes, steps, activeEnergy }`
  - `struct DailyMetricSample { let date: Date; let value: Double }`
  - `struct WorkoutSampleDTO { let uuid: String; let type: String; let start: Date; let durationMinutes: Double; let activeEnergy: Double; let distanceMeters: Double; let source: String }`
  - `protocol HealthDataSource { func dailyValues(_ metric: HealthMetric, days: Int) async throws -> [DailyMetricSample]; func workouts(since: Date) async throws -> [WorkoutSampleDTO] }`
  - `final class HealthIngestionService` (`@MainActor`): `init(store: HealthStore, source: HealthDataSource)`, `func syncNow(days: Int = 14) async`

- [ ] **Step 1: Write the protocol, DTOs, and a fake (in the source file + test file)**

```swift
// KAIZENN/Data/HealthStore/HealthDataSource.swift
import Foundation

enum HealthMetric: CaseIterable {
    case hrvSDNN, restingHR, sleepMinutes, steps, activeEnergy
}

struct DailyMetricSample {
    let date: Date
    let value: Double
}

struct WorkoutSampleDTO {
    let uuid: String
    let type: String
    let start: Date
    let durationMinutes: Double
    let activeEnergy: Double
    let distanceMeters: Double
    let source: String
}

protocol HealthDataSource {
    /// One value per day for `metric` over the last `days` days (gap days simply omitted).
    func dailyValues(_ metric: HealthMetric, days: Int) async throws -> [DailyMetricSample]
    func workouts(since: Date) async throws -> [WorkoutSampleDTO]
}
```

- [ ] **Step 2: Write the failing test (with fake source)**

```swift
// KAIZENNTests/HealthIngestionServiceTests.swift
import XCTest
@testable import KAIZENN

@MainActor
final class HealthIngestionServiceTests: XCTestCase {
    /// Fake that returns canned values and can be told to throw for one metric (per-type isolation test).
    final class FakeSource: HealthDataSource {
        var values: [HealthMetric: [DailyMetricSample]] = [:]
        var workoutList: [WorkoutSampleDTO] = []
        var throwingMetric: HealthMetric?

        func dailyValues(_ metric: HealthMetric, days: Int) async throws -> [DailyMetricSample] {
            if metric == throwingMetric { throw NSError(domain: "test", code: 1) }
            return values[metric] ?? []
        }
        func workouts(since: Date) async throws -> [WorkoutSampleDTO] { workoutList }
    }

    func test_syncNow_writesSnapshotsAndWorkouts() async {
        let store = HealthStore(inMemory: true)
        let source = FakeSource()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        source.values[.hrvSDNN] = [DailyMetricSample(date: day, value: 48)]
        source.values[.restingHR] = [DailyMetricSample(date: day, value: 53)]
        source.workoutList = [WorkoutSampleDTO(uuid: "W1", type: "running", start: day,
            durationMinutes: 30, activeEnergy: 320, distanceMeters: 6000, source: "Watch")]

        let service = HealthIngestionService(store: store, source: source)
        await service.syncNow(days: 14)

        let snaps = store.snapshots(since: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(snaps.count, 1)
        XCTAssertEqual(snaps.first?.hrvSDNN, 48)
        XCTAssertEqual(snaps.first?.restingHR, 53)
        XCTAssertEqual(store.workouts(since: Date(timeIntervalSince1970: 0)).count, 1)
    }

    func test_syncNow_oneMetricFailing_doesNotAbortOthers() async {
        let store = HealthStore(inMemory: true)
        let source = FakeSource()
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        source.throwingMetric = .hrvSDNN
        source.values[.restingHR] = [DailyMetricSample(date: day, value: 53)]

        let service = HealthIngestionService(store: store, source: source)
        await service.syncNow(days: 14)

        let snaps = store.snapshots(since: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(snaps.first?.restingHR, 53)   // RHR survived despite HRV throwing
        XCTAssertNil(snaps.first?.hrvSDNN)
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN" && xcodebuild test -scheme KAIZENN -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:KAIZENNTests/HealthIngestionServiceTests 2>&1 | tail -20
```
Expected: FAIL — `cannot find 'HealthIngestionService' in scope`.

- [ ] **Step 4: Write HealthIngestionService**

```swift
// KAIZENN/Data/HealthStore/HealthIngestionService.swift
import Foundation

@MainActor
final class HealthIngestionService: ObservableObject {
    private let store: HealthStore
    private let source: HealthDataSource

    init(store: HealthStore, source: HealthDataSource) {
        self.store = store
        self.source = source
    }

    /// Pull the last `days` of daily metrics + workouts and upsert. Per-metric isolation:
    /// one metric throwing does not abort the rest.
    func syncNow(days: Int = 14) async {
        for metric in HealthMetric.allCases {
            do {
                let samples = try await source.dailyValues(metric, days: days)
                for sample in samples {
                    store.upsertSnapshot(date: sample.date) { snap in
                        apply(metric, value: sample.value, to: snap)
                    }
                }
            } catch {
                // Log + continue; gap stays nil. (Logging hook intentionally minimal.)
                continue
            }
        }

        do {
            let since = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            for w in try await source.workouts(since: since) {
                store.upsertWorkout(uuid: w.uuid, type: w.type, start: w.start,
                    durationMinutes: w.durationMinutes, activeEnergy: w.activeEnergy,
                    distanceMeters: w.distanceMeters, source: w.source)
            }
        } catch {
            // ignore — workouts retried next sync
        }
    }

    private func apply(_ metric: HealthMetric, value: Double, to snap: DailyHealthSnapshot) {
        switch metric {
        case .hrvSDNN:      snap.hrvSDNN = value
        case .restingHR:    snap.restingHR = value
        case .sleepMinutes: snap.sleepDurationMinutes = value
        case .steps:        snap.steps = Int(value)
        case .activeEnergy: snap.activeEnergy = value
        }
    }
}
```

- [ ] **Step 5: Add new files to the `KAIZENN` target** (Target Membership, as in Task 1 Step 5).

- [ ] **Step 6: Run test to verify it passes**

```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN" && xcodebuild test -scheme KAIZENN -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:KAIZENNTests/HealthIngestionServiceTests 2>&1 | tail -20
```
Expected: PASS (2 tests).

- [ ] **Step 7: Commit**

```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN" && git add KAIZENN/Data/HealthStore/HealthDataSource.swift KAIZENN/Data/HealthStore/HealthIngestionService.swift KAIZENNTests/HealthIngestionServiceTests.swift && git commit -m "feat: HealthIngestionService upserts daily metrics + workouts with per-metric isolation"
```

---

### Task 4: ACWR workout integration + ±30-min dedup in LoadStore

**Files:**
- Modify: `KAIZENN/Data/Persistence/LoadStore.swift` (recalc currently at lines 44–63)
- Test: `KAIZENNTests/LoadStoreWorkoutTests.swift`

**Interfaces:**
- Consumes: `WorkoutRecord` (Task 1); `GPSSession.sessionLoad`/`.date`, `StrengthSession.sessionLoad`/`.date` (existing).
- Produces: `LoadStore.setHealthWorkouts(_ workouts: [WorkoutRecord])` — stores them and re-runs `recalculate()`. A workout is **deduped** (excluded from load) if it overlaps any manual session within ±30 min of start. Its load proxy: `activeEnergy / 100` (kcal → load units, matching strength's `volume/1000` order of magnitude). Manual sessions always win.

- [ ] **Step 1: Write the failing test**

```swift
// KAIZENNTests/LoadStoreWorkoutTests.swift
import XCTest
@testable import KAIZENN

@MainActor
final class LoadStoreWorkoutTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: GPSSession.storageKey)
        UserDefaults.standard.removeObject(forKey: StrengthSession.storageKey)
    }
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: GPSSession.storageKey)
        UserDefaults.standard.removeObject(forKey: StrengthSession.storageKey)
        super.tearDown()
    }

    private func workout(uuid: String, daysAgo: Int, energy: Double) -> WorkoutRecord {
        let start = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return WorkoutRecord(hkUUID: uuid, type: "running", start: start,
            durationMinutes: 30, activeEnergy: energy, distanceMeters: 5000, source: "Watch")
    }

    func test_nonOverlappingWorkout_addsToAcuteLoad() {
        let store = LoadStore()
        let before = store.acuteLoad
        store.setHealthWorkouts([workout(uuid: "A", daysAgo: 1, energy: 500)])  // 500/100 = 5
        XCTAssertEqual(store.acuteLoad, before + 5, accuracy: 0.0001)
    }

    func test_workoutOverlappingManualSession_isDeduped() {
        let store = LoadStore()
        var gps = GPSSession()
        gps.date = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        store.addGPSSession(gps)                                   // manual session
        let baseline = store.acuteLoad

        // Watch workout within ±30 min of the manual session → should NOT add.
        let overlap = WorkoutRecord(hkUUID: "B", type: "running",
            start: gps.date.addingTimeInterval(10 * 60),
            durationMinutes: 30, activeEnergy: 500, distanceMeters: 5000, source: "Watch")
        store.setHealthWorkouts([overlap])
        XCTAssertEqual(store.acuteLoad, baseline, accuracy: 0.0001)  // deduped, manual wins
    }
}
```

> Note: this test calls `store.addGPSSession(_:)`. Confirm the existing public mutator name in `LoadStore.swift` (the agent report shows `gpsSessions` is `private(set)`, so a public `addGPSSession`/`add(_:)` exists). If the real method differs, adjust the test call to match — do not add a new mutator.

- [ ] **Step 2: Run test to verify it fails**

```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN" && xcodebuild test -scheme KAIZENN -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:KAIZENNTests/LoadStoreWorkoutTests 2>&1 | tail -20
```
Expected: FAIL — `value of type 'LoadStore' has no member 'setHealthWorkouts'`.

- [ ] **Step 3: Modify LoadStore**

Add a stored property near the other `@Published` lines (after line 9):
```swift
@Published private(set) var healthWorkouts: [WorkoutRecord] = []
```

Add the setter (anywhere in the class body):
```swift
func setHealthWorkouts(_ workouts: [WorkoutRecord]) {
    healthWorkouts = workouts
    recalculate()
}

/// A HealthKit workout counts toward load only if it does NOT overlap a manual
/// session (±30 min of start). Manual sessions always win (richer GPS/load data).
private func nonDuplicateWorkoutLoad(since cutoff: Date) -> Double {
    let window: TimeInterval = 30 * 60
    let manualDates = gpsSessions.map(\.date) + strengthSessions.map(\.date)
    return healthWorkouts
        .filter { $0.start >= cutoff }
        .filter { w in !manualDates.contains { abs($0.timeIntervalSince(w.start)) <= window } }
        .map { $0.activeEnergy / 100 }
        .reduce(0, +)
}
```

In `recalculate()`, fold the workout load into both windows. Change the acute block:
```swift
    let gpsAcute = gpsSessions.filter { $0.date >= cutoff7 }.map(\.sessionLoad).reduce(0, +)
    let strengthAcute = strengthSessions.filter { $0.date >= cutoff7 }.map(\.sessionLoad).reduce(0, +)
    acuteLoad = gpsAcute + strengthAcute + nonDuplicateWorkoutLoad(since: cutoff7)
```
And the chronic block:
```swift
    let gpsChronic28 = gpsSessions.filter { $0.date >= cutoff28 }.map(\.sessionLoad).reduce(0, +)
    let strengthChronic28 = strengthSessions.filter { $0.date >= cutoff28 }.map(\.sessionLoad).reduce(0, +)
    chronicLoad = (gpsChronic28 + strengthChronic28 + nonDuplicateWorkoutLoad(since: cutoff28)) / 4
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN" && xcodebuild test -scheme KAIZENN -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:KAIZENNTests/LoadStoreWorkoutTests 2>&1 | tail -20
```
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN" && git add KAIZENN/Data/Persistence/LoadStore.swift KAIZENNTests/LoadStoreWorkoutTests.swift && git commit -m "feat: fold HealthKit workouts into ACWR with ±30-min manual-session dedup"
```

---

### Task 5: Wire ReadinessBaselineProvider to BaselineCalculator + root injection

**Files:**
- Modify: `KAIZENN/Features/Readiness/ReadinessBaselineProvider.swift` (declared lines 6–11; `inputs(...)` lines 39–56)
- Modify: `KAIZENN/App/KAIZENNApp.swift` (root injection, lines 6–43)
- Modify: views that currently create their own `@StateObject` provider (DashboardView, CoachView per the interface report) → receive it as `@EnvironmentObject` instead.

**Interfaces:**
- Consumes: `HealthStore` (Task 1), `BaselineCalculator` (Task 2).
- Produces: `ReadinessBaselineProvider.refresh(from store: HealthStore)` — sets `baseline` and `hrvLnSDNNToday` from snapshot history. Provider becomes a single root-injected `@StateObject`.

- [ ] **Step 1: Add `refresh(from:)` to ReadinessBaselineProvider**

```swift
// In ReadinessBaselineProvider.swift, add inside the class:
func refresh(from store: HealthStore) {
    let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
    let snaps = store.snapshots(since: cutoff)
    baseline = BaselineCalculator.baseline(from: snaps)
    hrvLnSDNNToday = BaselineCalculator.latestHRVLnSDNN(from: snaps)
}
```

- [ ] **Step 2: Inject provider + store at root**

In `KAIZENNApp.swift`, add to the `@StateObject` block (after line 12):
```swift
    @StateObject private var healthStore = HealthStore()
    @StateObject private var baselineProvider = ReadinessBaselineProvider()
```
Add to the `RootView()` modifier chain (after `.environmentObject(loadStore)`):
```swift
            .environmentObject(healthStore)
            .environmentObject(baselineProvider)
```

- [ ] **Step 3: Remove the per-view `@StateObject` duplicates**

In each view that currently declares its own `@StateObject ... ReadinessBaselineProvider` (DashboardView, CoachView), change it to:
```swift
@EnvironmentObject var readinessBaseline: ReadinessBaselineProvider
```
so all surfaces share the one root instance. (Search: `ReadinessBaselineProvider()`.)

- [ ] **Step 4: Build to verify wiring compiles**

```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN" && xcodebuild build -scheme KAIZENN -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -15
```
Expected: `BUILD SUCCEEDED`. (No new unit test — this is wiring; behavior is covered by Tasks 2 and the device check in Task 6.)

- [ ] **Step 5: Commit**

```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN" && git add KAIZENN/Features/Readiness/ReadinessBaselineProvider.swift KAIZENN/App/KAIZENNApp.swift KAIZENN/Features 2>/dev/null; git commit -m "feat: feed ReadinessBaselineProvider from HealthStore history; inject at root"
```

---

### Task 6: Real HealthKitDataSource + BackgroundSyncScheduler + app wiring (device-verified)

**Files:**
- Modify: `KAIZENN/Data/HealthStore/HealthDataSource.swift` (add `HealthKitDataSource`)
- Create: `KAIZENN/Data/HealthStore/BackgroundSyncScheduler.swift`
- Modify: `KAIZENN/Info.plist` (add `BGTaskSchedulerPermittedIdentifiers`)
- Modify: `KAIZENN/App/KAIZENNApp.swift` (instantiate service, register BGTask, sync on launch)

**Interfaces:**
- Consumes: `HealthStore`, `HealthIngestionService`, `HealthDataSource`, `ReadinessBaselineProvider`.
- Produces: `final class HealthKitDataSource: HealthDataSource`; `enum BackgroundSyncScheduler { static let taskID = "com.kaizenn.healthsync"; static func register(handler: @escaping () async -> Void); static func schedule() }`.

- [ ] **Step 1: Add the BGTask identifier to Info.plist**

In `KAIZENN/Info.plist`, add (sibling of the existing `UIBackgroundModes`):
```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.kaizenn.healthsync</string>
</array>
```

- [ ] **Step 2: Implement `HealthKitDataSource`**

Append to `HealthDataSource.swift`. Uses `HKStatisticsCollectionQuery` for per-day aggregates and an `HKSampleQuery` for workouts. (This glue is verified on device, not unit-tested — it wraps `HKHealthStore`.)

```swift
import HealthKit

final class HealthKitDataSource: HealthDataSource {
    private let store = HKHealthStore()

    func dailyValues(_ metric: HealthMetric, days: Int) async throws -> [DailyMetricSample] {
        switch metric {
        case .hrvSDNN:      return try await dailyQuantity(.heartRateVariabilitySDNN,
                                unit: .secondUnit(with: .milli), options: .discreteAverage, days: days)
        case .restingHR:    return try await dailyQuantity(.restingHeartRate,
                                unit: HKUnit.count().unitDivided(by: .minute()), options: .discreteAverage, days: days)
        case .steps:        return try await dailyQuantity(.stepCount,
                                unit: .count(), options: .cumulativeSum, days: days)
        case .activeEnergy: return try await dailyQuantity(.activeEnergyBurned,
                                unit: .kilocalorie(), options: .cumulativeSum, days: days)
        case .sleepMinutes: return try await dailySleepMinutes(days: days)
        }
    }

    private func dailyQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit,
                               options: HKStatisticsOptions, days: Int) async throws -> [DailyMetricSample] {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return [] }
        let cal = Calendar.current
        let end = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -days, to: end) else { return [] }
        var comps = DateComponents(); comps.day = 1

        return try await withCheckedThrowingContinuation { cont in
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: nil,
                options: options, anchorDate: start, intervalComponents: comps)
            q.initialResultsHandler = { _, results, error in
                if let error { cont.resume(throwing: error); return }
                var out: [DailyMetricSample] = []
                results?.enumerateStatistics(from: start, to: end) { stat, _ in
                    let q = options.contains(.cumulativeSum) ? stat.sumQuantity() : stat.averageQuantity()
                    if let q { out.append(DailyMetricSample(date: stat.startDate, value: q.doubleValue(for: unit))) }
                }
                cont.resume(returning: out)
            }
            store.execute(q)
        }
    }

    private func dailySleepMinutes(days: Int) async throws -> [DailyMetricSample] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }
        let cal = Calendar.current
        let end = Date()
        guard let start = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: end)) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                                  sortDescriptors: nil) { _, results, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(q)
        }

        let asleep: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
        ]
        var perDay: [String: Double] = [:]
        var dateForKey: [String: Date] = [:]
        for s in samples where asleep.contains(s.value) {
            let key = HealthStore.dayKey(for: s.endDate)
            perDay[key, default: 0] += s.endDate.timeIntervalSince(s.startDate) / 60.0
            dateForKey[key] = cal.startOfDay(for: s.endDate)
        }
        return perDay.map { DailyMetricSample(date: dateForKey[$0.key]!, value: $0.value) }
    }

    func workouts(since: Date) async throws -> [WorkoutSampleDTO] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: Date())
        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: .workoutType(), predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: (results as? [HKWorkout]) ?? [])
            }
            store.execute(q)
        }
        return workouts.map { w in
            WorkoutSampleDTO(
                uuid: w.uuid.uuidString,
                type: "\(w.workoutActivityType.rawValue)",
                start: w.startDate,
                durationMinutes: w.duration / 60.0,
                activeEnergy: w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                distanceMeters: w.totalDistance?.doubleValue(for: .meter()) ?? 0,
                source: w.sourceRevision.source.name)
        }
    }
}
```

- [ ] **Step 3: Implement BackgroundSyncScheduler**

```swift
// KAIZENN/Data/HealthStore/BackgroundSyncScheduler.swift
import Foundation
import BackgroundTasks

enum BackgroundSyncScheduler {
    static let taskID = "com.kaizenn.healthsync"

    static func register(handler: @escaping () async -> Void) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskID, using: nil) { task in
            schedule()   // chain the next run
            let work = Task { await handler(); task.setTaskCompleted(success: true) }
            task.expirationHandler = { work.cancel(); task.setTaskCompleted(success: false) }
        }
    }

    /// Schedule the next run for ~5am local (earliest-begin).
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        let cal = Calendar.current
        let tomorrow5am = cal.nextDate(after: Date(),
            matching: DateComponents(hour: 5), matchingPolicy: .nextTime)
        request.earliestBeginDate = tomorrow5am
        try? BGTaskScheduler.shared.submit(request)
    }
}
```

- [ ] **Step 4: Wire it all in KAIZENNApp**

Add to the `@StateObject` block:
```swift
    @StateObject private var ingestion: HealthIngestionService = {
        // store created above is captured after init; see init() below
        HealthIngestionService(store: HealthStore(), source: HealthKitDataSource())
    }()
```
> Because `ingestion` must share the *same* `healthStore` instance injected at root, restructure: create `healthStore`, `ingestion`, and `baselineProvider` in an `init()` and assign via `_healthStore = StateObject(wrappedValue:)`. Concretely, replace the three separate `@StateObject` decls with:
```swift
    @StateObject private var healthStore: HealthStore
    @StateObject private var ingestion: HealthIngestionService
    @StateObject private var baselineProvider = ReadinessBaselineProvider()

    init() {
        let store = HealthStore()
        _healthStore = StateObject(wrappedValue: store)
        _ingestion = StateObject(wrappedValue:
            HealthIngestionService(store: store, source: HealthKitDataSource()))
        BackgroundSyncScheduler.register { [store] in
            // capture-safe background job
            // (UI-independent; provider refresh happens on next foreground)
            await MainActor.run { }   // placeholder for @MainActor hop
        }
    }
```
> Then register the BGTask handler to run the ingestion + baseline refresh. Put the real handler in `.task`/`.onAppear` wiring instead if capturing `ingestion`/`baselineProvider` in `init()` is awkward — the requirement is: **handler = `await ingestion.syncNow(); baselineProvider.refresh(from: healthStore)`**, and `BackgroundSyncScheduler.schedule()` is called once at launch.

Add to `RootView()`'s modifier chain:
```swift
            .environmentObject(healthStore)
            .environmentObject(baselineProvider)
            .task {
                await healthKitManager.requestAuthorization()
                await ingestion.syncNow()
                baselineProvider.refresh(from: healthStore)
                BackgroundSyncScheduler.schedule()
            }
```
> (If Task 5 already added the `healthStore`/`baselineProvider` `@StateObject`s and environment objects, reconcile — keep one set. The `init()` form above supersedes Task 5 Step 2's plain declarations because `ingestion` needs the shared store.)

- [ ] **Step 5: Build for the simulator (compile gate)**

```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN" && xcodebuild build -scheme KAIZENN -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -15
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Device verification on Juls (per project workflow — simulator cannot exercise HealthKit/BGTask)**

Build & run on Juls (UDID `00008120-001C54C23423A01E`), then:
1. Grant Health permissions when prompted; confirm the app reads (HRV/RHR/sleep present in Health on the phone).
2. Open the app, background it, then verify a snapshot was written: add a temporary debug log in `syncNow()` printing `store.snapshots(since:).count`, or inspect via the Readiness view leaving "calibrating" once ≥1 day of history exists.
3. Force the background task in the Xcode debugger console (pause, then):
```
e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.kaizenn.healthsync"]
```
   Confirm the handler runs and `setTaskCompleted` is hit.
4. Confirm ACWR changes after a logged Watch workout (Task 4 path) appears.

- [ ] **Step 7: Commit**

```bash
cd "/Users/suli/Desktop/Dev Projects/KAIZENN" && git add KAIZENN/Data/HealthStore/HealthDataSource.swift KAIZENN/Data/HealthStore/BackgroundSyncScheduler.swift KAIZENN/Info.plist KAIZENN/App/KAIZENNApp.swift && git commit -m "feat: real HealthKitDataSource + daily background sync + app wiring"
```

---

## Self-Review

**Spec coverage:**
- Durable SwiftData store (snapshots + workouts) → Task 1. ✓
- Daily background sync → Task 6 (`BackgroundSyncScheduler`). ✓
- Rolling baselines feeding readiness → Tasks 2 + 5. ✓
- ACWR fed by HealthKit workouts with ±30-min/manual-wins dedup → Task 4. ✓
- Per-type isolation, gap days = nil, self-healing bounded re-read → Tasks 1 & 3 (+ Deviation note). ✓
- Protocol-wrapped HealthKit for testability → Task 3 (`HealthDataSource` + fake). ✓
- Device-only verification on Juls → Task 6 Step 6. ✓
- `ReadinessBaselineProvider` injected once at root (fixes per-view duplication) → Task 5. ✓
- Anchored queries / `SyncAnchor` → intentionally dropped (Deviation from spec). ✓ (documented)

**Type consistency:** `HealthStore`, `DailyHealthSnapshot`, `WorkoutRecord`, `WorkoutSampleDTO`, `DailyMetricSample`, `HealthMetric`, `HealthDataSource`, `HealthIngestionService.syncNow`, `BaselineCalculator.{signalBaseline,baseline,latestHRVLnSDNN}`, `ReadinessBaselineProvider.refresh(from:)`, `LoadStore.setHealthWorkouts`, `SignalBaseline(mean:sd:n:)`, `ReadinessBaseline(hrvLnSDNN:restingHR:sleepHours:)` — names match across tasks.

**Open items flagged for the implementer (not placeholders — real-codebase confirmations):**
- Task 4 Step 1 note: confirm the existing public GPS-session mutator name on `LoadStore` and match the test call.
- Task 6 Step 4 note: `init()` vs `.task` placement for sharing the single `HealthStore` between `ingestion` and root injection — both forms specified; pick one and keep one set of `@StateObject`s.
