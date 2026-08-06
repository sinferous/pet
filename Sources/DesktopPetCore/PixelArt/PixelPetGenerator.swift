import Foundation

/// The set of animations the pet can play. Each maps to one or more frames.
public enum PetAnimation: String, CaseIterable, Sendable {
    case idle
    case walk
    case run
    case sleep
    case drink
    case play
    case react
    case follow
    case laugh
    case jump
    case roll
    case love
}

/// Procedural pixel-art generator for the default pet — a round, symmetric
/// blob-cat with ears, a little face, paws and a curled tail.
///
/// Everything is drawn from math (ellipses, outlines, fixed face pixels), so
/// the silhouette is guaranteed symmetric and every frame is the same size.
/// The output is plain string maps (`[String]`, top row first) that flow
/// through `PixelArtRenderer` like any hand-authored art — the generator just
/// produces frames that are internally consistent.
public enum PixelPetGenerator {

    public static let width = 16
    public static let height = 15

    /// Frames (top-row-first string maps) for an animation.
    public static func frames(for animation: PetAnimation) -> [[String]] {
        switch animation {
        case .idle:    return idleFrames()
        case .walk:    return walkFrames()
        case .run:     return runFrames()
        case .sleep:   return sleepFrames()
        case .drink:   return drinkFrames()
        case .play:    return playFrames()
        case .react:   return reactFrames()
        case .follow:  return walkFrames() // walking toward the cursor
        case .laugh:   return idleFrames() // Fallback for procedural engine
        case .jump:    return idleFrames() // Fallback for procedural engine
        case .roll:    return rollFrames()
        case .love:    return loveFrames()
        }
    }

    // MARK: - Frame recipes

    private static func idleFrames() -> [[String]] {
        // bob: 0, up, 0, up-with-blink — a breathing idle with a blink.
        return [
            render(bob: 0, feet: (0, 0), tail: 0, eyes: .open),
            render(bob: 1, feet: (0, 0), tail: 1, eyes: .open),
            render(bob: 0, feet: (0, 0), tail: 0, eyes: .open),
            render(bob: 1, feet: (0, 0), tail: 1, eyes: .closed),
        ]
    }

    private static func walkFrames() -> [[String]] {
        // A little hop-skip: alternating feet with a body bounce.
        return [
            render(bob: 0, feet: (0, 0), tail: 0, eyes: .open),
            render(bob: 1, feet: (1, 0), tail: 1, eyes: .open),
            render(bob: 0, feet: (0, 0), tail: 0, eyes: .open),
            render(bob: 1, feet: (0, 1), tail: 2, eyes: .open),
        ]
    }

    private static func sleepFrames() -> [[String]] {
        // Curled up, lower and flatter, eyes closed; breathing bob.
        return [
            render(bob: 0, feet: (0, 0), tail: 0, eyes: .closed, curled: true),
            render(bob: 1, feet: (0, 0), tail: 0, eyes: .closed, curled: true),
        ]
    }

    private static func drinkFrames() -> [[String]] {
        // Pet brings a little green bottle up to its mouth, tips its head back.
        return [
            render(bob: 0, feet: (0, 0), tail: 0, eyes: .open),
            render(bob: 0, feet: (0, 0), tail: 0, eyes: .open, bottle: .raised),
            render(bob: 0, feet: (0, 0), tail: 0, eyes: .open, bottle: .drinking, headTilt: 1),
            render(bob: 0, feet: (0, 0), tail: 0, eyes: .open, bottle: .lowered),
        ]
    }

    private static func playFrames() -> [[String]] {
        // Joyful hops.
        return [
            render(bob: 0, feet: (0, 0), tail: 0, eyes: .happy),
            render(bob: 2, feet: (1, 1), tail: 1, eyes: .happy),
            render(bob: 0, feet: (0, 0), tail: 2, eyes: .happy),
        ]
    }

    private static func reactFrames() -> [[String]] {
        // Petted: happy eyes, big blush, tiny bounce.
        return [
            render(bob: 0, feet: (0, 0), tail: 1, eyes: .happy, happyBlush: true),
            render(bob: 1, feet: (0, 0), tail: 2, eyes: .happy, happyBlush: true),
        ]
    }

    private static func runFrames() -> [[String]] {
        // A fast bouncy gait with the tail streaming out behind.
        return [
            render(bob: 2, feet: (0, 1), tail: 2, eyes: .open),
            render(bob: 3, feet: (1, 0), tail: 0, eyes: .open),
            render(bob: 2, feet: (0, 1), tail: 2, eyes: .open),
            render(bob: 3, feet: (1, 0), tail: 0, eyes: .open),
        ]
    }

