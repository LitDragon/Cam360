import SwiftUI
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var bootstrap: AppBootstrap?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }

        let bootstrap = AppBootstrap.launch(arguments: ProcessInfo.processInfo.arguments)
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: AppRootView(bootstrap: bootstrap))
        window.makeKeyAndVisible()

        self.bootstrap = bootstrap
        self.window = window
    }
}
