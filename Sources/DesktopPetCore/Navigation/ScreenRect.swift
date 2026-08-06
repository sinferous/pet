import Foundation

/// A display rectangle in global screen coordinates (bottom-left origin,
/// matching macOS `NSScreen.frame`). Deliberately uses plain `Double`s so this
/// module stays free of CoreGraphics and is portable to any platform.
public struct ScreenRect: Equatable, Sendable {
    public let minX: Double
    public let minY: Double
    public let width: Double
    public let height: Double

    public init(minX: Double, minY: Double, width: Double, height: Double) {
        self.minX = minX
        self.minY = minY
        self.width = width
        self.height = height
    }

    public var maxX: Double { minX + width }
    public var maxY: Double { minY + height }
    public var centerX: Double { minX + width / 2 }

    public func contains(x: Double, y: Double) -> Bool {
        x >= minX && x < maxX && y >= minY && y < maxY
    }
}
