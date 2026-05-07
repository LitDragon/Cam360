import SwiftUI

struct DeviceOnboardingView: View {
    @ObservedObject var store: DeviceOnboardingStore

    var body: some View {
        Group {
            switch store.route {
            case .introduction:
                introductionScreen
            case .searching:
                searchingScreen
            case .wifiDetails:
                wifiDetailsScreen
            case .connecting:
                connectingScreen
            case .success:
                successScreen
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
        .accessibility(identifier: "screen-onboarding")
        .animation(.easeInOut(duration: 0.2), value: store.route)
    }
}

private extension DeviceOnboardingView {
    var introductionScreen: some View {
        VStack(spacing: 0) {
            DeviceOnboardingNavigationBar(
                title: "Add Device",
                onBack: store.goBack
            )

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 28)

                Text("Add a new dashcam")
                    .font(AppTypography.pageTitle)
                    .foregroundColor(AppColor.textPrimary)

                Text("The app will search for nearby dashcams ready to connect. Please ensure your device is powered on.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppSpacing.lg)

                DeviceOnboardingTipCard(
                    iconName: "info.circle.fill",
                    message: "Tip: Make sure Bluetooth is enabled and your device is in setup mode."
                )
                .padding(.top, AppSpacing.xl)

                Spacer(minLength: 0)

                PrimaryButton(
                    title: "Start Search",
                    action: store.startSearch
                )

                Button(action: {}) {
                    Text("Having trouble? Get help")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, AppSpacing.lg)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    var searchingScreen: some View {
        VStack(spacing: 0) {
            DeviceOnboardingNavigationBar(
                title: "Add Device",
                onBack: store.goBack
            )

            VStack(spacing: 0) {
                Spacer(minLength: 36)

                DeviceOnboardingSignalIllustration()

                Text("Searching for nearby\ndashcams...")
                    .font(AppTypography.pageTitle)
                    .foregroundColor(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppSpacing.xxxl)

                Text("Make sure your device is powered on and in pairing mode.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppSpacing.md)
                    .padding(.horizontal, AppSpacing.xl)

                Spacer(minLength: 0)

                Button(action: store.goBack) {
                    HStack(spacing: AppSpacing.xs) {
                        Text("Can't find your device?")
                            .font(AppTypography.bodyStrong)
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(AppColor.brand)
                    .padding(.bottom, AppSpacing.xxxl)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.top, AppSpacing.xl)
        }
    }

    var wifiDetailsScreen: some View {
        VStack(spacing: 0) {
            DeviceOnboardingNavigationBar(
                title: "Connect to Wi-Fi",
                onBack: store.goBack
            )

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 24)

                Text("Enter Wi-Fi details")
                    .font(AppTypography.pageTitle)
                    .foregroundColor(AppColor.textPrimary)

                Text("Connect your phone to the dashcam hotspot before the app checks the control channel.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppSpacing.md)

                if let retryMessage = store.connectionStage.retryMessage {
                    DeviceOnboardingTipCard(
                        iconName: "exclamationmark.triangle.fill",
                        message: retryMessage,
                        tintColor: AppColor.warning,
                        backgroundColor: AppColor.warning.opacity(0.12)
                    )
                    .padding(.top, AppSpacing.lg)
                }

                Text("NETWORK NAME")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColor.textSecondary)
                    .padding(.top, AppSpacing.xxl)

                DeviceOnboardingReadonlyField(
                    iconName: "wifi",
                    value: store.networkName
                )
                .padding(.top, AppSpacing.md)

                Text("PASSWORD")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColor.textSecondary)
                    .padding(.top, AppSpacing.xl)

                DeviceOnboardingPasswordField(
                    text: $store.password,
                    isVisible: store.isPasswordVisible,
                    onToggleVisibility: store.togglePasswordVisibility
                )
                .padding(.top, AppSpacing.md)

                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColor.brand.opacity(0.65))
                        .padding(.top, 2)

                    Text("Use the hotspot name and password shown by the dashcam. Device control starts only after validation succeeds.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, AppSpacing.lg)

                Spacer(minLength: 0)

                PrimaryButton(
                    title: "Continue",
                    isEnabled: store.canContinueWithWiFiDetails,
                    trailingSystemImageName: "arrow.right",
                    action: store.continueFromWiFiDetails
                )
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    var connectingScreen: some View {
        VStack(spacing: 0) {
            DeviceOnboardingNavigationBar(
                title: "Nearby Devices",
                onBack: store.goBack
            )

            VStack(spacing: 0) {
                Spacer(minLength: 44)

                DeviceOnboardingSignalIllustration()

                Text(store.connectionStage.title(deviceName: store.pendingDeviceName))
                    .font(AppTypography.pageTitle)
                    .foregroundColor(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppSpacing.xxxl)
                    .padding(.horizontal, AppSpacing.md)

                Text(store.connectionStage.message)
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppSpacing.md)
                    .padding(.horizontal, AppSpacing.xl)

                AppProgressBar(
                    progress: store.connectionStage.progress,
                    minimumFillWidth: 24
                )
                    .padding(.top, AppSpacing.xxxl)
                    .padding(.horizontal, 72)

                Spacer(minLength: 0)

                Button(action: store.cancelConnection) {
                    Text("Cancel Connection")
                        .font(AppTypography.bodyStrong)
                        .foregroundColor(AppColor.textSecondary)
                        .padding(.bottom, AppSpacing.xxxl)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.top, AppSpacing.xl)
        }
    }

    var successScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 96)

            Circle()
                .fill(AppColor.brand.opacity(0.14))
                .frame(width: 84, height: 84)
                .overlay(
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundColor(AppColor.brand)
                )

            Text("Device added successfully")
                .font(AppTypography.pageTitle)
                .foregroundColor(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.xxxl)
                .padding(.horizontal, AppSpacing.xxl)

            Text("\(store.addedDeviceName) is now connected and ready to use.")
                .font(AppTypography.body)
                .foregroundColor(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AppSpacing.md)
                .padding(.horizontal, 42)

            Spacer(minLength: 0)

            VStack(spacing: AppSpacing.lg) {
                PrimaryButton(
                    title: "Go to Home",
                    action: store.enterHome
                )

                Button(action: store.addAnotherDevice) {
                    Text("Add another device")
                        .font(AppTypography.bodyStrong)
                        .foregroundColor(AppColor.brand)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }
}

private struct DeviceOnboardingNavigationBar: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColor.brand)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(PlainButtonStyle())

            Text(title)
                .font(AppTypography.navigationTitle)
                .foregroundColor(AppColor.textPrimary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
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

private struct DeviceOnboardingSignalIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(AppColor.brand.opacity(0.12))
                .frame(width: 184, height: 184)

            Circle()
                .fill(AppColor.brand.opacity(0.26))
                .frame(width: 114, height: 114)

            Circle()
                .fill(AppColor.brand)
                .frame(width: 66, height: 66)

            Image(systemName: "wifi")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.white)
        }
    }
}

private struct DeviceOnboardingTipCard: View {
    let iconName: String
    let message: String
    var tintColor: Color = AppColor.brand
    var backgroundColor: Color = AppColor.accentSurface.opacity(0.72)

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(tintColor)

            Text(message)
                .font(AppTypography.body)
                .foregroundColor(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .cornerRadius(AppRadius.medium)
    }
}

private struct DeviceOnboardingReadonlyField: View {
    let iconName: String
    let value: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColor.textSecondary)

            Text(value)
                .font(AppTypography.body)
                .foregroundColor(AppColor.textPrimary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .appSurface(borderColor: AppColor.border.opacity(0.72))
    }
}

private struct DeviceOnboardingPasswordField: View {
    @Binding var text: String
    let isVisible: Bool
    let onToggleVisibility: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "lock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColor.textSecondary)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text("Enter Wi-Fi password")
                        .font(AppTypography.body)
                        .foregroundColor(AppColor.textSecondary.opacity(0.7))
                }

                Group {
                    if isVisible {
                        TextField("", text: $text)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        SecureField("", text: $text)
                            .textContentType(.password)
                    }
                }
                .font(AppTypography.body)
                .foregroundColor(AppColor.textPrimary)
            }

            Button(action: onToggleVisibility) {
                Image(systemName: isVisible ? "eye.slash" : "eye")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColor.brand)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .appSurface(borderColor: AppColor.border.opacity(0.72))
    }
}
