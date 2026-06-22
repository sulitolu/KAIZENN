# Kai Schedule Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`). NOTE: in this environment subagents cannot run Bash; the controller executes inline.

**Goal:** Kai proposes concrete schedule changes (rule-based) that the athlete applies with one tap — nothing changes without Accept.

**Architecture:** A pure, unit-tested `CoachActionEngine` turns the readiness breakdown + sleep debt into `[ProposedAction]` (each carrying a draft `KTask`). `CoachView` renders them in a "Suggested by Kai" section with Accept/Edit/Dismiss; Accept writes via `ScheduleStore.addTask`. Dismissals persist per-day in `CoachActionStore`.

**Tech Stack:** Swift / SwiftUI, XCTest, `KTheme`, `ScheduleStore`/`KTask`, `xcodeproj` gem.

## Global Constraints
- Build: `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` then `xcodebuild -project KAIZENN.xcodeproj -scheme KAIZENN -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`. Tests: same with `test` and `-destination 'platform=iOS Simulator,name=iPhone 17'`. xcodebuild is the only authority — ignore SourceKit single-file errors.
- New files registered via `docs/superpowers/plans/add_file.rb` (app → `KAIZENN`, tests → `KAIZENNTests`); rbenv ruby: `export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH" && eval "$(rbenv init - bash)"`.
- **Propose & confirm only** — nothing is applied without an explicit Accept tap. Every applied action is a normal `KTask` (reversible).
- v1 is **schedule-only, rule-based, adds tasks only** (no edit-existing, no meal menus, no LLM).
- **App runs go to the device (Juls), never the simulator** (xcodebuild UDID `00008120-001C54C23423A01E`). Headless unit tests may use the sim runner.
- Tunable thresholds as named `static let` constants.
- Branch: `feat/kai-schedule-actions` (checked out).

### Reference: existing types this plan uses
- `KTask(title: String, notes: String? = nil, dueDate: Date? = nil, dueTime: Date? = nil, priority: Priority = .medium, category: TaskCategory = .general, ...)` — `Codable`; `TaskCategory` has `.recovery`, `.fitness`, `.nutrition`, `.general`, etc.
- `ScheduleStore.addTask(_ task: KTask)`, `ScheduleStore.tasks(for date: Date) -> [KTask]`.
- `AddTaskView(initialTitle: String = "", initialCategory: KTask.TaskCategory = .general)` — saves via its own `@EnvironmentObject scheduleStore`.
- `ReadinessBreakdown { recovery/sleep/strain/fuel: Double?; score: Int; label: ReadinessLabel; isCalibrating: Bool }`; `ReadinessLabel { primed, ready, moderate, caution, recover }`.
- `CoachView` already has `@EnvironmentObject scheduleStore`, the `readiness` computed property, and `readinessBaseline` (`ReadinessBaselineProvider`, exposes `sleepDebtHours`).
- `DateFormatter.isoDate` exists (used in `ScheduleModels.swift`).

---

### Task 1: CoachActionEngine + ProposedAction + CoachActionStore (pure, TDD)

**Files:**
- Create: `KAIZENN/Features/Coach/CoachActionEngine.swift`
- Test: `KAIZENNTests/CoachActionEngineTests.swift`

**Interfaces — Produces:**
- `struct ProposedAction: Identifiable { let id: String; let title: String; let detail: String; let task: KTask }`
- `enum CoachActionEngine { static func proposals(readiness: ReadinessBreakdown, sleepDebtHours: Double) -> [ProposedAction] }`
- `final class CoachActionStore { func dismissed() -> Set<String>; func dismiss(_ id: String) }`

- [ ] **Step 1: Write the failing test** — create `KAIZENNTests/CoachActionEngineTests.swift`:

```swift
import XCTest
@testable import KAIZENN

final class CoachActionEngineTests: XCTestCase {

    private func breakdown(label: ReadinessLabel, strain: Double?) -> ReadinessBreakdown {
        ReadinessBreakdown(recovery: 70, sleep: 70, strain: strain, fuel: 70,
                           score: 60, label: label, isCalibrating: false)
    }

    func testLowReadinessProposesRecoveryAndSleep() {
        let p = CoachActionEngine.proposals(readiness: breakdown(label: .recover, strain: 70), sleepDebtHours: 0)
        XCTAssertTrue(p.contains { $0.id == "recovery-session" })
        XCTAssertTrue(p.contains { $0.id == "protect-sleep" })
        XCTAssertEqual(p.first { $0.id == "recovery-session" }?.task.category, .recovery)
    }

    func testHighStrainProposesEaseTraining() {
        let p = CoachActionEngine.proposals(readiness: breakdown(label: .ready, strain: 40), sleepDebtHours: 0)
        XCTAssertTrue(p.contains { $0.id == "ease-training" })
    }

    func testSleepDebtProposesWindDown() {
        let p = CoachActionEngine.proposals(readiness: breakdown(label: .ready, strain: 80), sleepDebtHours: 4)
        XCTAssertTrue(p.contains { $0.id == "wind-down" })
    }

    func testGoodDayProposesNothing() {
        let p = CoachActionEngine.proposals(readiness: breakdown(label: .primed, strain: 90), sleepDebtHours: 0)
        XCTAssertTrue(p.isEmpty)
    }

    func testCapsAtThreeProposals() {
        let p = CoachActionEngine.proposals(readiness: breakdown(label: .recover, strain: 30), sleepDebtHours: 5)
        XCTAssertLessThanOrEqual(p.count, 3)
    }

    func testDismissPersistsForToday() {
        let store = CoachActionStore()
        store.dismiss("recovery-session")
        XCTAssertTrue(store.dismissed().contains("recovery-session"))
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "kaizenn_coach_dismissed_actions")
        super.tearDown()
    }
}
```

