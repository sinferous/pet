import Foundation

/// An 8-bit-per-channel RGBA color. Value type, equatable, immutable.
public struct PixelRGBA: Equatable, Sendable {
    public let r: UInt8
    public let g: UInt8
    public let b: UInt8
    public let a: UInt8

    public init(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 255) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public static let clear = PixelRGBA(0, 0, 0, 0)
}

/// Character → color mapping shared by the pixel parser and all artwork.
public enum PixelPalette {
    /// Canonical palette for the default pet. `.` (transparent) is not listed;
    /// the renderer treats any unmapped dot as fully transparent.
    public static let standard: [Character: PixelRGBA] = [
        "O": PixelRGBA(43, 43, 43),      // outline
        "B": PixelRGBA(250, 230, 200),   // body (cream)
        "S": PixelRGBA(232, 205, 165),   // body shade (belly/tail shadow)
        "P": PixelRGBA(242, 162, 181),   // pink (inner ear / blush)
        "E": PixelRGBA(40, 40, 48),      // eye
        "N": PixelRGBA(198, 110, 128),   // nose
        "W": PixelRGBA(255, 248, 238),   // mouth / white accent
        "T": PixelRGBA(219, 183, 134),   // tail
        "G": PixelRGBA(111, 194, 118),   // bottle green
        "L": PixelRGBA(217, 242, 221),   // bottle highlight
        "H": PixelRGBA(255, 123, 172),   // heart (used by scene overlays)
        "R": PixelRGBA(242, 60, 60),      // red (anger mark)
    ]

    /// Returns the color for a character, or `.clear` for `.` (transparent).
    public static func color(for character: Character, palette: [Character: PixelRGBA] = standard) -> PixelRGBA {
        if character == "." { return .clear }
        return palette[character] ?? .clear
    }
}
