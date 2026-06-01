import SwiftUI

struct PlaybackView: View {
    @ObservedObject var store: PlaybackStore
    var onClose: (() -> Void)? = nil
    var onOpenSettings: (() -> Void)? = nil

    @State private var selectedRoute: PlaybackRoute = .files
    @State private var isSearchPresented = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            PlaybackDriveLogHeader(
                onBack: onClose,
                onSearch: toggleSearch,
                onSettings: onOpenSettings
            )

            if isSearchPresented {
                PlaybackSearchField(text: $searchText)
            }

            PlaybackSegmentedControl(
                selection: $selectedRoute
            )

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.edgesIgnoringSafeArea(.all))
        .accessibility(identifier: "screen-playback")
    }

    @ViewBuilder
    private var content: some View {
        switch selectedRoute {
        case .files:
            PlaybackFilesView(store: store, sections: visibleSections)
        case .timeline:
            PlaybackTimelinePlaceholder()
        }
    }

    private var visibleSections: [PlaybackLogSection] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSearchText.isEmpty == false else {
            return PlaybackLogSampleData.sections
        }

        return PlaybackLogSampleData.sections.compactMap { section in
            let entries = section.entries.filter { $0.matches(trimmedSearchText) }
            guard entries.isEmpty == false else {
                return nil
            }
            return PlaybackLogSection(title: section.title, entries: entries)
        }
    }

    private func toggleSearch() {
        isSearchPresented.toggle()

        if isSearchPresented == false {
            searchText = ""
        }
    }
}

private struct PlaybackDriveLogHeader: View {
    let onBack: (() -> Void)?
    let onSearch: () -> Void
    let onSettings: (() -> Void)?

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Button(action: {
                onBack?()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColor.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(onBack == nil)
            .opacity(onBack == nil ? 0 : 1)

            Text("Drive Log")
                .font(AppTypography.navigationTitle)
                .foregroundColor(AppColor.brand)

            Spacer(minLength: 0)

            HStack(spacing: AppSpacing.sm) {
                PlaybackHeaderIconButton(
                    systemImage: "magnifyingglass",
                    action: onSearch
                )

                PlaybackHeaderIconButton(
                    systemImage: "gearshape",
                    action: {
                        onSettings?()
                    }
                )
                .disabled(onSettings == nil)
            }
        }
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, AppSpacing.md)
        .background(AppColor.background)
    }
}

private struct PlaybackHeaderIconButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(AppColor.brand)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct PlaybackSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColor.textSecondary)

            TextField("Search drive logs", text: $text)
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
        .padding(.bottom, AppSpacing.md)
    }
}

private struct PlaybackSegmentedControl: View {
    @Binding var selection: PlaybackRoute

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PlaybackRoute.allCases, id: \.self) { route in
                Button(action: {
                    selection = route
                }) {
                    ZStack {
                        Capsule()
                            .fill(selection == route ? AppColor.brand : Color.clear)

                        Text(route.title)
                            .font(AppTypography.bodyStrong)
                            .foregroundColor(selection == route ? .white : AppColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .padding(6)
        .appSurface(
            backgroundColor: AppColor.surfaceMuted,
            cornerRadius: AppRadius.large,
            borderColor: AppColor.border.opacity(0.35),
            shadow: ShadowStyle(
                color: Color.black.opacity(0.04),
                radius: 12,
                x: 0,
                y: 6
            )
        )
        .padding(.horizontal, AppSpacing.xxl)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.lg)
    }
}

private struct PlaybackFilesView: View {
    @ObservedObject var store: PlaybackStore
    let sections: [PlaybackLogSection]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                playbackStateView

                if sections.isEmpty {
                    EmptyStateView(
                        iconName: "magnifyingglass",
                        title: "No Matching Files",
                        message: "Try a different drive log keyword.",
                        style: .plain
                    )
                    .padding(.top, AppSpacing.lg)
                } else {
                    ForEach(sections) { section in
                        PlaybackLogSectionView(section: section)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xxxl)
        }
    }

    @ViewBuilder
    private var playbackStateView: some View {
        if store.isLoading {
            InlineLoadingView(
                title: "Loading Playback",
                message: "Reading the first device recording and playback resource."
            )
        } else if let lastLoadError = store.lastLoadError {
            ErrorStateView(
                title: "Playback Unavailable",
                message: lastLoadError,
                actionTitle: nil,
                action: nil
            )
        } else if let playbackResource = store.playbackResource {
            PlaybackResourceSummaryView(
                title: store.title,
                message: store.message,
                fileInfo: store.selectedFileInfo,
                playbackResource: playbackResource
            )
        } else {
            EmptyStateView(
                iconName: "play.rectangle",
                title: store.title,
                message: store.message,
                style: .plain
            )
        }
    }
}