- [ ] **Step 2: Register the test, run RED**

```bash
ruby docs/superpowers/plans/add_file.rb KAIZENNTests/CoachActionEngineTests.swift KAIZENNTests
```
Run the test command. Expected: FAIL (`CoachActionEngine`/`ProposedAction`/`CoachActionStore` undefined).

- [ ] **Step 3: Implement** — create `KAIZENN/Features/Coach/CoachActionEngine.swift`:

```swift
import Foundation

/// One concrete suggestion Kai can make. Applying it adds `task` to the schedule.
struct ProposedAction: Identifiable {
    let id: String        // stable key so a dismissal persists for the day
    let title: String
    let detail: String
    let task: KTask
}

/// Rule-based proposal generator. Pure (readiness + sleep debt in → proposals out) so it's
/// unit-testable and the LLM can later become an alternate source feeding the same pipeline.
enum CoachActionEngine {
    static let strainThreshold = 55.0
    static let sleepDebtThreshold = 3.0
    static let maxProposals = 3

    static func proposals(readiness: ReadinessBreakdown, sleepDebtHours: Double) -> [ProposedAction] {
        var out: [ProposedAction] = []
        let lowReadiness = readiness.label == .caution || readiness.label == .recover

        if lowReadiness {
            out.append(ProposedAction(
                id: "recovery-session",
                title: "Add a recovery session",
                detail: "20 min mobility — your readiness is low today",
                task: KTask(title: "Recovery / mobility — 20 min", category: .recovery)))
            out.append(ProposedAction(
                id: "protect-sleep",
                title: "Protect your sleep tonight",
                detail: "Aim for 9h — recovery starts with sleep",
                task: KTask(title: "Lights out for 9h sleep", category: .recovery)))
        }
        if let strain = readiness.strain, strain < strainThreshold {
            out.append(ProposedAction(
                id: "ease-training",
                title: "Ease a hard session this week",
                detail: "Training strain is high — swap one hard day for easy",
                task: KTask(title: "Make one hard session easier this week", category: .fitness)))
        }
        if sleepDebtHours >= sleepDebtThreshold {
            out.append(ProposedAction(
                id: "wind-down",
                title: "Earlier wind-down tonight",
                detail: String(format: "You're ~%.0fh down on sleep this week", sleepDebtHours),
                task: KTask(title: "Start wind-down 30 min earlier tonight", category: .recovery)))
        }
        return Array(out.prefix(maxProposals))
    }
}

/// Persists per-day dismissals so a dismissed card doesn't reappear the same day.
/// Only today's set is kept, so it self-clears when the date rolls over.
final class CoachActionStore {
    private let key = "kaizenn_coach_dismissed_actions"
    private var today: String { DateFormatter.isoDate.string(from: Date()) }

    func dismissed() -> Set<String> {
        let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: [String]] ?? [:]
        return Set(dict[today] ?? [])
    }

    func dismiss(_ id: String) {
        var todays = dismissed()
        todays.insert(id)
        UserDefaults.standard.set([today: Array(todays)], forKey: key)
    }
}
```

- [ ] **Step 4: Register source, run GREEN**

```bash
ruby docs/superpowers/plans/add_file.rb KAIZENN/Features/Coach/CoachActionEngine.swift KAIZENN
```
Run the test command. Expected: all `CoachActionEngineTests` PASS.

- [ ] **Step 5: Commit**

```bash
git add KAIZENN/Features/Coach/CoachActionEngine.swift KAIZENNTests/CoachActionEngineTests.swift KAIZENN.xcodeproj/project.pbxproj
git commit -m "feat(kai): CoachActionEngine — rule-based schedule proposals (tested)"
```

---

### Task 2: "Suggested by Kai" section in CoachView (Accept / Edit / Dismiss)

**Files:**
- Modify: `KAIZENN/Features/Coach/CoachView.swift`

**Interfaces — Consumes:** `CoachActionEngine.proposals`, `ProposedAction`, `CoachActionStore`, `ScheduleStore.addTask`, `AddTaskView`.

