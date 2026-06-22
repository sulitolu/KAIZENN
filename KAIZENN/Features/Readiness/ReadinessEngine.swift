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

/// Baseline-relative readiness scoring. Pure (no HealthKit) — baselines are passed in.
/// HRV uses ln(SDNN) because Apple HealthKit exposes only SDNN (not RMSSD); the personalization
/// method (vs the athlete's own rolling baseline) is what the research supports, and it transfers.
enum ReadinessEngine {
    // Tunable defaults (see research spec). Full-model weights; renormalised over present pillars.
    static let wRecovery = 0.45, wSleep = 0.30, wStrain = 0.18, wFuel = 0.07
    static let wHRV = 0.30, wRHR = 0.15         // within-Recovery weights
    static let sleepDebtPenaltyPerHour = 3.0, sleepDebtPenaltyCap = 30.0
    static let sleepRegPenaltyPerHour = 10.0, sleepRegPenaltyCap = 20.0, sleepRegTolerance = 1.0
    static let strainSlope = 40.0               // sub drop per unit of (acute/chronic - 1)

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
