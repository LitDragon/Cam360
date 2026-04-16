import Combine

enum MainTab: String, CaseIterable, Codable {
    case dashboard
    case gallery
    case events
    case settings

    var title: String {
        switch self {
        case .dashboard:
            return "概览"
        case .gallery:
            return "相册"
        case .events:
            return "事件"
        case .settings:
            return "设置"
        }
    }

    var systemImageName: String {
        switch self {
        case .dashboard:
            return "square.grid.2x2"
        case .gallery:
            return "photo.on.rectangle.angled"
        case .events:
            return "bell.badge"
        case .settings:
            return "gearshape"
        }
    }

    var accessibilityIdentifier: String {
        "main-tab-\(rawValue)"
    }
}

enum AppRoute: Equatable {
    case onboarding
    case main(MainTab)
}

final class AppRouter: ObservableObject {
    @Published private(set) var route: AppRoute

    init(route: AppRoute) {
        self.route = route
    }

    var selectedMainTab: MainTab {
        get {
            if case let .main(tab) = route {
                return tab
            }
            return .dashboard
        }
        set {
            showMain(tab: newValue)
        }
    }

    func showOnboarding() {
        route = .onboarding
    }

    func showMain(tab: MainTab = .dashboard) {
        route = .main(tab)
    }
}
