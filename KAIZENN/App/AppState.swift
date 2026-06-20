import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool
    @Published var selectedTab: Tab = .dashboard
    @Published var userProfile: UserProfile

    enum Tab: Int, CaseIterable {
        case dashboard, nutrition, hub, coach, schedule

        var title: String {
            switch self {
            case .dashboard: return "Home"
            case .nutrition: return "Fuel"
            case .hub:       return "Hub"
            case .coach:     return "Kai"
            case .schedule:  return "Schedule"
            }
        }

        // Localization key for the tab label; resolve via L.t(titleKey, lang).
        var titleKey: String {
            switch self {
            case .dashboard: return "tab.home"
            case .nutrition: return "tab.fuel"
            case .hub:       return "tab.hub"
            case .coach:     return "tab.kai"
            case .schedule:  return "tab.schedule"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: return "bolt.circle.fill"
            case .nutrition: return "fork.knife"
            case .hub:       return "antenna.radiowaves.left.and.right"
            case .coach:     return "brain.head.profile"
            case .schedule:  return "calendar"
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
