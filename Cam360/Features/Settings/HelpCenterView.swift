import SwiftUI

private enum HelpCenterRoute: Hashable {
    case faq
    case contactSupport
}

struct HelpCenterView: View {
    @ObservedObject var store: SettingsStore
    var dismiss: (() -> Void)? = nil
    @State private var searchText = ""
    @State private var route: HelpCenterRoute?

    private let topicItems: [HelpCenterItem] = [
        HelpCenterItem(iconAssetName: "ConnectDevice", title: "Connect Device"),
        HelpCenterItem(iconAssetName: "LivePreview", title: "Live Preview Issues"),
        HelpCenterItem(iconAssetName: "SDCard", title: "SD Card & Storage"),
        HelpCenterItem(iconAssetName: "Recording", title: "Recording & Events"),
        HelpCenterItem(iconAssetName: "WiFi", title: "Wi-Fi & Connection"),
        HelpCenterItem(iconAssetName: "FirmwareUpdate", title: "Firmware Update")
    ]

    private let quickActionItems: [HelpCenterItem] = [
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
                destination: FAQView(dismiss: dismissNestedRoute)
                    .navigationBarHidden(true),
                tag: .faq,
                selection: routeBinding
            ) {
                EmptyView()
            }

            NavigationLink(
                destination: ContactSupportView(dismiss: dismissNestedRoute)
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
            answer: "当前阶段只保留预览入口和状态占位；真实视频流需要设备端链路联调后再接入。"
        ),
        FAQItem(
            id: "download-recordings",
            category: "视频",
            question: "录像下载保存在哪里？",
            answer: "下载管理会在真实下载服务接入后展示保存位置，目标是相册或 App 本地目录。"
        ),
        FAQItem(
            id: "device-settings",
            category: "设置",
            question: "设置修改会立即写入设备吗？",
            answer: "当前写操作仍是本地占位流转；设备命令主题确认后再切换为真实提交。"
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
                            subtitle: "周一至周五 9:00-18:00",
                            actionTitle: "Call"
                        )

                        SettingsActionRow(
                            iconName: "envelope",
                            title: "Support Email",
                            subtitle: "support@example.com",
                            actionTitle: "Email"
                        )

                        SettingsActionRow(
                            iconName: "message",
                            title: "Online Support",
                            subtitle: "网页或在线聊天入口待接入",
                            actionTitle: "Open",
                            showsDivider: false
                        )
                    }

                    SettingsNoticeCard(
                        title: "Support Placeholder",
                        message: "真实电话、邮箱和在线客服地址尚未在业务文档中给出，本页只按 UI 清单保留入口形态。",
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
