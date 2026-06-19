# KAIZENN — Athlete Performance Platform Design Spec
**Date:** 2026-06-19  
**Status:** Approved — Ready for Implementation

---

## Vision

> **One App. Every Athlete. Personalised By Sport.**

KAIZENN is the first app built around the universal athlete identity. The engine — recovery, load, readiness, nutrition, performance — is the same for every athlete. Sport changes the language, benchmarks, and AI coaching. Not the architecture.

---

## Design Direction

**Option A — Readiness First** (approved)

- Big readiness score front and centre on the dashboard
- Four pillars beneath showing exactly what built that score
- Stat cards below for quick-glance data
- Design tokens: violet `#7C6FFF` primary, coral `#FF6B8A` match/alert, teal `#4ECDC4` GPS/load, amber `#FFB347` nutrition, green `#5EFFB7` connected/optimal
- Near-black depth layers: `#06060C` → `#080810` → `#0C0C16` → `#1A1A28`
- No emoji anywhere. SVG line icons only.
- Dynamic Island on all screens
- 0.5px borders, radial gradient glows on key elements
- Font weight 900 for primary numbers, tight negative letter-spacing

---

## The Five Universal Pillars

Every feature, screen, and AI insight maps back to one of these:

| Pillar | Tracks | Colour |
|---|---|---|
| Recovery | Sleep, HRV, soreness, rest quality | Violet |
| Load | ACWR, GPS volume, strength tonnage | Teal |
| Readiness | Composite score 0–100 | Violet → Coral gradient |
| Nutrition | Calories, macros, hydration, timing | Amber |
| Performance | Session results correlated to prep | Coral |

---

## Sport Profile — The Personalisation Layer

Set once in onboarding. Drives everything downstream.

- **Sport** — Rugby, Soccer, Basketball, Athletics, Gym, Swimming, Cycling, Other
- **Position / Role** — e.g. Prop vs Winger; benchmarks and AI coaching shift completely
- **Season Phase** — Pre-season / In-season / Off-season (training targets adapt)
- **Performance Day** — match day, race day, competition (whole week orients to this)
- **Wearable** — Whoop, Garmin, Polar, Apple Watch, None

### How Sport Profile affects the app

| Setting | What changes |
|---|---|
| Sport | Tab labels, AI language, benchmark targets |
| Position | Macro targets, load thresholds, AI coaching focus |
| Season Phase | Calorie targets, training load sweet spot, recovery expectations |
| Performance Day | Week timeline orientation, countdown display, pre-game nutrition prompts |

---

## Feature Specifications

### 1. Dashboard — Readiness Hero

**Layout:**
- Header: season context label + athlete name + avatar
- Score Hero card: large readiness number (0–100) with gradient, PEAK CONDITION / AT RISK label, bordered ring echo
- Four pillars inside score card: Sleep, Load, Fuel, HRV — each with colour-coded icon block, value, and label
- Stat row: GPS Load, Resting HR, Match countdown — each with mini progress bar
- All on dark `#080810` background

**Readiness Score calculation:**
- Sleep (25%): HealthKit sleep hours vs 8hr target
- Load (25%): ACWR ratio — 0.8–1.3 = full score, outside = penalised
- Fuel (25%): daily calorie + protein % of position-based target
- HRV (25%): Whoop/Garmin HRV trend vs personal baseline

**Framing:** Score is always forward-looking. Low score → shows what to address, never a punishment. "Your edge: hit protein and sleep 8hrs tonight."

---

### 2. Nutrition — Fuel Tab

**Layout:**
- Context header: match week day + countdown chip
- Calorie hero card: large consumed number, progress bar, macro row (protein/carbs/fat each with coloured value + mini bar)
- Scan Meal button: violet gradient icon, prominent, full-width feel
- Food log entries: colour-coded dot, food name, grams (editable), kcal

**Food Photo AI:**
- Athlete taps Scan Meal → camera opens
- Photo sent to Claude Vision API with sport + position context
- Claude returns structured JSON: food items, estimated grams, macros
- KAIZENN displays editable breakdown screen
- Each item: name, gram input (number pad), unit toggle (g / oz / cups / pieces / servings)
- Macros recalculate live as athlete adjusts grams
- Confirm with one tap → logged
- AI Coach contextualises against position target immediately after

