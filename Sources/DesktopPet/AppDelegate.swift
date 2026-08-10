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

        petWindowController?.onRightClick = { [weak statusItemController] in
            statusItemController?.showMenuAtCursor()
        }

        DispatchQueue.main.async { [weak self] in
            self?.checkRunningFromTemp()
        }
    }

    // MARK: - Temporary Location Check

    private func checkRunningFromTemp() {
        let path = Bundle.main.bundlePath
        let lowercasePath = path.lowercased()
        
        let isTranslocated = lowercasePath.contains("apptranslocation")
        let isMountedDmg = lowercasePath.hasPrefix("/volumes/")
        
        if isTranslocated || isMountedDmg {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Luna - Temporary Location Warning"
            alert.informativeText = """
                Luna is currently running from a temporary location or mounted disk image (DMG).
                
                The "Start at Login" feature will NOT work after a restart because temporary paths are cleared or randomized by macOS.
                
                To resolve this:
                1. Move the application to a permanent folder (like your Applications folder).
                2. Run the application from that permanent location.
                """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
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
