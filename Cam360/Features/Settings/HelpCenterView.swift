import SwiftUI

private enum HelpCenterRoute: Hashable {
    case gettingStarted
    case guide(HelpGuideTopic)
    case faq
    case contactSupport
}

private enum HelpGuideTopic: CaseIterable, Hashable {
    case connectDevice
    case livePreview
    case storage
    case recording
    case wifi
    case firmware

    var iconAssetName: String {
        switch self {
        case .connectDevice:
            return "ConnectDevice"
        case .livePreview:
            return "LivePreview"
        case .storage:
            return "SDCard"
        case .recording:
            return "Recording"
        case .wifi:
            return "WiFi"
        case .firmware:
            return "FirmwareUpdate"
        }
    }

    var title: String {
        switch self {
        case .connectDevice:
            return "Connect Device"
        case .livePreview:
            return "Live Preview Issues"
        case .storage:
            return "SD Card & Storage"
        case .recording:
            return "Recording & Events"
        case .wifi:
            return "Wi-Fi & Connection"
        case .firmware:
            return "Firmware Update"
        }
    }

    var summary: String {
        switch self {
        case .connectDevice:
            return "按添加设备流程完成热点确认、密码检查和控制通道校验。"
        case .livePreview:
            return "当前只保留控制通道截图链路；真实视频流仍等待设备端联调。"
        case .storage:
            return "查看 SD 卡状态、容量、格式化入口和 App 本地保存记录。"
        case .recording:
            return "管理录像入口、事件列表和已定义的录像设置项。"
        case .wifi:
            return "查看和修改设备热点名称、密码，并保留重连提示。"
        case .firmware:
            return "查看固件版本和设备侧升级进度；候选版本源尚未接入。"
        }
    }

    var steps: [String] {
        switch self {
        case .connectDevice:
            return [
                "确认行车记录仪已开机并处于热点模式。",
                "从 Home 或录像页点击 Add Device，按页面提示核对热点名称和密码。",
                "连接失败时按页面 recovery action 检查热点密码、本地网络权限或重试控制通道校验。"
            ]
        case .livePreview:
            return [
                "进入 Live Preview 前先确认控制通道 ready。",
                "截图按钮会走 SNAPSHOT_CTRL -> SNAPSHOT_DATA，并预览可解码 Base64 截图。",
                "录制、全屏、真实预览流和本地相册保存仍等待设备端媒体链路。"
            ]
        case .storage:
            return [
                "Storage Policy 展示 SD 卡在线状态、容量、错误文案和预计剩余录制时长。",
                "Downloads 只展示 DOWNLOAD_PROGRESS 事件和 completed 完成记录。",
                "Local Videos 只读取 App 已确认保存的本地索引，不伪造文件存在性。"
            ]
        case .recording:
            return [
                "Home 和录像页复用 RecordingStore 展示当前设备、存储摘要和最近事件。",
                "Gallery 和 Events 通过 MEDIA_INDEX 读取媒体或事件型列表。",
                "真实录像控制结果和事件推送闭环仍需设备或可信模拟器确认。"
            ]
        case .wifi:
            return [
                "Network Identity 打开时优先消费 STATE_SYNC(scope=wifi)。",
                "保存前校验 SSID 非空且不超过 32 字节，密码为 8...63 位可打印 ASCII。",
                "真实设备重启生效和系统 Wi-Fi 重连仍等待硬件联调。"
            ]
        case .firmware:
            return [
                "Firmware Update 默认显示候选版本源未接入。",
                "UPGRADE_PROGRESS 可驱动升级进度、完成和失败展示。",
                "真实包下载、签名真实性和设备写入仍需设备端或可信模拟器确认。"
            ]
        }
    }
}

struct HelpCenterView: View {
    @ObservedObject var store: SettingsStore
    var dismiss: (() -> Void)? = nil
    @State private var searchText = ""
    @State private var route: HelpCenterRoute?

    private let topicItems = HelpGuideTopic.allCases.map {
        HelpCenterItem(iconAssetName: $0.iconAssetName, title: $0.title, route: .guide($0))
    }

    private let quickActionItems: [HelpCenterItem] = [
        HelpCenterItem(iconAssetName: "helpCenter", title: "New User Guide", route: .gettingStarted),
        HelpCenterItem(iconAssetName: "FAQ", title: "FAQ", route: .faq),
        HelpCenterItem(iconAssetName: "ContactSupport", title: "Contact Support", route: .contactSupport)
    ]

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "Help Center",
                leadingSystemImage: "arrow.left",
                leadingAction: dismissAction
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    Text("Find answers and troubleshooting help")
                        .font(AppTypography.body)
                        .foregroundColor(AppColor.textSecondary)

