import Foundation
import UserNotifications
import DesktopPetCore

/// Schedules hourly water-drinking reminders via system notifications and
/// triggers the in-app drink animation on the behavior machine.
final class WaterReminderManager {

    private weak var behavior: BehaviorMachine?
    private var inAppTimer: Timer?

    init(behavior: BehaviorMachine) {
        self.behavior = behavior
    }

    // MARK: - Public API

    func enable() {
        requestPermissionThenSchedule()
        scheduleInAppTimer()
    }

    func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["com.desktop-pet.water-reminder"])
        inAppTimer?.invalidate()
        inAppTimer = nil
    }

    // MARK: - System notification

    private func requestPermissionThenSchedule() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted { self.scheduleHourlyNotification() }
        }
    }

    private func scheduleHourlyNotification() {
        let content = UNMutableNotificationContent()
        content.title = "💧 Water Reminder"
        content.body = "Time for a glass of water! Stay hydrated 🐱"
        content.sound = .default

        // Fire every hour on the minute.
        var dateComponents = DateComponents()
        dateComponents.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

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

    /// Fires a `Timer` that triggers the drink animation at the top of every
    /// hour, regardless of notification permission.
    private func scheduleInAppTimer() {
        inAppTimer?.invalidate()
        let interval = timeUntilNextHour()
        inAppTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.fireDrink()
        }
    }

    private func fireDrink() {
        DispatchQueue.main.async { [weak self] in
            self?.behavior?.startWaterDrink()
        }
        // Re-schedule for the next hour.
        scheduleInAppTimer()
    }

    private func timeUntilNextHour() -> TimeInterval {
        let now = Date()
        guard let next = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(minute: 0),
            matchingPolicy: .nextTime) else { return 3600 }
        return next.timeIntervalSince(now)
    }
}
