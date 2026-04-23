import SwiftUI

struct GallerySectionsList: View {
    let sections: [GallerySectionModel]
    let isSelectionMode: Bool
    let selectedIDs: Set<GalleryItem.ID>
    let bottomPadding: CGFloat
    let onTapItem: (GalleryItem) -> Void
    let onLongPressItem: (GalleryItem) -> Void
    let onMore: (GalleryItem) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                ForEach(sections) { section in
                    GallerySectionBlock(
                        section: section,
                        isSelectionMode: isSelectionMode,
                        selectedIDs: selectedIDs,
                        onTapItem: onTapItem,
                        onLongPressItem: onLongPressItem,
                        onMore: onMore
                    )
                }
            }
            .padding(.horizontal, AppSpacing.xxl)
            .padding(.top, AppSpacing.xl)
            .padding(.bottom, bottomPadding)
        }
    }
}

struct GallerySectionBlock: View {
    let section: GallerySectionModel
    let isSelectionMode: Bool
    let selectedIDs: Set<GalleryItem.ID>
    let onTapItem: (GalleryItem) -> Void
    let onLongPressItem: (GalleryItem) -> Void
    let onMore: (GalleryItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text(section.kind.title)
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColor.textPrimary)

                Spacer(minLength: 0)

                Text("\(section.items.count) 项 · \(section.kind.trailingText)")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.textSecondary)
            }

            VStack(spacing: AppSpacing.md) {
                ForEach(section.items) { item in
                    GalleryMediaCard(
                        item: item,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedIDs.contains(item.id),
                        onTap: {
                            onTapItem(item)
                        },
                        onLongPress: {
                            onLongPressItem(item)
                        },
                        onMore: {
                            onMore(item)
                        }
                    )
                }
            }
        }
    }
}

struct GalleryMediaCard: View {
    let item: GalleryItem
    let isSelectionMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onMore: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            if isSelectionMode {
                selectionIndicator
            }

            GalleryThumbnail(item: item)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text(item.title)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(AppTypography.body)
                    .foregroundColor(AppColor.textSecondary)

                Text(item.detail)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.textSecondary)
            }

            Spacer(minLength: 0)

            if isSelectionMode == false {
                Button(action: onMore) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColor.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .cornerRadius(AppRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(cardBorderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onLongPressGesture(perform: onLongPress)
    }

    private var selectionIndicator: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(isSelected ? AppColor.brand : AppColor.surfaceMuted)
                .frame(width: 24, height: 24)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    private var cardBackground: Color {
        isSelected ? AppColor.accentSurface : AppColor.surface
    }

    private var cardBorderColor: Color {
        isSelected ? AppColor.brand.opacity(0.28) : AppColor.border.opacity(0.7)
    }
}

struct GalleryThumbnail: View {
    let item: GalleryItem

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: item.thumbnailColors),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 128, height: 78)

            Image(systemName: item.thumbnailSymbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white.opacity(0.88))
                .frame(width: 128, height: 78)

            if let badgeTitle = item.badgeTitle {
                StatusTag(title: badgeTitle, tone: item.badgeTone)
                    .padding(AppSpacing.xs)
            }

            if item.kind != .photo {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 128, height: 78)
            }

            VStack {
                Spacer(minLength: 0)

                HStack {
                    Spacer(minLength: 0)

                    Text(item.duration ?? "照片")
                        .font(AppTypography.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Color.black.opacity(0.32))
                        .cornerRadius(AppRadius.small)
                        .padding(AppSpacing.xs)
                }
            }
        }
    }
}
