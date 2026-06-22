# Readiness v2 — Phase 1 (Passive Engine Rework) Design

**Date:** 2026-06-22
**Branch:** `feat/settings-notifications-i18n` (current; metrics work lands before any push)
**Research basis:** `docs/superpowers/specs/2026-06-22-readiness-score-research.md`
**Status:** Approved design — ready for implementation plan

## Goal
Replace the current readiness scoring with a **baseline-relative, research-aligned model** using only data KAIZENN already collects (HealthKit HRV/RHR/sleep + in-app load/nutrition). No new user-facing inputs in Phase 1. Reshape the pillars to **Recovery / Sleep / Strain / Fuel**.

## Non-goals (Phase 2+, explicitly out of scope here)
- Subjective wellness check-in UI; session-RPE prompt; coach/squad view; menstrual/alcohol logging; standing HRV. The engine reserves a Wellness weight slot but Phase 1 ships without it.

## Key constraint
Apple HealthKit exposes HRV only as **SDNN**, not the RMSSD used in the cited studies. The **personalization method transfers** (compare to the athlete's own rolling baseline); absolute RMSSD thresholds do not. Phase 1 uses `ln(SDNN)` vs personal baseline. This is documented in-code and in the research spec.

## Architecture (units, each independently testable)

1. **HealthKit history fetches** — `Data/HealthKit/HealthKitManager.swift` (extend):
   - `fetchDailySeries(_ id: HKQuantityTypeIdentifier, unit:, days:) async -> [Double]` — one value per day (daily average) over `days`, for HRV (SDNN) and resting HR. Returns chronological values; missing days omitted.
   - `fetchSleepHistory(nights: Int) async -> [Double]` — per-night sleep hours over `nights`.
   - (Reuse existing `fetchAverageQuantity` where only a mean is needed.)

2. **`ReadinessBaseline`** — new value type (`Features/Readiness/ReadinessBaseline.swift`):
   ```
   struct SignalBaseline { let mean: Double; let sd: Double; let n: Int }
   struct ReadinessBaseline {
       let hrv: SignalBaseline?      // ln(SDNN)
       let restingHR: SignalBaseline?
       let sleepHours: SignalBaseline?
       let sleepNeed: Double         // personal need, default 8.0
       let isCalibrating: Bool       // true if < MIN_DAYS history for HRV or sleep
   }
   ```
   Built by a provider that pulls the history fetches and computes mean/SD. `MIN_DAYS = 14`.

3. **`ReadinessEngine` v2** — rewrite `Features/Readiness/ReadinessEngine.swift`, staying pure:
   - `ReadinessInputs` v2: today's HRV (SDNN), restingHR, last-night sleep, sleep debt (computed), training strain (acute/chronic load), fuel (cal/protein), **+ the `ReadinessBaseline`**.
   - `breakdown(for:)` returns `ReadinessBreakdown` v2 with per-pillar sub-scores (Recovery/Sleep/Strain/Fuel), the composite `score`, `label`, and `isCalibrating`.

4. **UI** — `DashboardView` + `ReadinessReportView` updated to the new pillar tiles (Recovery/Sleep/Strain/Fuel) and a "vs your baseline" context line; a "Calibrating — learning your baseline" treatment when `isCalibrating`.

## Scoring

For each signal: `z = (today − mean) / sd`, then `sub = clamp(80 + 20·z, 0, 100)`. **Invert** RHR and Strain (higher = worse → use `−z`). HRV `today` = 7-day rolling mean of `ln(SDNN)`; baseline = 60-day mean/SD of daily `ln(SDNN)`.

**Pillars (weights are defensible defaults [C], exposed as constants for tuning):**

| Pillar | Weight | Composition |
|---|---|---|
| Recovery | 0.45 | 0.30 HRV(lnSDNN z) + 0.15 RHR(−z); renormalize if one missing |
| Sleep | 0.30 | duration vs need (z if baseline, else ratio) + 14-night debt penalty + regularity (−z of night-to-night SD) |
| Strain | 0.18 | **existing external load** from `loadStore` (GPS/strength session load — `acuteLoad` vs `chronicLoad`, which it already computes); higher acute-vs-chronic → lower sub. **No ACWR 0.8–1.3 injury gate.** (Session-RPE is Phase 2.) |
| Fuel | 0.07 | existing cal/protein 50/50 (demoted) |

**Composite:** `readiness = Σ(wᵢ·subᵢ) / Σ(wᵢ for present pillars)`, rounded to Int. Require Recovery **or** Sleep present; else `isCalibrating`/insufficient.

**Labels (baseline-relative):** ≥85 Primed · 70–84 Ready · 55–69 Moderate · 40–54 Caution · <40 Recover.

## Cold-start / Calibrating
If `< MIN_DAYS (14)` of HRV or sleep history → `isCalibrating = true`. While calibrating, compute a **gentler absolute fallback** (today's HRV/sleep mapped to soft absolute curves, no z-scoring) and surface it labeled "Calibrating — learning your baseline," so day-2 users see a sensible provisional number, not a false red/green.

## Missing-data handling
- Any pillar with no usable input is dropped and weights renormalize over present pillars.
- HRV present but baseline absent (new user) → calibrating fallback.
- All recovery+sleep signals absent → show "Not enough data yet."

## Backward compatibility
- The Daily report's pillar rows and the Home card's pillar tiles change from Sleep/Load/Fuel/HRV to Recovery/Sleep/Strain/Fuel. The Weekly report's per-pillar trends update accordingly (Recovery trend = HRV/RHR; Strain trend = load). The `ReadinessLabel` color mapping is reused.
- `readinessScore` stays an `Int` 0–100, so existing call sites (Home number, ring) keep working.

## Testing
Unit tests (`ReadinessEngineTests`):
- z→sub mapping (z=0→80, z=+1→100 cap, z=−2→40), inversion for RHR/Strain.
- Per-pillar composition (Recovery HRV+RHR blend; Sleep debt/regularity).
- Composite renormalization when a pillar is missing.
- Cold-start: `isCalibrating` true under 14 days; fallback produces a bounded 0–100 score.
- Baseline math: `SignalBaseline` mean/sd over a known series.
Manual: build + run on Juls with real HealthKit data; confirm Recovery reflects actual HRV/RHR, calibrating state shows for a fresh profile.

## File-level sketch (for the plan)
- Extend `Data/HealthKit/HealthKitManager.swift` — `fetchDailySeries`, `fetchSleepHistory`.
- New `Features/Readiness/ReadinessBaseline.swift` — `SignalBaseline`, `ReadinessBaseline`, baseline provider.
- Rewrite `Features/Readiness/ReadinessEngine.swift` — v2 inputs/sub-scores/composite + calibrating fallback.
- Update `Features/Dashboard/DashboardView.swift` — build v2 inputs + baselines; new pillar tiles.
- Update `Features/Readiness/ReadinessReportView.swift` — new pillar rows + calibrating treatment + "vs baseline" line.
- Tests `KAIZENNTests/ReadinessEngineTests.swift` — rewrite for v2.
- Register any new files via `add_file.rb` (explicit-reference project).