                    SettingsSearchBar(
                        text: $searchText,
                        placeholder: "Search help articles"
                    )

                    SettingsSectionHeader(title: "Help Topics")
                    helpCard(for: topicItems)

                    SettingsSectionHeader(title: "Quick Actions")
                    helpCard(for: quickActionItems)

                    HStack(spacing: 0) {
                        Text("Still need help? ")
                            .font(AppTypography.body)
                            .foregroundColor(AppColor.textSecondary)

                        Text("Contact support")
                            .font(AppTypography.bodyStrong)
                            .foregroundColor(AppColor.brand)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, AppSpacing.xl)
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppLayout.scrollBottomContentInset)
            }
        }
        .background(navigationLinks)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-help-center")
    }

    private func helpCard(for items: [HelpCenterItem]) -> some View {
        SettingsGroupCard {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                SettingsNavigationRow(
                    iconName: nil,
                    iconAssetName: item.iconAssetName,
                    title: item.title,
                    showsDivider: index < items.count - 1,
                    action: {
                        if let route = item.route {
                            self.route = route
                        }
                    }
                )
            }
        }
    }

    private var routeBinding: Binding<HelpCenterRoute?> {
        Binding(
            get: { route },
            set: { route = $0 }
        )
    }

    private var navigationLinks: some View {
        Group {
            NavigationLink(
                destination: GettingStartedGuideView(dismiss: dismissNestedRoute)
                    .navigationBarHidden(true),
                tag: .gettingStarted,
                selection: routeBinding
            ) {
                EmptyView()
            }

            ForEach(HelpGuideTopic.allCases, id: \.self) { topic in
                NavigationLink(
                    destination: HelpGuideArticleView(topic: topic, dismiss: dismissNestedRoute)
                        .navigationBarHidden(true),
                    tag: .guide(topic),
                    selection: routeBinding
                ) {
                    EmptyView()
                }
            }

            NavigationLink(
                destination: FAQView(dismiss: dismissNestedRoute)
                    .navigationBarHidden(true),
                tag: .faq,
                selection: routeBinding
            ) {
                EmptyView()
            }

            NavigationLink(
                destination: ContactSupportView(
                    dismiss: dismissNestedRoute,
                    onOpenFAQ: openFAQ
                )
                    .navigationBarHidden(true),
                tag: .contactSupport,
                selection: routeBinding
            ) {
                EmptyView()
            }
        }
        .hidden()
    }

    private func dismissNestedRoute() {
        route = nil
    }

    private func openFAQ() {
        route = .faq
    }

    private func dismissAction() {
        if let dismiss = dismiss {
            dismiss()
        } else {
            store.dismissRoute()
        }
    }
}

private struct HelpCenterItem {
    let iconAssetName: String
    let title: String
    var route: HelpCenterRoute? = nil
}

private struct GettingStartedGuideView: View {
    let dismiss: () -> Void
    @State private var stepIndex = 0

