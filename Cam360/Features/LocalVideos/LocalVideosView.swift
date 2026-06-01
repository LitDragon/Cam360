import SwiftUI
import UIKit

struct LocalVideosView: View {
    @ObservedObject var store: LocalVideosStore
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            AppTopBar(
                title: "本地视频",
                subtitle: "已保存到 App 的视频和截图",
                leadingSystemImage: onClose == nil ? nil : "chevron.left",
                leadingAction: onClose
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    SectionCard(title: "存储空间") {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "internaldrive")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(AppColor.brand)

                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(store.usedStorageText)
                                    .font(AppTypography.bodyStrong)
                                    .foregroundColor(AppColor.textPrimary)

                                Text("仅统计 App 已确认保存的视频和截图索引。")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColor.textSecondary)
                            }
                        }
                    }

                    SectionCard(title: "视频列表") {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            if store.items.isEmpty {
                                EmptyStateView(
                                    iconName: "film",
                                    title: store.title,
                                    message: store.message
                                )
                            } else {
                                ForEach(store.items) { item in
                                    LocalVideoRow(
                                        item: item,
                                        canOpen: store.canOpenItem,
                                        canShare: store.canShareItem,
                                        canDelete: store.canDeleteItem,
                                        onShare: {
                                            store.requestShare(itemID: item.id)
                                        },
                                        onDelete: {
                                            store.requestDelete(itemID: item.id)
                                        }
                                    )
                                }
                            }
                        }
                    }

                    SectionCard(title: "截图列表") {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            if store.screenshots.isEmpty {
                                EmptyStateView(
                                    iconName: "photo",
                                    title: "暂无本地截图",
                                    message: "本地保存路径接入前，不展示伪造的截图记录。"
                                )
                            } else {
                                ForEach(store.screenshots) { item in
                                    LocalScreenshotRow(
                                        item: item,
                                        canDelete: store.canDeleteScreenshot,
                                        onDelete: {
                                            store.requestDeleteScreenshot(itemID: item.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(AppSpacing.lg)
            }
        }
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-local-videos")
        .onAppear(perform: store.reload)
        .sheet(
            isPresented: shareSheetPresented,
            onDismiss: {
                store.cancelPendingShare()
            }
        ) {
            if let url = store.pendingShareURL {
                ActivityView(activityItems: [url])
            }
        }
        .alert(isPresented: deleteAlertPresented) {
            Alert(
                title: Text(store.deleteConfirmationTitle),
                message: Text(store.deleteConfirmationMessage),
                primaryButton: .destructive(Text("删除")) {
                    store.confirmPendingDeletion()
                },
                secondaryButton: .cancel {
                    store.cancelPendingDeletion()
                }
            )
        }
        .alert(isPresented: deleteScreenshotAlertPresented) {
            Alert(
                title: Text(store.deleteScreenshotConfirmationTitle),
                message: Text(store.deleteScreenshotConfirmationMessage),
                primaryButton: .destructive(Text("删除")) {
                    store.confirmPendingScreenshotDeletion()
                },
                secondaryButton: .cancel {
                    store.cancelPendingScreenshotDeletion()
                }
            )
        }
    }

    private var deleteAlertPresented: Binding<Bool> {
        Binding(
            get: { store.pendingDeletion != nil },
            set: { isPresented in
                if isPresented == false {
                    store.cancelPendingDeletion()
                }
            }
        )
    }

    private var shareSheetPresented: Binding<Bool> {
        Binding(
            get: { store.pendingShareURL != nil },
            set: { isPresented in
                if isPresented == false {
                    store.cancelPendingShare()
                }
            }
        )
    }

    private var deleteScreenshotAlertPresented: Binding<Bool> {
        Binding(
            get: { store.pendingScreenshotDeletion != nil },
            set: { isPresented in
                if isPresented == false {
                    store.cancelPendingScreenshotDeletion()
                }
            }
        )
    }
}

private struct LocalVideoRow: View {
    let item: LocalVideoItem
    let canOpen: Bool
    let canShare: Bool
    let canDelete: Bool
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppColor.brand)
                .frame(width: 44, height: 44)
                .background(AppColor.accentSurface)
                .cornerRadius(AppRadius.small)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(item.title)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)

                Text(detailText)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.textSecondary)
            }

            Spacer(minLength: AppSpacing.md)

            LocalVideoActionButton(iconName: "square.and.arrow.up", isEnabled: canShare, action: onShare)
            LocalVideoActionButton(iconName: "trash", isEnabled: canDelete, action: onDelete)
        }
        .padding(AppSpacing.md)
        .background(AppColor.surfaceMuted)
        .cornerRadius(AppRadius.small)
    }

    private var detailText: String {
        "\(durationText) · \(sizeText)"
    }

    private var durationText: String {
        let minutes = item.durationSeconds / 60
        let seconds = item.durationSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var sizeText: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(item.fileSizeBytes))
    }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct LocalVideoActionButton: View {
    let iconName: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isEnabled ? AppColor.brand : AppColor.textSecondary)
                .frame(width: 32, height: 32)
                .background(isEnabled ? AppColor.accentSurface : AppColor.surface)
                .cornerRadius(AppRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isEnabled == false)
    }
}

private struct LocalScreenshotRow: View {
    let item: LocalScreenshotItem
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: "photo.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppColor.brand)
                .frame(width: 44, height: 44)
                .background(AppColor.accentSurface)
                .cornerRadius(AppRadius.small)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(item.title)
                    .font(AppTypography.bodyStrong)
                    .foregroundColor(AppColor.textPrimary)
                    .lineLimit(1)

                Text(sizeText)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.textSecondary)
            }

            Spacer(minLength: AppSpacing.md)

            LocalVideoActionButton(iconName: "trash", isEnabled: canDelete, action: onDelete)
        }
        .padding(AppSpacing.md)
        .background(AppColor.surfaceMuted)
        .cornerRadius(AppRadius.small)
    }

    private var sizeText: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(item.fileSizeBytes))
    }
}
