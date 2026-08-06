import XCTest
import DesktopPetCore

final class PixelArtRendererTests: XCTestCase {

    func testRendersSimpleFrameWithCorrectRowOrder() throws {
        let rows = [
            "AB",
            "CD",
        ]
        let palette: [Character: PixelRGBA] = [
            "A": PixelRGBA(1, 2, 3),
            "B": PixelRGBA(4, 5, 6),
            "C": PixelRGBA(7, 8, 9),
            "D": PixelRGBA(10, 11, 12),
        ]
        let frame = try PixelArtRenderer.render(rows: rows, palette: palette)

        XCTAssertEqual(frame.width, 2)
        XCTAssertEqual(frame.height, 2)
        XCTAssertEqual(frame.pixels.count, 2 * 2 * 4)

        // Row 0 (top) = "AB" → pixel (0,0)=A, (1,0)=B.
        XCTAssertEqual([frame.pixels[0], frame.pixels[1], frame.pixels[2], frame.pixels[3]], [1, 2, 3, 255])
        XCTAssertEqual([frame.pixels[4], frame.pixels[5], frame.pixels[6], frame.pixels[7]], [4, 5, 6, 255])
        // Row 1 = "CD" → (0,1)=C, (1,1)=D.
        XCTAssertEqual([frame.pixels[8], frame.pixels[9], frame.pixels[10], frame.pixels[11]], [7, 8, 9, 255])
        XCTAssertEqual([frame.pixels[12], frame.pixels[13], frame.pixels[14], frame.pixels[15]], [10, 11, 12, 255])
    }

    func testTransparentDots() throws {
        let rows = [".X"]
        let frame = try PixelArtRenderer.render(rows: rows, palette: ["X": PixelRGBA(200, 0, 0)])
        XCTAssertEqual(frame.alpha(x: 0, y: 0), 0)
        XCTAssertEqual(frame.alpha(x: 1, y: 0), 255)
    }

    func testAlphaAtUsesTopBasedCoordinates() throws {
        let rows = ["...", ".E."]
        let frame = try PixelArtRenderer.render(rows: rows, palette: ["E": PixelRGBA(0, 0, 0)])
        XCTAssertEqual(frame.alpha(x: 1, y: 0), 0)
        XCTAssertEqual(frame.alpha(x: 1, y: 1), 255)
    }

    func testRaggedRowsThrows() {
        let rows = ["....", "..", "...."]
        XCTAssertThrowsError(try PixelArtRenderer.render(rows: rows, palette: [:])) { error in
            guard case PixelArtError.raggedRows = error else {
                return XCTFail("Expected raggedRows, got \(error)")
            }
        }
    }

    func testEmptyThrows() {
        XCTAssertThrowsError(try PixelArtRenderer.render(rows: [], palette: [:])) { error in
            guard case PixelArtError.empty = error else {
                return XCTFail("Expected empty, got \(error)")
            }
        }
    }

    func testUnknownCharacterThrows() {
        let rows = ["?."]
        XCTAssertThrowsError(try PixelArtRenderer.render(rows: rows, palette: [:])) { error in
            guard case PixelArtError.unknownCharacter = error else {
                return XCTFail("Expected unknownCharacter, got \(error)")
            }
        }
    }
}