    private let steps = [
        OnboardingGuideStep(
            iconName: "plus.circle",
            title: "添加设备",
            message: "确认行车记录仪已开机并进入热点模式，然后从 Home 或录像页点击 Add Device。"
        ),
        OnboardingGuideStep(
            iconName: "wifi",
            title: "连接热点",
            message: "按添加设备流程核对热点名称和密码；手机 Wi-Fi、本地网络权限需要保持可用。"
        ),
        OnboardingGuideStep(
            iconName: "car.fill",
            title: "进入主页",
            message: "完成添加后回到 Home 和录像页，查看设备状态、存储摘要、最近事件和常用入口。"
        ),
        OnboardingGuideStep(
            iconName: "folder",
            title: "管理内容",
            message: "通过 Gallery、Playback、Downloads 和 Local Videos 管理已定义的媒体列表与本地索引；真实播放和保存仍等待设备链路。"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "New User Guide",
                subtitle: "\(stepIndex + 1)/\(steps.count)",
                leadingSystemImage: "arrow.left",
                leadingAction: dismiss
            )

            VStack(spacing: AppSpacing.xxl) {
                Spacer(minLength: AppSpacing.xl)

                stepCard

                stepIndicator

                HStack(spacing: AppSpacing.md) {
                    Button(action: dismiss) {
                        Text("Skip")
                            .font(AppTypography.bodyStrong)
                            .foregroundColor(AppColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColor.surfaceMuted)
                            .cornerRadius(AppRadius.medium)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: previousStep) {
                        Text("Previous")
                            .font(AppTypography.bodyStrong)
                            .foregroundColor(stepIndex == 0 ? AppColor.textSecondary : AppColor.brand)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColor.surface)
                            .cornerRadius(AppRadius.medium)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(stepIndex == 0)

                    PrimaryButton(
                        title: stepIndex == steps.count - 1 ? "Complete" : "Next",
                        action: nextStep
                    )
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.bottom, AppLayout.scrollBottomContentInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-new-user-guide")
    }

    private var stepCard: some View {
        let step = steps[stepIndex]
        return VStack(spacing: AppSpacing.xl) {
            Circle()
                .fill(AppColor.accentSurface)
                .frame(width: 96, height: 96)
                .overlay(
                    Image(systemName: step.iconName)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundColor(AppColor.brand)
                )

            VStack(spacing: AppSpacing.sm) {
                Text(step.title)
                    .font(AppTypography.pageTitle)
                    .foregroundColor(AppColor.textPrimary)

                Text(step.message)
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xxl)
        .background(AppColor.surface)
        .cornerRadius(AppRadius.large)
    }

    private var stepIndicator: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(steps.indices, id: \.self) { index in
                Capsule()
                    .fill(index == stepIndex ? AppColor.brand : AppColor.border)
                    .frame(width: index == stepIndex ? 24 : 8, height: 8)
            }
        }
    }

    private func previousStep() {
        stepIndex = max(stepIndex - 1, 0)
    }

    private func nextStep() {
        guard stepIndex < steps.count - 1 else {
            dismiss()
            return
        }

        stepIndex += 1
    }
}

private struct HelpGuideArticleView: View {
    let topic: HelpGuideTopic
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: topic.title,
                subtitle: "使用教程",
                leadingSystemImage: "arrow.left",
                leadingAction: dismiss
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SettingsNoticeCard(
                        title: topic.title,
                        message: topic.summary,
                        tone: .info,
                        iconName: "info.circle"
                    )

                    SettingsSectionHeader(title: "Steps")
                    SettingsGroupCard {
                        ForEach(Array(topic.steps.enumerated()), id: \.offset) { index, step in
                            HelpGuideStepRow(
                                index: index + 1,
                                message: step,
                                showsDivider: index < topic.steps.count - 1
                            )
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppLayout.scrollBottomContentInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-help-guide")
    }
}

private struct HelpGuideStepRow: View {
    let index: Int
    let message: String
    let showsDivider: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Text("\(index)")
                    .font(AppTypography.caption)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(AppColor.brand)
                    .clipShape(Circle())

                Text(message)
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.lg)

            if showsDivider {
                Divider()
                    .background(AppColor.border)
                    .padding(.leading, AppSpacing.lg)
            }
        }
    }
}

private struct OnboardingGuideStep {
    let iconName: String
    let title: String
    let message: String
}

private struct FAQView: View {
    let dismiss: () -> Void
    @State private var searchText = ""
    @State private var selectedCategory = "全部"
    @State private var expandedQuestionID: String?

