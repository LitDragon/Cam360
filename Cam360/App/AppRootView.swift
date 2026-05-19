import SwiftUI

struct AppRootView: View {
    let bootstrap: AppBootstrap

    @State private var isShowingOnboarding = false

    init(bootstrap: AppBootstrap) {
        self.bootstrap = bootstrap
    }

    var body: some View {
        Group {
            if isShowingOnboarding {
                onboardingView
            } else {
                mainTabs
            }
        }
        .accentColor(AppColor.brand)
    }

    private var mainTabs: some View {
        MainTabView(
            initialSelectedTab: bootstrap.initialSelectedTab,
            recordingStore: bootstrap.container.recordingStore,
            galleryStore: bootstrap.container.galleryStore,
            settingsStore: bootstrap.container.settingsStore,
            deviceListStore: bootstrap.container.deviceListStore,
            livePreviewStore: bootstrap.container.livePreviewStore,
            playbackStore: bootstrap.container.playbackStore,
            downloadsStore: bootstrap.container.downloadsStore,
            eventsStore: bootstrap.container.eventsStore,
            onAddDevice: {
                isShowingOnboarding = true
            }
        )
    }

    private var onboardingView: some View {
        NavigationView {
            DeviceOnboardingView(
                store: bootstrap.container.deviceOnboardingStore,
                onReturnHome: {
                    isShowingOnboarding = false
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}