**Sport-intelligent targets:**
- Position-based macro targets calculated from Sport Profile + body weight
- Training day vs match day vs recovery day targets differ
- Hydration target scales with session load from Wearable Hub

**Additional log methods:** Barcode scanner (existing), manual search (existing), team meal plan photo scan (same Photo AI flow)

---

### 3. Wearable Hub — Athlete Data

**Layout:**
- Header: data sources label + connected count chip
- Device row: Whoop, Garmin, Apple Watch, Polar — each shows connected (green glow) or + Add state
- GPS card: source label + CATAPULT/GARMIN chip, metric grid (distance, player load, sprints), HSR percentage bar
- Import Team Session button: teal accent, uploads Catapult CSV
- Strength card: amber accent, exercise list with progress bars and kg values

**GPS Data — three entry modes:**

| Mode | How | What's extracted |
|---|---|---|
| Auto-sync | Garmin / Polar → Apple Health → KAIZENN | Distance, pace, HR zones, route |
| Catapult CSV Import | Coach exports → athlete imports from Files app | Total distance, HSR%, sprint count, player load, accel/decel |
| Manual entry | Athlete inputs duration, distance, intensity | Feeds ACWR as estimated load |

**GPS metrics displayed:** Total distance (km), Player Load, Sprint Count, High-Speed Running % (HSR)

**Strength Logger:**
- Exercise library: Squat, Bench Press, Deadlift, Power Clean, RDL, Pull-up, custom
- Per exercise: sets × reps × weight (fast bubble UI)
- Auto-calculates: total volume (sets × reps × weight), estimated 1RM
- Progress chart per exercise over time
- Volume feeds into ACWR load calculation alongside GPS sessions

**Photo AI — Training Menu Scanner:**
- Athlete photos printed program, whiteboard session, or handwritten plan
- Claude Vision extracts: exercises, sets, reps, weights, distances, intervals
- Returns structured JSON → pre-populates session for one-tap confirm
- Same Claude API call as food scanning, different system prompt

**ACWR Calculation:**
- Acute load = sum of all session loads (GPS + strength) in last 7 days
- Chronic load = rolling 4-week average
- ACWR = acute / chronic
- Sweet spot: 0.8–1.3. Below: undertraining. Above 1.5: overload danger zone
- Displayed as visual needle on track, with zone labels

---

### 4. AI Coach — Kai Coach

**Layout:**
- Sport + position + season phase context header
- "Kai Coach" title (not "AI Coach" — the name makes it feel personal)
- Today's Brief card: gradient border, coach message with bolded key data points
- Focus Today section: numbered action items (1/2/3) with colour-coded number blocks
- Chat input pinned above tab bar: placeholder "Ask Kai anything..." + send button

**Sport Intelligence:**
Kai knows: sport, position, season phase, this week's load (GPS + strength combined), last night's sleep, HRV trend, nutrition for the day, days until next match/race.

**Proactive daily brief — language by sport:**

| Sport | Language examples |
|---|---|
| Rugby | "Match week edge", "contact load", "captain's run today" |
| Soccer | "Fixture prep", "sprint capacity", "90-min conditioning" |
| Basketball | "Game week", "back-to-back recovery" |
| Gym | "PR block", "progressive overload", "deload week" |
| Running | "Race taper", "long run recovery", "threshold work" |

**System prompt includes:** sport, position, season phase, today's ACWR, last sleep hours, HRV delta, nutrition % complete, days to performance day, position-specific macro targets.

---

### 5. Onboarding Expansion

Current onboarding gains a Sport Profile step:

1. Welcome + name (existing)
2. **Sport selection** — grid of sport cards with minimal icons
3. **Position / role** — dynamic based on sport selected
4. **Season phase** — Pre-season / In-season / Off-season
5. **Performance day** — day picker (what day is your match/race?)
6. **Wearable** — connect Whoop / Garmin / Polar / Apple Watch / skip
7. Goals + targets (existing, now position-informed)

