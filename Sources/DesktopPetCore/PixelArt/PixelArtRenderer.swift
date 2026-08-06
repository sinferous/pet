import Foundation

/// A rendered frame: raw RGBA bytes plus dimensions.
///
/// Rows are stored **top row first** (index 0 = top of the image), matching the
/// natural string-art authoring order. Vertical flip for CoreGraphics
/// (which is bottom-up) is the consumer's concern, handled in the app layer.
public struct RenderedFrame: Equatable, Sendable {
    public let pixels: [UInt8]
    public let width: Int
    public let height: Int

    public init(pixels: [UInt8], width: Int, height: Int) {
        precondition(pixels.count == width * height * 4, "pixel buffer must be width*height*4 bytes")
        self.pixels = pixels
        self.width = width
        self.height = height
    }

    /// Alpha (0–255) at a pixel. `y` is top-based: 0 = top row.
    public func alpha(x: Int, y: Int) -> UInt8 {
        guard x >= 0, x < width, y >= 0, y < height else { return 0 }
        return pixels[(y * width + x) * 4 + 3]
    }
}

public enum PixelArtError: Error, Equatable, CustomStringConvertible {
    case empty
    case raggedRows(firstLength: Int, row: Int, length: Int)
    case unknownCharacter(Character, x: Int, y: Int)

    public var description: String {
        switch self {
        case .empty: return "Pixel art has no rows"
        case let .raggedRows(firstLength, row, length):
            return "Pixel art row \(row) has length \(length); expected \(firstLength)"
        case let .unknownCharacter(c, x, y):
            return "Unknown palette character '\(c)' at x=\(x), y=\(y)"
        }
    }
}

/// Converts string-based pixel maps into raw RGBA buffers. Pure and testable
/// on any platform — no AppKit/CoreGraphics involvement.
public enum PixelArtRenderer {
    /// Renders `rows` (top row first) using `palette`. `.` maps to transparent.
    public static func render(rows: [String], palette: [Character: PixelRGBA]) throws -> RenderedFrame {
        guard let first = rows.first, !first.isEmpty else { throw PixelArtError.empty }
        let width = first.count
        let height = rows.count

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for (rowIndex, row) in rows.enumerated() {
            guard row.count == width else {
                throw PixelArtError.raggedRows(firstLength: width, row: rowIndex, length: row.count)
            }
            for (colIndex, ch) in row.enumerated() {
                if ch == "." { continue } // transparent
                guard let color = palette[ch] else {
                    throw PixelArtError.unknownCharacter(ch, x: colIndex, y: rowIndex)
                }
                let offset = (rowIndex * width + colIndex) * 4
                pixels[offset + 0] = color.r
                pixels[offset + 1] = color.g
                pixels[offset + 2] = color.b
                pixels[offset + 3] = color.a
            }
        }
        return RenderedFrame(pixels: pixels, width: width, height: height)
    }
}
