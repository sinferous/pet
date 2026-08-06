import AppKit
import DesktopPetCore

/// Creates and manages the menu-bar icon and its dropdown menu.
final class StatusItemController {

    private let statusItem: NSStatusItem
    private let settings: SettingsStore
    private let sleepPreventer: SleepPreventer
    private let autoStart: AutoStartManager
    private let waterReminder: WaterReminderManager

    private let sleepItem = NSMenuItem()
    private let waterItem = NSMenuItem()
    private let autoStartItem = NSMenuItem()

    init(settings: SettingsStore,
         sleepPreventer: SleepPreventer,
         autoStart: AutoStartManager,
         waterReminder: WaterReminderManager) {
        self.settings = settings
        self.sleepPreventer = sleepPreventer
        self.autoStart = autoStart
        self.waterReminder = waterReminder

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.title = "🐱"
        }
        statusItem.menu = buildMenu()
        refreshCheckmarks()
    }

    // MARK: - Menu construction

    private func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "Desktop Pet")

        sleepItem.title = "Prevent Sleep"
        sleepItem.target = self
        sleepItem.action = #selector(toggleSleep)
        menu.addItem(sleepItem)

        waterItem.title = "Water Reminders"
        waterItem.target = self
        waterItem.action = #selector(toggleWater)
        menu.addItem(waterItem)

        autoStartItem.title = "Start at Login"
        autoStartItem.target = self
        autoStartItem.action = #selector(toggleAutoStart)
        menu.addItem(autoStartItem)

        menu.addItem(.separator())

        let updateItem = NSMenuItem(title: "Check for Updates…",
                                    action: #selector(checkForUpdates),
                                    keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Desktop Pet",
                                  action: #selector(quitApp),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

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

    // MARK: - Helpers

    private func refreshCheckmarks() {
        sleepItem.state = settings.sleepPrevention ? .on : .off
        waterItem.state = settings.waterReminders ? .on : .off
        autoStartItem.state = autoStart.isEnabled ? .on : .off
    }
}