- [ ] **Step 1: Add state + the proposals computed property.** Near the other `@State` in `CoachView` add:

```swift
    private let actionStore = CoachActionStore()
    @State private var hiddenActionIDs: Set<String> = []
    @State private var editingProposal: ProposedAction?
```
And a computed property (place beside `readiness`):

```swift
    private var kaiProposals: [ProposedAction] {
        let dismissed = actionStore.dismissed()
        let todays = scheduleStore.tasks(for: Date())
        return CoachActionEngine.proposals(readiness: readiness, sleepDebtHours: readinessBaseline.sleepDebtHours)
            .filter { !hiddenActionIDs.contains($0.id) && !dismissed.contains($0.id) }
            .filter { p in !todays.contains { $0.title == p.task.title } }   // don't re-suggest something already scheduled
    }
```

- [ ] **Step 2: Add the section view + card.** Add these to `CoachView`:

```swift
    @ViewBuilder
    private var suggestedSection: some View {
        let proposals = kaiProposals
        if !proposals.isEmpty {
            KSection(title: "Suggested by Kai") {
                VStack(spacing: KTheme.Spacing.sm) {
                    ForEach(proposals) { proposalCard($0) }
                }
            }
        }
    }

    private func proposalCard(_ p: ProposedAction) -> some View {
        KCard {
            VStack(alignment: .leading, spacing: KTheme.Spacing.sm) {
                Text(p.title)
                    .font(KTheme.Typography.headingSmall)
                    .foregroundColor(KTheme.Colors.textPrimary)
                Text(p.detail)
                    .font(KTheme.Typography.caption)
                    .foregroundColor(KTheme.Colors.textSecondary)
                HStack(spacing: KTheme.Spacing.sm) {
                    Button {
                        scheduleStore.addTask(p.task)
                        withAnimation(KTheme.Animation.snappy) { _ = hiddenActionIDs.insert(p.id) }
                    } label: {
                        Text("Accept").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Capsule().fill(KTheme.Colors.accentPrimary))
                    }
                    .buttonStyle(.plain)

                    Button { editingProposal = p } label: {
                        Text("Edit").font(.system(size: 14, weight: .semibold)).foregroundColor(KTheme.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        actionStore.dismiss(p.id)
                        withAnimation(KTheme.Animation.snappy) { _ = hiddenActionIDs.insert(p.id) }
                    } label: {
                        Text("Dismiss").font(.system(size: 14)).foregroundColor(KTheme.Colors.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
```

- [ ] **Step 3: Render the section + Edit sheet.** In the Coach `body`'s `VStack`, insert `suggestedSection` right after `focusTodaySection`. Add an Edit sheet alongside the existing `.sheet(item: $activeAction)`:

```swift
        .sheet(item: $editingProposal) { p in
            AddTaskView(initialTitle: p.task.title, initialCategory: p.task.category)
                .environmentObject(scheduleStore)
        }
```

- [ ] **Step 4: Build + verify.** Run the build command → `** BUILD SUCCEEDED **`. Then run the test command → `CoachActionEngineTests` + the readiness suites still pass. Deploy to Juls (device build, UDID `00008120-001C54C23423A01E`; install/launch via `devicectl`) and confirm: with a low-readiness/sleep-debt state, a "Suggested by Kai" section appears in the Coach tab; **Accept** adds the task to the Schedule tab; **Dismiss** hides it and it stays hidden on reopening Kai; **Edit** opens the prefilled add-task form.

- [ ] **Step 5: Commit**

```bash
git add KAIZENN/Features/Coach/CoachView.swift
git commit -m "feat(kai): Suggested by Kai section — propose/accept schedule actions"
```

---

## Self-Review

- **Spec coverage:** propose→confirm (Task 2 Accept-only apply) ✓; rule-based engine + starter rules (Task 1) ✓; ProposedAction carrying a KTask (Task 1) ✓; dismiss persistence per-day (Task 1 `CoachActionStore`) ✓; "Suggested by Kai" section with Accept/Edit/Dismiss (Task 2) ✓; dedup vs already-scheduled (Task 2 `kaiProposals` filter) ✓; hides when empty (Task 2 `if !proposals.isEmpty`) ✓; pure/testable engine (Task 1) ✓; reversible (adds normal KTask) ✓.
- **Placeholder scan:** none — full code in every step; thresholds are named constants.
- **Type consistency:** `ProposedAction`/`CoachActionEngine.proposals`/`CoachActionStore.dismissed()/dismiss(_:)` consistent across Tasks 1–2. `KTask(title:category:)`, `ScheduleStore.addTask`, `AddTaskView(initialTitle:initialCategory:)`, `readinessBaseline.sleepDebtHours`, `ReadinessLabel.caution/.recover` all match the verified existing APIs.
- **Edge:** `ReadinessLabel` is a no-associated-value enum → implicitly `Equatable`, so `label == .caution` compiles.
