import SwiftUI

struct GalleryHeaderView: View {
    let isSelectionMode: Bool
    let isSearchExpanded: Bool
    let selectionTitle: String
    let onDismissSelection: () -> Void
    let onToggleSearch: () -> Void
    let onEnterSelectionMode: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                if isSelectionMode {
                    Button(action: onDismissSelection) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColor.textPrimary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Text(selectionTitle)
                        .font(AppTypography.navigationTitle)
                        .foregroundColor(AppColor.textPrimary)
                } else {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("相册")
                            .font(AppTypography.navigationTitle)
                            .foregroundColor(AppColor.textPrimary)

                        Text("本地录制、事件片段与抓拍照片")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColor.textSecondary)
                    }
                }

                Spacer(minLength: 0)

                if isSelectionMode {
                    Button("取消", action: onDismissSelection)
                        .buttonStyle(PlainButtonStyle())
                        .font(AppTypography.bodyStrong)
                        .foregroundColor(AppColor.brand)
                } else {
                    HStack(spacing: AppSpacing.sm) {
                        Button(action: onToggleSearch) {
                            Image(systemName: isSearchExpanded ? "xmark.circle.fill" : "magnifyingglass")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(isSearchExpanded ? AppColor.textSecondary : AppColor.brand)
                                .frame(width: 36, height: 36)
                                .background(AppColor.surfaceMuted)
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button("选择", action: onEnterSelectionMode)
                            .buttonStyle(PlainButtonStyle())
                            .font(AppTypography.bodyStrong)
                            .foregroundColor(AppColor.brand)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(AppColor.surface)
        .overlay(
            Rectangle()
                .fill(AppColor.border.opacity(0.8))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

struct GalleryFilterBar: View {
    let selectedFilter: GalleryFilter
    let onSelect: (GalleryFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(GalleryFilter.allCases) { filter in
                    Button(action: {
                        onSelect(filter)
                    }) {
                        Text(filter.title)
                            .font(AppTypography.bodyStrong)
                            .foregroundColor(selectedFilter == filter ? .white : AppColor.textSecondary)
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.md)
                            .background(selectedFilter == filter ? AppColor.brand : AppColor.surfaceMuted)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.vertical, AppSpacing.lg)
        }
        .background(AppColor.background)
    }
}

struct GallerySearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColor.textSecondary)

            TextField("搜索媒体", text: $text)
                .font(AppTypography.body)
                .foregroundColor(AppColor.textPrimary)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(AppColor.surface)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(AppColor.border.opacity(0.7), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.bottom, AppSpacing.lg)
    }
}

struct GalleryEmptyState: View {
    let message: String

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer(minLength: 0)

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 38, weight: .regular))
                .foregroundColor(AppColor.textSecondary)

            VStack(spacing: AppSpacing.sm) {
                Text("暂无匹配内容")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColor.textPrimary)

                Text(message)
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.xxl)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct GalleryBatchActionBar: View {
    let hasSelection: Bool
    let onDownload: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            GalleryFooterButton(
                title: "下载到本机",
                systemImage: "arrow.down.circle",
                isDestructive: false,
                isEnabled: hasSelection,
                action: onDownload
            )

            GalleryFooterButton(
                title: "删除",
                systemImage: "trash",
                isDestructive: true,
                isEnabled: hasSelection,
                action: onDelete
            )
        }
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.vertical, AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(AppColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                        .stroke(AppColor.border.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 8)
        )
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.bottom, AppSpacing.lg)
    }
}

struct GalleryFooterButton: View {
    let title: String
    let systemImage: String
    let isDestructive: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))

                Text(title)
                    .font(AppTypography.bodyStrong)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
            .background(backgroundColor)
            .cornerRadius(AppRadius.large)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isEnabled == false)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private var foregroundColor: Color {
        isDestructive ? .white : AppColor.brand
    }

    private var backgroundColor: Color {
        isDestructive ? AppColor.danger : AppColor.accentSurface
    }
}