---

## Architecture Notes

**No new dependencies.** All features use existing Apple frameworks + existing Claude API:
- HealthKit — wearable aggregation (Garmin, Polar, Whoop all sync here)
- Claude Vision API — food photo AI + training menu scanner (extend `ClaudeService.swift`)
- URLSession — Catapult CSV parsing (no extra SDK needed)
- SwiftUI Charts — ACWR load curve, lift progress charts
- UserDefaults JSON — GPS sessions, strength sessions, sport profile (matches existing persistence pattern)

**Claude Vision extension to `ClaudeService.swift`:**
- Add `chatWithImage(image: UIImage, messages: [ChatMessage], systemPrompt: String)` method
- Encode image as base64, include in Anthropic messages array as `image` content block
- Same API endpoint, same key, same model — just different message structure

**Sport Profile storage:**
- Add `sportProfile: SportProfile` to `UserProfile` model
- `SportProfile`: sport, position, seasonPhase, performanceDay (weekday int), wearable
- Persisted in `AppState` alongside existing `UserProfile`

**ACWR store:**
- New `LoadStore` observing ActivityStore + new GPS/Strength session stores
- Calculates acute (7-day) and chronic (28-day) rolling load
- Exposed as `@Published var acwr: Double` for Dashboard and AI Coach

---

## What Changes in Existing Files

| File | Change |
|---|---|
| `AppState.swift` | Add `sportProfile: SportProfile` to `UserProfile` |
| `KAIZENNApp.swift` | Add `LoadStore` as `@StateObject` |
| `OnboardingFlowView.swift` | Add Sport Profile steps |
| `DashboardView.swift` | Replace existing dashboard with Readiness Hero layout |
| `CoachView.swift` | Add proactive brief, sport-aware system prompt, numbered actions |
| `NutritionView.swift` | Add Scan Meal button, photo AI flow, editable breakdown |
| `AddFoodView.swift` | Add camera capture + Claude Vision parsing |
| `ClaudeService.swift` | Add `chatWithImage()` method |
| `ActivityView.swift` | Add GPS session view + Strength Logger |
| `LogWorkoutView.swift` | Expand to strength logger (sets × reps × weight) |

**New files:**
| File | Purpose |
|---|---|
| `SportProfile.swift` | Model: sport, position, phase, performanceDay, wearable |
| `LoadStore.swift` | ACWR calculation, acute + chronic load |
| `GPSSession.swift` | Model: GPS session data (distance, player load, sprints, HSR) |
| `StrengthSession.swift` | Model: exercises, sets, reps, weight, volume, 1RM |
| `CatapultParser.swift` | CSV parsing for Catapult exports |
| `WearableHubView.swift` | New Wearable Hub tab screen |
| `FoodPhotoScanView.swift` | Camera capture + Claude Vision + editable breakdown |
| `TrainingMenuScanView.swift` | Camera capture + Claude Vision → session pre-populate |
| `StrengthLoggerView.swift` | Sets × reps × weight logger |
| `ACWRView.swift` | Load curve with needle and zone labels |

---

## Build Priority Order

1. **Sport Profile model + onboarding** — everything downstream depends on this
2. **Dashboard Readiness Hero** — visual centrepiece, replaces existing dashboard
3. **LoadStore + ACWR** — feeds dashboard pillars and AI coach
4. **Wearable Hub tab** — GPS auto-sync, Catapult import, strength logger
5. **Claude Vision** — extend ClaudeService, food photo AI, training menu scanner
6. **Nutrition photo AI + editable breakdown** — Scan Meal flow
7. **AI Coach upgrade** — sport-aware system prompt, proactive brief, numbered actions
8. **Onboarding polish** — sport card grid, position selector

---

## Success Criteria

- Athlete opens app → immediately knows their readiness and what to do today
- Rugby prop and marathon runner both feel the app was built for them
- GPS data from Catapult is visible to the athlete for the first time
- Logging a meal takes under 10 seconds (photo scan path)
- Logging a training session takes under 30 seconds (photo scan path)
- AI Coach brief is specific enough that athlete reads it every morning
