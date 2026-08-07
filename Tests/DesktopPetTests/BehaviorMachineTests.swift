import XCTest
import DesktopPetCore

final class BehaviorMachineTests: XCTestCase {

    private var now: TimeInterval = 0

    override func setUp() {
        super.setUp()
        now = 0
    }

    private func makeMachine(roll: Double,
                             idleDelay: TimeInterval = 5,
                             sleepAfter: TimeInterval = 1000) -> BehaviorMachine {
        return BehaviorMachine(
            clock: { [unowned self] in self.now },
            rollChance: { roll },
            idleDecisionDelay: { idleDelay },
            sleepAfterIdle: { sleepAfter }
        )
    }

    private func advance(_ machine: BehaviorMachine, by t: TimeInterval) {
        now += t
        machine.tick()
    }

    func testStartsIdle() {
        XCTAssertEqual(makeMachine(roll: 0).state, .idle)
    }

    func testIdleWalksAfterDecisionDelay() {
        let m = makeMachine(roll: 0.05) // < 0.10 → walk
        advance(m, by: 5)
        XCTAssertEqual(m.state, .walk)
        m.completeWalk()
        XCTAssertEqual(m.state, .idle)
    }

    func testIdleStaysIdleOnHighRoll() {
        let m = makeMachine(roll: 0.98) // >= 0.94 → idle again
        advance(m, by: 5)
        XCTAssertEqual(m.state, .idle)
    }

    func testRandomlyRuns() {
        let m = makeMachine(roll: 0.15) // 0.10 <= roll < 0.18 → run
        advance(m, by: 5)
        XCTAssertEqual(m.state, .run)
        m.completeWalk()
        XCTAssertEqual(m.state, .idle)
    }

    func testRunHasSafetyDeadline() {
        let m = makeMachine(roll: 0.15)
        advance(m, by: 5)
        XCTAssertEqual(m.state, .run)
        advance(m, by: 16) // run deadline is 5...15s
        XCTAssertEqual(m.state, .idle)
    }

    func testRandomlyRolls() {
        let m = makeMachine(roll: 0.45) // 0.42...0.49 → roll
        advance(m, by: 5)
        XCTAssertEqual(m.state, .roll)
        advance(m, by: 8) // roll deadline is 4...7s
        XCTAssertEqual(m.state, .idle)
    }

    func testRandomlyPlaysWithWoolBall() {
        let m = makeMachine(roll: 0.52) // 0.49...0.56 → woolball
        advance(m, by: 5)
        XCTAssertEqual(m.state, .woolball)
        advance(m, by: 9) // woolball deadline is 5...8s
        XCTAssertEqual(m.state, .idle)
    }

    func testRandomlyCheers() {
        let m = makeMachine(roll: 0.60) // 0.56...0.63 → cheer
        advance(m, by: 5)
        XCTAssertEqual(m.state, .cheer)
        advance(m, by: 6) // cheer deadline is 3...5s
        XCTAssertEqual(m.state, .idle)
    }

    func testRandomlyLoves() {
        let m = makeMachine(roll: 0.65) // 0.63...0.70 → love
        advance(m, by: 5)
        XCTAssertEqual(m.state, .love)
        advance(m, by: 7) // love deadline is 4...6s
        XCTAssertEqual(m.state, .idle)
    }

    func testParkedForcesIdleAndSuppressesMovement() {
        let m = makeMachine(roll: 0.15) // would run
        m.setParked(true)
        XCTAssertEqual(m.state, .idle)
        advance(m, by: 10)
        XCTAssertEqual(m.state, .idle) // parked: no run/walk decisions
        m.setParked(false)
        advance(m, by: 1)
        XCTAssertEqual(m.state, .run) // resumes moving immediately
    }

    func testParkingForcesIdleFromWalk() {
        let m = makeMachine(roll: 0.05)
        advance(m, by: 5) // walk
        XCTAssertEqual(m.state, .walk)
        m.setParked(true)
        XCTAssertEqual(m.state, .idle)
    }

    func testParkedSuppressesFollow() {
        let m = makeMachine(roll: 0.10) // roll < 0.30 allows follow
        m.setParked(true)
        m.setCursor(inRange: true)
        XCTAssertEqual(m.state, .idle) // no follow while parked
        m.setParked(false)
        m.setCursor(inRange: true)
        XCTAssertEqual(m.state, .follow) // follow works again
    }

    func testTriggerActivityFromMenu() {
        let m = makeMachine(roll: 0.5)
        m.triggerActivity(.roll)
        XCTAssertEqual(m.state, .roll)
        m.triggerActivity(.drink)
        XCTAssertEqual(m.state, .drink)
    }

    func testLongIdleFallsAsleepAndClickWakesIt() {
        let m = makeMachine(roll: 0.5, idleDelay: 1000, sleepAfter: 10)
        advance(m, by: 10)
        XCTAssertEqual(m.state, .sleep)

        m.handleClick()
        XCTAssertEqual(m.state, .react)

        advance(m, by: 3) // react lasts 2.5s
        XCTAssertEqual(m.state, .idle)
    }

    func testClickReactsThenCalmsDown() {
        let m = makeMachine(roll: 0.5)
        m.handleClick()
        XCTAssertEqual(m.state, .react)
        advance(m, by: 3)
        XCTAssertEqual(m.state, .idle)
    }

    func testCursorProximityStartsAndStopsFollow() {
        let m = makeMachine(roll: 0.10) // roll < 0.30 allows follow
        m.setCursor(inRange: true)
        XCTAssertEqual(m.state, .follow)
        m.setCursor(inRange: false)
        XCTAssertEqual(m.state, .idle)
    }

    func testFollowTimesOut() {
        let m = makeMachine(roll: 0.10) // roll < 0.30 allows follow
        m.setCursor(inRange: true)
        XCTAssertEqual(m.state, .follow)
        advance(m, by: 11) // follow lasts 10s
        XCTAssertEqual(m.state, .idle)
    }

    func testWaterReminderTriggersDrink() {
        let m = makeMachine(roll: 0.5)
        m.startWaterDrink()
        XCTAssertEqual(m.state, .drink)
        advance(m, by: 7) // drink lasts 6s
        XCTAssertEqual(m.state, .idle)
    }

    func testPlayWindsDownToIdle() {
        let m = makeMachine(roll: 0.20) // 0.18...0.26 → play
        advance(m, by: 5)
        XCTAssertEqual(m.state, .play)
        advance(m, by: 5) // next decision forces play → idle
        XCTAssertEqual(m.state, .idle)
    }

    func testWalkHasSafetyDeadline() {
        let m = makeMachine(roll: 0.05)
        advance(m, by: 5)
        XCTAssertEqual(m.state, .walk)
        advance(m, by: 30) // walk deadline is 10...25s
        XCTAssertEqual(m.state, .idle)
    }

    func testDragOverridesStateAndEndsIdle() {
        let m = makeMachine(roll: 0.05)
        m.handleDragStart()
        XCTAssertEqual(m.state, .react)
        m.handleDragEnd()
        XCTAssertEqual(m.state, .idle)
    }

    func testStateChangeNotifications() {
        let m = makeMachine(roll: 0.05)
        var observed: [PetState] = []
        m.onStateChange = { observed.append($0) }
        advance(m, by: 5) // → walk
        m.completeWalk()  // → idle
        XCTAssertEqual(observed, [.walk, .idle])
    }
}
