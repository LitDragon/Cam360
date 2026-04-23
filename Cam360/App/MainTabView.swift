import SwiftUI

struct MainTabView: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColor.background.edgesIgnoringSafeArea(.all)

            currentScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.bottom, isTabBarHidden ? 0 : 108)

            if isTabBarHidden == false {
                MainTabBar(selectedTab: router.selectedMainTab) {
                    router.showMain(tab: $0)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
            }
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch router.selectedMainTab {
        case .dashboard:
            DashboardView()
        case .gallery:
            GalleryView()
        case .settings:
            SettingsView(store: settingsStore)
        }
    }

    private var isTabBarHidden: Bool {
        switch router.selectedMainTab {
        case .settings:
            return settingsStore.route != nil
        case .dashboard, .gallery:
            return false
        }
    }
}
