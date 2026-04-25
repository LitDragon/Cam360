import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        NavigationView {
            SettingsOverviewView(store: store)
                .background(navigationLinks)
                .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accessibility(identifier: "screen-settings")
    }

    private var routeBinding: Binding<SettingsRoute?> {
        Binding(
            get: { store.route },
            set: { route in
                guard let route = route else {
                    store.dismissRoute()
                    return
                }

                store.show(route)
            }
        )
    }

    private var navigationLinks: some View {
        Group {
            navigationLink(tag: .systemPreferences) {
                SystemPreferencesView(store: store)
            }

            navigationLink(tag: .recordingSettings) {
                RecordingSettingsView(store: store)
            }

            navigationLink(tag: .storagePolicy) {
                StoragePolicyView(store: store)
            }

            navigationLink(tag: .watermarkConfiguration) {
                WatermarkConfigurationView(store: store)
            }

            navigationLink(tag: .deviceSettings) {
                DeviceSettingsDetailView(store: store)
            }

            navigationLink(tag: .safetySettings) {
                SafetySettingsView(store: store)
            }

            navigationLink(tag: .renameDevice) {
                RenameDeviceView(store: store)
            }

            NavigationLink(
                destination: HelpCenterView(store: store)
                    .navigationBarHidden(true),
                tag: .helpCenter,
                selection: routeBinding
            ) {
                EmptyView()
            }

            NavigationLink(
                destination: NotificationSettingsView(store: store)
                    .navigationBarHidden(true),
                tag: .notificationSettings,
                selection: routeBinding
            ) {
                EmptyView()
            }

            NavigationLink(
                destination: SystemPermissionsView(store: store)
                    .navigationBarHidden(true),
                tag: .systemPermissions,
                selection: routeBinding
            ) {
                EmptyView()
            }
        }
        .hidden()
    }

    private func navigationLink<Destination: View>(
        tag: SettingsRoute,
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
