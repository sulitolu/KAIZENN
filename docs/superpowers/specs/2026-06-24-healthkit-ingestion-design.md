# HealthKit Data Ingestion — Design Spec

**Date:** 2026-06-24
**Branch:** `feat/kai-schedule-actions` (work to branch from here)
**Status:** Awaiting user review

## Goal

Get real watch + phone health data flowing into KAIZENN reliably and durably, so
readiness and ACWR run on the athlete's actual HRV, resting heart rate, sleep, and
workouts — refreshed automatically each day, even when the app is closed.

This spec covers **Apple HealthKit only** (Apple Watch + iPhone). Garmin / Whoop /
Oura (cloud-to-cloud) and Android / Health Connect are deliberately out of scope and
will each get their own follow-up spec. The architecture here is designed so those
sources later become *additional writers into the same on-device store* without
touching the readiness or ACWR code.

## The key insight that shapes scope

On Apple's platform, anything the Watch writes to HealthKit (completed workouts,
heart rate, HRV) is **automatically synced by the OS into the iPhone's HealthKit
store**. The existing `WatchConnectivityManager` carries only water-log messages, and
for *daily batch* sync it can stay that way. We do **not** build a Watch→Phone health
pipe. The Watch is already a producer into HealthKit; this project builds a reliable
**consumer + durable store** on top of the single iPhone HealthKit store. (A manual
WatchConnectivity health pipe would only be needed for *live* streaming, which is out
of scope.)

## What already exists (do not rebuild)

- `KAIZENN/Data/HealthKit/HealthKitManager.swift` — reads steps, HR, resting HR,
  HRV (SDNN), sleep stages, body mass, workouts; has authorization + a step
  `HKObserverQuery`. Reads are on-demand into transient `@Published` vars.
- Readiness engine — computes a score from HRV + RHR + sleep + ACWR + fuel; degrades
  on missing inputs.
- ACWR — acute/chronic load computed in `KAIZENN/Data/Persistence/LoadStore.swift`
  from **manually-logged** GPS + strength sessions only.
- `ReadinessReportView.swift` references `@EnvironmentObject var readinessBaseline:
  ReadinessBaselineProvider` — but it is never injected. This spec fills that gap.

## Gaps this spec closes

1. **No persistence.** HealthKit data lives only in transient `@Published` vars;
   baselines are recomputed from scratch each read and there is no day-to-day history.
2. **No true background collection.** The observer only fires while the app is open;
   nothing wakes the app to compute morning readiness.
3. **No incremental reads.** No `HKAnchoredObjectQuery`; every fetch re-queries
   everything instead of pulling just-new samples.
4. **ACWR ignores HealthKit workouts** — a Watch run doesn't affect training load.

## Decisions locked during brainstorming

- **Source first:** Apple HealthKit (Watch + iPhone). Garmin/Whoop/Oura and Android
  are separate follow-up specs.
- **Freshness:** daily background sync (`BGTaskScheduler` + `HKObserverQuery` with
  background delivery), not on-open-only and not live streaming.
- **Storage:** SwiftData, on-device. (Project is otherwise UserDefaults-JSON; this
  is the first SwiftData usage and is the right home for time-series data.)
- **Workout dedup:** time-window dedup — a HealthKit workout overlapping a manual
  session within ±30 min of the same type counts once; the **manual log wins**
  (richer GPS/load metrics). Non-overlapping HealthKit workouts add to load.

## Architecture — five focused units

Each unit has one job and a clean interface: ingestion doesn't know about UI, the
store doesn't know about HealthKit, baselines don't know where data came from.

### 1. `HealthStore` (SwiftData models) — the durable layer

- **`DailyHealthSnapshot`** — one row per day. Fields: `date`, `hrvSDNN`,
  `restingHR`, `sleepDurationMinutes`, sleep stage breakdown (REM / core / deep /
  unspecified minutes), `steps`, `activeEnergy`. Missing values stay `nil` (see
  Error Handling — a gap day is *no row*, not a zero row).
- **`WorkoutRecord`** — mirrors each `HKWorkout`: `hkUUID` (dedup key), `type`,
  `start`, `durationMinutes`, `activeEnergy`, `distanceMeters`, `source`.
- **`SyncAnchor`** — stores the serialized `HKQueryAnchor` per HealthKit data type so
  anchored queries pull only new samples.

### 2. `HealthIngestionService` — the one entry point for getting data in

