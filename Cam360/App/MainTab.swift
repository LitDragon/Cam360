enum MainTab: String, CaseIterable, Codable {
    case dashboard
    case gallery
    case settings

    var title: String {
        switch self {
        case .dashboard:
            return "首页"
        case .gallery:
            return "相册"
        case .settings:
            return "更多"
        }
    }

    var systemImageName: String {
        switch self {
        case .dashboard:
            return "camera.viewfinder"
        case .gallery:
            return "photo"
        case .settings:
            return "ellipsis"
        }
    }

    var accessibilityIdentifier: String {
        "main-tab-\(rawValue)"
    }
}
