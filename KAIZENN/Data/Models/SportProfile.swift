import Foundation

struct SportProfile: Codable, Equatable {
    var sport: Sport = .other
    var position: String = ""
    var seasonPhase: SeasonPhase = .inSeason
    var performanceDayOfWeek: Int = 6  // 1=Sunday … 7=Saturday
    var wearable: Wearable = .appleWatch

    enum Sport: String, Codable, CaseIterable {
        case rugby, soccer, basketball, athletics, gym, swimming, cycling, other
        var displayName: String { rawValue.capitalized }
        var positions: [String] {
            switch self {
            case .rugby:      return ["Prop","Hooker","Lock","Flanker","No.8","Scrum-half","Fly-half","Centre","Wing","Fullback"]
            case .soccer:     return ["Goalkeeper","Defender","Midfielder","Winger","Striker"]
            case .basketball: return ["Point Guard","Shooting Guard","Small Forward","Power Forward","Centre"]
            case .athletics:  return ["Sprinter","Distance","Thrower","Jumper","Multi-event"]
            case .gym:        return ["Powerlifter","Bodybuilder","CrossFit","General Fitness"]
            case .swimming:   return ["Freestyle","Backstroke","Breaststroke","Butterfly","IM"]
            case .cycling:    return ["Road","Track","MTB","Triathlon"]
            case .other:      return ["Athlete"]
            }
        }
        var acwrTarget: ClosedRange<Double> { 0.8...1.3 }
        var proteinPerKg: Double {
            switch self {
            case .rugby, .gym: return 2.0
            case .basketball, .soccer: return 1.8
            default: return 1.6
            }
        }
    }

    enum SeasonPhase: String, Codable, CaseIterable {
        case preSeason, inSeason, offSeason
        var displayName: String {
            switch self {
            case .preSeason: return "Pre-Season"
            case .inSeason:  return "In-Season"
            case .offSeason: return "Off-Season"
            }
        }
    }

    enum Wearable: String, Codable, CaseIterable {
        case whoop, garmin, polar, appleWatch, none
        var displayName: String {
            switch self {
            case .whoop:      return "Whoop"
            case .garmin:     return "Garmin"
            case .polar:      return "Polar"
            case .appleWatch: return "Apple Watch"
            case .none:       return "None"
            }
        }
    }

    var daysUntilPerformance: Int {
        let today = Calendar.current.component(.weekday, from: Date())
        let diff = performanceDayOfWeek - today
        return diff >= 0 ? diff : diff + 7
    }
}
