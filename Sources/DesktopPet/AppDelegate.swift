import AppKit
import UserNotifications
import DesktopPetCore

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    private var petWindowController: PetWindowController?
    private var statusItemController: StatusItemController?
    private var waterReminder: WaterReminderManager?
    private var sleepPreventer: SleepPreventer?
    private var autoStart: AutoStartManager?
    private var activity: NSObjectProtocol?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent App Nap from throttling the pet.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Animating Luna")

        UNUserNotificationCenter.current().delegate = self

        let settings = SettingsStore.shared
        let behavior = BehaviorMachine()

        sleepPreventer = SleepPreventer()
        if settings.sleepPrevention { sleepPreventer?.start() }

        autoStart = AutoStartManager()
        waterReminder = WaterReminderManager(behavior: behavior)
        waterReminder?.intervalMinutes = settings.waterIntervalMinutes
        if settings.waterReminders { waterReminder?.enable() }

        petWindowController = PetWindowController(behavior: behavior)
        petWindowController?.show()

        statusItemController = StatusItemController(
            settings: settings,
            sleepPreventer: sleepPreventer!,
            autoStart: autoStart!,
            waterReminder: waterReminder!,
            behavior: behavior,
            parkHandler: { [weak petWindowController] parked in
                if parked {
                    petWindowController?.park()
                } else {
                    petWindowController?.unpark()
                }
            },
            sayHandler: { [weak petWindowController] in
                petWindowController?.say()
            })
    }

    func applicationWillTerminate(_ notification: Notification) {
        sleepPreventer?.stop()
        waterReminder?.disable()
        if let activity { ProcessInfo.processInfo.endActivity(activity) }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show the notification even when the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler handler: @escaping () -> Void) {
        handler()
    }
}
