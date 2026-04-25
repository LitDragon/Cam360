import SwiftUI

struct DashboardView: View {
    @ObservedObject var store: DashboardStore
    let onAddDevice: () -> Void
    let onOpenGallery: () -> Void
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
                                recentEvents: store.recentEvents,
                                isRecording: store.isRecording,
                                storageState: store.storageState,
                                onToggleRecording: store.toggleRecording,
                                onOpenGallery: onOpenGallery
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
                    onAddDevice: addDevice
                )
            }

            if store.shouldShowFeatureSheet {
                DashboardFeatureSheet(
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

    func dismissFeatureSheet() {
        store.dismissFeatureSheet()
    }

    func completeFeatureSheet() {
        store.addMockDevicesIfNeeded()
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
    let recentEvents: [DashboardRecentEvent]
    let isRecording: Bool
    let storageState: DashboardStorageState
    let onToggleRecording: () -> Void
    let onOpenGallery: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            DashboardPreviewCard()

            DashboardCaptureControls(
                isRecording: isRecording,
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

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Text("Recent Events")
                        .font(AppTypography.bodyStrong)
                        .foregroundColor(AppColor.textPrimary)

                    Spacer(minLength: 0)

                    if recentEvents.isEmpty == false {
                        Button(action: onOpenGallery) {
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
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.56, blue: 0.9),
                            Color(red: 0.14, green: 0.43, blue: 0.82),
                            Color(red: 0.1, green: 0.23, blue: 0.44)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .frame(height: 214)

            DashboardPreviewLandscape()
                .frame(height: 214)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: AppSpacing.sm) {
                    DashboardPreviewPill(
                        title: "LIVE",
                        dotColor: AppColor.danger
                    )
                    DashboardPreviewPill(title: "4K")

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                HStack {
                    Spacer(minLength: 0)

                    Text("2023-10-27 14:32:15")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.84))
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 20, x: 0, y: 12)
    }
}

private struct DashboardPreviewLandscape: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height * 0.16))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.26, y: geometry.size.height * 0.1))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.38, y: geometry.size.height * 0.76))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height * 0.76))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.77, green: 0.62, blue: 0.35),
                            Color(red: 0.45, green: 0.33, blue: 0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { path in
                    path.move(to: CGPoint(x: geometry.size.width * 0.27, y: geometry.size.height * 0.5))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.44))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.76))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.34, y: geometry.size.height * 0.76))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.07, green: 0.48, blue: 0.76),
                            Color(red: 0.03, green: 0.28, blue: 0.52)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { path in
                    path.move(to: CGPoint(x: geometry.size.width * 0.22, y: geometry.size.height * 0.77))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.45, y: geometry.size.height * 0.58))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.62))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height * 0.92))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.42, green: 0.43, blue: 0.45),
                            Color(red: 0.2, green: 0.21, blue: 0.23)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { path in
                    path.move(to: CGPoint(x: geometry.size.width * 0.64, y: geometry.size.height * 0.65))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.7))
                }
                .stroke(Color(red: 0.24, green: 0.23, blue: 0.19), lineWidth: 4)

                Path { path in
                    path.move(to: CGPoint(x: geometry.size.width * 0.44, y: geometry.size.height * 0.58))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.36, y: geometry.size.height))
                }
                .stroke(Color.white.opacity(0.92), style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [14, 18]))

                Path { path in
                    path.move(to: CGPoint(x: geometry.size.width * 0.46, y: geometry.size.height * 0.58))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.62))
                }
                .stroke(Color.white.opacity(0.86), lineWidth: 2)

                Path { path in
                    path.move(to: CGPoint(x: geometry.size.width * 0.33, y: geometry.size.height * 0.65))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.07, y: geometry.size.height * 0.69))
                }
                .stroke(Color(red: 0.93, green: 0.8, blue: 0.16), lineWidth: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
    }
}

private struct DashboardPreviewPill: View {
    let title: String
    var dotColor: Color? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let dotColor = dotColor {
                Circle()
                    .fill(dotColor)
                    .frame(width: 6, height: 6)
            }

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.42))
        .cornerRadius(10)
    }
}

