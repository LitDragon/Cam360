import SnapshotTesting
import SwiftUI
import XCTest
@testable import Cam360

final class Cam360SnapshotTests: XCTestCase {
    @MainActor
    func testOnboardingSnapshot() {
        withBootstrap(arguments: [AppBootstrap.LaunchArgument.forceOnboarding]) { bootstrap in
            assertSnapshot(
                of: UIHostingController(rootView: AppRootView(bootstrap: bootstrap)),
                as: .image(on: .iPhoneSe)
            )
        }
    }

    @MainActor
    func testDashboardSnapshot() {
        assertMainSnapshot(for: .dashboard)
    }

    @MainActor
    func testGallerySnapshot() {
        assertMainSnapshot(for: .gallery)
    }

    @MainActor
    func testEventsSnapshot() {
        assertMainSnapshot(for: .events)
    }

    @MainActor
    func testSettingsSnapshot() {
        assertMainSnapshot(for: .settings)
    }

    @MainActor
    private func assertMainSnapshot(for tab: MainTab) {
        withBootstrap(
            arguments: [
                AppBootstrap.LaunchArgument.forceMain,
                AppBootstrap.LaunchArgument.selectedTab,
                tab.rawValue,
            ]
        ) { bootstrap in
            assertSnapshot(
                of: UIHostingController(rootView: AppRootView(bootstrap: bootstrap)),
                as: .image(on: .iPhoneSe),
                named: tab.rawValue
            )
        }
    }

    @MainActor
    private func withBootstrap(arguments: [String], test: (AppBootstrap) -> Void) {
        let suiteName = "Cam360SnapshotTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }

        let bootstrap = AppBootstrap.launch(arguments: arguments, userDefaults: userDefaults)
        test(bootstrap)
    }
}
