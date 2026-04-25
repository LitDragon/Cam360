import SwiftUI

struct RenameDeviceView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "Rename Device",
                subtitle: "Update the label shown throughout the app",
                leadingSystemImage: "arrow.left",
                leadingAction: store.dismissRoute
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SettingsGroupCard {
                        SettingsInputRow(
                            title: "Device Name",
                            text: renameDeviceBinding,
                            placeholder: "DriveCam X Pro",
                            showsDivider: false
                        )
                    }

                    SettingsFootnote(
                        text: "This only updates the app-side display name in the current M0 flow."
                    )
                    .padding(.horizontal, AppSpacing.sm)

                    PrimaryButton(title: "Save Name") {
                        store.renameDevice()
                    }
                    .opacity(canSave ? 1 : 0.48)
                    .disabled(canSave == false)
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, 140)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-rename-device")
    }

    private var canSave: Bool {
        store.renameDeviceDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var renameDeviceBinding: Binding<String> {
        Binding(
            get: { store.renameDeviceDraft },
            set: { store.setRenameDeviceDraft($0) }
        )
    }
}
