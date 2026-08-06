import XCTest
import DesktopPetCore

final class ScreenNavigatorTests: XCTestCase {

    private let left = ScreenRect(minX: 0, minY: 0, width: 1920, height: 1080)
    private let right = ScreenRect(minX: 1920, minY: 0, width: 1920, height: 1080)

    func testStepRightCrossesToAdjacentScreen() {
        let step = ScreenNavigator.step(currentX: 1919.5, currentY: 50,
                                        facing: .right, speed: 10,
                                        screens: [left, right])
        XCTAssertTrue(step.crossedScreen)
        XCTAssertEqual(step.x, 1920)
        XCTAssertEqual(step.y, 0) // new screen's floor
        XCTAssertEqual(step.facing, .right)
    }

    func testStepLeftCrossesToAdjacentScreen() {
        let step = ScreenNavigator.step(currentX: 1920.5, currentY: 200,
                                        facing: .left, speed: 10,
                                        screens: [left, right])
        XCTAssertTrue(step.crossedScreen)
        XCTAssertEqual(step.x, 1919.9) // enters right edge of the left screen
        XCTAssertEqual(step.y, 0)
        XCTAssertEqual(step.facing, .left)
    }

    func testTurnsAroundWhenNoNeighborToTheRight() {
        let step = ScreenNavigator.step(currentX: 1919.5, currentY: 100,
                                        facing: .right, speed: 10,
                                        screens: [left])
        XCTAssertFalse(step.crossedScreen)
        XCTAssertEqual(step.facing, .left)
        XCTAssertLessThan(step.x, 1920)
    }

    func testTurnsAroundWhenNoNeighborToTheLeft() {
        let step = ScreenNavigator.step(currentX: 0.5, currentY: 100,
                                        facing: .left, speed: 10,
                                        screens: [left])
        XCTAssertFalse(step.crossedScreen)
        XCTAssertEqual(step.facing, .right)
        XCTAssertGreaterThan(step.x, 0)
    }

    func testSmallGapStillCountsAsAdjacent() {
        let far = ScreenRect(minX: 1922, minY: 0, width: 1920, height: 1080)
        let step = ScreenNavigator.step(currentX: 1919.5, currentY: 50,
                                        facing: .right, speed: 10,
                                        screens: [left, far])
        XCTAssertTrue(step.crossedScreen)
        XCTAssertEqual(step.x, 1922)
    }

    func testLargeGapDoesNotCross() {
        let far = ScreenRect(minX: 1930, minY: 0, width: 1920, height: 1080)
        let step = ScreenNavigator.step(currentX: 1919.5, currentY: 50,
                                        facing: .right, speed: 10,
                                        screens: [left, far])
        XCTAssertFalse(step.crossedScreen)
        XCTAssertEqual(step.facing, .left)
    }

    func testPickTargetStaysWithinScreen() {
        let screens = [left, right]
        for _ in 0..<200 {
            guard let target = ScreenNavigator.pickTarget(screens: screens, margin: 40) else {
                return XCTFail("expected a target")
            }
            let screen = screens[target.screenIndex]
            XCTAssertGreaterThanOrEqual(target.x, screen.minX + 40)
            XCTAssertLessThanOrEqual(target.x, screen.maxX - 40)
            XCTAssertEqual(target.y, screen.minY)
        }
    }

    func testPickTargetReturnsNilForNoScreens() {
        XCTAssertNil(ScreenNavigator.pickTarget(screens: []))
    }
}
