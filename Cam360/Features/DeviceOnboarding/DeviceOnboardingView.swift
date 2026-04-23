import SwiftUI

struct DeviceOnboardingView: View {
    @ObservedObject var store: DeviceOnboardingStore

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "设备接入",
                eyebrow: currentContent.stepLabel,
                subtitle: currentContent.title
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    DeviceOnboardingStatusCard(
                        hasConnectedHotspot: store.hasConnectedHotspot,
                        hasValidatedDevice: store.hasValidatedDevice
                    )

                    SectionCard(title: currentContent.sectionTitle) {
                        VStack(alignment: .leading, spacing: AppSpacing.lg) {
                            Text(currentContent.message)
                                .font(AppTypography.body)
                                .foregroundColor(AppColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                ForEach(currentContent.instructions, id: \.self) { item in
                                    DeviceOnboardingBullet(text: item)
                                }
                            }
                        }
                    }

                    if let footnote = currentContent.footnote {
                        SettingsFootnote(text: footnote, iconName: currentContent.footnoteIconName)
                            .padding(.horizontal, AppSpacing.sm)
                    }
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
            }

            DeviceOnboardingActionBar(content: currentContent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-onboarding")
        .onAppear(perform: store.prepareForDisplay)
    }

    private var currentContent: DeviceOnboardingStepContent {
        switch store.route {
        case .preparation:
            return DeviceOnboardingStepContent(
                stepLabel: "第 1 步 / 4",
                title: "准备连接设备热点",
                sectionTitle: "接入准备",
                message: "先确认接入条件，再去连接行车记录仪热点。当前版本不会自动切换系统 Wi-Fi。",
                instructions: [
                    "确认行车记录仪已经通电，并保持手机靠近设备。",
                    "保持 iPhone 的 Wi-Fi 已开启，准备手动加入设备热点。",
                    "本轮流程会先确认“已连设备热点”，再确认“设备已经可控”。"
                ],
                footnote: "当前仓库还没有真实 AP 连接能力，这里先把用户可见流程和失败分流收紧。",
                footnoteIconName: "wifi",
                primaryTitle: "开始接入",
                primaryAction: store.startHotspotGuide,
                secondaryTitle: "清空本地状态",
                secondaryAction: store.clearPlaceholderData
            )
        case .hotspotGuide:
            return DeviceOnboardingStepContent(
                stepLabel: "第 2 步 / 4",
                title: "连接设备热点",
                sectionTitle: "热点连接",
                message: "前往系统 Wi-Fi 加入行车记录仪热点，成功后再回到 App。",
                instructions: [
                    "打开 iPhone 的 Wi-Fi 设置，并选择设备热点。",
                    "看到系统已连接后，回到 App。",
                    "这一阶段只表示手机已连上设备热点，不代表设备已经可控制。"
                ],
                footnote: "如果系统切回了别的网络，后续校验会失败，需要重新回到这里。",
                footnoteIconName: "antenna.radiowaves.left.and.right",
                primaryTitle: "我已连上设备热点",
                primaryAction: store.confirmHotspotConnected,
                secondaryTitle: "返回准备页",
                secondaryAction: store.returnToPreparation
            )
        case .verification:
            return DeviceOnboardingStepContent(
                stepLabel: "第 3 步 / 4",
                title: "确认设备已经可控",
                sectionTitle: "连接后校验",
                message: "连上热点后，还需要确认设备已经进入可继续操作的状态。",
                instructions: [
                    "保持当前仍连接在设备热点下，不要先切回其它网络。",
                    "确认你已经可以继续进入实时预览或读取设备信息。",
                    "如果还不能进入设备会话，请走失败恢复路径重新检查。"
                ],
                footnote: "当前这里先保留人工确认入口，后续会替换成真实握手与能力探测。",
                footnoteIconName: "bolt.horizontal.circle",
                primaryTitle: "我已确认设备可控",
                primaryAction: store.confirmDeviceValidated,
                secondaryTitle: "仍然无法连通",
                secondaryAction: store.showRecoveryGuide
            )
        case .recovery:
            return DeviceOnboardingStepContent(
                stepLabel: "恢复路径",
                title: "重新检查连接条件",
                sectionTitle: "失败恢复",
                message: "热点已经加入，但设备还没被确认可控。先检查连接条件，再回到校验。",
                instructions: [
                    "确认 iPhone 仍然停留在设备热点下，没有切回其它网络。",
                    "如果设备刚重启或切网，等待稳定后再继续校验。",
                    "如果怀疑热点连接本身有问题，先回到热点步骤重新连接。"
                ],
                footnote: "失败不再收口成一个“连接失败”提示，后续会替换成 AP 和握手阶段的显式错误。",
                footnoteIconName: "exclamationmark.triangle",
                primaryTitle: "重新校验设备",
                primaryAction: store.retryVerification,
                secondaryTitle: "返回热点步骤",
                secondaryAction: store.returnToHotspotGuide,
                tertiaryTitle: "清空本地状态",
                tertiaryAction: store.clearPlaceholderData
            )
        case .ready:
            return DeviceOnboardingStepContent(
                stepLabel: "第 4 步 / 4",
                title: "接入信息已确认",
                sectionTitle: "完成确认",
                message: "当前多步引导已经形成最小闭环，可以先进入主界面。",
                instructions: [
                    "设备热点状态已经确认。",
                    "设备可控状态已经确认。",
                    "下一步会把这条闭环继续接到统一的 DeviceSession。"
                ],
                footnote: "进入应用后仍保持当前 3-tab 主结构，后续再把 session 和预览链路串起来。",
                footnoteIconName: "checkmark.circle",
                primaryTitle: "进入应用",
                primaryAction: store.finishOnboarding,
                secondaryTitle: "返回设备校验",
                secondaryAction: store.returnToVerification
            )
        }
    }
}