- Uses `HKAnchoredObjectQuery` (incremental) per type, replacing today's full
  re-reads, and `HKObserverQuery` with **background delivery enabled** per type.
- Normalizes HK samples → upserts into `HealthStore` (snapshots keyed by day,
  workouts keyed by `hkUUID`).
- Public surface: `syncNow() async` and `startObserving()`.
- Reads HealthKit through a `HealthDataSource` protocol (see Testing), never
  `HKHealthStore` directly.

### 3. `BackgroundSyncScheduler` — daily wake

- Registers a `BGTaskScheduler` task (~5–6am) that calls `syncNow()` then triggers a
  readiness recompute, so morning readiness is ready before the app opens.
- Owns reschedule logic and the background-task expiration handler.

### 4. `BaselineProvider` — rolling baselines

- Reads `HealthStore` history → rolling 7 / 14 / 28-day baselines for HRV / RHR /
  sleep. Averages over real readings only (skips gap days).
- This is the concrete implementation injected for the missing
  `ReadinessBaselineProvider`, feeding the existing Readiness engine.

### 5. ACWR integration

- `LoadStore` additionally consumes `WorkoutRecord`s so Watch/HealthKit workouts
  count toward acute/chronic load, applying the time-window dedup rule above.

**Why this shape:** the isolation is what lets Garmin/Whoop later become just another
writer into `HealthStore` without touching readiness or ACWR.

## Data flow

```
Apple Watch ─┐
             ├─→ iPhone HealthKit store ──→ HealthIngestionService ──→ HealthStore (SwiftData)
iPhone ──────┘   (OS syncs Watch→Phone)    (anchored query: new only)        │
                                                                              ▼
                                                            BaselineProvider (rolling avgs)
                                                                              │
                                                                              ▼
                                                              ReadinessEngine.recompute()
                                                                              │
                                                                              ▼
                                                           UI reads from HealthStore (durable)
                                                              + optional readiness notification
```

**Three triggers, one `syncNow()` path:**

1. **Background task** (`BGTaskScheduler`, ~5–6am) → morning readiness pre-computed.
2. **Observer + background delivery** → OS wakes the app when the Watch writes new
   data (e.g., a finished workout).
3. **App foreground** → catch-up sync on open.

Each run: anchored query pulls only new samples per type → upsert into `HealthStore`
→ `BaselineProvider` recomputes → `ReadinessEngine` recomputes → UI re-renders from
the durable store; optional notification if readiness crosses a threshold.

## Error handling

- **Authorization denied / partial grant.** HealthKit hides denial state by design,
  so "no data for type X" and "denied type X" are treated identically: the snapshot
  field stays `nil` and the Readiness engine degrades gracefully. A single "Health
  access" status in settings lets the athlete fix it.
- **Per-type isolation.** One type's query failing must not abort the whole sync;
  each type ingests independently, failures are logged, and anchors advance only for
  types that succeeded.
- **Background task expiration.** `BGTask`s get ~30s; an expiration handler saves the
  SwiftData context and reschedules — partial-now/finish-next-wake, never data loss.
- **Anchor reset / corruption.** If an anchored query rejects a stored anchor, fall
  back to a bounded full re-read (last 60 days) and re-seed the anchor — self-healing.
- **Empty / gap days.** No data for a day = no snapshot row, so baselines average over
  real readings and aren't dragged down by absent days.

## Testing

The key move is **protocol-wrapping HealthKit** so logic is testable without a device.

- **`HealthDataSource` protocol** abstracts the HK queries. Real impl wraps
  `HKHealthStore`; `FakeHealthDataSource` feeds canned samples in tests.
- **Ingestion tests** — feed fake samples; assert `HealthStore` rows, anchor
  advancement, and dedup behavior.
- **Baseline tests** — seed SwiftData with known daily history; assert rolling
  7/14/28-day math including gap-day handling.
- **ACWR dedup tests** — overlapping vs non-overlapping workout/manual pairs produce
  the expected load.
- **Background scheduler** — unit-test the decision logic (what to sync, reschedule on
  expiry); the BGTask plumbing and authorization UI are verified manually on **Juls**
  (device-only, per project workflow).

## Out of scope (future specs)

- Garmin / Whoop / Oura cloud ingestion (OAuth + vendor APIs → backend).
- Android / Health Connect (requires an Android app, which does not exist today).
- Live in-workout heart-rate streaming via WatchConnectivity.
- Supabase sync of health data for a coach/trainer dashboard.
