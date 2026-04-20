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
    var showsDivider: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        SettingsRowButton(action: action) {
            SettingsRowLayout(
                iconName: iconName,
                title: title,
                subtitle: subtitle,
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
    var showsDivider: Bool = true

    var body: some View {
        SettingsRowLayout(
            iconName: iconName,
            title: title,
            subtitle: subtitle,
            showsDivider: showsDivider
        ) {
            Group {
                if #available(iOS 14.0, *) {
                    Toggle("", isOn: $isOn)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle(tint: AppColor.brand))
                } else {
                    Toggle("", isOn: $isOn)
                        .labelsHidden()
                        .toggleStyle(SwitchToggleStyle())
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
    var showsDivider: Bool = true

    var body: some View {
        SettingsRowLayout(
            iconName: iconName,
            title: title,
            subtitle: subtitle,
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
    var showsDivider: Bool = true
    var action: (() -> Void)? = nil

    var body: some View {
        SettingsRowLayout(
            iconName: iconName,
            title: title,
            subtitle: subtitle,
            showsDivider: showsDivider
        ) {
            SettingsRowButton(action: action) {
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

private struct SettingsRowLayout<Accessory: View>: View {
    let iconName: String?
    let title: String
    let subtitle: String?
    let showsDivider: Bool
    let accessory: Accessory

    init(
        iconName: String?,
        title: String,
        subtitle: String?,
        showsDivider: Bool,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.iconName = iconName
        self.title = title
        self.subtitle = subtitle
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

            if showsDivider {
                Divider()
                    .padding(.leading, dividerLeadingInset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dividerLeadingInset: CGFloat {
        guard iconName != nil else {
            return AppSpacing.lg
        }

        return AppSpacing.lg + 36 + AppSpacing.md
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
    let content: Content

    init(action: (() -> Void)?, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if let action = action {
            Button(action: action) {
                content
            }
            .buttonStyle(PlainButtonStyle())
        } else {
            content
        }
    }
}
