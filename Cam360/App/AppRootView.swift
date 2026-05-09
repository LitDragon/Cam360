import SwiftUI

struct AppRootView: View {
    let bootstrap: AppBootstrap

    @ObservedObject private var router: AppRouter

    init(bootstrap: AppBootstrap) {
        self.bootstrap = bootstrap
        _router = ObservedObject(wrappedValue: bootstrap.router)
    }

    var body: some View {
        Group {
            switch router.route {
            case .onboarding:
                NavigationView {
                    DeviceOnboardingView(store: bootstrap.container.deviceOnboardingStore)
                }
                .navigationViewStyle(StackNavigationViewStyle())
            case .main:
                MainTabView(
                    router: router,
                    dashboardStore: bootstrap.container.dashboardStore,
                    galleryStore: bootstrap.container.galleryStore,
                    settingsStore: bootstrap.container.settingsStore,
                    onOpenFeature: router.showFeature(_:)
                )
            case .feature(let featureRoute, _):
                featureScreen(featureRoute)
            }
        }
        .accentColor(AppColor.brand)
    }

    @ViewBuilder
    private func featureScreen(_ route: AppFeatureRoute) -> some View {
        switch route {
        case .deviceList:
            DeviceListView(
                store: bootstrap.container.deviceListStore,
                onClose: router.closeFeature
            )
        case .livePreview:
            LivePreviewView(
                store: bootstrap.container.livePreviewStore,
                onClose: router.closeFeature
            )
        case .playback:
            PlaybackView(
                store: bootstrap.container.playbackStore,
                onClose: router.closeFeature,
                onOpenSettings: {
                    router.showMain(tab: .settings)
                }
            )
        case .downloads:
            DownloadsView(
                store: bootstrap.container.downloadsStore,
                onClose: router.closeFeature
            )
        case .events:
            EventsView(
                store: bootstrap.container.eventsStore,
                onClose: router.closeFeature
            )
        }
    }
}
