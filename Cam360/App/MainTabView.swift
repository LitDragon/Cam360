import SwiftUI

struct MainTabView: View {
    @ObservedObject var router: AppRouter

    let container: AppContainer

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColor.background.edgesIgnoringSafeArea(.all)

            currentScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.bottom, 108)

            MainTabBar(selectedTab: router.selectedMainTab) {
                router.showMain(tab: $0)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.lg)
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch router.selectedMainTab {
        case .dashboard:
            DashboardView(
                deviceStore: container.deviceListStore,
                livePreviewStore: container.livePreviewStore
            )
        case .gallery:
            GalleryView(
                playbackStore: container.playbackStore,
                downloadsStore: container.downloadsStore
            )
        case .events:
            EventsView()
        case .settings:
            SettingsView(store: container.settingsStore)
        }
    }
}