    private let categories = ["全部", "连接", "预览", "视频", "设置"]
    private let questions = [
        FAQItem(
            id: "connect-ap",
            category: "连接",
            question: "连接设备前需要准备什么？",
            answer: "请确认行车记录仪已开机并处于热点连接模式，手机 Wi-Fi、蓝牙和本地网络权限保持可用。"
        ),
        FAQItem(
            id: "preview-unavailable",
            category: "预览",
            question: "为什么实时预览暂不可用？",
            answer: "当前可在控制通道 ready 后获取截图数据；真实视频流、录制、全屏和本地保存仍需设备端链路联调。"
        ),
        FAQItem(
            id: "download-recordings",
            category: "视频",
            question: "录像下载保存在哪里？",
            answer: "当前只消费设备侧 DOWNLOAD_PROGRESS 进度；真实开始下载、暂停和保存位置仍待下载服务接入。"
        ),
        FAQItem(
            id: "device-settings",
            category: "设置",
            question: "设置修改会立即写入设备吗？",
            answer: "已定义的设置项会按设备命令提交，并在成功后更新页面；真实设备响应和错误码仍需联调确认。"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "FAQ",
                subtitle: "常见问题",
                leadingSystemImage: "arrow.left",
                leadingAction: dismiss
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SettingsSearchBar(text: $searchText, placeholder: "搜索问题...")

                    categoryBar

                    SettingsGroupCard {
                        ForEach(Array(filteredQuestions.enumerated()), id: \.element.id) { index, item in
                            FAQRow(
                                item: item,
                                isExpanded: expandedQuestionID == item.id,
                                showsDivider: index < filteredQuestions.count - 1,
                                action: {
                                    toggleQuestion(item.id)
                                }
                            )
                        }
                    }

                    SettingsNavigationRow(
                        iconName: nil,
                        iconAssetName: "ContactSupport",
                        title: "联系我们",
                        subtitle: "需要人工协助时查看支持方式",
                        showsDivider: false
                    )
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppLayout.scrollBottomContentInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-faq")
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        Text(category)
                            .font(AppTypography.caption)
                            .foregroundColor(selectedCategory == category ? .white : AppColor.textSecondary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(selectedCategory == category ? AppColor.brand : AppColor.surfaceMuted)
                            .cornerRadius(AppRadius.small)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private var filteredQuestions: [FAQItem] {
        questions.filter { item in
            let matchesCategory = selectedCategory == "全部" || item.category == selectedCategory
            let matchesSearch = searchText.isEmpty
                || item.question.localizedCaseInsensitiveContains(searchText)
                || item.answer.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    private func toggleQuestion(_ id: String) {
        expandedQuestionID = expandedQuestionID == id ? nil : id
    }
}

private struct FAQRow: View {
    let item: FAQItem
    let isExpanded: Bool
    let showsDivider: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: action) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(item.question)
                            .font(AppTypography.bodyStrong)
                            .foregroundColor(AppColor.textPrimary)

                        Text(item.category)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColor.textSecondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColor.textSecondary)
                }
                .padding(AppSpacing.lg)
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                Text(item.answer)
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.lg)
            }

            if showsDivider {
                Divider()
                    .background(AppColor.border)
                    .padding(.leading, AppSpacing.lg)
            }
        }
    }
}

private struct ContactSupportView: View {
    let dismiss: () -> Void
    let onOpenFAQ: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "Contact Support",
                subtitle: "客服支持",
                leadingSystemImage: "arrow.left",
                leadingAction: dismiss
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    SettingsSectionHeader(title: "Support Channels")
                    SettingsGroupCard {
                        SettingsActionRow(
                            iconName: "phone",
                            title: "Customer Hotline",
                            subtitle: "真实客服热线待业务提供",
                            actionTitle: "待提供",
                            isEnabled: false
                        )

                        SettingsActionRow(
                            iconName: "envelope",
                            title: "Support Email",
                            subtitle: "真实客服邮箱待业务提供",
                            actionTitle: "待提供",
                            isEnabled: false
                        )

                        SettingsActionRow(
                            iconName: "message",
                            title: "Online Support",
                            subtitle: "网页或在线聊天入口待业务提供",
                            actionTitle: "待提供",
                            isEnabled: false,
                            showsDivider: false
                        )
                    }

                    SettingsSectionHeader(title: "Service Window")
                    SettingsGroupCard {
                        SettingsStatusRow(
                            iconName: "clock",
                            title: "Working Hours",
                            statusText: "周一至周五 9:00-18:00",
                            showsDivider: false
                        )
                    }

                    SettingsSectionHeader(title: "Before Contacting")
                    SettingsGroupCard {
                        SettingsNavigationRow(
                            iconName: nil,
                            iconAssetName: "FAQ",
                            title: "FAQ",
                            subtitle: "先查看常见连接、预览、视频和设置问题",
                            showsDivider: false,
                            action: onOpenFAQ
                        )
                    }

                    SettingsNoticeCard(
                        title: "Support Placeholder",
                        message: "真实电话、邮箱和在线客服地址尚未在业务文档中给出，本页只按 UI 清单保留入口形态，不触发拨号、邮件或外部网页。",
                        tone: .info,
                        iconName: "info.circle"
                    )
                }
                .padding(.horizontal, AppSpacing.xxl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppLayout.scrollBottomContentInset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-settings-contact-support")
    }
}

private struct FAQItem {
    let id: String
    let category: String
    let question: String
    let answer: String
}
