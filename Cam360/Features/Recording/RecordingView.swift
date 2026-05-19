import SwiftUI

private enum RecordingNavigationRoute: Hashable {
    case deviceSettings
    case livePreview
    case playback
    case downloads
    case events
}

struct RecordingView: View {
    @ObservedObject var store: RecordingStore
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var livePreviewStore: LivePreviewStore
    @ObservedObject var playbackStore: PlaybackStore
    @ObservedObject var downloadsStore: DownloadsStore
    @ObservedObject var eventsStore: EventsStore

    let onAddDevice: () -> Void
    let onOpenGallery: () -> Void
    let onClose: () -> Void

    @State private var route: RecordingNavigationRoute?

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                AppTopBar(
                    title: recordingTitle,
                    subtitle: store.selectedDevice?.status.title,
                    leadingSystemImage: "arrow.left",
                    leadingAction: onClose,
                    trailingAssetName: "RecordGear",
                    trailingAssetSize: 36,
                    trailingAction: openSettings
                )

                ScrollView(showsIndicators: false) {
                    Group {
                        if store.hasDevices {
                            RecordingConnectedStateView(
                                previewState: store.previewState,
                                recentEvents: store.recentEvents,
                                isRecording: store.isRecording,
                                storageState: store.storageState,
                                onOpenLivePreview: openLivePreview,
                                onToggleRecording: store.toggleRecording,
                                onOpenGallery: onOpenGallery,
                                onOpenPlayback: openPlayback,
                                onOpenDownloads: openDownloads,
                                onOpenEvents: openEvents
                            )
                        } else {
                            RecordingEmptyStateView(
                                onAddDevice: addDevice
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.xxl)
                    .padding(.top, AppSpacing.xxl)
                    .padding(.bottom, AppSpacing.xxxl)
                }
            }

            if store.shouldShowFeatureSheet {
                RecordingFeatureSheet(
                    deviceState: store.featureSheetDeviceState,
                    onSkip: dismissFeatureSheet,
                    onEnterHome: completeFeatureSheet
                )
            }
        }
        .background(navigationLinks)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-recording")
        .animation(.easeInOut(duration: 0.2), value: store.hasDevices)
        .animation(.easeInOut(duration: 0.2), value: store.shouldShowFeatureSheet)
        .onAppear(perform: store.refresh)
    }

    private var recordingTitle: String {
        store.selectedDevice?.name ?? "Recording"
    }

    private var routeBinding: Binding<RecordingNavigationRoute?> {
        Binding(
            get: { route },
            set: { route = $0 }
        )
    }

    private var navigationLinks: some View {
        Group {
            navigationLink(tag: .deviceSettings) {
                SettingsView(
                    store: settingsStore,
                    root: .deviceSettings,
                    embedsNavigationView: false,
                    onClose: dismissRoute
                )
            }

            navigationLink(tag: .livePreview) {
                LivePreviewView(
                    store: livePreviewStore,
                    onClose: dismissRoute
                )
            }

            navigationLink(tag: .playback) {
                PlaybackView(
                    store: playbackStore,
                    onClose: dismissRoute,
                    onOpenSettings: openSettings
                )
            }

            navigationLink(tag: .downloads) {
                DownloadsView(
                    store: downloadsStore,
                    onClose: dismissRoute
                )
            }

            navigationLink(tag: .events) {
                EventsView(
                    store: eventsStore,
                    onClose: dismissRoute
                )
            }
        }
        .hidden()
    }

    private func navigationLink<Destination: View>(
        tag: RecordingNavigationRoute,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(
            destination: destination()
                .navigationBarHidden(true),
            tag: tag,
            selection: routeBinding
        ) {
            EmptyView()
        }
    }
}

private extension RecordingView {
    func openSettings() {
        settingsStore.dismissRoute()
        settingsStore.prepareDeviceSettings(for: store.selectedDeviceID)
        route = .deviceSettings
    }

    func openLivePreview() {
        route = .livePreview
    }

    func openPlayback() {
        route = .playback
    }

    func openDownloads() {
        route = .downloads
    }

    func openEvents() {
        route = .events
    }

    func dismissRoute() {
        route = nil
    }

    func addDevice() {
        onAddDevice()
    }

    func dismissFeatureSheet() {
        store.dismissFeatureSheet()
    }

    func completeFeatureSheet() {
        store.addPlaceholderDevicesIfNeeded()
        store.dismissFeatureSheet()
    }
}