private struct DashboardCaptureControls: View {
    let isRecording: Bool
    let onToggleRecording: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Button(action: {}) {
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

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(AppColor.border.opacity(0.35))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(AppColor.brand)
                        .frame(width: max(geometry.size.width * CGFloat(summary.usageFraction), 12), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.lg)
        .background(AppColor.surface)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(AppColor.border.opacity(0.7), lineWidth: 1)
        )
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
        .background(AppColor.surface)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(AppColor.border.opacity(0.7), lineWidth: 1)
        )
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
            .background(AppColor.surface)
            .cornerRadius(AppRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke(AppColor.border.opacity(0.7), lineWidth: 1)
            )
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
                    DashboardEventBadge(
                        title: event.badgeTitle,
                        tone: event.badgeTone
                    )

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
        .background(AppColor.surface)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(AppColor.border.opacity(0.65), lineWidth: 1)
        )
    }
}

private struct DashboardEventArtworkView: View {
    let artwork: DashboardEventArtwork

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(backgroundGradient)
                .frame(width: 56, height: 56)

            Image(systemName: symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))
        }
    }

    private var backgroundGradient: LinearGradient {
        switch artwork {
        case .vehicle:
            return LinearGradient(
                colors: [
                    Color(red: 0.72, green: 0.63, blue: 0.59),
                    Color(red: 0.37, green: 0.34, blue: 0.36)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .landscape:
            return LinearGradient(
                colors: [
                    Color(red: 0.42, green: 0.75, blue: 0.82),
                    Color(red: 0.23, green: 0.45, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .nightDrive:
            return LinearGradient(
                colors: [
                    Color(red: 0.24, green: 0.39, blue: 0.57),
                    Color(red: 0.08, green: 0.11, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .parking:
            return LinearGradient(
                colors: [
                    Color(red: 0.53, green: 0.75, blue: 0.48),
                    Color(red: 0.21, green: 0.43, blue: 0.24)
                ],
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

private struct DashboardEventBadge: View {
    let title: String
    let tone: StatusTagTone

    var body: some View {
        Text(title)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
    }

    private var foregroundColor: Color {
        switch tone {
        case .danger:
            return .white
        case .neutral:
            return AppColor.textSecondary
        case .accent:
            return AppColor.brand
        case .success:
            return AppColor.success
        case .warning:
            return AppColor.warning
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .danger:
            return AppColor.danger
        case .neutral:
            return AppColor.surfaceMuted
        case .accent:
            return AppColor.accentSurface
        case .success:
            return AppColor.success.opacity(0.16)
        case .warning:
            return AppColor.warning.opacity(0.18)
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

            Button(action: onAddDevice) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))

                    Text("Add Device")
                        .font(AppTypography.button)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
                .background(AppColor.brand)
                .cornerRadius(AppRadius.medium)
            }
            .buttonStyle(PlainButtonStyle())
            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)

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
                            colors: [
                                Color(red: 0.54, green: 0.58, blue: 0.66),
                                Color(red: 0.34, green: 0.37, blue: 0.45)
                            ],
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

                Text(appVersionText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColor.border)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.xxxl)
            .padding(.bottom, AppSpacing.xl)
            .frame(width: 300)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(AppColor.surface)
            .cornerRadius(AppRadius.xLarge)
            .shadow(color: Color.black.opacity(0.12), radius: 24, x: 10, y: 0)
            .padding(.leading, AppSpacing.lg)
            .padding(.vertical, AppSpacing.lg)
        }
    }

    private var appVersionText: String {
        guard let rawVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              rawVersion.isEmpty == false,
              rawVersion.contains("$(") == false else {
            return "DASHCAM PRO v1.0"
        }

        return "DASHCAM PRO v\(rawVersion)"
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
        case .connected, .nearby:
            return AppColor.brand
        case .offline:
            return AppColor.textSecondary
        }
    }
}

private struct DashboardFeatureSheet: View {
    private enum Page: Int {
        case splash
        case connect
        case success
    }

    let onSkip: () -> Void
    let onEnterHome: () -> Void

    @State private var currentPage: Page = .splash
    @State private var splashProgress: CGFloat = 0.12

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.98, blue: 1.0),
                    Color(red: 0.93, green: 0.95, blue: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            switch currentPage {
            case .splash:
                splashPage
            case .connect:
                connectPage
            case .success:
                successPage
            }
        }
        .accessibility(identifier: "dashboard-feature-onboarding")
        .animation(.easeInOut(duration: 0.25), value: currentPage)
        .onAppear(perform: startSplashAnimation)
    }

    private var splashPage: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                .frame(width: 94, height: 50)
                .padding(.top, 80)
                .padding(.leading, 46)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            DashboardFeatureSplashIllustration()

            Text("VIGILANT LENS")
                .font(.system(size: 30, weight: .heavy))
                .foregroundColor(AppColor.textPrimary)
                .padding(.top, 40)

            Text("PRECISION CO-PILOT")
                .font(.system(size: 14, weight: .medium))
                .tracking(2.2)
                .foregroundColor(AppColor.textSecondary)
                .padding(.top, AppSpacing.sm)

            Spacer(minLength: 0)

            VStack(spacing: AppSpacing.lg) {
                DashboardFeatureProgressBar(progress: splashProgress)
                    .frame(width: 194)

                Text(appVersionText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColor.textSecondary.opacity(0.9))
            }
            .padding(.bottom, 64)
        }
    }

    private var connectPage: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)

                Button(action: onSkip) {
                    Text("Skip")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(AppColor.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 60)
            .padding(.horizontal, 24)

            Spacer(minLength: 32)

            DashboardFeatureConnectIllustration()
                .padding(.horizontal, 36)

            Text("Connect via WiFi")
                .font(.system(size: 31, weight: .bold))
                .foregroundColor(AppColor.textPrimary)
                .padding(.top, 44)

            Text("Seamlessly link your phone to the dashcam to preview and manage recordings.")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.top, 18)
                .padding(.horizontal, 48)

            DashboardFeaturePageIndicator(currentIndex: 1)
                .padding(.top, 42)

            Spacer(minLength: 0)

            DashboardFeaturePrimaryButton(
                title: "Next Step",
                action: showSuccess
            )
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
        }
    }

    private var successPage: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                Button(action: onSkip) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(AppColor.textSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(PlainButtonStyle())

                Text("Connection Status")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColor.brand)

                Spacer(minLength: 0)

                Image(systemName: "person.crop.circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(AppColor.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .padding(.top, 48)
            .padding(.horizontal, 16)
            .padding(.bottom, AppSpacing.lg)

            Rectangle()
                .fill(AppColor.border.opacity(0.45))
                .frame(height: 1)

            Spacer(minLength: 56)

            DashboardFeatureSuccessIllustration()

            Text("Connection Successful")
                .font(.system(size: 31, weight: .bold))
                .foregroundColor(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 42)
                .padding(.horizontal, 24)

            DashboardFeatureDeviceCard()
                .padding(.top, 24)
                .padding(.horizontal, 34)

            Text("The Vigilant Lens is now synced and ready to provide real-time telemetry and safety monitoring.")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.top, 34)
                .padding(.horizontal, 36)

            Spacer(minLength: 0)

            DashboardFeaturePrimaryButton(
                title: "Enter Home",
                action: onEnterHome
            )
            .padding(.horizontal, 34)

            DashboardFeatureFooterChips()
                .padding(.top, 64)
                .padding(.bottom, 32)
        }
    }

    private func startSplashAnimation() {
        guard currentPage == .splash else {
            return
        }

        withAnimation(.easeInOut(duration: 0.85)) {
            splashProgress = 0.34
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard currentPage == .splash else {
                return
            }

            currentPage = .connect
        }
    }

    private func showSuccess() {
        currentPage = .success
    }

    private var appVersionText: String {
        guard let rawVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              rawVersion.isEmpty == false,
              rawVersion.contains("$(") == false else {
            return "v 1.0"
        }

        return "v \(rawVersion)"
    }
}

