# Readiness Score — Research-Backed Redesign (v2)

**Date:** 2026-06-22
**Source:** deep-research pass (26 sources, 25 claims adversarially verified; 20 confirmed, 5 killed)
**Status:** Proposal — not yet implemented

> Evidence grading below: **[A]** = verified in this research pass (confirmed claim, primary source); **[B]** = supported but softer / partially an open question; **[C]** = my engineering judgment where evidence is thin. The research's synthesis stage under-delivered (left placeholders), so the composite weighting here is **[C]** — defensible defaults, NOT validated numbers.

## What the evidence actually says (and what it killed)

**Confirmed [A]:**
- **HRV must be personalized and rolling, not absolute.** A single morning reading is noisy; a **7-day rolling average of lnRMSSD** vs the athlete's *own* baseline is what reveals fatigue. The relationship is **non-monotonic** — both unusually low *and* unusually high lnRMSSD can signal fatigue (parasympathetic saturation). (Plews 2013, DOI 10.1007/s40279-013-0071-8; Plews 2012, PMID 22367011)
- **The validated decision rule** (Vesterinen 2016, PMID 26909534): train hard only when the 7-day rolling lnRMSSD sits **within or above the Smallest Worthwhile Change band (baseline mean ± 0.5 SD)**; otherwise go easy. This produced a +2.1% 3000 m improvement (p=0.004).
- **Session-RPE (RPE × duration) is a validated internal-load measure** (r 0.56–0.97 vs HR-based TRIMP). (Haddad 2017, PMC5673663)
- **The coupled ACWR is statistically flawed.** Replacing the shared term drops the injury odds ratio from ~2.45 to ~1.5; the original authors recommend ACWR **not** be used as an injury-risk gate. (Lolli 2020, DOI 10.1007/s40279-020-01378-6; Impellizzeri)

**Killed by adversarial verification (do NOT claim these):**
- ✗ "HRV-guided training produces *significantly superior* performance" (0-3) — the real effect is **small**, and mainly shows up in vagal-HRV/aerobic markers, not broadly in performance. (Manresa 2021, PMC8507742)
- ✗ "There is *no* evidence for ACWR at all" (0-3) — too strong; ACWR is contested as an *injury gate*, but defensible for trend monitoring (Gabbett/Windt).
- ✗ "EWMA ACWR is *more sensitive* than rolling-average" (1-2) — not established.

## Diagnosis of the current KAIZENN model

| Current pillar | Problem vs evidence |
|---|---|
| Sleep = `min(hours/8,1)×100` | Crude; ignores **debt** and **regularity**, which matter [B]. |
| Load = ACWR 0.8–1.3 sweet-spot → 100 | **This is exactly the criticized method [A].** Presents readiness as injury logic, which the literature rejects. |
| Fuel = 50% cal + 50% protein, weight 25% | No evidence daily fuel predicts next-day readiness at anything like 25% [C]. Over-weighted. |
| HRV = latest vs baseline, weight 25% | Right idea, wrong execution: uses **latest single reading**, not the **7-day rolling lnRMSSD vs an SWC band** [A]. Under-weighted relative to its evidence. |
| Resting HR | **Not used at all** — a validated, free (HealthKit) overreaching/illness signal [A/B]. |
| Subjective wellness | Not used — research finds it **as predictive as HRV** [B] (Saw 2016). |

## Recommended v2 model — baseline-relative composite

**Core principle [A]: score each signal as a deviation from the athlete's own rolling baseline (z-score), not against population-absolute thresholds.** Personalization is the single strongest finding in the literature.

For each input compute `z = (today_or_rolling − baselineMean) / baselineSD`, then a sub-score
`s = clamp(80 + 20·z, 0, 100)` (so "at your normal" ≈ 80; each SD better/worse = ±20). HRV uses the **7-day rolling** lnRMSSD for `today`; others use today vs baseline.

