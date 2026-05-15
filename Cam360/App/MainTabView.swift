import SwiftUI

private enum DashboardNavigationRoute: Hashable {
    case deviceList
    case deviceSettings
    case livePreview
    case playback
    case downloads
    case events
}

private enum GalleryNavigationRoute: Hashable {
    case playback
    case downloads
}

struct MainTabView: View {
    @ObservedObject var dashboardStore: DashboardStore
    @ObservedObject var galleryStore: GalleryStore
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var deviceListStore: DeviceListStore
    @ObservedObject var livePreviewStore: LivePreviewStore
    @ObservedObject var playbackStore: PlaybackStore
    @ObservedObject var downloadsStore: DownloadsStore
    @ObservedObject var eventsStore: EventsStore
    let onAddDevice: () -> Void

    @State private var selectedTab: MainTab
    @State private var dashboardRoute: DashboardNavigationRoute?
    @State private var galleryRoute: GalleryNavigationRoute?

    init(
        initialSelectedTab: MainTab = .dashboard,
        dashboardStore: DashboardStore,
        galleryStore: GalleryStore,
        settingsStore: SettingsStore,
        deviceListStore: DeviceListStore,
        livePreviewStore: LivePreviewStore,
        playbackStore: PlaybackStore,
        downloadsStore: DownloadsStore,
        eventsStore: EventsStore,
        onAddDevice: @escaping () -> Void
    ) {
        _selectedTab = State(initialValue: initialSelectedTab)
        self.dashboardStore = dashboardStore
        self.galleryStore = galleryStore
        self.settingsStore = settingsStore
        self.deviceListStore = deviceListStore
        self.livePreviewStore = livePreviewStore
        self.playbackStore = playbackStore
        self.downloadsStore = downloadsStore
        self.eventsStore = eventsStore
        self.onAddDevice = onAddDevice
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppColor.background.edgesIgnoringSafeArea(.all)

            currentScreen
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.bottom, isTabBarHidden ? 0 : AppLayout.mainTabReservedBottomInset)

            if isTabBarHidden == false {
                MainTabBar(selectedTab: selectedTab) {
                    selectedTab = $0
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
            }
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch selectedTab {
        case .dashboard:
            dashboardScreen
        case .gallery:
            galleryScreen
        case .settings:
            SettingsView(store: settingsStore, root: .more)
        }
    }

    private var dashboardScreen: some View {
        NavigationView {
            DashboardView(
                store: dashboardStore,
                onAddDevice: onAddDevice,
                onOpenDeviceList: {
                    dashboardRoute = .deviceList
                },
                onOpenLivePreview: {
                    dashboardRoute = .livePreview
                },
                onOpenGallery: {
                    selectedTab = .gallery
                },
                onOpenPlayback: {
                    dashboardRoute = .playback
                },
                onOpenDownloads: {
                    dashboardRoute = .downloads
                },
                onOpenEvents: {
                    dashboardRoute = .events
                },
                onOpenSettings: {
                    settingsStore.dismissRoute()
                    settingsStore.prepareDeviceSettings(for: dashboardStore.selectedDeviceID)
                    dashboardRoute = .deviceSettings
                }
            )
            .background(dashboardNavigationLinks)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var galleryScreen: some View {
        NavigationView {
            GalleryView(
                store: galleryStore,
                onOpenPlayback: {
                    galleryRoute = .playback
                },
                onOpenDownloads: {
                    galleryRoute = .downloads
                }
            )
            .background(galleryNavigationLinks)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var dashboardNavigationLinks: some View {
        Group {
            dashboardNavigationLink(tag: .deviceList) {
                DeviceListView(
                    store: deviceListStore,
                    onClose: {
                        dashboardRoute = nil
                    }
                )
            }

            dashboardNavigationLink(tag: .deviceSettings) {
                SettingsView(
                    store: settingsStore,
                    root: .deviceSettings,
                    embedsNavigationView: false,
                    onClose: {
                        dashboardRoute = nil
                    }
                )
            }

            dashboardNavigationLink(tag: .livePreview) {
                LivePreviewView(
                    store: livePreviewStore,
                    onClose: {
                        dashboardRoute = nil
                    }
                )
            }

            dashboardNavigationLink(tag: .playback) {
                PlaybackView(
                    store: playbackStore,
                    onClose: {
                        dashboardRoute = nil
                    },
                    onOpenSettings: {
                        dashboardRoute = nil
                        selectedTab = .settings
                    }
                )
            }

            dashboardNavigationLink(tag: .downloads) {
                DownloadsView(
                    store: downloadsStore,
                    onClose: {
                        dashboardRoute = nil
                    }
                )
            }

            dashboardNavigationLink(tag: .events) {
                EventsView(
                    store: eventsStore,
                    onClose: {
                        dashboardRoute = nil
                    }
                )
            }
        }
        .hidden()
    }

    private var galleryNavigationLinks: some View {
        Group {
            galleryNavigationLink(tag: .playback) {
                PlaybackView(
                    store: playbackStore,
                    onClose: {
                        galleryRoute = nil
                    },
                    onOpenSettings: {
                        galleryRoute = nil
                        selectedTab = .settings
                    }
                )
            }

            galleryNavigationLink(tag: .downloads) {
                DownloadsView(
                    store: downloadsStore,
                    onClose: {
                        galleryRoute = nil
                    }
                )
            }
        }
        .hidden()
    }

    private func dashboardNavigationLink<Destination: View>(
        tag: DashboardNavigationRoute,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(
            destination: destination()
                .navigationBarHidden(true),
            tag: tag,
            selection: $dashboardRoute
        ) {
            EmptyView()
        }
    }

    private func galleryNavigationLink<Destination: View>(
        tag: GalleryNavigationRoute,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(
            destination: destination()
                .navigationBarHidden(true),
            tag: tag,
            selection: $galleryRoute
        ) {
            EmptyView()
        }
    }

    private var isTabBarHidden: Bool {
        switch selectedTab {
        case .settings:
            return false
        case .dashboard:
            return dashboardStore.shouldShowFeatureSheet || dashboardRoute != nil
        case .gallery:
            return galleryRoute != nil
        }
    }
}
