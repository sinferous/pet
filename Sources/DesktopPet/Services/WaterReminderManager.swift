import Foundation
import UserNotifications
import DesktopPetCore

/// Schedules water-drinking reminders every `intervalMinutes` (default 60)
/// via system notifications and triggers the in-app drink animation on the
/// behavior machine. Mirrors the web preview's configurable hydration interval.
final class WaterReminderManager {

    private weak var behavior: BehaviorMachine?
    private var inAppTimer: Timer?
    private var isEnabled = false

    /// Minutes between hydration alerts. Setting this and calling `reconfigure()`
    /// re-schedules both the notification and the in-app timer.
    var intervalMinutes: Int = 60

    init(behavior: BehaviorMachine) {
        self.behavior = behavior
    }

    // MARK: - Public API

    func enable() {
        isEnabled = true
        requestPermissionThenSchedule()
        scheduleInAppTimer()
    }

    func disable() {
        isEnabled = false
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["com.desktop-pet.water-reminder"])
        inAppTimer?.invalidate()
        inAppTimer = nil
    }

    /// Re-schedules everything at the current `intervalMinutes`. Called when the
    /// user changes the interval from the menu while reminders are on.
    func reconfigure() {
        guard isEnabled else { return }
        disable()
        enable()
    }

    // MARK: - System notification

    private func requestPermissionThenSchedule() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { self.scheduleNotification() }
        }
    }

    private func scheduleNotification() {
        let content = UNMutableNotificationContent()
        content.title = "💧 Water Reminder"
        content.body = "Time for a glass of water! Stay hydrated 🐱"
        content.sound = .default

        // Repeat every N minutes. `repeats: true` requires >= 60s, so any
        // minute value >= 1 is valid.
        let interval = TimeInterval(max(1, intervalMinutes) * 60)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)

        let request = UNNotificationRequest(
            identifier: "com.desktop-pet.water-reminder",
            content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[WaterReminder] failed to schedule notification: \(error)")
            }
        }
    }

    // MARK: - In-app sync

    /// Fires a repeating `Timer` that triggers the drink animation every
    /// `intervalMinutes`, regardless of notification permission.
    private func scheduleInAppTimer() {
        inAppTimer?.invalidate()
        let interval = TimeInterval(max(1, intervalMinutes) * 60)
        inAppTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.fireDrink()
        }
    }

    private func fireDrink() {
        DispatchQueue.main.async { [weak self] in
            self?.behavior?.startWaterDrink()
        }
    }
}
