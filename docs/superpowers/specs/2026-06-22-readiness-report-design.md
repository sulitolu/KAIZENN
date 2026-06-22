# Readiness Report — Design Spec

**Date:** 2026-06-22
**Branch:** `feat/readiness-report`
**Status:** Awaiting user review

## Goal

Let an athlete tap the readiness ring/number on the Home (Dashboard) screen to open a **Readiness Report** that shows *their own data and trends* — a daily view and a weekly view.

## The distinction from Kai (Coach tab)

This is the defining constraint. The two surfaces must not blur:

| Surface | Job | Content |
|---|---|---|
| **Kai (Coach tab)** | "What should I do?" | AI brief, focus actions, AI weekly report, chat, science tips |
| **Readiness Report (new)** | "What are my numbers?" | The score broken into its inputs, raw values, and historical trends — **no AI text, no recommendations, no chat** |

If a screen element reads like advice ("prioritise rest today"), it belongs in Kai, not here. The Report only states facts the data already contains.

## Entry point

- The score + ring (top row of `scoreHeroCard` in `DashboardView.swift`, currently `navigate(to: .coach)`) instead presents the Readiness Report as a sheet.
- The four pillar tiles below keep their existing destinations (Sleep → —, Load → Hub, Fuel → Nutrition, HRV → —). Unchanged.

## Presentation

- A modal **sheet** (`.sheet`) titled "Readiness".
- A **Daily / Weekly** segmented control at the top, reusing the segmented-row visual pattern already used in `SettingsView`. Default: Daily.
- Styling via existing `KTheme` tokens; matches card/look of the rest of the app.

## Daily view

1. **Hero**: today's readiness score (the gradient number), the ring echo, and the readiness label (PEAK / GAME READY / BUILD DAY / RECOVERY DAY) — same values the Home card shows.
2. **Pillar breakdown** — for each of Sleep / Load / Fuel / HRV, one row showing:
   - The pillar's **contribution** to the score (its sub-score / weight).
   - The **raw input** behind it: Sleep `6.2h`, Load `ACWR 1.4 (high)`, Fuel `1850 / 2300 kcal` + protein, HRV `48ms (−4 vs baseline)`.
3. The breakdown makes the score legible: "why is today a 24?" is answered by reading the four rows.

## Weekly view

1. **Readiness trend** — last 7 days as bars (or a line), with the weekly **average**, and **best / worst** day called out.
2. **Per-pillar 7-day mini-trends** — small sparkline/bars for Sleep, Load, Fuel, HRV, and Weight.
3. Missing data is shown as a **gap**, never a fabricated value.

## Architecture

### New: `ReadinessEngine`
The readiness math currently lives inside `DashboardView` (`readinessScore`, `sleepScore`, `loadScore`, `fuelScore`, `hrvScore`) and only computes "today" from live store values. Extract it into a small, testable type:

```
struct ReadinessInputs { sleepHours, acwr, calorieRatio, proteinRatio, hrvLatest, hrvBaseline ... }
struct ReadinessBreakdown { score: Int, label, sleepScore, loadScore, fuelScore, hrvScore, hrvAvailable }

enum ReadinessEngine {
    static func breakdown(for inputs: ReadinessInputs) -> ReadinessBreakdown
}
```

- `DashboardView` is refactored to build `ReadinessInputs` from its stores and call the engine — same on-screen result, one source of truth.
- The Report's Daily view calls the same engine for today, and its Weekly view calls it once per day across the last 7 days.
- This refactor is the enabler for the weekly readiness trend; without it the formula would be duplicated and drift.

### New: `ReadinessReportView`
The sheet. Owns the Daily/Weekly toggle and the two sub-views (`ReadinessDailyView`, `ReadinessWeeklyView`). Reads the same `@EnvironmentObject` stores the Dashboard injects.

## Data sources (all confirmed to exist)

- **Fuel (per day):** `NutritionStore.dailyNutrition(for:)`, `weeklyNutrition(endingOn:)`, `weeklyCalories(endingOn:)`
- **Weight:** `WeightStore.trendLine(lastDays:)`, `measurements(lastDays:)`, `weightChange(lastDays:)`
- **Load:** `LoadStore.workouts(lastDays:)`, `acwr`, `gpsSessions`
- **Sleep / HRV (today):** `HealthKitManager.sleepHoursLast`, `hrvLatestMs`, `hrvBaselineMs`
- **History fetches:** `HealthKitManager.fetchHeartRateHistory(hours:)`, `fetchWeightHistory(days:)`

### Known data gap (must be handled in the plan)
The weekly **readiness** trend needs each past day's Sleep, ACWR, Fuel, and HRV. Fuel and weight have ready per-day history; **per-day sleep and per-day HRV do not yet have 7-day fetch methods**, and historical ACWR would need recomputation from `gpsSessions`. The implementation plan must either:
- (a) add `HealthKitManager` methods to fetch sleep-per-night and HRV-per-day for the last 7 days, and compute ACWR per day from sessions; or
- (b) ship the weekly readiness trend for days with complete data only (gaps elsewhere), and always ship the per-pillar trends that *do* have history (fuel, weight, load).

Recommendation: ship (b) first (always-correct, no over-promising), add (a) as a follow-up so the readiness trend fills in.

## Non-goals (YAGNI)

- No AI text, recommendations, coaching, or chat (that is Kai's job).
- No editing/logging from the Report — it is read-only. Logging stays in the existing quick actions.
- No data export, no sharing, no date-range picker beyond today/this-week in v1.

## Testing

- **`ReadinessEngine`**: unit tests over known inputs → expected score/label, including the HRV-absent path (3-pillar weighting) and boundary labels (40/60/80).
- **Views**: rendered with seeded store data; verify daily breakdown values match the engine and weekly gaps render for missing days.
- **Manual on device**: tap ring → report opens; toggle Daily/Weekly; values match the Home card.

## File-level plan (for the implementation plan to expand)

- **New** `Features/Readiness/ReadinessEngine.swift` — scoring, pure/testable.
- **New** `Features/Readiness/ReadinessReportView.swift` — sheet + Daily/Weekly toggle.
- **New** `Features/Readiness/ReadinessDailyView.swift`, `ReadinessWeeklyView.swift` — the two modes.
- **Modify** `Features/Dashboard/DashboardView.swift` — use `ReadinessEngine`; change the ring/number button to present the report sheet instead of navigating to Coach.
- **Modify** `Core/Health/HealthKitManager.swift` — (follow-up) add 7-day sleep/HRV history fetches.
- **Note:** project uses explicit file references (no synchronized folders), so new files must be added to `project.pbxproj` / the build's Sources phase, or placed in an existing compiled file. The plan must account for this (see `reference_kaizenn_build`).