| Input | Weight [C] | Transform | Baseline window | Evidence |
|---|---|---|---|---|
| **HRV (lnRMSSD, 7-day rolling)** | 0.30 | z vs SWC band (±0.5 SD → full credit); penalize below | 60-day mean/SD | [A] Plews, Vesterinen |
| **Sleep** | 0.25 | duration vs personal need + 7-day **debt** penalty + **regularity** (SD of midpoint) | 14–28 day | [B] |
| **Resting HR (trend)** | 0.15 | inverted z (elevation = worse) | 30-day | [A/B] Plews |
| **Training strain** | 0.15 | sRPE load: acute (7-day EWMA) vs chronic (28-day EWMA) as a **fatigue** signal, NOT an injury gate | 28-day | [A] Haddad; [A] drop ACWR-gate |
| **Subjective wellness** | 0.10 | mean of soreness/fatigue/mood/stress (1–5) → 0–100 | n/a (today) | [B] Saw 2016 |
| **Fuel** | 0.05 | keep current cal/protein, **demoted** | n/a | [C] |

`readiness = Σ(weightᵢ · subScoreᵢ) / Σ(weights present)` → **graceful degradation**: if an input is missing, renormalize over what's present (require at least HRV *or* sleep, else show "insufficient data" rather than a fake number). This generalizes the current 3-pillar fallback.

**Labels** — because inputs are baseline-relative, the score already centers on the athlete's norm. Keep 0–100 bands but **frame them as deviation from your normal, not absolute fitness**: ≥85 Primed · 70–84 Ready · 55–69 Moderate · 40–54 Caution · <40 Recover. (Thresholds [C] — tune in practice.)

## Inputs that need NEW instrumentation (flagged per your "best-possible" choice)

| Input | Status in KAIZENN | What's needed |
|---|---|---|
| HRV 7-day rolling lnRMSSD + 60-day SWC | HealthKit has HRV samples | **New baseline logic** (rolling mean/SD, ln transform) |
| Resting HR trend | HealthKit has RHR | **New** — just start consuming it + baseline |
| Sleep debt + regularity | HealthKit has sleep | **New logic** (cumulative deficit, midpoint SD) |
| Session-RPE load | Not collected | **New UI** — post-session 1–10 RPE prompt |
| Subjective wellness | Not collected | **New UI** — 10-sec morning check-in (soreness/fatigue/mood/stress) |
| Menstrual phase / alcohol / illness | Not collected | Optional logs; **effect sizes unverified [C]** |
| Standing HRV (most predictive vagal index, Manresa) | Not collected | Guided standing measurement — hard; likely skip |

## Honest caveats (well-supported — keep these in the UI/expectations)

- **Effect sizes are small.** A composite readiness score is a *soft daily nudge*, not a precise predictor of performance or injury. [A]
- **Individual variation is large** — population/absolute thresholds fail; you must baseline per athlete. [A]
- **No composite readiness score is validated end-to-end.** Commercial scores (WHOOP/Oura/Garmin/Polar) are largely proprietary with only modest independent validation; don't treat them as ground truth. [B]
- **Don't present readiness as injury risk** — the ACWR-style framing that implies this is not supported. [A]
- The weighting scheme here is a **defensible default, not a validated constant** — expose it as tunable. [C]

## Key citations
- Plews et al. 2013, *Sports Med* — HRV personalization, 7-day rolling, non-monotonic. DOI 10.1007/s40279-013-0071-8
- Plews et al. 2012 — lnRMSSD & CV decline in functional overreaching. PMID 22367011
- Vesterinen et al. 2016 — HRV-guided training via SWC band. PMID 26909534
- Manresa-Rocamora et al. 2021 — meta-analysis: HRV-guided benefit modest. PMC8507742
- Haddad et al. 2017 — session-RPE validity. PMC5673663
- Lolli et al. 2020, *Sports Med* — ACWR coupling artefact. DOI 10.1007/s40279-020-01378-6
- Impellizzeri et al. — ACWR conceptual issues & pitfalls.
- Saw et al. 2016, *Sports Med* — subjective wellness ≥ objective markers.
- Oura "Readiness Contributors" — example of a documented commercial composite.

## Open questions the research did not fully resolve
Exact sleep thresholds for next-day readiness; subjective-wellness effect sizes vs HRV head-to-head; validated internals of WHOOP/Oura/Garmin/Polar; effect sizes for menstrual/alcohol/age/illness; whether the HRV penalty applies to all athletes or mainly a high-vagal subgroup.