private struct PlaybackResourceSummaryView: View {
    let title: String
    let message: String
    let fileInfo: DeviceFileInfo?
    let playbackResource: DeviceFilePlaybackResource

    var body: some View {
        SectionCard(title: "Device Playback") {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                PlaybackOfflinePlayerSurface(
                    durationText: Self.durationText(playbackResource.duration ?? fileInfo?.item.duration)
                )

                HStack(alignment: .top, spacing: AppSpacing.md) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(AppColor.brand)
                        .frame(width: 40, height: 40)
                        .background(AppColor.accentSurface)
                        .cornerRadius(AppRadius.small)

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HStack(spacing: AppSpacing.sm) {
                            Text(title)
                                .font(AppTypography.bodyStrong)
                                .foregroundColor(AppColor.textPrimary)
                                .lineLimit(1)

                            StatusTag(
                                title: playbackResource.seekable ? "READY" : "STREAM",
                                tone: .accent,
                                size: .compact
                            )
                        }

                        Text(message)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColor.textSecondary)
                            .lineLimit(2)
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    PlaybackMetadataRow(title: "Path", value: playbackResource.path)

                    if let duration = playbackResource.duration {
                        PlaybackMetadataRow(title: "Duration", value: "\(duration)s")
                    } else if let duration = fileInfo?.item.duration {
                        PlaybackMetadataRow(title: "Duration", value: "\(duration)s")
                    }

                    if let size = playbackResource.size ?? fileInfo?.item.size {
                        PlaybackMetadataRow(title: "Size", value: Self.sizeText(size))
                    }

                    if let resolution = fileInfo?.item.resolution {
                        PlaybackMetadataRow(title: "Resolution", value: resolution)
                    }

                    if let codec = fileInfo?.codec {
                        PlaybackMetadataRow(title: "Codec", value: codec)
                    }

                    if let framerate = fileInfo?.framerate {
                        PlaybackMetadataRow(title: "Frame Rate", value: "\(framerate) fps")
                    }
                }

                PlaybackOfflineActionRow()
            }
        }
    }

    private static func durationText(_ seconds: Int?) -> String {
        guard let seconds else {
            return "--:--"
        }

        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private static func sizeText(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

private struct PlaybackOfflinePlayerSurface: View {
    let durationText: String

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.12, green: 0.15, blue: 0.21),
                        Color(red: 0.22, green: 0.29, blue: 0.39)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundColor(.white.opacity(0.86))

                    StatusTag(
                        title: "PLAYER PENDING",
                        tone: .neutral,
                        size: .compact
                    )
                }
            }
            .frame(height: 164)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

            VStack(spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    Text("00:00")
                    Spacer(minLength: 0)
                    Text(durationText)
                }
                .font(AppTypography.caption)
                .foregroundColor(AppColor.textSecondary)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppColor.surfaceMuted)
                        .frame(height: AppLayout.progressLineHeight)

                    Capsule()
                        .fill(AppColor.brand.opacity(0.35))
                        .frame(width: 18, height: AppLayout.progressLineHeight)
                }

                Text("Playback controls are shown only as an offline shell until the real player chain is verified.")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PlaybackOfflineActionRow: View {
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            PlaybackOfflineActionButton(title: "Play", systemImage: "play.fill")
            PlaybackOfflineActionButton(title: "Full", systemImage: "arrow.up.left.and.arrow.down.right")
            PlaybackOfflineActionButton(title: "Download", systemImage: "arrow.down.circle")
            PlaybackOfflineActionButton(title: "Share", systemImage: "square.and.arrow.up")
            PlaybackOfflineActionButton(title: "Delete", systemImage: "trash")
        }
    }
}

private struct PlaybackOfflineActionButton: View {
    let title: String
    let systemImage: String

