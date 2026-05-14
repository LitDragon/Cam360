import SwiftUI

struct AppRootView: View {
    let bootstrap: AppBootstrap

    @ObservedObject private var router: AppRouter

    init(bootstrap: AppBootstrap) {
        self.bootstrap = bootstrap
        _router = ObservedObject(wrappedValue: bootstrap.router)
    }

    var body: some View {
        ZStack {
            switch router.route {
            case .onboarding:
                NavigationView {
                    DeviceOnboardingView(store: bootstrap.container.deviceOnboardingStore)
                }
                .navigationViewStyle(StackNavigationViewStyle())
            case .main:
                mainTabs
            case .feature(.deviceSettings, _):
                mainTabs

                featureScreen(.deviceSettings)
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
            case .feature(let featureRoute, _):
                featureScreen(featureRoute)
            }
        }
        .accentColor(AppColor.brand)
    }

    private var mainTabs: some View {
        MainTabView(
            router: router,
            dashboardStore: bootstrap.container.dashboardStore,
            galleryStore: bootstrap.container.galleryStore,
            settingsStore: bootstrap.container.settingsStore,
            onOpenFeature: router.showFeature(_:)
        )
    }

    @ViewBuilder
    private func featureScreen(_ route: AppFeatureRoute) -> some View {
        switch route {
        case .deviceList:
            DeviceListView(
                store: bootstrap.container.deviceListStore,
                onClose: router.closeFeature
            )
        case .deviceSettings:
            SettingsView(
                store: bootstrap.container.settingsStore,
                root: .deviceSettings,
                onClose: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        router.closeFeature()
                    }
                }
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
