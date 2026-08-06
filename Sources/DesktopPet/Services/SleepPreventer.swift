import Foundation
import IOKit.pwr_mgt

/// Prevents idle-sleep by holding an IOKit power assertion while enabled.
/// The assertion is released on `stop()` or when the process exits.
/// No background child processes are spawned (caffeinate is avoided).
final class SleepPreventer {

    private var assertionID: IOPMAssertionID = 0
    private(set) var isActive = false

    func start() {
        guard !isActive else { return }
        let reason = "DesktopPet is keeping the display awake" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoIdleSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID)
        isActive = (result == kIOReturnSuccess)
    }

    func stop() {
        guard isActive else { return }
        IOPMAssertionRelease(assertionID)
        isActive = false
        assertionID = 0
    }

    deinit { stop() }
}
