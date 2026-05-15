import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: DashboardStore
    let onAddDevice: () -> Void
    let onOpenDeviceList: () -> Void
    let onOpenLivePreview: () -> Void
    let onOpenGallery: () -> Void
    let onOpenPlayback: () -> Void
    let onOpenDownloads: () -> Void
    let onOpenEvents: () -> Void
    let onOpenSettings: () -> Void

    @State private var isDrawerPresented = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                DashboardHeaderView(
                    title: store.selectedDevice?.name ?? "Home",
                    subtitle: store.selectedDevice?.status.title,
                    showsMenu: store.hasDevices,
                    onMenu: toggleDrawer,
                    onSettings: onOpenSettings
                )

                ScrollView(showsIndicators: false) {
                    Group {
                        if store.hasDevices {
                            DashboardConnectedStateView(
                                previewState: store.previewState,
                                recentEvents: store.recentEvents,
                                isRecording: store.isRecording,
                                storageState: store.storageState,
                                onOpenLivePreview: onOpenLivePreview,
                                onToggleRecording: store.toggleRecording,
                                onOpenGallery: onOpenGallery,
                                onOpenPlayback: onOpenPlayback,
                                onOpenDownloads: onOpenDownloads,
                                onOpenEvents: onOpenEvents
                            )
                        } else {
                            DashboardEmptyStateView(
                                onAddDevice: addDevice
                            )
                        }
                    }
                    .padding(.horizontal, AppSpacing.xxl)
                    .padding(.top, AppSpacing.xxl)
                    .padding(.bottom, AppSpacing.xxxl)
                }
            }

            if isDrawerPresented {
                DashboardDrawerOverlay(
                    devices: store.devices,
                    selectedDeviceID: store.selectedDeviceID,
                    onClose: closeDrawer,
                    onSelectDevice: selectDevice(_:),
                    onOpenDeviceList: openDeviceList,
                    onAddDevice: addDevice
                )
            }

            if store.shouldShowFeatureSheet {
                DashboardFeatureSheet(
                    deviceState: store.featureSheetDeviceState,
                    onSkip: dismissFeatureSheet,
                    onEnterHome: completeFeatureSheet
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-dashboard")
        .animation(.easeInOut(duration: 0.2), value: isDrawerPresented)
        .animation(.easeInOut(duration: 0.2), value: store.hasDevices)
        .animation(.easeInOut(duration: 0.2), value: store.shouldShowFeatureSheet)
        .onAppear(perform: store.refresh)
    }
}

private extension DashboardView {
    func toggleDrawer() {
        guard store.shouldShowFeatureSheet == false else {
            return
        }

        isDrawerPresented.toggle()
    }

    func closeDrawer() {
        isDrawerPresented = false
    }

    func selectDevice(_ deviceID: DashboardDeviceItem.ID) {
        store.selectDevice(id: deviceID)
        closeDrawer()
    }

    func addDevice() {
        closeDrawer()
        onAddDevice()
    }

    func openDeviceList() {
        closeDrawer()
        onOpenDeviceList()
    }

    func dismissFeatureSheet() {
        store.dismissFeatureSheet()
    }

    func completeFeatureSheet() {
        store.addPlaceholderDevicesIfNeeded()
        store.dismissFeatureSheet()
    }
}

private struct DashboardHeaderView: View {
    let title: String
    let subtitle: String?
    let showsMenu: Bool
    let onMenu: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            if showsMenu {
                Button(action: onMenu) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColor.brand)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Color.clear
                    .frame(width: 36, height: 36)
            }

            Spacer(minLength: 0)

            VStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.navigationTitle)
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)

                if let subtitle = subtitle {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(AppColor.brand)
                            .frame(width: 5, height: 5)

                        Text(subtitle.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColor.brand)
                    }
                }
            }

            Spacer(minLength: 0)

            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColor.textPrimary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.vertical, AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(AppColor.surface)
        .overlay(
            Rectangle()
                .fill(AppColor.border.opacity(0.8))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

private struct DashboardConnectedStateView: View {
    let previewState: DashboardPreviewState
    let recentEvents: [DashboardRecentEvent]
    let isRecording: Bool
    let storageState: DashboardStorageState
    let onOpenLivePreview: () -> Void
    let onToggleRecording: () -> Void
    let onOpenGallery: () -> Void
    let onOpenPlayback: () -> Void
    let onOpenDownloads: () -> Void
    let onOpenEvents: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            Button(action: onOpenLivePreview) {
                DashboardPreviewCard(state: previewState)
            }
            .buttonStyle(PlainButtonStyle())

            DashboardCaptureControls(
                isRecording: isRecording,
                onCapturePhoto: onOpenLivePreview,
                onToggleRecording: onToggleRecording
            )

            switch storageState {
            case let .available(summary):
                DashboardStorageCard(summary: summary)
            case let .unavailable(title, message):
                DashboardStorageUnavailableCard(
                    title: title,
                    message: message
                )
            }

            DashboardGalleryRow(action: onOpenGallery)
            DashboardFeatureLinkRows(
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
                    DashboardRecentEventsEmptyState()
                } else {
                    VStack(spacing: AppSpacing.md) {
                        ForEach(recentEvents) { event in
                            DashboardEventRow(event: event)
                        }
                    }
                }
            }
        }
    }
}

