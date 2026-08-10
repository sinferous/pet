import Foundation

/// Which horizontal way the pet is facing.
public enum Facing: String, Sendable {
    case left, right

    public var flipped: Facing { self == .left ? .right : .left }
}

/// A spot the pet decided to walk to.
public struct WalkTarget: Equatable, Sendable {
    public let screenIndex: Int
    public let x: Double
    /// The floor (bottom edge) of the target screen.
    public let y: Double

    public init(screenIndex: Int, x: Double, y: Double) {
        self.screenIndex = screenIndex
        self.x = x
        self.y = y
    }
}

/// Result of advancing the pet one step.
public struct WalkStep: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let facing: Facing
    /// True when the pet stepped off one screen and onto an adjacent one.
    public let crossedScreen: Bool

    public init(x: Double, y: Double, facing: Facing, crossedScreen: Bool) {
        self.x = x
        self.y = y
        self.facing = facing
        self.crossedScreen = crossedScreen
    }
}

/// Pure multi-screen walk math: picking a random target and advancing the pet's
/// global position, crossing screen boundaries when screens are adjacent and
/// turning around when there's no neighbor. No AppKit involved — the app layer
/// feeds it `[ScreenRect]` built from `NSScreen.screens`.
public enum ScreenNavigator {

    /// Two rectangles count as "touching" when their edges are within this
    /// tolerance (screens can be off by a fraction of a point).
    public static let adjacencyTolerance: Double = 4.0

    /// Picks a random reachable target on a random screen, inset from the edges.
    public static func pickTarget(screens: [ScreenRect],
                                  margin: Double = 40,
                                  winWidth: Double = 256,
                                  petHeight: Double = 120) -> WalkTarget? {
        guard !screens.isEmpty else { return nil }
        let index = Int.random(in: 0..<screens.count)
        let screen = screens[index]
        
        let insetX = min(margin, screen.width / 4)
        let insetY = min(margin, screen.height / 4)
        
        let rangeX = screen.width - insetX * 2 - winWidth
        let rangeY = screen.height - insetY * 2 - petHeight
        
        let x = rangeX > 0 ? screen.minX + insetX + Double.random(in: 0...rangeX) : screen.centerX
        let y = rangeY > 0 ? screen.minY + insetY + Double.random(in: 0...rangeY) : screen.minY
        
        return WalkTarget(screenIndex: index, x: x, y: y)
    }

    /// Advances `x` and `y` towards target coordinates by `speed`, crossing to an adjacent
    /// screen at the edge, or turning around when there is none.
    public static func step(currentX: Double,
                            currentY: Double,
                            targetX: Double,
                            targetY: Double,
                            facing: Facing,
                            speed: Double,
                            screens: [ScreenRect],
                            width: Double = 0.0) -> WalkStep {
        guard let screen = screens.first(where: { $0.contains(x: currentX + width / 2, y: currentY) }) ??
                           screens.first(where: { $0.contains(x: currentX, y: currentY) }) else {
            return WalkStep(x: currentX, y: currentY, facing: facing, crossedScreen: false)
        }

        let dx = targetX - currentX
        let dy = targetY - currentY
        let len = (dx * dx + dy * dy).squareRoot()
        
        var x = currentX
        var y = currentY
        
        if len > 0 {
            let s = min(speed, len)
            x += (dx / len) * s
            y += (dy / len) * s
        }
        
        var resultFacing = dx >= 0 ? Facing.right : Facing.left
        var crossed = false

        if x <= screen.minX {
            if let next = adjacentScreen(to: .left, of: screen, screens: screens) {
                x = next.maxX - width
                crossed = true
            } else {
                x = screen.minX + 0.1
                resultFacing = .right
            }
        } else if x >= screen.maxX - width {
            if let next = adjacentScreen(to: .right, of: screen, screens: screens) {
                x = next.minX
                crossed = true
            } else {
                x = screen.maxX - width - 0.1
                resultFacing = .left
            }
        }

        return WalkStep(x: x, y: y, facing: resultFacing, crossedScreen: crossed)
    }

    // MARK: - Helpers

    private static func adjacentScreen(to direction: Facing,
                                       of screen: ScreenRect,
                                       screens: [ScreenRect]) -> ScreenRect? {
        switch direction {
        case .right:
            return screens
                .filter { abs($0.minX - screen.maxX) <= adjacencyTolerance }
                .min { $0.minX < $1.minX }
        case .left:
            return screens
                .filter { abs($0.maxX - screen.minX) <= adjacencyTolerance }
                .max { $0.maxX < $1.maxX }
        }
    }
}
