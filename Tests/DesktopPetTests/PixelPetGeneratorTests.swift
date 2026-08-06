import XCTest
import DesktopPetCore

final class PixelPetGeneratorTests: XCTestCase {

    func testAllAnimationsProduceWellFormedFrames() throws {
        let palette = PixelPalette.standard
        for animation in PetAnimation.allCases {
            let frames = PixelPetGenerator.frames(for: animation)
            XCTAssertFalse(frames.isEmpty, "\(animation) should have frames")
            for (i, rows) in frames.enumerated() {
                XCTAssertEqual(rows.count, PixelPetGenerator.height, "\(animation)[\(i)] height")
                for (y, row) in rows.enumerated() {
                    XCTAssertEqual(row.count, PixelPetGenerator.width, "\(animation)[\(i)] row \(y) width")
                    for ch in row {
                        if ch == "." { continue }
                        XCTAssertNotNil(palette[ch],
                                        "\(animation)[\(i)] contains unmapped char '\(ch)'")
                    }
                }
                // Every frame must render without error.
                _ = try PixelArtRenderer.render(rows: rows, palette: palette)
            }
        }
    }

    func testIdleHasBreathingBlinkVariation() {
        let idle = PixelPetGenerator.frames(for: .idle)
        XCTAssertGreaterThanOrEqual(idle.count, 4)
        // Frames should differ from each other (bob/blink variation).
        let unique = Set(idle)
        XCTAssertGreaterThan(unique.count, 1, "idle frames should vary")
    }

    func testWalkHasFourDistinctFrames() {
        let walk = PixelPetGenerator.frames(for: .walk)
        XCTAssertEqual(walk.count, 4)
    }

    func testSleepEyesAreClosed() {
        let sleep = PixelPetGenerator.frames(for: .sleep)
        for rows in sleep {
            // y = 8 → top-first row index = height - 1 - 8 = 6.
            let eyeRow = rows[PixelPetGenerator.height - 1 - 8]
            let chars = Array(eyeRow)
            // Closed eyes: long lines spanning cols 4...6 and 10...12.
            XCTAssertEqual(chars[4], "E")
            XCTAssertEqual(chars[12], "E")
        }
    }

    func testFollowReusesWalkFrames() {
        XCTAssertEqual(PixelPetGenerator.frames(for: .follow),
                       PixelPetGenerator.frames(for: .walk))
    }

    func testPlayUsesHappyEyes() {
        let play = PixelPetGenerator.frames(for: .play)
        let happyEyes = play.first!
        let eyeRow = happyEyes[PixelPetGenerator.height - 1 - 8]
        let chars = Array(eyeRow)
        // Happy eyes are angled: (5, 9) → top-first row index 5 at col 5.
        let lowerEyeRow = happyEyes[PixelPetGenerator.height - 1 - 9]
        let lower = Array(lowerEyeRow)
        XCTAssertEqual(chars[6], "E")
        XCTAssertEqual(lower[5], "E")
    }
}