    var body: some View {
        Button(action: {}) {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(AppColor.surfaceMuted)
                    .cornerRadius(AppRadius.small)

                Text(title)
                    .font(AppTypography.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .foregroundColor(AppColor.textSecondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(true)
    }
}

private struct PlaybackMetadataRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColor.textSecondary)
                .frame(width: 64, alignment: .leading)

            Text(value)
                .font(AppTypography.caption)
                .foregroundColor(AppColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct PlaybackLogSectionView: View {
    let section: PlaybackLogSection

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text(section.title)
                .font(AppTypography.bodyStrong)
                .foregroundColor(AppColor.textPrimary)

            VStack(spacing: AppSpacing.sm) {
                ForEach(rows, id: \.first?.id) { row in
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(row) { entry in
                            PlaybackLogTile(entry: entry)
                        }

                        ForEach(0..<(4 - row.count), id: \.self) { _ in
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var rows: [[PlaybackLogEntry]] {
        stride(from: 0, to: section.entries.count, by: 4).map { startIndex in
            let endIndex = min(startIndex + 4, section.entries.count)
            return Array(section.entries[startIndex..<endIndex])
        }
    }
}

private struct PlaybackLogTile: View {
    let entry: PlaybackLogEntry

    var body: some View {
        ZStack(alignment: .topLeading) {
            PlaybackLogArtworkView(style: entry.artworkStyle)

            if entry.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(6)
            } else if entry.isHighlighted {
                Circle()
                    .fill(AppColor.danger)
                    .frame(width: 9, height: 9)
                    .padding(5)
            }

            VStack {
                Spacer(minLength: 0)

                HStack {
                    Spacer(minLength: 0)

                    Text(entry.duration)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.58))
                        .cornerRadius(3)
                        .padding(4)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
    }
}

private struct PlaybackLogArtworkView: View {
    let style: PlaybackLogArtworkStyle

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: style.backgroundColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            switch style {
            case .sunriseRoad:
                roadScene(horizonColor: Color.white.opacity(0.22), laneColor: Color.yellow.opacity(0.8))
            case .forestCabin:
                cabinScene(accentColor: Color(red: 0.24, green: 0.48, blue: 0.28))
            case .bridge:
                bridgeScene()
            case .nightRoad:
                nightLightScene()
            case .cockpit:
                cabinScene(accentColor: Color(red: 0.2, green: 0.57, blue: 0.62))
            case .tunnel:
                tunnelScene()
            case .mountainCabin:
                cabinScene(accentColor: Color(red: 0.54, green: 0.68, blue: 0.37))
            case .autumnRoad:
                roadScene(horizonColor: Color.orange.opacity(0.32), laneColor: Color.white.opacity(0.78))
            case .parkingLot:
                parkingScene()
            case .desertRoad:
                roadScene(horizonColor: Color.white.opacity(0.28), laneColor: Color.white.opacity(0.82))
            }
        }
    }

    private func roadScene(horizonColor: Color, laneColor: Color) -> some View {
        GeometryReader { geometry in
            ZStack {
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    path.move(to: CGPoint(x: width * 0.38, y: height))
                    path.addLine(to: CGPoint(x: width * 0.53, y: height * 0.42))
                    path.addLine(to: CGPoint(x: width * 0.68, y: height))
                    path.closeSubpath()
                }
                .fill(Color.black.opacity(0.45))

                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    path.move(to: CGPoint(x: 0, y: height * 0.48))
                    path.addQuadCurve(
                        to: CGPoint(x: width, y: height * 0.42),
                        control: CGPoint(x: width * 0.55, y: height * 0.32)
                    )
                }
                .stroke(horizonColor, lineWidth: 2)

                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    path.move(to: CGPoint(x: width * 0.52, y: height))
                    path.addLine(to: CGPoint(x: width * 0.56, y: height * 0.48))
                }
                .stroke(laneColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8, 8]))
            }
        }
    }

    private func cabinScene(accentColor: Color) -> some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.black.opacity(0.54))
                    .frame(width: geometry.size.width * 0.72, height: geometry.size.height * 0.28)
                    .offset(y: geometry.size.height * 0.28)

                Circle()
                    .stroke(Color.white.opacity(0.68), lineWidth: 3)
                    .frame(width: geometry.size.width * 0.28, height: geometry.size.width * 0.28)
                    .offset(x: -geometry.size.width * 0.22, y: geometry.size.height * 0.23)

                Rectangle()
                    .fill(accentColor.opacity(0.9))
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.32)
                    .offset(y: -geometry.size.height * 0.34)
            }
        }
    }

    private func bridgeScene() -> some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(Color.white.opacity(0.26))
                    .frame(width: geometry.size.width * 0.66, height: 2)

                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    path.move(to: CGPoint(x: width * 0.24, y: height * 0.62))
                    path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.24))
                    path.addLine(to: CGPoint(x: width * 0.76, y: height * 0.62))
                }
                .stroke(Color.white.opacity(0.72), lineWidth: 3)

                ForEach(0..<5, id: \.self) { index in
                    Rectangle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 1, height: geometry.size.height * 0.28)
                        .offset(x: CGFloat(index - 2) * geometry.size.width * 0.1, y: geometry.size.height * 0.08)
                }
            }
        }
    }

    private func nightLightScene() -> some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(Color.black.opacity(0.46))
                    .frame(height: geometry.size.height * 0.36)
                    .offset(y: geometry.size.height * 0.32)

                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(Color.yellow.opacity(index % 2 == 0 ? 0.9 : 0.55))
                        .frame(width: 5 + CGFloat(index % 3) * 3, height: 5 + CGFloat(index % 3) * 3)
                        .blur(radius: 1.2)
                        .offset(
                            x: CGFloat(index - 3) * geometry.size.width * 0.14,
                            y: CGFloat(index % 2) * geometry.size.height * 0.18 - geometry.size.height * 0.1
                        )
                }
            }
        }
    }

    private func tunnelScene() -> some View {
        GeometryReader { geometry in
            ZStack {
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    path.move(to: CGPoint(x: width * 0.1, y: height))
                    path.addLine(to: CGPoint(x: width * 0.48, y: height * 0.2))
                    path.addLine(to: CGPoint(x: width * 0.9, y: height))
                }
                .stroke(Color.orange.opacity(0.7), lineWidth: 3)

                ForEach(0..<4, id: \.self) { index in
                    Rectangle()
                        .fill(Color.white.opacity(0.65))
                        .frame(width: geometry.size.width * 0.34, height: 2)
                        .rotationEffect(.degrees(-18))
                        .offset(
                            x: CGFloat(index - 1) * geometry.size.width * 0.16,
                            y: CGFloat(index - 1) * geometry.size.height * 0.12
                        )
                }
            }
        }
    }

    private func parkingScene() -> some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.red.opacity(0.72))
                    .frame(width: geometry.size.width * 0.34, height: geometry.size.height * 0.12)
                    .offset(x: -geometry.size.width * 0.18, y: geometry.size.height * 0.1)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.blue.opacity(0.64))
                    .frame(width: geometry.size.width * 0.38, height: geometry.size.height * 0.13)
                    .offset(x: geometry.size.width * 0.2, y: geometry.size.height * 0.08)

                Rectangle()
                    .fill(Color.white.opacity(0.36))
                    .frame(width: geometry.size.width, height: 1)
                    .offset(y: geometry.size.height * 0.32)
            }
        }
    }
}

