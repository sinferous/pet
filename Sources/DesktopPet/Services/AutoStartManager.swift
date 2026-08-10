import Foundation
import ServiceManagement

/// Manages login-item auto-start using `SMAppService` (macOS 13+).
///
/// Default is **off** — the user must launch manually first and can enable
/// via the menu bar toggle.
final class AutoStartManager {

    /// Whether the app is currently registered as a login item.
    var isEnabled: Bool {
        return launchAgentExists()
    }

    func enable() {
        // Copy the currently running app bundle to a permanent location under Application Support.
        // This ensures autostart works reliably even if the app was run from a temporary translocated path or DMG.
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let destFolder = appSupport.appendingPathComponent("DesktopPet", isDirectory: true)
            let destAppURL = destFolder.appendingPathComponent("Luna.app")
            
            do {
                try FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: destAppURL.path) {
                    try FileManager.default.removeItem(at: destAppURL)
                }
                try FileManager.default.copyItem(at: Bundle.main.bundleURL, to: destAppURL)
                print("[AutoStart] Successfully copied app bundle to permanent location: \(destAppURL.path)")
                installLaunchAgent(for: destAppURL)
                return
            } catch {
                print("[AutoStart] Failed to copy app bundle: \(error), attempting direct registration")
            }
        }
        
        // Fallback: register the currently running app bundle directly
        installLaunchAgent(for: Bundle.main.bundleURL)
    }

    func disable() {
        removeLaunchAgent()
        
        // Clean up the copied app bundle if it exists
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let destAppURL = appSupport.appendingPathComponent("DesktopPet/Luna.app")
            if FileManager.default.fileExists(atPath: destAppURL.path) {
                try? FileManager.default.removeItem(at: destAppURL)
            }
        }
    }

    // MARK: - LaunchAgent management

    private static let agentID = "com.desktop-pet.autostart"
    private var agentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(Self.agentID).plist")
    }

    private func launchAgentExists() -> Bool {
        FileManager.default.fileExists(atPath: agentURL.path)
    }

    private func installLaunchAgent(for appURL: URL) {
        let plist: [String: Any] = [
            "Label": Self.agentID,
            "ProgramArguments": ["/usr/bin/open", appURL.path],
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