private struct RecordingConnectedStateView: View {
    let previewState: RecordingPreviewState
    let recentEvents: [RecordingRecentEvent]
    let isRecording: Bool
    let storageState: RecordingStorageState
    let onOpenLivePreview: () -> Void
    let onToggleRecording: () -> Void
    let onOpenGallery: () -> Void
    let onOpenPlayback: () -> Void
    let onOpenDownloads: () -> Void
    let onOpenEvents: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            Button(action: onOpenLivePreview) {
                RecordingPreviewCard(state: previewState)
            }
            .buttonStyle(PlainButtonStyle())

            RecordingCaptureControls(
                isRecording: isRecording,
                onCapturePhoto: onOpenLivePreview,
                onToggleRecording: onToggleRecording
            )

            switch storageState {
            case let .available(summary):
                RecordingStorageCard(summary: summary)
            case let .unavailable(title, message):
                RecordingStorageUnavailableCard(
                    title: title,
                    message: message
                )
            }

            RecordingGalleryRow(action: onOpenGallery)
            RecordingFeatureLinkRows(
                onOpenPlayback: onOpenPlayback,
                onOpenDownloads: onOpenDownloads
            )

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Text("Recent Events")
                        .font(AppTypography.bodyStrong)
                        .foregroundColor(AppColor.textPrimary)

                    Spacer(minLength: 0)

                    if recentEvents.isEmpty == false {
                        Button(action: onOpenEvents) {
                            Text("View all")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColor.brand)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                if recentEvents.isEmpty {
                    RecordingRecentEventsEmptyState()
                } else {
                    VStack(spacing: AppSpacing.md) {
                        ForEach(recentEvents) { event in
                            RecordingEventRow(event: event)
                        }
                    }
                }
            }
        }
    }
}

private struct RecordingPreviewCard: View {
    let state: RecordingPreviewState

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("首页占位")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: AppLayout.recordingPreviewHeight)
                .clipped()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: AppSpacing.sm) {
                    RecordingPreviewPill(
                        title: state.statusTitle,
                        dotColor: AppColor.danger
                    )
                    RecordingPreviewPill(title: state.resolutionTitle)

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                HStack {
                    Spacer(minLength: 0)

                    Text(state.timestampText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppArtworkPalette.recordingPreviewTimestamp)
                        .padding(.horizontal, AppSpacing.sm)
                        .frame(height: 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.black.opacity(0.2))
                        )
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .stroke(AppArtworkPalette.recordingPreviewOverlayStroke, lineWidth: AppLayout.hairline)
        )
        .shadow(
            color: AppShadow.recordingPreview.color,
            radius: AppShadow.recordingPreview.radius,
            x: AppShadow.recordingPreview.x,
            y: AppShadow.recordingPreview.y
        )
    }
}

private struct RecordingPreviewPill: View {
    let title: String
    var dotColor: Color? = nil

    var body: some View {
        HStack(spacing: AppLayout.recordingPreviewPillDotSize) {
            if let dotColor = dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(
                        width: AppLayout.recordingPreviewPillDotSize,
                        height: AppLayout.recordingPreviewPillDotSize
                    )
            }

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppLayout.recordingPreviewPillVerticalPadding)
        .background(AppArtworkPalette.recordingPreviewPillBackground)
        .cornerRadius(AppRadius.recordingPreviewPill)
    }
}

private struct RecordingCaptureControls: View {
    let isRecording: Bool
    let onCapturePhoto: () -> Void
    let onToggleRecording: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Button(action: onCapturePhoto) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "camera")
                        .font(.system(size: 15, weight: .medium))

                    Text("Photo")
                        .font(AppTypography.bodyStrong)
                }
                .foregroundColor(AppColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
                .background(AppColor.surface)
                .cornerRadius(AppRadius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .stroke(AppColor.border.opacity(0.7), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: onToggleRecording) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                        .font(.system(size: 17, weight: .semibold))

                    Text(isRecording ? "Stop Recording" : "Start Recording")
                        .font(AppTypography.bodyStrong)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
                .background(isRecording ? AppColor.danger : AppColor.brand)
                .cornerRadius(AppRadius.medium)
                .shadow(color: (isRecording ? AppColor.danger : AppColor.brand).opacity(0.2), radius: 16, x: 0, y: 8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

private struct RecordingStorageCard: View {
    let summary: RecordingStorageSummary

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Storage Summary")
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)

                Spacer(minLength: 0)

                Text(summary.usageText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColor.textSecondary)
            }

            Text("\(summary.usedCapacityText) / \(summary.totalCapacityText)")
                .font(AppTypography.body)
                .foregroundColor(AppColor.textSecondary)

            AppProgressBar(
                progress: CGFloat(summary.usageFraction),
                minimumFillWidth: 12,
                trackColor: AppColor.border.opacity(0.35),
                cornerRadius: 3
            )
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.lg)
        .appSurface()
    }
}

private struct RecordingStorageUnavailableCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Circle()
                .fill(AppColor.accentSurface)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "sdcard")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColor.brand)
                )

            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)

                Text(message)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, AppSpacing.xxl)
        .appSurface()
    }
}

private struct RecordingGalleryRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColor.brand)

                Text("Open Full Gallery")
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColor.border)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.lg)
            .appSurface()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct RecordingFeatureLinkRows: View {
    let onOpenPlayback: () -> Void
    let onOpenDownloads: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            RecordingFeatureLinkButton(
                title: "Playback",
                subtitle: "查看可回放资源",
                systemImage: "play.rectangle",
                action: onOpenPlayback
            )
            RecordingFeatureLinkButton(
                title: "Downloads",
                subtitle: "管理离线队列",
                systemImage: "arrow.down.circle",
                action: onOpenDownloads
            )
        }
    }
}

private struct RecordingFeatureLinkButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColor.brand)
                    .frame(width: 34, height: 34)
                    .background(AppColor.accentSurface)
                    .cornerRadius(AppRadius.small)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.bodyStrong)
                        .foregroundColor(AppColor.textPrimary)

                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .frame(maxWidth: .infinity)
            .appSurface()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct RecordingRecentEventsEmptyState: View {
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Circle()
                .fill(AppColor.surfaceMuted)
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "tray")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(AppColor.textSecondary.opacity(0.8))
                )

            VStack(spacing: AppSpacing.sm) {
                Text("No recent events")
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)

                Text("New driving events and saved clips will appear here.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)

                Text("You can still view all recordings in Full Gallery.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.textSecondary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.xl)
        .padding(.vertical, 44)
    }
}

private struct RecordingEventRow: View {
    let event: RecordingRecentEvent

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            RecordingEventArtworkView(artwork: event.artwork)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(event.title)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)

                HStack(spacing: AppSpacing.sm) {
                    RecordingEventBadge(event: event)

                    Text(event.detail)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColor.textSecondary)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColor.border)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .frame(height: 74)
        .appSurface(borderColor: AppColor.border.opacity(0.65))
    }
}

private struct RecordingEventBadge: View {
    let event: RecordingRecentEvent

    var body: some View {
        Text(event.badgeTitle)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, AppSpacing.xs)
            .background(backgroundColor)
            .cornerRadius(6)
    }

    private var backgroundColor: Color {
        switch event.badgeTone {
        case .danger:
            return Color(hex: "#BA1A1A")
        default:
            return Color(hex: "#585F70")
        }
    }
}

private struct RecordingEventArtworkView: View {
    let artwork: RecordingEventArtwork

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(backgroundGradient)
                .frame(width: 64, height: 48)

