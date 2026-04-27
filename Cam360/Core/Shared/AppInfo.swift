import Foundation

enum AppInfo {
    private static let placeholderVersion = "1.0"
    private static let placeholderBrandedName = "DASHCAM PRO"

    static var shortVersionText: String {
        "v\(resolvedVersion)"
    }

    static var brandedVersionText: String {
        "\(placeholderBrandedName) \(shortVersionText)"
    }

    private static var resolvedVersion: String {
        guard let rawVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              rawVersion.isEmpty == false,
              rawVersion.contains("$(") == false else {
            return placeholderVersion
        }

        return rawVersion
    }
}
