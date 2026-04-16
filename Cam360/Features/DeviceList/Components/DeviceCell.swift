import SwiftUI

struct DeviceCell: View {
    let device: KnownDeviceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(device.name)
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColor.textPrimary)

            Text(device.hotspotSSID)
                .font(AppTypography.body)
                .foregroundColor(AppColor.textSecondary)

            Text("最近连接：\(KnownDeviceCellFormatter.string(from: device.lastConnectedAt))")
                .font(AppTypography.caption)
                .foregroundColor(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.lg)
        .background(AppColor.surface)
        .cornerRadius(AppRadius.small)
    }
}

private enum KnownDeviceCellFormatter {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