private struct PlaybackTimelinePlaceholder: View {
    var body: some View {
        EmptyStateView(
            iconName: "timeline.selection",
            title: "Timeline Pending",
            message: "Timeline grouping will stay offline until verified file timestamps are available.",
            style: .plain
        )
        .padding(.top, AppSpacing.xxxl)
        .padding(.horizontal, AppSpacing.xxl)
    }
}

private struct PlaybackLogSection: Identifiable {
    let title: String
    let entries: [PlaybackLogEntry]

    var id: String { title }
}

private struct PlaybackLogEntry: Identifiable {
    let id: String
    let title: String
    let duration: String
    let artworkStyle: PlaybackLogArtworkStyle
    let isLocked: Bool
    let isHighlighted: Bool

    func matches(_ keyword: String) -> Bool {
        title.lowercased().contains(keyword.lowercased()) ||
            duration.lowercased().contains(keyword.lowercased())
    }
}

private enum PlaybackLogArtworkStyle {
    case sunriseRoad
    case forestCabin
    case bridge
    case nightRoad
    case cockpit
    case tunnel
    case mountainCabin
    case autumnRoad
    case parkingLot
    case desertRoad

    var backgroundColors: [Color] {
        switch self {
        case .sunriseRoad:
            return [
                Color(red: 0.92, green: 0.70, blue: 0.44),
                Color(red: 0.13, green: 0.21, blue: 0.30)
            ]
        case .forestCabin:
            return [
                Color(red: 0.70, green: 0.82, blue: 0.74),
                Color(red: 0.12, green: 0.28, blue: 0.24)
            ]
        case .bridge:
            return [
                Color(red: 0.12, green: 0.52, blue: 0.72),
                Color(red: 0.05, green: 0.20, blue: 0.34)
            ]
        case .nightRoad:
            return [
                Color(red: 0.12, green: 0.10, blue: 0.08),
                Color(red: 0.01, green: 0.01, blue: 0.02)
            ]
        case .cockpit:
            return AppArtworkPalette.gallerySnapshot
        case .tunnel:
            return AppArtworkPalette.galleryParkingMonitor
        case .mountainCabin:
            return [
                Color(red: 0.62, green: 0.78, blue: 0.52),
                Color(red: 0.10, green: 0.26, blue: 0.30)
            ]
        case .autumnRoad:
            return [
                Color(red: 0.86, green: 0.57, blue: 0.29),
                Color(red: 0.17, green: 0.22, blue: 0.24)
            ]
        case .parkingLot:
            return [
                Color(red: 0.32, green: 0.67, blue: 0.86),
                Color(red: 0.16, green: 0.21, blue: 0.28)
            ]
        case .desertRoad:
            return [
                Color(red: 0.94, green: 0.79, blue: 0.52),
                Color(red: 0.36, green: 0.29, blue: 0.24)
            ]
        }
    }
}

