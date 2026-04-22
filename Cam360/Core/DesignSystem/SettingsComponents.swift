import SwiftUI

struct SettingsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(AppTypography.caption)
            .foregroundColor(AppColor.textSecondary)
            .kerning(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsGroupCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColor.border.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
    }
}

struct SettingsNavigationRow: View {
    let iconName: String?
    let title: String
    var subtitle: String? = nil
    var trailingSystemImage: String = "chevron.right"
    var isEnabled: Bool = true
    var showsDivider: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        SettingsRowButton(action: action, isEnabled: isEnabled) {
            SettingsRowLayout(
                iconName: iconName,
                title: title,
                subtitle: subtitle,
                isEnabled: isEnabled,
                showsDivider: showsDivider
            ) {
                Image(systemName: trailingSystemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColor.textSecondary.opacity(0.8))
            }
        }
    }
}

struct SettingsToggleRow: View {
    let iconName: String?
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var isEnabled: Bool = true
    var showsDivider: Bool = true

    var body: some View {
        SettingsRowLayout(
            iconName: iconName,
            title: title,
            subtitle: subtitle,
            isEnabled: isEnabled,
            showsDivider: showsDivider
        ) {
            Group {
                if #available(iOS 14.0, *) {
                    Toggle("", isOn: $isOn)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: AppColor.brand))
                        .disabled(isEnabled == false)
                } else {
                    Toggle("", isOn: $isOn)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle())
                        .disabled(isEnabled == false)
                }
            }
        }
    }
}

struct SettingsStatusRow: View {
    let iconName: String?
    let title: String
    var subtitle: String? = nil
    let statusText: String
    var trailingSystemImage: String? = nil
    var statusColor: Color = AppColor.textSecondary
    var isEnabled: Bool = true
    var showsDivider: Bool = true

    var body: some View {
        SettingsRowLayout(
            iconName: iconName,
            title: title,
            subtitle: subtitle,
            isEnabled: isEnabled,
            showsDivider: showsDivider
        ) {
            HStack(spacing: AppSpacing.sm) {
                Text(statusText)
                    .font(AppTypography.caption)
                    .foregroundColor(statusColor)

                if let trailingSystemImage = trailingSystemImage {
                    Image(systemName: trailingSystemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(statusColor)
                }
            }
        }
    }
}

struct SettingsActionRow: View {
    let iconName: String?
    let title: String
    var subtitle: String? = nil
    let actionTitle: String
    var isEnabled: Bool = true
    var showsDivider: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        SettingsRowLayout(
            iconName: iconName,
            title: title,
            subtitle: subtitle,
            isEnabled: isEnabled,
            showsDivider: showsDivider
        ) {
            SettingsRowButton(action: action, isEnabled: isEnabled) {
                Text(actionTitle)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.brand)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColor.accentSurface)
                    .cornerRadius(AppRadius.large)
            }
        }
    }
}

struct SettingsSearchBar: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppColor.textSecondary)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(AppTypography.body)
                        .foregroundColor(AppColor.textSecondary)
                }

                TextField("", text: $text)
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textPrimary)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(AppColor.surface)
        .cornerRadius(AppRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.large)
                .stroke(AppColor.border.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
    }
}

struct SettingsTimeField: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title.uppercased())
                .font(AppTypography.caption)
                .foregroundColor(AppColor.textSecondary)

            HStack(spacing: AppSpacing.sm) {
                Text(value)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)

                Spacer(minLength: 0)

                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColor.textSecondary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .background(AppColor.surfaceMuted)
            .cornerRadius(AppRadius.small)
        }
    }
}

struct SettingsFootnote: View {
    let text: String
    var iconName: String = "info.circle"

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColor.textSecondary)
                .padding(.top, 2)

            Text(text)
                .font(AppTypography.caption)
                .foregroundColor(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SettingsValueRow: View {
    let iconName: String?
    let title: String
    var subtitle: String? = nil
    let valueText: String
    var valueColor: Color = AppColor.textSecondary
    var trailingSystemImage: String? = nil
    var isEnabled: Bool = true
    var showsDivider: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        SettingsRowButton(action: action, isEnabled: isEnabled) {
            SettingsRowLayout(
                iconName: iconName,
                title: title,
                subtitle: subtitle,
                isEnabled: isEnabled,
                showsDivider: showsDivider
            ) {
                HStack(spacing: AppSpacing.sm) {
                    Text(valueText)
                        .font(AppTypography.body)
                        .foregroundColor(valueColor)
                        .multilineTextAlignment(.trailing)

                    if let trailingSystemImage = trailingSystemImage {
                        Image(systemName: trailingSystemImage)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(valueColor)
                    }
                }
            }
        }
    }
}

enum SettingsInputFieldKind {
    case plain
    case secure
}

struct SettingsInputRow: View {
    let title: String
    @Binding var text: String
    var subtitle: String? = nil
    var placeholder: String = ""
    var fieldKind: SettingsInputFieldKind = .plain
    var trailingSystemImage: String? = nil
    var isEnabled: Bool = true
    var showsDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: AppSpacing.sm) {
                    ZStack(alignment: .leading) {
                        if text.isEmpty {
                            Text(placeholder)
                                .font(AppTypography.body)
                                .foregroundColor(AppColor.textSecondary)
                        }

                        inputField
                    }

                    if let trailingSystemImage = trailingSystemImage {
                        Image(systemName: trailingSystemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColor.textSecondary)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.md)
                .background(AppColor.surfaceMuted)
                .cornerRadius(AppRadius.small)
                .opacity(isEnabled ? 1 : 0.42)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.lg)
            .opacity(isEnabled ? 1 : 0.42)

            if showsDivider {
                Divider()
                    .padding(.leading, AppSpacing.lg)
            }
        }
    }

    @ViewBuilder
    private var inputField: some View {
        switch fieldKind {
        case .plain:
            TextField("", text: $text)
                .font(AppTypography.body)
                .foregroundColor(AppColor.textPrimary)
                .disabled(isEnabled == false)
        case .secure:
            SecureField("", text: $text)
                .font(AppTypography.body)
                .foregroundColor(AppColor.textPrimary)
                .disabled(isEnabled == false)
        }
    }
}

