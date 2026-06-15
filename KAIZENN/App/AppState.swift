import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool
    @Published var selectedTab: Tab = .dashboard
    @Published var userProfile: UserProfile

    enum Tab: Int, CaseIterable {
        case dashboard, nutrition, activity, weight, schedule, coach
        var title: String {
            switch self {
            case .dashboard: return "Home"
            case .nutrition: return "Nutrition"
            case .activity: return "Activity"
            case .weight: return "Weight"
            case .schedule: return "Schedule"
            case .coach: return "AI Coach"
            }
        }
        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2.fill"
            case .nutrition: return "fork.knife"
            case .activity: return "figure.run"
            case .weight: return "scalemass.fill"
            case .schedule: return "calendar"
            case .coach: return "brain.head.profile"
            }
        }
    }

    init() {
        let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.hasCompletedOnboarding = completed
        self.userProfile = UserProfile.load()
    }

    func completeOnboarding(profile: UserProfile) {
        userProfile = profile
        profile.save()
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            hasCompletedOnboarding = true
        }
    }
}
