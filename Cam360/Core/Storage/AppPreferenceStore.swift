import Foundation

protocol AppPreferenceStore: AnyObject {
    var hasCompletedOnboarding: Bool { get set }
    func reset()
}

final class UserDefaultsAppPreferenceStore: AppPreferenceStore {
    private enum Key {
        static let hasCompletedOnboarding = "preferences.hasCompletedOnboarding"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }

    var hasCompletedOnboarding: Bool {
        get {
            userDefaults.bool(forKey: Key.hasCompletedOnboarding)
        }
        set {
            userDefaults.set(newValue, forKey: Key.hasCompletedOnboarding)
        }
    }

    func reset() {
        userDefaults.removeObject(forKey: Key.hasCompletedOnboarding)
    }
}