struct SettingsSegmentedRow<Option: Hashable>: View {
    let title: String
    var subtitle: String? = nil
    let options: [Option]
    @Binding var selection: Option
    let titleForOption: (Option) -> String
    var showsDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: AppSpacing.sm) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            selection = option
                        }) {
                            Text(titleForOption(option))
                                .font(AppTypography.bodyStrong)
                                .foregroundColor(selection == option ? .white : AppColor.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppSpacing.md)
                                .background(selection == option ? AppColor.brand : AppColor.surfaceMuted)
                                .cornerRadius(AppRadius.small)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.lg)

            if showsDivider {
                Divider()
                    .padding(.leading, AppSpacing.lg)
            }
        }
    }
}

struct SettingsMetricDetail {
    let iconName: String?
    let title: String
    let value: String
}

struct SettingsMetricCard: View {
    let title: String
    let progress: Double
    let progressLabel: String
    var progressCaption: String? = nil
    var details: [SettingsMetricDetail] = []
    var footnote: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text(title)
                .font(AppTypography.bodyStrong)
                .foregroundColor(AppColor.textPrimary)

            HStack(alignment: .center, spacing: AppSpacing.xl) {
                SettingsProgressRing(
                    progress: progress,
                    label: progressLabel,
                    caption: progressCaption
                )

                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    ForEach(Array(details.enumerated()), id: \.offset) { entry in
                        HStack(alignment: .center, spacing: AppSpacing.sm) {
                            if let iconName = entry.element.iconName {
                                Image(systemName: iconName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppColor.brand)
                            }

                            Text(entry.element.title)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColor.textSecondary)

                            Spacer(minLength: AppSpacing.sm)

                            Text(entry.element.value)
                                .font(AppTypography.bodyStrong)
                                .foregroundColor(AppColor.textPrimary)
                        }
                    }
                }
            }

            if let footnote = footnote {
                SettingsFootnote(text: footnote)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(AppColor.border.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 8)
    }
}

enum SettingsNoticeTone {
    case info
    case warning
    case danger
}

struct SettingsNoticeCard: View {
    let title: String
    let message: String
    var tone: SettingsNoticeTone = .info
    var iconName: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            if let iconName = iconName {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(foregroundColor)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(foregroundColor)

                Text(message)
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var foregroundColor: Color {
        switch tone {
        case .info:
            return AppColor.brand
        case .warning:
            return AppColor.warning
        case .danger:
            return AppColor.danger
        }
    }

    private var backgroundColor: Color {
        switch tone {
        case .info:
            return AppColor.accentSurface
        case .warning:
            return AppColor.warning.opacity(0.12)
        case .danger:
            return AppColor.dangerSurface
        }
    }

    private var borderColor: Color {
        foregroundColor.opacity(0.18)
    }
}

private struct SettingsRowLayout<Accessory: View>: View {
    let iconName: String?
    let title: String
    let subtitle: String?
    let isEnabled: Bool
    let showsDivider: Bool
    let accessory: Accessory

    init(
        iconName: String?,
        title: String,
        subtitle: String?,
        isEnabled: Bool,
        showsDivider: Bool,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.iconName = iconName
        self.title = title
        self.subtitle = subtitle
        self.isEnabled = isEnabled
        self.showsDivider = showsDivider
        self.accessory = accessory()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                if let iconName = iconName {
                    SettingsIconBadge(systemImageName: iconName)
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(title)
                        .font(AppTypography.bodyStrong)
                        .foregroundColor(AppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: AppSpacing.md)

                accessory
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.lg)
            .opacity(isEnabled ? 1 : 0.42)

            if showsDivider {
                Divider()
                    .padding(.leading, dividerLeadingInset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var dividerLeadingInset: CGFloat {
        guard iconName != nil else {
            return AppSpacing.lg
        }

        return AppSpacing.lg + 36 + AppSpacing.md
    }
}

private struct SettingsProgressRing: View {
    let progress: Double
    let label: String
    let caption: String?

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColor.surfaceMuted, lineWidth: 8)

            Circle()
                .trim(from: 0, to: normalizedProgress)
                .stroke(
                    AppColor.brand,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: AppSpacing.xs) {
                Text(label)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)

                if let caption = caption {
                    Text(caption)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColor.textSecondary)
                }
            }
        }
        .frame(width: 92, height: 92)
    }

    private var normalizedProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }
}

private struct SettingsIconBadge: View {
    let systemImageName: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(AppColor.accentSurface)
                .frame(width: 36, height: 36)

            Image(systemName: systemImageName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColor.brand)
        }
    }
}

private struct SettingsRowButton<Content: View>: View {
    let action: (() -> Void)?
    let isEnabled: Bool
    let content: Content

    init(action: (() -> Void)?, isEnabled: Bool, @ViewBuilder content: () -> Content) {
        self.action = action
        self.isEnabled = isEnabled
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if let action = action {
            Button(action: action) {
                content
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isEnabled == false)
        } else {
            content
        }
    }
}
