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

    private struct CustomReminder {
        let time: String // e.g. "14:30"
        let message: String
        var triggered: Bool
    }
    private var customReminders: [CustomReminder] = []
    private var reminderTimer: Timer?

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

        reminderTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.checkCustomReminders()
        }

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
            },
            hideSeekHandler: { [weak petWindowController] hidden in
                petWindowController?.setHidden(hidden)
            },
            customReminderHandler: { [weak self] in
                self?.showCustomReminderDialog()
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

    private func showCustomReminderDialog() {
        let alert = NSAlert()
        alert.messageText = "Set Custom Reminder"
        alert.informativeText = "Enter time (24h format, e.g. 14:30) and message for today."
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")
        
        let customView = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 60))
        
        let timeField = NSTextField(frame: NSRect(x: 0, y: 35, width: 220, height: 22))
        timeField.placeholderString = "Time (e.g. 14:30)"
        
        let msgField = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 22))
        msgField.placeholderString = "Message"
        
        customView.addSubview(timeField)
        customView.addSubview(msgField)
        alert.accessoryView = customView
        
        alert.window.initialFirstResponder = timeField
        
        if alert.runModal() == .alertFirstButtonReturn {
            var time = timeField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let msg = msgField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Normalize time input format (e.g. "6:20" -> "06:20")
            let parts = time.split(separator: ":")
            if parts.count == 2, let hVal = Int(parts[0]), let mVal = Int(parts[1]) {
                time = String(format: "%02d:%02d", hVal, mVal)
            }
            
            if !time.isEmpty && !msg.isEmpty {
                customReminders.append(CustomReminder(time: time, message: msg, triggered: false))
            }
        }
    }

    private func checkCustomReminders() {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let nowStr = formatter.string(from: Date())
        
        for i in 0..<customReminders.count {
            if !customReminders[i].triggered && customReminders[i].time == nowStr {
                customReminders[i].triggered = true
                petWindowController?.triggerCustomReminder(message: customReminders[i].message)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        reminderTimer?.invalidate()
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
