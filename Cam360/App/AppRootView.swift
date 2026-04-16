import SwiftUI

struct AppRootView: View {
    let bootstrap: AppBootstrap

    @ObservedObject private var router: AppRouter

    init(bootstrap: AppBootstrap) {
        self.bootstrap = bootstrap
        _router = ObservedObject(wrappedValue: bootstrap.router)
    }

    var body: some View {
        Group {
            switch router.route {
            case .onboarding:
                NavigationView {
                    DeviceOnboardingView(store: bootstrap.container.deviceOnboardingStore)
                }
                .navigationViewStyle(StackNavigationViewStyle())
            case .main:
                MainTabView(router: router, container: bootstrap.container)
            }
        }
        .accentColor(AppColor.brand)
    }
}