private struct DashboardFeatureSplashIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 136, height: 136)
                .shadow(color: AppColor.brand.opacity(0.1), radius: 16, x: 0, y: 8)

            Circle()
                .fill(AppColor.brand)
                .frame(width: 92, height: 92)
                .overlay(
                    Image(systemName: "video.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(.white)
                )

            Circle()
                .fill(AppColor.brand)
                .frame(width: 18, height: 18)
                .offset(x: 46, y: -46)
        }
    }
}

private struct DashboardFeatureConnectIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.23, blue: 0.28),
                            Color(red: 0.08, green: 0.09, blue: 0.13)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 186, height: 90)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 18)
                .overlay(
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.34, green: 0.47, blue: 0.58),
                                        Color(red: 0.15, green: 0.17, blue: 0.21)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .padding(12)

                        Image(systemName: "video.fill")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(.white)
                    }
                )
                .offset(x: -52, y: -30)

            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(Color(red: 0.97, green: 0.97, blue: 1.0))
                    .frame(width: 126, height: 224)
                    .overlay(
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .stroke(Color.black.opacity(0.8), lineWidth: 4)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 10)

                VStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(AppColor.border.opacity(0.75))
                        .frame(width: 48, height: 4)
                        .padding(.top, 26)

                    Circle()
                        .fill(AppColor.brand.opacity(0.14))
                        .frame(width: 62, height: 62)
                        .overlay(
                            Image(systemName: "wifi")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(AppColor.brand)
                        )

                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(AppColor.border.opacity(0.55))
                            .frame(width: 70, height: 6)

                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(AppColor.border.opacity(0.4))
                            .frame(width: 56, height: 6)
                    }

                    Spacer(minLength: 0)
                }
            }
            .offset(x: 54, y: 4)

            Circle()
                .stroke(AppColor.brand.opacity(0.3), lineWidth: 2)
                .frame(width: 110, height: 110)
                .offset(x: 0, y: -16)

            Circle()
                .stroke(AppColor.brand.opacity(0.55), lineWidth: 2)
                .frame(width: 176, height: 176)
                .offset(x: 0, y: -16)
        }
        .frame(height: 300)
    }
}

private struct DashboardFeatureSuccessIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColor.brand.opacity(0.12), lineWidth: 1)
                .frame(width: 118, height: 118)

            Circle()
                .stroke(AppColor.brand.opacity(0.2), lineWidth: 1.5)
                .frame(width: 94, height: 94)

            Circle()
                .fill(Color.white.opacity(0.94))
                .frame(width: 72, height: 72)

            Circle()
                .fill(AppColor.brand)
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                )
        }
    }
}

private struct DashboardFeatureDeviceCard: View {
    var body: some View {
        VStack(spacing: 18) {
            Text("PAIRED DEVICE")
                .font(.system(size: 12, weight: .medium))
                .tracking(1.5)
                .foregroundColor(AppColor.textSecondary)

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColor.brand)

                Text("Vigilant Lens DL-400")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColor.textPrimary)
            }

            HStack(spacing: AppSpacing.sm) {
                Circle()
                    .fill(AppColor.brand)
                    .frame(width: 8, height: 8)

                Text("Signal Strength: Optimal")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColor.brand)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(Color.white.opacity(0.95))
        .cornerRadius(AppRadius.medium)
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 10)
    }
}

private struct DashboardFeatureFooterChips: View {
    private let titles = ["LINKED", "5G DATA", "GPS ACTIVE"]

    var body: some View {
        HStack(spacing: 18) {
            ForEach(titles, id: \.self) { title in
                HStack(spacing: 7) {
                    Circle()
                        .fill(AppColor.brand)
                        .frame(width: 6, height: 6)

                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.8)
                        .foregroundColor(AppColor.textSecondary)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.7))
        .clipShape(Capsule())
    }
}

private struct DashboardFeaturePrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Spacer(minLength: 0)

                Text(title)
                    .font(AppTypography.button)
                    .foregroundColor(.white)

                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(AppColor.brand)
            .cornerRadius(28)
        }
        .buttonStyle(PlainButtonStyle())
        .shadow(color: AppColor.brand.opacity(0.28), radius: 16, x: 0, y: 10)
    }
}

private struct DashboardFeaturePageIndicator: View {
    let currentIndex: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3) { index in
                if index == currentIndex {
                    Capsule()
                        .fill(AppColor.brand)
                        .frame(width: 32, height: 8)
                } else {
                    Circle()
                        .fill(AppColor.border.opacity(0.9))
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
}

private struct DashboardFeatureProgressBar: View {
    let progress: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(AppColor.brand.opacity(0.14))
                .frame(height: 5)

            Capsule()
                .fill(AppColor.brand)
                .frame(width: 194 * progress, height: 5)
        }
    }
}