    private static func rollFrames() -> [[String]] {
        // A barrel roll: the blob squashes wide, then stretches tall, then squashes
        // again — reads as tumbling for the procedural fallback (the bundled app
        // uses the real 90°-rotation SVG roll frames instead).
        return [
            render(bob: 0, feet: (0, 0), tail: 0, eyes: .happy, bodyRx: 6.0, bodyRy: 4.7, bodyCy: 6.2),
            render(bob: 0, feet: (0, 0), tail: 1, eyes: .happy, bodyRx: 6.6, bodyRy: 3.4, bodyCy: 6.0),
            render(bob: 0, feet: (0, 0), tail: 2, eyes: .happy, bodyRx: 3.8, bodyRy: 6.2, bodyCy: 6.4),
            render(bob: 0, feet: (0, 0), tail: 1, eyes: .happy, bodyRx: 6.6, bodyRy: 3.4, bodyCy: 6.0),
        ]
    }

    private static func loveFrames() -> [[String]] {
        // Heart-shaped eyes + heavy blush, gentle bob.
        return [
            render(bob: 0, feet: (0, 0), tail: 1, eyes: .heart, happyBlush: true),
            render(bob: 1, feet: (0, 0), tail: 2, eyes: .heart, happyBlush: true),
        ]
    }

    // MARK: - Rendering primitives

    private struct Grid {
        var cells: [[Character]]

        init() {
            cells = Array(repeating: Array(repeating: Character("."), count: PixelPetGenerator.width),
                          count: PixelPetGenerator.height)
        }

        mutating func set(_ x: Int, _ y: Int, _ c: Character) {
            if x >= 0, x < PixelPetGenerator.width, y >= 0, y < PixelPetGenerator.height {
                cells[y][x] = c
            }
        }

        /// Converts any non-transparent pixel adjacent to empty space into the
        /// outline color, giving the whole silhouette a clean border.
        mutating func outlinePass() {
            var next = cells
            for y in 0..<PixelPetGenerator.height {
                for x in 0..<PixelPetGenerator.width {
                    guard cells[y][x] != "." else { continue }
                    let neighbours = [
                        (x, y + 1), (x, y - 1), (x + 1, y), (x - 1, y)
                    ]
                    let touchesEmpty = neighbours.contains { nx, ny in
                        nx < 0 || nx >= PixelPetGenerator.width
                            || ny < 0 || ny >= PixelPetGenerator.height
                            || cells[ny][nx] == "."
                    }
                    if touchesEmpty { next[y][x] = "O" }
                }
            }
            cells = next
        }

        /// Top row first, matching string-art authoring order.
        func rows() -> [String] {
            (0..<PixelPetGenerator.height).reversed().map { String(cells[$0]) }
        }
    }

    private enum EyeStyle {
        case open, closed, happy, heart
    }

    private enum BottlePose {
        case none, raised, drinking, lowered
    }

    private struct FrameSpec {
        var bob: Int = 0
        var feet = (left: 0, right: 0)
        var tail: Int = 0
        var eyes: EyeStyle = .open
        var curled = false
        var bottle: BottlePose = .none
        var headTilt = 0
        var happyBlush = false
        var bodyRx: Double? = nil
        var bodyRy: Double? = nil
        var bodyCy: Double? = nil
    }

    private static func render(bob: Int = 0,
                               feet: (left: Int, right: Int) = (0, 0),
                               tail: Int = 0,
                               eyes: EyeStyle = .open,
                               curled: Bool = false,
                               bottle: BottlePose = .none,
                               headTilt: Int = 0,
                               happyBlush: Bool = false,
                               bodyRx: Double? = nil,
                               bodyRy: Double? = nil,
                               bodyCy: Double? = nil) -> [String] {
        var grid = Grid()
        let dy = Double(bob)

        if curled {
            drawEllipse(&grid, cx: 8, cy: 4.6 + dy, rx: 6.2, ry: 4.0, fill: "B")
            drawEllipse(&grid, cx: 4.5, cy: 10.6 + dy, rx: 1.6, ry: 2.2, fill: "B")
            drawEllipse(&grid, cx: 11.5, cy: 10.6 + dy, rx: 1.6, ry: 2.2, fill: "B")
        } else {
            drawEllipse(&grid, cx: 8, cy: bodyCy ?? (6.2 + dy), rx: bodyRx ?? 6.0, ry: bodyRy ?? 4.7, fill: "B")
            drawEllipse(&grid, cx: 4.5, cy: 11.8 + dy, rx: 1.7, ry: 2.7, fill: "B")
            drawEllipse(&grid, cx: 11.5, cy: 11.8 + dy, rx: 1.7, ry: 2.7, fill: "B")
        }

        drawInnerEars(&grid, cx1: 4.5, cy1: 11.8 + dy, cx2: 11.5, cy2: 11.8 + dy)
        drawFeet(&grid, left: feet.left, right: feet.right)
        drawTail(&grid, phase: tail)

        grid.outlinePass()

        drawFace(&grid, eyes: eyes, headTilt: headTilt, happyBlush: happyBlush)

        if bottle != .none { drawBottle(&grid, pose: bottle) }

        return grid.rows()
    }

    private static func drawEllipse(_ grid: inout Grid, cx: Double, cy: Double,
                                    rx: Double, ry: Double,
                                    fill: Character, outlineThreshold: Double = 0.8) {
        for y in 0..<height {
            for x in 0..<width {
                let dx = (Double(x) + 0.5 - cx) / rx
                let dy = (Double(y) + 0.5 - cy) / ry
                let d = dx * dx + dy * dy
                if d <= 1.0 {
                    grid.set(x, y, d >= outlineThreshold ? "O" : fill)
                }
            }
        }
    }

