enum PlaybackRoute: CaseIterable, Equatable, Hashable {
    case files
    case timeline

    var title: String {
        switch self {
        case .files:
            return "Files"
        case .timeline:
            return "Timeline"
        }
    }
}
