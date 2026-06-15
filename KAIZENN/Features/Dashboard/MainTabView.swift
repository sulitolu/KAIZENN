import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthKitManager: HealthKitManager

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $appState.selectedTab) {
                DashboardView()
                    .tag(AppState.Tab.dashboard)

                NutritionView()
                    .tag(AppState.Tab.nutrition)

                ActivityView()
                    .tag(AppState.Tab.activity)

                WeightView()
                    .tag(AppState.Tab.weight)

                ScheduleView()
                    .tag(AppState.Tab.schedule)

                CoachView()
                    .tag(AppState.Tab.coach)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            KTabBar(selectedTab: $appState.selectedTab)
        }
        .background(KTheme.Colors.background)
        .ignoresSafeArea(edges: .bottom)
        .task {
            await healthKitManager.requestAuthorization()
        }
    }
}

// MARK: — Custom Tab Bar
struct KTabBar: View {
    @Binding var selectedTab: AppState.Tab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppState.Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(KTheme.Animation.snappy) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: KTheme.Radius.md)
                                    .fill(KTheme.Colors.accentPrimary.opacity(0.15))
                                    .frame(width: 44, height: 32)
                                    .kGlow(color: KTheme.Colors.accentPrimary, radius: 12)
                            }
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? KTheme.Colors.accentPrimary : KTheme.Colors.textTertiary)
                                .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                                .animation(KTheme.Animation.bounce, value: selectedTab == tab)
                        }
                        .frame(width: 44, height: 32)
                        Text(tab.title)
                            .font(KTheme.Typography.caption)
                            .foregroundColor(selectedTab == tab ? KTheme.Colors.accentPrimary : KTheme.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, KTheme.Spacing.md)
        .padding(.top, KTheme.Spacing.sm)
        .padding(.bottom, KTheme.Spacing.lg)
        .background(
            KTheme.Colors.surface
                .ignoresSafeArea(edges: .bottom)
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(KTheme.Colors.border),
                    alignment: .top
                )
        )
    }
}