    private static func drawInnerEars(_ grid: inout Grid, cx1: Double, cy1: Double,
                                      cx2: Double, cy2: Double) {
        // Pink patches near the top-center of each ear.
        for y in 0..<height {
            for x in 0..<width {
                let a = ((Double(x) + 0.5 - cx1) / 1.2) * ((Double(x) + 0.5 - cx1) / 1.2)
                    + ((Double(y) + 0.5 - cy1) / 1.7) * ((Double(y) + 0.5 - cy1) / 1.7)
                let b = ((Double(x) + 0.5 - cx2) / 1.2) * ((Double(x) + 0.5 - cx2) / 1.2)
                    + ((Double(y) + 0.5 - cy2) / 1.7) * ((Double(y) + 0.5 - cy2) / 1.7)
                let earTop = cy1 + 0.2
                if (a <= 0.55 || b <= 0.55), Double(y) + 0.5 >= earTop {
                    grid.set(x, y, "P")
                }
            }
        }
    }

    private static func drawFeet(_ grid: inout Grid, left: Int, right: Int) {
        drawEllipse(&grid, cx: 5.5, cy: 0.6 + Double(left), rx: 1.5, ry: 1.0, fill: "B")
        drawEllipse(&grid, cx: 10.5, cy: 0.6 + Double(right), rx: 1.5, ry: 1.0, fill: "B")
    }

    private static func drawTail(_ grid: inout Grid, phase: Int) {
        // A small curl at the bottom-right; `phase` wags it a little.
        switch phase % 3 {
        case 1:
            for (x, y) in [(12, 1), (13, 1), (14, 1), (14, 2), (14, 3), (13, 4), (14, 4), (13, 3)] {
                grid.set(x, y, "T")
            }
        case 2:
            for (x, y) in [(12, 1), (13, 1), (14, 1), (14, 2), (13, 2), (13, 3)] {
                grid.set(x, y, "T")
            }
        default:
            for (x, y) in [(12, 1), (13, 1), (14, 1), (14, 2), (14, 3), (13, 3)] {
                grid.set(x, y, "T")
            }
        }
        grid.set(12, 1, "S")
        grid.set(13, 2, "S")
    }

    private static func drawFace(_ grid: inout Grid, eyes: EyeStyle,
                                 headTilt: Int, happyBlush: Bool) {
        let tilt = headTilt // +1 = head tilted back (eyes/nose drop by 1)
        let eyeY = 8 - tilt

        switch eyes {
        case .open:
            grid.set(5, eyeY, "E"); grid.set(6, eyeY, "E")
            grid.set(10, eyeY, "E"); grid.set(11, eyeY, "E")
        case .closed:
            for x in 4...6 { grid.set(x, eyeY, "E") }
            for x in 10...12 { grid.set(x, eyeY, "E") }
        case .happy:
            // "^ ^" — pixels angled up.
            grid.set(5, eyeY + 1, "E"); grid.set(6, eyeY, "E")
            grid.set(10, eyeY + 1, "E"); grid.set(11, eyeY, "E")
        case .heart:
            // Tiny heart eyes: a 3×3 heart at each eye.
            for y in (eyeY - 1)...(eyeY + 1) {
                grid.set(4, y, "E"); grid.set(11, y, "E")
            }
            for x in 5...6 { grid.set(x, eyeY, "E"); grid.set(x, eyeY + 1, "E") }
            for x in 9...10 { grid.set(x, eyeY, "E"); grid.set(x, eyeY + 1, "E") }
        }

        grid.set(7, 6 - tilt, "N")
        grid.set(8, 6 - tilt, "N")

        // Mouth: a little "ω".
        grid.set(6, 4, "W"); grid.set(7, 5, "W"); grid.set(8, 5, "W"); grid.set(9, 4, "W")

        // Blush.
        grid.set(3, 7, "P"); grid.set(12, 7, "P")
        if happyBlush {
            grid.set(4, 6, "P"); grid.set(11, 6, "P")
        }
    }

    private static func drawBottle(_ grid: inout Grid, pose: BottlePose) {
        switch pose {
        case .raised:
            // Bottle held at the pet's side.
            for (x, y) in [(10, 3), (11, 3), (10, 4), (11, 4), (10, 5), (11, 5)] {
                grid.set(x, y, "G")
            }
            grid.set(11, 3, "L")
        case .drinking:
            // Bottle up at the mouth.
            for (x, y) in [(6, 3), (7, 3), (6, 4), (7, 4), (6, 5), (7, 5)] {
                grid.set(x, y, "G")
            }
            grid.set(7, 3, "L")
        case .lowered:
            for (x, y) in [(11, 2), (12, 2), (11, 3), (12, 3)] {
                grid.set(x, y, "G")
            }
            grid.set(12, 2, "L")
        case .none:
            break
        }
    }
}
