import Foundation

struct NotificationPreferences: Codable, Equatable {
    var emergencyEventNotifications: Bool
    var collisionAlerts: Bool
    var parkingIncidentAlerts: Bool
    var pushNotifications: Bool
    var soundForNotifications: Bool
    var quietHoursEnabled: Bool
    var quietHoursStart: String
    var quietHoursEnd: String

    static let defaultValue = NotificationPreferences(
        emergencyEventNotifications: true,
        collisionAlerts: true,
        parkingIncidentAlerts: false,
        pushNotifications: true,
        soundForNotifications: true,
        quietHoursEnabled: false,
        quietHoursStart: "10:00 PM",
        quietHoursEnd: "06:00 AM"
    )
}

protocol AppPreferenceStore: AnyObject {
    var hasCompletedOnboarding: Bool { get set }
    var shareAnonymousLogs: Bool { get set }
    var notificationPreferences: NotificationPreferences { get set }
    func reset()
}

final class UserDefaultsAppPreferenceStore: AppPreferenceStore {
    private enum Key {
        static let hasCompletedOnboarding = "preferences.hasCompletedOnboarding"
        static let shareAnonymousLogs = "preferences.shareAnonymousLogs"
        static let notificationPreferences = "preferences.notificationPreferences"
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

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

    var shareAnonymousLogs: Bool {
        get {
            guard userDefaults.object(forKey: Key.shareAnonymousLogs) != nil else {
                return true
            }

            return userDefaults.bool(forKey: Key.shareAnonymousLogs)
        }
        set {
            userDefaults.set(newValue, forKey: Key.shareAnonymousLogs)
        }
    }

    var notificationPreferences: NotificationPreferences {
        get {
            guard let data = userDefaults.data(forKey: Key.notificationPreferences),
                  let preferences = try? decoder.decode(NotificationPreferences.self, from: data) else {
                return .defaultValue
            }

            return preferences
        }
        set {
            let data = try? encoder.encode(newValue)
            userDefaults.set(data, forKey: Key.notificationPreferences)
        }
    }

    func reset() {
        userDefaults.removeObject(forKey: Key.hasCompletedOnboarding)
        userDefaults.removeObject(forKey: Key.shareAnonymousLogs)
        userDefaults.removeObject(forKey: Key.notificationPreferences)
    }
}
