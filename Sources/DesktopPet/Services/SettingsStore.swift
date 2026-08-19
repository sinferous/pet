import Foundation

/// Persists user preferences in `UserDefaults`.
final class SettingsStore {

    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    private enum Key: String {
        case sleepPrevention
        case waterReminders
        case waterIntervalMinutes
        case autoStart
        case stayAtBottom
    }

    // MARK: - Properties

    var sleepPrevention: Bool {
        get { defaults.object(forKey: Key.sleepPrevention.rawValue) as? Bool ?? true } // on by default
        set { defaults.set(newValue, forKey: Key.sleepPrevention.rawValue) }
    }

    var waterReminders: Bool {
        get { defaults.object(forKey: Key.waterReminders.rawValue) as? Bool ?? true } // on by default
        set { defaults.set(newValue, forKey: Key.waterReminders.rawValue) }
    }

    /// Minutes between hydration alerts. Clamped to 1...1440 (default 60).
    var waterIntervalMinutes: Int {
        get {
            let stored = defaults.object(forKey: Key.waterIntervalMinutes.rawValue) as? Int ?? 60
            return min(1440, max(1, stored))
        }
        set {
            defaults.set(min(1440, max(1, newValue)), forKey: Key.waterIntervalMinutes.rawValue)
        }
    }

    var autoStart: Bool {
        get { defaults.object(forKey: Key.autoStart.rawValue) as? Bool ?? false } // off by default
        set { defaults.set(newValue, forKey: Key.autoStart.rawValue) }
    }

    var stayAtBottom: Bool {
        get { defaults.object(forKey: Key.stayAtBottom.rawValue) as? Bool ?? false } // off by default
        set { defaults.set(newValue, forKey: Key.stayAtBottom.rawValue) }
    }

    private init() {}
}