            Image(systemName: symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))
        }
    }

    private var backgroundGradient: LinearGradient {
        switch artwork {
        case .vehicle:
            return LinearGradient(
                colors: AppArtworkPalette.recordingEventVehicle,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .landscape:
            return LinearGradient(
                colors: AppArtworkPalette.recordingEventLandscape,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .nightDrive:
            return LinearGradient(
                colors: AppArtworkPalette.recordingEventNightDrive,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .parking:
            return LinearGradient(
                colors: AppArtworkPalette.recordingEventParking,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var symbolName: String {
        switch artwork {
        case .vehicle:
            return "car.fill"
        case .landscape:
            return "leaf.fill"
        case .nightDrive:
            return "camera.fill"
        case .parking:
            return "p.circle.fill"
        }
    }
}

private struct RecordingEmptyStateView: View {
    let onAddDevice: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer(minLength: 28)

            RecordingDeviceIllustration()

            VStack(spacing: AppSpacing.sm) {
                Text("No device added yet")
                    .font(AppTypography.pageTitle)
                    .foregroundColor(AppColor.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Connect your dashcam to start recording your journeys and manage your clips.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryButton(
                title: "Add Device",
                leadingSystemImageName: "plus",
                action: onAddDevice
            )

            Button(action: {}) {
                Text("Need help pairing?")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.brand)
            }
            .buttonStyle(PlainButtonStyle())

            Spacer(minLength: 0)
        }
        .frame(minHeight: 560)
    }
}

private struct RecordingDeviceIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(AppColor.accentSurface.opacity(0.68))
                .frame(width: 176, height: 176)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color.white)
                .frame(width: 62, height: 116)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(AppColor.border, lineWidth: 1)
                )
                .rotationEffect(.degrees(-7))
                .offset(x: -46, y: -4)

            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(AppColor.brand)

                Image(systemName: "wifi")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(AppColor.brand)
            }
            .offset(x: -44, y: 6)

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppColor.textPrimary.opacity(0.78))
                    .frame(width: 70, height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.18),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .offset(y: 8)

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: AppArtworkPalette.recordingDeviceBody,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 118, height: 74)
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.82))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle()
                                    .fill(AppColor.textPrimary.opacity(0.82))
                                    .frame(width: 24, height: 24)
                            )
                    )
                    .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 8)
            }
            .offset(x: 32, y: 22)

            Circle()
                .stroke(AppColor.brand.opacity(0.18), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                .frame(width: 172, height: 122)
                .offset(x: 8, y: -6)

            Group {
                Circle()
                    .fill(Color.white)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColor.brand)
                    )
                    .offset(x: -24, y: -58)

                Circle()
                    .fill(Color.white)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "bolt.horizontal.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppColor.brand)
                    )
                    .offset(x: 66, y: -58)
            }
        }
        .frame(width: 240, height: 200)
    }
}

struct RecordingDrawerOverlay: View {
    let devices: [RecordingDeviceItem]
    let selectedDeviceID: RecordingDeviceItem.ID?
    let onClose: () -> Void
    let onSelectDevice: (RecordingDeviceItem.ID) -> Void
    let onAddDevice: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.2)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture(perform: onClose)

            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Devices")
                        .font(AppTypography.pageTitle)
                        .foregroundColor(AppColor.textPrimary)

                    Text("\(devices.count) device\(devices.count == 1 ? "" : "s")")
                        .font(AppTypography.body)
                        .foregroundColor(AppColor.textSecondary)
                }

                VStack(spacing: AppSpacing.md) {
                    ForEach(devices) { device in
                        RecordingDrawerRow(
                            device: device,
                            isSelected: device.id == selectedDeviceID,
                            action: {
                                onSelectDevice(device.id)
                            }
                        )
                    }
                }

                Spacer(minLength: 0)

                Button(action: onAddDevice) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16, weight: .semibold))

                        Text("Add New Device")
                            .font(AppTypography.bodyStrong)
                    }
                    .foregroundColor(AppColor.brand)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColor.accentSurface.opacity(0.65))
                    .cornerRadius(AppRadius.medium)
                }
                .buttonStyle(PlainButtonStyle())

                Text(AppInfo.brandedVersionText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColor.border)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.xxxl)
            .padding(.bottom, AppSpacing.xl)
            .frame(width: AppLayout.recordingDrawerWidth)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(AppColor.surface)
            .cornerRadius(AppRadius.xLarge)
            .shadow(color: Color.black.opacity(0.12), radius: 24, x: 10, y: 0)
            .padding(.leading, AppSpacing.lg)
            .padding(.vertical, AppSpacing.lg)
        }
    }

}

private struct RecordingDrawerRow: View {
    let device: RecordingDeviceItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                        .fill(Color.white.opacity(isSelected ? 0.18 : 0.9))
                        .frame(width: 38, height: 38)

                    Image(systemName: "camera.macro")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(isSelected ? .white : AppColor.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(AppTypography.bodyStrong)
                        .foregroundColor(isSelected ? .white : AppColor.textPrimary)
                        .multilineTextAlignment(.leading)

                    Text(device.status.title)
                        .font(AppTypography.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.86) : statusColor)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(AppRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var backgroundColor: Color {
        isSelected ? AppColor.brand : AppColor.background
    }

    private var statusColor: Color {
        switch device.status {
        case .connected:
            return AppColor.brand
        case .connecting:
            return AppColor.warning
        case .disconnected:
            return AppColor.textSecondary
        }
    }
}
