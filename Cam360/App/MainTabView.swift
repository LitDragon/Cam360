import SwiftUI

private enum HomeNavigationRoute: Hashable {
    case recording
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
    @ObservedObject var recordingStore: RecordingStore
    @ObservedObject var galleryStore: GalleryStore
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var livePreviewStore: LivePreviewStore
    @ObservedObject var playbackStore: PlaybackStore
    @ObservedObject var downloadsStore: DownloadsStore
    @ObservedObject var eventsStore: EventsStore
    let onAddDevice: () -> Void

    @State private var selectedTab: MainTab
    @State private var homeRoute: HomeNavigationRoute?
    @State private var galleryRoute: GalleryNavigationRoute?

    init(
        initialSelectedTab: MainTab = .home,
        recordingStore: RecordingStore,
        galleryStore: GalleryStore,
        settingsStore: SettingsStore,
        livePreviewStore: LivePreviewStore,
        playbackStore: PlaybackStore,
        downloadsStore: DownloadsStore,
        eventsStore: EventsStore,
        onAddDevice: @escaping () -> Void
    ) {
        _selectedTab = State(initialValue: initialSelectedTab)
        self.recordingStore = recordingStore
        self.galleryStore = galleryStore
        self.settingsStore = settingsStore
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
        case .home:
            homeScreen
        case .gallery:
            galleryScreen
        case .settings:
            SettingsView(store: settingsStore, root: .more)
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
                    onAddDevice: onAddDevice,
                    onOpenLivePreview: {
                        homeRoute = .livePreview
                    },
                    onOpenGallery: {
                        homeRoute = nil
                        selectedTab = .gallery
                    },
                    onOpenPlayback: {
                        homeRoute = .playback
                    },
                    onOpenDownloads: {
                        homeRoute = .downloads
                    },
                    onOpenEvents: {
                        homeRoute = .events
                    },
                    onOpenSettings: {
                        settingsStore.dismissRoute()
                        settingsStore.prepareDeviceSettings(for: recordingStore.selectedDeviceID)
                        homeRoute = .deviceSettings
                    }
                )
            }

            homeNavigationLink(tag: .deviceSettings) {
                SettingsView(
                    store: settingsStore,
                    root: .deviceSettings,
                    embedsNavigationView: false,
                    onClose: {
                        homeRoute = nil
                    }
                )
            }

            homeNavigationLink(tag: .livePreview) {
                LivePreviewView(
                    store: livePreviewStore,
                    onClose: {
                        homeRoute = nil
                    }
                )
            }

            homeNavigationLink(tag: .playback) {
                PlaybackView(
                    store: playbackStore,
                    onClose: {
                        homeRoute = nil
                    },
                    onOpenSettings: {
                        homeRoute = nil
                        selectedTab = .settings
                    }
                )
            }

            homeNavigationLink(tag: .downloads) {
                DownloadsView(
                    store: downloadsStore,
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
                .navigationBarHidden(tag != .recording),
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