private enum PlaybackLogSampleData {
    static let sections: [PlaybackLogSection] = [
        PlaybackLogSection(
            title: "Today",
            entries: [
                PlaybackLogEntry(
                    id: "today-sunrise",
                    title: "Morning commute",
                    duration: "0:45",
                    artworkStyle: .sunriseRoad,
                    isLocked: false,
                    isHighlighted: false
                ),
                PlaybackLogEntry(
                    id: "today-forest",
                    title: "Forest road",
                    duration: "1:20",
                    artworkStyle: .forestCabin,
                    isLocked: false,
                    isHighlighted: true
                ),
                PlaybackLogEntry(
                    id: "today-bridge",
                    title: "Bridge crossing",
                    duration: "0:15",
                    artworkStyle: .bridge,
                    isLocked: true,
                    isHighlighted: false
                ),
                PlaybackLogEntry(
                    id: "today-night",
                    title: "Night drive",
                    duration: "3:00",
                    artworkStyle: .nightRoad,
                    isLocked: false,
                    isHighlighted: false
                ),
                PlaybackLogEntry(
                    id: "today-cockpit",
                    title: "Cabin view",
                    duration: "0:58",
                    artworkStyle: .cockpit,
                    isLocked: false,
                    isHighlighted: false
                ),
                PlaybackLogEntry(
                    id: "today-sun",
                    title: "Low sun",
                    duration: "2:45",
                    artworkStyle: .sunriseRoad,
                    isLocked: false,
                    isHighlighted: false
                ),
                PlaybackLogEntry(
                    id: "today-tunnel",
                    title: "Tunnel",
                    duration: "0:30",
                    artworkStyle: .tunnel,
                    isLocked: true,
                    isHighlighted: false
                ),
                PlaybackLogEntry(
                    id: "today-mountain",
                    title: "Mountain road",
                    duration: "1:12",
                    artworkStyle: .mountainCabin,
                    isLocked: false,
                    isHighlighted: false
                )
            ]
        ),
        PlaybackLogSection(
            title: "Yesterday",
            entries: [
                PlaybackLogEntry(
                    id: "yesterday-night",
                    title: "City lights",
                    duration: "5:00",
                    artworkStyle: .nightRoad,
                    isLocked: false,
                    isHighlighted: false
                ),
                PlaybackLogEntry(
                    id: "yesterday-autumn",
                    title: "Autumn road",
                    duration: "2:10",
                    artworkStyle: .autumnRoad,
                    isLocked: false,
                    isHighlighted: false
                ),
                PlaybackLogEntry(
                    id: "yesterday-parking",
                    title: "Parking lot",
                    duration: "0:45",
                    artworkStyle: .parkingLot,
                    isLocked: false,
                    isHighlighted: true
                ),
                PlaybackLogEntry(
                    id: "yesterday-desert",
                    title: "Open highway",
                    duration: "10:00",
                    artworkStyle: .desertRoad,
                    isLocked: false,
                    isHighlighted: false
                )
            ]
        )
    ]
}