private struct DashboardPreviewCard: View {
    let state: DashboardPreviewState

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("首页占位")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: AppLayout.dashboardPreviewHeight)
                .clipped()

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: AppSpacing.sm) {
                    DashboardPreviewPill(
                        title: state.statusTitle,
                        dotColor: AppColor.danger
                    )
                    DashboardPreviewPill(title: state.resolutionTitle)

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                HStack {
                    Spacer(minLength: 0)

                    Text(state.timestampText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppArtworkPalette.dashboardPreviewTimestamp)
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
                .stroke(AppArtworkPalette.dashboardPreviewOverlayStroke, lineWidth: AppLayout.hairline)
        )
        .shadow(
            color: AppShadow.dashboardPreview.color,
            radius: AppShadow.dashboardPreview.radius,
            x: AppShadow.dashboardPreview.x,
            y: AppShadow.dashboardPreview.y
        )
    }
}

private struct DashboardPreviewPill: View {
    let title: String
    var dotColor: Color? = nil

    var body: some View {
        HStack(spacing: AppLayout.dashboardPreviewPillDotSize) {
            if let dotColor = dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(
                        width: AppLayout.dashboardPreviewPillDotSize,
                        height: AppLayout.dashboardPreviewPillDotSize
                    )
            }

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppLayout.dashboardPreviewPillVerticalPadding)
        .background(AppArtworkPalette.dashboardPreviewPillBackground)
        .cornerRadius(AppRadius.dashboardPreviewPill)
    }
}

private struct DashboardCaptureControls: View {
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

private struct DashboardStorageCard: View {
    let summary: DashboardStorageSummary

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

private struct DashboardStorageUnavailableCard: View {
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

private struct DashboardGalleryRow: View {
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

private struct DashboardFeatureLinkRows: View {
    let onOpenPlayback: () -> Void
    let onOpenDownloads: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            DashboardFeatureLinkButton(
                title: "Playback",
                subtitle: "查看可回放资源",
                systemImage: "play.rectangle",
                action: onOpenPlayback
            )
            DashboardFeatureLinkButton(
                title: "Downloads",
                subtitle: "管理离线队列",
                systemImage: "arrow.down.circle",
                action: onOpenDownloads
            )
        }
    }
}

private struct DashboardFeatureLinkButton: View {
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

private struct DashboardRecentEventsEmptyState: View {
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

private struct DashboardEventRow: View {
    let event: DashboardRecentEvent

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            DashboardEventArtworkView(artwork: event.artwork)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(event.title)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)

                HStack(spacing: AppSpacing.sm) {
                    DashboardEventBadge(event: event)

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

private struct DashboardEventBadge: View {
    let event: DashboardRecentEvent

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

private struct DashboardEventArtworkView: View {
    let artwork: DashboardEventArtwork

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
                colors: AppArtworkPalette.dashboardEventVehicle,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .landscape:
            return LinearGradient(
                colors: AppArtworkPalette.dashboardEventLandscape,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .nightDrive:
            return LinearGradient(
                colors: AppArtworkPalette.dashboardEventNightDrive,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .parking:
            return LinearGradient(
                colors: AppArtworkPalette.dashboardEventParking,
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

private struct DashboardEmptyStateView: View {
    let onAddDevice: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer(minLength: 28)

            DashboardDeviceIllustration()

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

private struct DashboardDeviceIllustration: View {
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
                            colors: AppArtworkPalette.dashboardDeviceBody,
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

private struct DashboardDrawerOverlay: View {
    let devices: [DashboardDeviceItem]
    let selectedDeviceID: DashboardDeviceItem.ID?
    let onClose: () -> Void
    let onSelectDevice: (DashboardDeviceItem.ID) -> Void
    let onOpenDeviceList: () -> Void
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
                        DashboardDrawerRow(
                            device: device,
                            isSelected: device.id == selectedDeviceID,
                            action: {
                                onSelectDevice(device.id)
                            }
                        )
                    }
                }

                Spacer(minLength: 0)

                Button(action: onOpenDeviceList) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "externaldrive")
                            .font(.system(size: 16, weight: .semibold))

                        Text("Manage Devices")
                            .font(AppTypography.bodyStrong)
                    }
                    .foregroundColor(AppColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColor.background)
                    .cornerRadius(AppRadius.medium)
                }
                .buttonStyle(PlainButtonStyle())

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
            .frame(width: AppLayout.dashboardDrawerWidth)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(AppColor.surface)
            .cornerRadius(AppRadius.xLarge)
            .shadow(color: Color.black.opacity(0.12), radius: 24, x: 10, y: 0)
            .padding(.leading, AppSpacing.lg)
            .padding(.vertical, AppSpacing.lg)
        }
    }

}

private struct DashboardDrawerRow: View {
    let device: DashboardDeviceItem
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
