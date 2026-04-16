import Combine

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
            return "house.fill"
        case .gallery:
            return "photo.on.rectangle.angled"
        case .settings:
            return "ellipsis.circle"
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
