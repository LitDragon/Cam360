import SwiftUI

private enum HomeNavigationRoute: Hashable {
    case recording
    case devices
    case events
}

private enum GalleryNavigationRoute: Hashable {
    case playback
    case downloads
}

struct MainTabView: View {
    @ObservedObject var recordingStore: RecordingStore
    @ObservedObject var deviceListStore: DeviceListStore
    @ObservedObject var galleryStore: GalleryStore
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var livePreviewStore: LivePreviewStore
    @ObservedObject var playbackStore: PlaybackStore
    @ObservedObject var downloadsStore: DownloadsStore
    @ObservedObject var localVideosStore: LocalVideosStore
    @ObservedObject var eventsStore: EventsStore
    @ObservedObject var statisticsStore: StatisticsStore
    let onAddDevice: () -> Void

    @State private var selectedTab: MainTab
    @State private var homeRoute: HomeNavigationRoute?
    @State private var galleryRoute: GalleryNavigationRoute?

    init(
        initialSelectedTab: MainTab = .home,
        recordingStore: RecordingStore,
        deviceListStore: DeviceListStore,
        galleryStore: GalleryStore,
        settingsStore: SettingsStore,
        livePreviewStore: LivePreviewStore,
        playbackStore: PlaybackStore,
        downloadsStore: DownloadsStore,
        localVideosStore: LocalVideosStore,
        eventsStore: EventsStore,
        statisticsStore: StatisticsStore,
        onAddDevice: @escaping () -> Void
    ) {
        _selectedTab = State(initialValue: initialSelectedTab)
        self.recordingStore = recordingStore
        self.deviceListStore = deviceListStore
        self.galleryStore = galleryStore
        self.settingsStore = settingsStore
        self.livePreviewStore = livePreviewStore
        self.playbackStore = playbackStore
        self.downloadsStore = downloadsStore
        self.localVideosStore = localVideosStore
        self.eventsStore = eventsStore
        self.statisticsStore = statisticsStore
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
        case .home:
            homeScreen
        case .gallery:
            galleryScreen
        case .settings:
            SettingsView(store: settingsStore, statisticsStore: statisticsStore, root: .more)
        }
    }

    private var homeScreen: some View {
        NavigationView {
            HomeView(
                store: recordingStore,
                onAddDevice: onAddDevice,
                onOpenRecordingPage: {
                    homeRoute = .recording
                },
                onOpenDeviceList: {
                    homeRoute = .devices
                },
                onOpenEvents: {
                    homeRoute = .events
                }
            )
            .background(homeNavigationLinks)
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

    private var homeNavigationLinks: some View {
        Group {
            homeNavigationLink(tag: .recording) {
                RecordingView(
                    store: recordingStore,
                    settingsStore: settingsStore,
                    livePreviewStore: livePreviewStore,
                    playbackStore: playbackStore,
                    downloadsStore: downloadsStore,
                    localVideosStore: localVideosStore,
                    eventsStore: eventsStore,
                    statisticsStore: statisticsStore,
                    onAddDevice: onAddDevice,
                    onOpenGallery: {
                        homeRoute = nil
                        selectedTab = .gallery
                    },
                    onClose: {
                        homeRoute = nil
                    }
                )
            }

            homeNavigationLink(tag: .devices) {
                DeviceListView(
                    store: deviceListStore,
                    onClose: {
                        homeRoute = nil
                    }
                )
            }

            homeNavigationLink(tag: .events) {
                EventsView(
                    store: eventsStore,
                    onClose: {
                        homeRoute = nil
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
                    localVideosStore: localVideosStore,
                    onClose: {
                        galleryRoute = nil
                    }
                )
            }
        }
        .hidden()
    }

    private func homeNavigationLink<Destination: View>(
        tag: HomeNavigationRoute,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(
            destination: destination()
                .navigationBarHidden(true),
            tag: tag,
            selection: $homeRoute
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
        case .home:
            return recordingStore.shouldShowFeatureSheet || homeRoute != nil
        case .gallery:
            return galleryRoute != nil
        }
    }
}
