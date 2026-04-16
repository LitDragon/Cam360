//
//  Cam360UITests.swift
//  Cam360UITests
//
//  Created by Naxclow on 2026/4/15.
//

import XCTest

final class Cam360UITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsOnboardingByDefault() throws {
        let app = XCUIApplication()
        app.launchArguments = [AppLaunchArgument.resetStorage]
        app.launch()

        XCTAssertTrue(app.staticTexts["连接你的行车记录仪"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testForceMainCanSwitchAcrossAllTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = [AppLaunchArgument.resetStorage, AppLaunchArgument.forceMain]
        app.launch()

        assertTab(identifier: "main-tab-dashboard", on: app, screenIdentifier: "screen-dashboard")
        assertTab(identifier: "main-tab-gallery", on: app, screenIdentifier: "screen-gallery")
        assertTab(identifier: "main-tab-settings", on: app, screenIdentifier: "screen-settings")
    }

    private func assertTab(identifier: String, on app: XCUIApplication, screenIdentifier: String) {
        app.buttons[identifier].tap()
        XCTAssertTrue(app.otherElements[screenIdentifier].waitForExistence(timeout: 2))
    }
}

private enum AppLaunchArgument {
    static let resetStorage = "-uitest-reset-storage"
    static let forceMain = "-uitest-force-main"
}
