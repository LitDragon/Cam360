enum ModernFeatureAvailability {
    static var supportsModernEnhancements: Bool {
        if #available(iOS 17, *) {
            return true
        }
        return false
    }
}
