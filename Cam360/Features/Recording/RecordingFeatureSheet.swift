import SwiftUI

struct RecordingFeatureSheet: View {
    private enum Page: Int {
        case splash
        case connect
        case success
    }

    let deviceState: RecordingFeatureDeviceState
    let onSkip: () -> Void
    let onEnterHome: () -> Void

    @State private var currentPage: Page = .splash
    @State private var splashProgress: CGFloat = 0.12

    var body: some View {
        ZStack {
            LinearGradient(
                colors: AppArtworkPalette.recordingFeatureBackground,
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
        .accessibility(identifier: "recording-feature-onboarding")
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

            RecordingFeatureSplashIllustration()

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
                RecordingFeatureProgressBar(progress: splashProgress)
                    .frame(width: RecordingFeatureProgressBar.width)

                Text(AppInfo.shortVersionText)
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

            RecordingFeatureConnectIllustration()
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

            RecordingFeaturePageIndicator(currentIndex: 1)
                .padding(.top, 42)

            Spacer(minLength: 0)

            RecordingFeaturePrimaryButton(
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

            RecordingFeatureSuccessIllustration()

            Text("Connection Successful")
                .font(.system(size: 31, weight: .bold))
                .foregroundColor(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 42)
                .padding(.horizontal, 24)

            RecordingFeatureDeviceCard(state: deviceState)
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

            RecordingFeaturePrimaryButton(
                title: "Enter Home",
                action: onEnterHome
            )
            .padding(.horizontal, 34)

            RecordingFeatureFooterChips()
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
}

private struct RecordingFeatureSplashIllustration: View {
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

private struct RecordingFeatureConnectIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: AppArtworkPalette.recordingFeatureCameraBody,
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
                                    colors: AppArtworkPalette.recordingFeatureCameraScreen,
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
                    .fill(AppArtworkPalette.recordingFeaturePhoneBody)
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

private struct RecordingFeatureSuccessIllustration: View {
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

private struct RecordingFeatureDeviceCard: View {
    let state: RecordingFeatureDeviceState

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

                Text(state.pairedDeviceName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColor.textPrimary)
            }

            HStack(spacing: AppSpacing.sm) {
                Circle()
                    .fill(AppColor.brand)
                    .frame(width: 8, height: 8)

                Text(state.connectionStatusText)
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

private struct RecordingFeatureFooterChips: View {
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

private struct RecordingFeaturePrimaryButton: View {
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

private struct RecordingFeaturePageIndicator: View {
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

private struct RecordingFeatureProgressBar: View {
    static let width: CGFloat = 194

    let progress: CGFloat

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(AppColor.brand.opacity(0.14))
                .frame(height: 5)

            Capsule()
                .fill(AppColor.brand)
                .frame(width: Self.width * progress, height: 5)
        }
    }
}
