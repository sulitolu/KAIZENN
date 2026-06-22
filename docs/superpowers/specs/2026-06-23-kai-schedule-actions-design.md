# Kai Schedule Actions — v1 Design (Propose → Accept)

**Date:** 2026-06-23
**Builds on:** the unified Kai (Kai reads `ReadinessEngine`) — branch `feat/coach-readiness-unify`.
**Status:** Approved design — ready for implementation plan.

## Goal
Let Kai **propose concrete schedule changes** the athlete accepts with one tap. v1 is **schedule-only** and **rule-based**; nothing is applied without an explicit Accept. This ships the reusable propose→accept **action framework**.

## Trust model (decided)
**Propose & confirm.** Kai never silently changes anything. Each proposal is a card with **Accept / Edit / Dismiss**. Accept applies it; Edit opens the existing prefilled `AddTaskView`; Dismiss hides it (for the day). Every applied action is a normal `KTask` the athlete can later delete — fully reversible.

## Non-goals (Phase 2+)
- Meal-menu generation; LLM-generated proposals; auto-apply/undo; modifying *existing* calendar items (v1 only *adds* tasks); coach/squad actions. The framework is built so the LLM can later become an alternate proposal source feeding the same pipeline.

## Architecture (units)

1. **`ProposedAction`** — value type (`Features/Coach/CoachActionEngine.swift`):
   ```
   struct ProposedAction: Identifiable {
       let id: String        // stable key (e.g. "recovery-session") so Dismiss persists per day
       let title: String     // "Add a recovery session"
       let detail: String    // "20 min mobility — your readiness is low today"
       let task: KTask        // the draft applied on Accept
   }
   ```
   v1 keeps it simple: every proposal resolves to **adding one `KTask`** (YAGNI — no edit-existing yet).

2. **`CoachActionEngine`** — pure, **unit-tested** (`enum`, static func):
   ```
   static func proposals(readiness: ReadinessBreakdown, sleepDebtHours: Double, today: Date) -> [ProposedAction]
   ```
   Starter rules (tunable constants):
   - `readiness.label` is `.caution` or `.recover` → **"Add a recovery session"** (`KTask` title "Recovery / mobility 20 min", category `.recovery`) **+ "Protect your sleep tonight"** (category `.recovery`).
   - `readiness.strain` present and `< 55` (high acute load) → **"Ease a hard session this week"** (category `.fitness`, a reminder task).
   - `sleepDebtHours >= 3` → **"Earlier wind-down tonight"** (category `.recovery`).
   - Readiness `.primed`/`.ready` with no flags → **no proposals** (Kai doesn't nag when you're fine).
   - Cap at 3 proposals; stable order by priority.

3. **Dismiss persistence** — `CoachActionStore` (tiny) persists dismissed `ProposedAction.id`s keyed by ISO date in UserDefaults, so a dismissed card doesn't reappear the same day. Cleared automatically when the date rolls over.

4. **UI** — a **"Suggested by Kai"** section in `CoachView` (its own `KSection`, above or replacing nothing — added near Focus Today). Renders the non-dismissed proposals as cards:
   - **Accept** → `scheduleStore.addTask(proposal.task)`, then mark applied (toast/checkmark) and remove the card.
   - **Edit** → present `AddTaskView(initialTitle: proposal.task.title, initialCategory: proposal.task.category)`.
   - **Dismiss** → record id in `CoachActionStore`, remove the card.
   - If no proposals: the section hides entirely (no empty state).

## Data flow
`ReadinessBreakdown` (already computed in `CoachView.readiness`) + `readinessBaseline.sleepDebtHours` → `CoachActionEngine.proposals(...)` → filter out dismissed (`CoachActionStore`) → render cards → Accept writes via `ScheduleStore.addTask`.

## Error handling / edges
- No readiness yet / calibrating → still allow sleep-debt + strain proposals where data exists; if nothing qualifies, show nothing.
- Duplicate guard: if a task with the same title already exists for today (via `scheduleStore.tasks(for:)`), suppress that proposal so Kai doesn't re-suggest something already on the schedule.
- Accept is idempotent per card (card removed immediately).

## Testing
- **`CoachActionEngineTests`** (pure): low-readiness yields the recovery + sleep proposals; high strain yields the ease-training proposal; `.primed` with no flags yields `[]`; sleep-debt threshold boundary; 3-proposal cap; stable ordering.
- Manual on **Juls** (device-only rule): force a low-readiness/calibrating state, confirm the "Suggested by Kai" section appears, Accept adds a task to the schedule, Dismiss hides it and it stays hidden on re-open.

## File sketch (for the plan)
- **New** `Features/Coach/CoachActionEngine.swift` — `ProposedAction` + `CoachActionEngine` (pure) + `CoachActionStore` (dismiss persistence).
- **New** `KAIZENNTests/CoachActionEngineTests.swift`.
- **Modify** `Features/Coach/CoachView.swift` — add the "Suggested by Kai" section + Accept/Edit/Dismiss wiring; it already has `scheduleStore`, `readiness`, and `readinessBaseline`.
- Register new files via `add_file.rb` (explicit-reference project).
