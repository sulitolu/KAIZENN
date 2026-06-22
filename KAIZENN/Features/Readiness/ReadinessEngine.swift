import SwiftUI

struct ReadinessInputs {
    var sleepHours: Double
    var acwr: Double
    var consumedCalories: Double
    var calorieTarget: Double
    var proteinConsumed: Double
    var proteinTarget: Double
    var hrvLatestMs: Double?
    var hrvBaselineMs: Double?
}

enum ReadinessLabel {
    case peak, gameReady, build, recovery

    var displayText: String {
        switch self {
        case .peak:      return "PEAK CONDITION"
        case .gameReady: return "GAME READY"
        case .build:     return "BUILD DAY"
        case .recovery:  return "RECOVERY DAY"
        }
    }

    var color: Color {
        switch self {
        case .peak:      return Color(hex: "5EFFB7")
        case .gameReady: return Color(hex: "7C6FFF")
        case .build:     return Color(hex: "FFB347")
        case .recovery:  return Color(hex: "FF6B8A")
        }
    }
}

struct ReadinessBreakdown {
    let sleepScore: Double
    let loadScore: Double
    let fuelScore: Double
    let hrvScore: Double
    let hrvAvailable: Bool
    let score: Int
    let label: ReadinessLabel
}

enum ReadinessEngine {

    static func sleepScore(_ hours: Double) -> Double {
        min(hours / 8.0, 1.0) * 100
    }

    static func loadScore(_ acwr: Double) -> Double {
        guard acwr != 0 else { return 75 }
        let range: ClosedRange<Double> = 0.8...1.3
        if range.contains(acwr) { return 100 }
        let delta = acwr < range.lowerBound ? range.lowerBound - acwr : acwr - range.upperBound
        return max(0, 100 - (delta * 100))
    }

    static func fuelScore(consumedCalories: Double, calorieTarget: Double,
                          proteinConsumed: Double, proteinTarget: Double) -> Double {
        guard calorieTarget > 0, proteinTarget > 0 else { return 50 }
        let calorieRatio = min(consumedCalories / calorieTarget, 1.0)
        let proteinRatio = min(proteinConsumed / proteinTarget, 1.0)
        return (calorieRatio * 0.5 + proteinRatio * 0.5) * 100
    }

    static func hrvScore(latest: Double?, baseline: Double?) -> Double {
        guard let latest else { return 75 }
        guard let base = baseline, base > 0 else { return 75 }
        let ratio = latest / base
        return min(max(75 + (ratio - 1.0) * 150, 0), 100)
    }

    static func label(for score: Int) -> ReadinessLabel {
        switch score {
        case 80...:   return .peak
        case 60..<80: return .gameReady
        case 40..<60: return .build
        default:      return .recovery
        }
    }

    static func breakdown(for i: ReadinessInputs) -> ReadinessBreakdown {
        let s = sleepScore(i.sleepHours)
        let l = loadScore(i.acwr)
        let f = fuelScore(consumedCalories: i.consumedCalories, calorieTarget: i.calorieTarget,
                          proteinConsumed: i.proteinConsumed, proteinTarget: i.proteinTarget)
        let hrvAvailable = i.hrvLatestMs != nil
        let h = hrvScore(latest: i.hrvLatestMs, baseline: i.hrvBaselineMs)
        let raw = hrvAvailable
            ? s * 0.25 + l * 0.25 + f * 0.25 + h * 0.25
            : s * 0.33 + l * 0.33 + f * 0.34
        let score = Int(raw)
        return ReadinessBreakdown(sleepScore: s, loadScore: l, fuelScore: f, hrvScore: h,
                                  hrvAvailable: hrvAvailable, score: score, label: label(for: score))
    }
}
