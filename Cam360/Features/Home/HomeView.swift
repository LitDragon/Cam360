import SwiftUI

struct HomeView: View {
    @ObservedObject var store: RecordingStore
    let onAddDevice: () -> Void
    let onOpenDeviceList: () -> Void
    let onOpenRecordingPage: () -> Void
    let onOpenEvents: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                HomeHeaderView(
                    title: title,
                    statusText: statusText,
                    showsMenu: store.hasDevices,
                    onMenu: onOpenDeviceList
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        if store.hasDevices {
                            HomeHeroCard(action: onOpenRecordingPage)
                                .padding(.horizontal, AppSpacing.xxl)
                                .padding(.top, AppSpacing.xl)

                            HomeRecentEventsSection(
                                events: Self.recentEvents,
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
        .onAppear(perform: store.refresh)
    }

    private var title: String {
        store.selectedDevice?.name ?? "Vigilant Lens DL-400"
    }

    private var statusText: String {
        store.selectedDevice?.status.title ?? "Connected"
    }

    private func dismissFeatureSheet() {
        store.dismissFeatureSheet()
    }

    private func completeFeatureSheet() {
        store.addPlaceholderDevicesIfNeeded()
        store.dismissFeatureSheet()
    }

    private static let recentEvents = [
        HomeRecentEvent(
            title: "Braking Detected",
            detail: "Today, 11:42 AM",
            imageName: "HomeEventBraking"
        ),
        HomeRecentEvent(
            title: "Parking Sentry",
            detail: "Yesterday, 09:15 PM",
            imageName: "HomeEventParking"
        )
    ]
}

private struct HomeRecentEvent: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let imageName: String
}

private struct HomeHeaderView: View {
    let title: String
    let statusText: String
    let showsMenu: Bool
    let onMenu: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            if showsMenu {
                Button(action: onMenu) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(AppColor.brand)
                        .frame(width: AppLayout.iconButton, height: AppLayout.iconButton)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                Color.clear
                    .frame(width: AppLayout.iconButton, height: AppLayout.iconButton)
            }

            Spacer(minLength: 0)

            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Circle()
                        .fill(AppColor.brand)
                        .frame(width: 6, height: 6)

                    Text(statusText.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColor.brand)
                }
            }

            Spacer(minLength: 0)

            Color.clear
                .frame(width: AppLayout.iconButton, height: AppLayout.iconButton)
        }
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, 13)
        .frame(maxWidth: .infinity)
        .background(AppColor.background)
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
    let events: [HomeRecentEvent]
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
    let event: HomeRecentEvent
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.lg) {
                Image(event.imageName)
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
}
