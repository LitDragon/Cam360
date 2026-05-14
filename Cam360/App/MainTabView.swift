import SwiftUI

struct MainTabView: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var dashboardStore: DashboardStore
    @ObservedObject var galleryStore: GalleryStore
    @ObservedObject var settingsStore: SettingsStore
    let onOpenFeature: (AppFeatureRoute) -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColor.background.edgesIgnoringSafeArea(.all)

            currentScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.bottom, isTabBarHidden ? 0 : AppLayout.mainTabReservedBottomInset)

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
            DashboardView(
                store: dashboardStore,
                onAddDevice: router.showOnboarding,
                onOpenDeviceList: {
                    onOpenFeature(.deviceList)
                },
                onOpenLivePreview: {
                    onOpenFeature(.livePreview)
                },
                onOpenGallery: {
                    router.showMain(tab: .gallery)
                },
                onOpenPlayback: {
                    onOpenFeature(.playback)
                },
                onOpenDownloads: {
                    onOpenFeature(.downloads)
                },
                onOpenEvents: {
                    onOpenFeature(.events)
                },
                onOpenSettings: {
                    settingsStore.dismissRoute()
                    onOpenFeature(.deviceSettings)
                }
            )
        case .gallery:
            GalleryView(
                store: galleryStore,
                onOpenPlayback: {
                    onOpenFeature(.playback)
                },
                onOpenDownloads: {
                    onOpenFeature(.downloads)
                }
            )
        case .settings:
            SettingsView(store: settingsStore, root: .more)
        }
    }

    private var isTabBarHidden: Bool {
        switch router.selectedMainTab {
        case .settings:
            return false
        case .dashboard:
            return dashboardStore.shouldShowFeatureSheet
        case .gallery:
            return false
        }
    }
}