private struct DeviceOnboardingStepContent {
    let stepLabel: String
    let title: String
    let sectionTitle: String
    let message: String
    let instructions: [String]
    let footnote: String?
    let footnoteIconName: String
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?
    var tertiaryTitle: String? = nil
    var tertiaryAction: (() -> Void)? = nil
}

private struct DeviceOnboardingStatusCard: View {
    let hasConnectedHotspot: Bool
    let hasValidatedDevice: Bool

    var body: some View {
        SectionCard(title: "接入状态") {
            VStack(spacing: AppSpacing.md) {
                DeviceOnboardingStatusRow(
                    iconName: "wifi",
                    title: "设备热点",
                    detail: hasConnectedHotspot ? "已确认连接设备热点" : "尚未确认热点连接",
                    tagTitle: hasConnectedHotspot ? "已连接" : "待连接",
                    tone: hasConnectedHotspot ? .success : .warning
                )

                DeviceOnboardingStatusRow(
                    iconName: "bolt.horizontal.circle",
                    title: "设备可控",
                    detail: deviceDetailText,
                    tagTitle: deviceTagTitle,
                    tone: deviceTone
                )
            }
        }
    }

    private var deviceDetailText: String {
        if hasValidatedDevice {
            return "已确认可以继续进入设备会话"
        }

        if hasConnectedHotspot {
            return "热点已连通，等待确认设备是否可控"
        }

        return "还没有进入设备校验阶段"
    }

    private var deviceTagTitle: String {
        if hasValidatedDevice {
            return "已确认"
        }

        if hasConnectedHotspot {
            return "待校验"
        }

        return "未开始"
    }

    private var deviceTone: StatusTagTone {
        if hasValidatedDevice {
            return .success
        }

        if hasConnectedHotspot {
            return .accent
        }

        return .neutral
    }
}

private struct DeviceOnboardingStatusRow: View {
    let iconName: String
    let title: String
    let detail: String
    let tagTitle: String
    let tone: StatusTagTone

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColor.brand)
                .frame(width: 28, height: 28)
                .background(AppColor.accentSurface)
                .cornerRadius(AppRadius.small)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)

                Text(detail)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            StatusTag(title: tagTitle, tone: tone)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(AppColor.surfaceMuted)
        .cornerRadius(AppRadius.medium)
    }
}

private struct DeviceOnboardingBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Circle()
                .fill(AppColor.brand)
                .frame(width: 6, height: 6)
                .padding(.top, 7)

            Text(text)
                .font(AppTypography.body)
                .foregroundColor(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DeviceOnboardingActionBar: View {
    let content: DeviceOnboardingStepContent

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            PrimaryButton(title: content.primaryTitle, action: content.primaryAction)

            if let secondaryTitle = content.secondaryTitle, let secondaryAction = content.secondaryAction {
                Button(action: secondaryAction) {
                    Text(secondaryTitle)
                        .font(AppTypography.button)
                        .foregroundColor(AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                }
            }

            if let tertiaryTitle = content.tertiaryTitle, let tertiaryAction = content.tertiaryAction {
                Button(action: tertiaryAction) {
                    Text(tertiaryTitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColor.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                }
            }
        }
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.xxl)
        .background(AppColor.surface)
        .overlay(
            Rectangle()
                .fill(AppColor.border.opacity(0.8))
                .frame(height: 1),
            alignment: .top
        )
    }
}
