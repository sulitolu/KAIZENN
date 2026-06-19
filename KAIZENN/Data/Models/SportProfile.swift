import Foundation

// MARK: — Sport Profile
/// Stores an athlete's sport-specific identity: the sport they play, their position,
/// the current phase of their training season, and the wearable device they use.
/// Persisted as JSON in UserDefaults alongside UserProfile.
struct SportProfile: Codable {

    var sport: Sport = .other
    var primaryPosition: String = ""
    var trainingPhase: TrainingPhase = .offseason
    var wearableDevice: WearableDevice = .none

    // MARK: Sport

    enum Sport: String, Codable, CaseIterable {
        case rugby
        case soccer
        case basketball
        case americanFootball
        case swimming
        case trackAndField
        case other

        var displayName: String {
            switch self {
            case .rugby:           return "Rugby"
            case .soccer:          return "Soccer"
            case .basketball:      return "Basketball"
            case .americanFootball: return "American Football"
            case .swimming:        return "Swimming"
            case .trackAndField:   return "Track & Field"
            case .other:           return "Other"
            }
        }

        var icon: String {
            switch self {
            case .rugby:           return "sportscourt.fill"
            case .soccer:          return "soccerball"
            case .basketball:      return "basketball.fill"
            case .americanFootball: return "american.football.fill"
            case .swimming:        return "figure.pool.swim"
            case .trackAndField:   return "figure.run"
            case .other:           return "star.circle.fill"
            }
        }

        /// Common positions for each sport, used to populate picker suggestions.
        var commonPositions: [String] {
            switch self {
            case .rugby:
                return ["Prop", "Hooker", "Lock", "Flanker", "Number 8",
                        "Scrum-half", "Fly-half", "Centre", "Wing", "Fullback"]
            case .soccer:
                return ["Goalkeeper", "Centre-back", "Full-back", "Wing-back",
                        "Defensive Midfielder", "Central Midfielder",
                        "Attacking Midfielder", "Winger", "Striker"]
            case .basketball:
                return ["Point Guard", "Shooting Guard", "Small Forward",
                        "Power Forward", "Center"]
            case .americanFootball:
                return ["Quarterback", "Running Back", "Wide Receiver",
                        "Tight End", "Offensive Lineman",
                        "Defensive Lineman", "Linebacker",
                        "Cornerback", "Safety", "Kicker", "Punter"]
            case .swimming:
                return ["Freestyle", "Backstroke", "Breaststroke",
                        "Butterfly", "Individual Medley"]
            case .trackAndField:
                return ["Sprinter", "Middle Distance", "Long Distance",
                        "Hurdler", "High Jump", "Long Jump",
                        "Triple Jump", "Shot Put", "Discus",
                        "Javelin", "Decathlon / Heptathlon"]
            case .other:
                return []
            }
        }
    }

    // MARK: Training Phase

    enum TrainingPhase: String, Codable, CaseIterable {
        case offseason
        case preseason
        case inseason
        case postseason

        var displayName: String {
            switch self {
            case .offseason:  return "Off-Season"
            case .preseason:  return "Pre-Season"
            case .inseason:   return "In-Season"
            case .postseason: return "Post-Season"
            }
        }

        var icon: String {
            switch self {
            case .offseason:  return "moon.zzz.fill"
            case .preseason:  return "bolt.fill"
            case .inseason:   return "flame.fill"
            case .postseason: return "checkmark.seal.fill"
            }
        }

        /// Guidance text shown on the training phase picker.
        var description: String {
            switch self {
            case .offseason:
                return "Recovery and foundational conditioning between competitive seasons."
            case .preseason:
                return "Building fitness and sharpening sport-specific skills before the season starts."
            case .inseason:
                return "Maintaining performance and managing load during the competitive season."
            case .postseason:
                return "Active recovery and reflection immediately after the season ends."
            }
        }
    }

    // MARK: Wearable Device

    enum WearableDevice: String, Codable, CaseIterable {
        case none
        case appleWatch
        case garmin
        case polar
        case whoop
        case other

        var displayName: String {
            switch self {
            case .none:       return "None"
            case .appleWatch: return "Apple Watch"
            case .garmin:     return "Garmin"
            case .polar:      return "Polar"
            case .whoop:      return "WHOOP"
            case .other:      return "Other"
            }
        }

        var icon: String {
            switch self {
            case .none:       return "applewatch.slash"
            case .appleWatch: return "applewatch"
            case .garmin:     return "applewatch.watchface"
            case .polar:      return "heart.circle.fill"
            case .whoop:      return "waveform.path.ecg"
            case .other:      return "applewatch.watchface"
            }
        }

        /// Returns true for devices that can supply HealthKit data on iOS.
        var supportsHealthKit: Bool {
            switch self {
            case .appleWatch: return true
            default:          return false
            }
        }
    }

    // MARK: Persistence

    static let storageKey = "kaizenn_sport_profile"

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    static func load() -> SportProfile {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let profile = try? JSONDecoder().decode(SportProfile.self, from: data)
        else { return SportProfile() }
        return profile
    }
}
