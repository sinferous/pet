import AppKit
import DesktopPetCore

/// Converts `NSScreen.screens` into the pure-Foundation `[ScreenRect]`
/// used by `ScreenNavigator`, and maps back to an index for positioning.
enum ScreenAdapter {

    /// Snapshot the current display arrangement as `[ScreenRect]`.
    static func screenRects() -> [ScreenRect] {
        NSScreen.screens.map { screen in
            let f = screen.frame
            return ScreenRect(minX: f.minX, minY: f.minY,
                              width: f.width, height: f.height)
        }
    }

    /// Returns the index of the screen that contains `point` (in global
    /// coordinates, bottom-left origin).  Returns `nil` if no screen matches.
    static func screenIndex(containing point: NSPoint,
                            in screens: [ScreenRect]) -> Int? {
        for (i, rect) in screens.enumerated() {
            if rect.contains(x: Double(point.x), y: Double(point.y)) {
                return i
            }
        }
        return nil
    }
}
