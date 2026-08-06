import Foundation
import ServiceManagement

/// Manages login-item auto-start using `SMAppService` (macOS 13+).
///
/// Default is **off** — the user must launch manually first and can enable
/// via the menu bar toggle.
final class AutoStartManager {

    /// Whether the app is currently registered as a login item.
    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return launchAgentExists()
    }

    func enable() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                return
            } catch {
                print("[AutoStart] SMAppService.register failed: \(error), falling back to LaunchAgent")
            }
        }
        installLaunchAgent()
    }

    func disable() {
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.unregister()
                return
            } catch {
                print("[AutoStart] SMAppService.unregister failed: \(error)")
            }
        }
        removeLaunchAgent()
    }

    // MARK: - LaunchAgent fallback

    private static let agentID = "com.desktop-pet.autostart"
    private var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(Self.agentID).plist")
    }

    private func launchAgentExists() -> Bool {
        FileManager.default.fileExists(atPath: agentURL.path)
    }

    private func installLaunchAgent() {
        let exe = Bundle.main.executableURL?.path ?? ProcessInfo.processInfo.arguments[0]
        let plist: [String: Any] = [
            "Label": Self.agentID,
            "ProgramArguments": [exe],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        let dir = agentURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        (plist as NSDictionary).write(to: agentURL, atomically: true)
    }

    private func removeLaunchAgent() {
        try? FileManager.default.removeItem(at: agentURL)
    }
}
