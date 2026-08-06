import Foundation

/// Persists user preferences in `UserDefaults`.
final class SettingsStore {

    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard

    private enum Key: String {
        case sleepPrevention
        case waterReminders
        case autoStart
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

    var autoStart: Bool {
        get { defaults.object(forKey: Key.autoStart.rawValue) as? Bool ?? false } // off by default
        set { defaults.set(newValue, forKey: Key.autoStart.rawValue) }
    }

    private init() {}
}
