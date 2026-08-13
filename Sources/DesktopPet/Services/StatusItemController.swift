import AppKit
import DesktopPetCore

/// Creates and manages the menu-bar icon and its dropdown menu.
final class StatusItemController {

    private let statusItem: NSStatusItem
    private let settings: SettingsStore
    private let sleepPreventer: SleepPreventer
    private let autoStart: AutoStartManager
    private let waterReminder: WaterReminderManager
    private let behavior: BehaviorMachine
    private let parkHandler: (Bool) -> Void
    private let sayHandler: () -> Void

    private var isParked = false
    private var isHidden = false

    private let sleepItem = NSMenuItem()
    private let waterItem = NSMenuItem()
    private let intervalItem = NSMenuItem()
    private let autoStartItem = NSMenuItem()
    private let idleItem = NSMenuItem()
    private let pokeItem = NSMenuItem()
    private let hideSeekItem = NSMenuItem()
    private let sayItem = NSMenuItem()
    private let hideSeekHandler: (Bool) -> Void
    private let customReminderHandler: () -> Void

    init(settings: SettingsStore,
         sleepPreventer: SleepPreventer,
         autoStart: AutoStartManager,
         waterReminder: WaterReminderManager,
         behavior: BehaviorMachine,
         parkHandler: @escaping (Bool) -> Void,
         sayHandler: @escaping () -> Void,
         hideSeekHandler: @escaping (Bool) -> Void,
         customReminderHandler: @escaping () -> Void) {
        self.settings = settings
        self.sleepPreventer = sleepPreventer
        self.autoStart = autoStart
        self.waterReminder = waterReminder
        self.behavior = behavior
        self.parkHandler = parkHandler
        self.sayHandler = sayHandler
        self.hideSeekHandler = hideSeekHandler
        self.customReminderHandler = customReminderHandler

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.title = "🐱"
        }
        statusItem.menu = buildMenu()
        refreshCheckmarks()
    }

    // MARK: - Menu construction

    private func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "Luna")

        sleepItem.title = "Prevent Sleep"
        sleepItem.target = self
        sleepItem.action = #selector(toggleSleep)
        menu.addItem(sleepItem)

        waterItem.title = "Water Reminders"
        waterItem.target = self
        waterItem.action = #selector(toggleWater)
        menu.addItem(waterItem)

        intervalItem.title = "Hydration Interval…"
        intervalItem.target = self
        intervalItem.action = #selector(setHydrationInterval)
        menu.addItem(intervalItem)

        autoStartItem.title = "Start at Login"
        autoStartItem.target = self
        autoStartItem.action = #selector(toggleAutoStart)
        menu.addItem(autoStartItem)

        idleItem.title = "Idle (Park)"
        idleItem.target = self
        idleItem.action = #selector(togglePark)
        menu.addItem(idleItem)

        pokeItem.title = "Poke"
        pokeItem.target = self
        pokeItem.action = #selector(poke)
        menu.addItem(pokeItem)

        hideSeekItem.title = "Hide/Seek"
        hideSeekItem.target = self
        hideSeekItem.action = #selector(toggleHideSeek)
        menu.addItem(hideSeekItem)

        sayItem.title = "Say"
        sayItem.target = self
        sayItem.action = #selector(triggerSay)
        menu.addItem(sayItem)

        let customReminderItem = NSMenuItem(title: "Set Custom Reminder…", action: #selector(setCustomReminder), keyEquivalent: "")
        customReminderItem.target = self
        menu.addItem(customReminderItem)

        let movementsItem = NSMenuItem(title: "Movements", action: nil, keyEquivalent: "")
        movementsItem.submenu = buildMovementsMenu()
        menu.addItem(movementsItem)

        menu.addItem(.separator())

        let updateItem = NSMenuItem(title: "Check for Updates…",
                                    action: #selector(checkForUpdates),
                                    keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Luna",
                                  action: #selector(quitApp),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    /// Submenu mirroring the web control panel's buttons — each item triggers a
    /// pet activity directly (same labels/order as the browser preview).
    private func buildMovementsMenu() -> NSMenu {
        let menu = NSMenu(title: "Movements")
        let movements: [(String, PetState)] = [
            ("Idle", .idle),
            ("Walk", .walk),
            ("Sleep", .sleep),
            ("Play", .play),
            ("React (Shy)", .react),
            ("Drink (Water)", .drink),
            ("Laugh (Tears)", .laugh),
            ("Jump (Hops)", .jump),
            ("Run", .run),
            ("Roll", .roll),
            ("Wool Ball", .woolball),
            ("Cheer", .cheer),
            ("Love", .love),
        ]
        for (title, state) in movements {
            let item = NSMenuItem(title: title, action: #selector(triggerMovement(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = state.rawValue
            menu.addItem(item)
        }
        return menu
    }

    // MARK: - Actions

    @objc private func toggleSleep() {
        settings.sleepPrevention.toggle()
        if settings.sleepPrevention {
            sleepPreventer.start()
        } else {
            sleepPreventer.stop()
        }
        refreshCheckmarks()
    }

    @objc private func toggleWater() {
        settings.waterReminders.toggle()
        if settings.waterReminders {
            waterReminder.enable()
        } else {
            waterReminder.disable()
        }
        refreshCheckmarks()
    }

    @objc private func setHydrationInterval() {
        let alert = NSAlert()
        alert.messageText = "Hydration Interval"
        alert.informativeText = "How many minutes between hydration alerts? (1–1440)"

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        field.stringValue = String(settings.waterIntervalMinutes)
        field.placeholderString = "60"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let parsed = Int(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 60
        let minutes = min(1440, max(1, parsed))
        settings.waterIntervalMinutes = minutes
        waterReminder.intervalMinutes = minutes
        waterReminder.reconfigure()
        refreshCheckmarks()
    }

    @objc private func togglePark() {
        isParked.toggle()
        parkHandler(isParked)
        refreshCheckmarks()
    }

    @objc private func poke() {
        isParked = false
        parkHandler(false)
        refreshCheckmarks()
    }

    @objc private func toggleHideSeek() {
        isHidden.toggle()
        hideSeekHandler(isHidden)
        refreshCheckmarks()
    }

    @objc private func setCustomReminder() {
        customReminderHandler()
    }

    @objc private func triggerSay() {
        sayHandler()
    }

    @objc private func triggerMovement(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let state = PetState(rawValue: raw) else { return }
        isParked = false
        parkHandler(false) // unpark so the movement plays and normal behavior resumes
        behavior.triggerActivity(state)
        refreshCheckmarks()
    }

    @objc private func toggleAutoStart() {
        if autoStart.isEnabled {
            autoStart.disable()
            settings.autoStart = false
        } else {
            autoStart.enable()
            settings.autoStart = true
        }
        refreshCheckmarks()
    }

    @objc private func checkForUpdates() {
        guard let url = URL(string: "https://github.com/user/desktop-pet/releases") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func showMenuAtCursor() {
        if let menu = statusItem.menu {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }

    // MARK: - Helpers

    private func refreshCheckmarks() {
        sleepItem.state = settings.sleepPrevention ? .on : .off
        waterItem.state = settings.waterReminders ? .on : .off
        autoStartItem.state = autoStart.isEnabled ? .on : .off
        idleItem.state = isParked ? .on : .off
        hideSeekItem.state = isHidden ? .on : .off
        intervalItem.title = "Hydration Interval… (\(settings.waterIntervalMinutes) min)"
    }
}
