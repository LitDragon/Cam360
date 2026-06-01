import SwiftUI

struct HomeView: View {
    @ObservedObject var store: RecordingStore
    let onAddDevice: () -> Void
    let onOpenRecordingPage: () -> Void
    let onOpenDeviceList: () -> Void
    let onOpenEvents: () -> Void

    @State private var isDrawerPresented = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                AppTopBar(
                    title: title,
                    subtitle: statusText,
                    leadingSystemImage: store.hasDevices ? "line.3.horizontal" : nil,
                    leadingAction: toggleDrawer
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if store.hasDevices {
                            HomeHeroCard(action: onOpenRecordingPage)
                                .padding(.horizontal, AppSpacing.xxl)
                                .padding(.top, AppSpacing.xl)

                            HomeRecentEventsSection(
                                events: store.recentEvents,
                                onViewAll: onOpenEvents
                            )
                            .padding(.horizontal, AppSpacing.xxxl)
                            .padding(.top, 34)
                            .padding(.bottom, AppSpacing.xxxl)
                        } else {
                            HomeEmptyDeviceState(onAddDevice: onAddDevice)
                                .padding(.horizontal, AppSpacing.xxl)
                                .padding(.top, 96)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .background(AppColor.surface)
            }

            if isDrawerPresented {
                RecordingDrawerOverlay(
                    devices: store.devices,
                    selectedDeviceID: store.selectedDeviceID,
                    onClose: closeDrawer,
                    onSelectDevice: selectDevice(_:),
                    onOpenDeviceList: openDeviceList,
                    onAddDevice: addDevice
                )
            }

            if store.shouldShowFeatureSheet {
                RecordingFeatureSheet(
                    deviceState: store.featureSheetDeviceState,
                    onSkip: dismissFeatureSheet,
                    onEnterHome: completeFeatureSheet
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.surface.edgesIgnoringSafeArea(.bottom))
        .accessibility(identifier: "screen-home")
        .animation(.easeInOut(duration: 0.2), value: isDrawerPresented)
        .onAppear(perform: store.refresh)
    }

    private var title: String {
        store.selectedDevice?.name ?? "Vigilant Lens DL-400"
    }

    private var statusText: String {
        store.selectedDevice?.status.title ?? "Connected"
    }

    private func toggleDrawer() {
        guard store.shouldShowFeatureSheet == false else {
            return
        }

        isDrawerPresented.toggle()
    }

    private func closeDrawer() {
        isDrawerPresented = false
    }

    private func selectDevice(_ deviceID: RecordingDeviceItem.ID) {
        store.selectDevice(id: deviceID)
        closeDrawer()
    }

    private func addDevice() {
        closeDrawer()
        onAddDevice()
    }

    private func openDeviceList() {
        closeDrawer()
        onOpenDeviceList()
    }

    private func dismissFeatureSheet() {
        store.dismissFeatureSheet()
    }

    private func completeFeatureSheet() {
        store.addPlaceholderDevicesIfNeeded()
        store.dismissFeatureSheet()
    }

}

private struct HomeHeroCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("HomeHero")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .aspectRatio(337.0 / 252.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibility(identifier: "home-recording-card")
    }
}

private struct HomeEmptyDeviceState: View {
    let onAddDevice: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Circle()
                .fill(AppColor.accentSurface)
                .frame(width: 96, height: 96)
                .overlay(
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(AppColor.brand)
                )

            VStack(spacing: AppSpacing.sm) {
                Text("No device added yet")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColor.textPrimary)

                Text("Connect your dashcam to preview and manage recordings.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            PrimaryButton(
                title: "Add Device",
                leadingSystemImageName: "plus",
                action: onAddDevice
            )
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HomeRecentEventsSection: View {
    let events: [RecordingRecentEvent]
    let onViewAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent Events")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppColor.textPrimary)

                Spacer(minLength: 0)

                Button(action: onViewAll) {
                    Text("View all")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColor.brand)
                }
                .buttonStyle(PlainButtonStyle())
            }

            VStack(spacing: AppSpacing.xxl) {
                ForEach(events) { event in
                    HomeRecentEventRow(event: event, action: onViewAll)
                }
            }
        }
    }
}

private struct HomeRecentEventRow: View {
    let event: RecordingRecentEvent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.lg) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColor.textPrimary)

                    Text(event.detail)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppColor.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColor.border)
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var imageName: String {
        switch event.artwork {
        case .parking:
            return "HomeEventParking"
        default:
            return "HomeEventBraking"
        }
    }
}
