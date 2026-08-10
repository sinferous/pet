import Foundation

/// Pure, testable state machine that decides what the pet is doing.
///
/// The machine owns no timers; it is driven by repeated `tick()` calls (the
/// app calls it every animation frame). Long delays are stored as deadlines,
/// so the machine is fully deterministic under an injected clock and can be
/// unit-tested without a run loop.
public final class BehaviorMachine {

    /// Injectable clock; defaults to process uptime (Foundation, cross-platform).
    public var clock: () -> TimeInterval

    /// Injectable chance roll (0...1). Tests stub this for determinism.
    public var rollChance: () -> Double

    /// Seconds to wait before the pet next decides to move/play. Injectable.
    public var idleDecisionDelay: () -> TimeInterval

    /// Seconds to wait before the pet falls asleep while idle. Injectable.
    public var sleepAfterIdle: () -> TimeInterval

    public var onStateChange: ((PetState) -> Void)?

    public private(set) var state: PetState = .idle

    private var nextDecisionTime: TimeInterval = 0
    private var nextSleepTime: TimeInterval = 0
    private var lastWalkTime: TimeInterval = 0
    private var stateUntil: TimeInterval = 0
    private var walkDeadline: TimeInterval = 0
    private var runDeadline: TimeInterval = 0
    private var rollDeadline: TimeInterval = 0
    private var woolballDeadline: TimeInterval = 0
    private var cheerDeadline: TimeInterval = 0
    private var loveDeadline: TimeInterval = 0

    private var cursorInRange = false
    private var dragging = false
    private var parked = false

    public init(clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
                rollChance: @escaping () -> Double = { Double.random(in: 0...1) },
                idleDecisionDelay: @escaping () -> TimeInterval = { .random(in: 5...15) },
                sleepAfterIdle: @escaping () -> TimeInterval = { .random(in: 30...60) }) {
        self.clock = clock
        self.rollChance = rollChance
        self.idleDecisionDelay = idleDecisionDelay
        self.sleepAfterIdle = sleepAfterIdle

        let t = clock()
        nextDecisionTime = t + idleDecisionDelay()
        nextSleepTime = t + sleepAfterIdle()
        lastWalkTime = t
    }

    // MARK: - External events

    /// Cursor proximity update from the app layer (`true` = within follow range).
    /// Only follows ~30% of the time for a more natural feel.
    public func setCursor(inRange: Bool) {
        guard !parked else { return } // parked: don't chase the cursor
        cursorInRange = inRange
        if inRange, state == .idle || state == .walk || state == .run {
            // Only follow the cursor ~30% of the time
            if rollChance() < 0.30 {
                enter(.follow)
            }
        } else if !inRange, state == .follow {
            enter(.idle)
        }
    }

    /// A click/pet anywhere on the pet's body.
    public func handleClick() {
        if state == .sleep {
            enter(.react) // waking up
        } else if state != .drink {
            enter(.react)
        }
    }

    public func handleDragStart() {
        dragging = true
        if state != .sleep { enter(.react) }
    }

    public func handleDragEnd() {
        dragging = false
        enter(.idle)
    }

    /// The hourly water reminder fired — the pet drinks and the app shows a bubble.
    public func startWaterDrink() {
        enter(.drink)
    }

    /// The walk target was reached (or the pet decided to stop).
    public func completeWalk() {
        if state == .walk || state == .run { enter(.idle) }
    }

    /// Parked mode: the cat stays put (idle, no walking/running/following/sleeping).
    /// Used by the menu's "Idle (Park)" item; "Poke" turns it back off.
    public func setParked(_ value: Bool) {
        guard parked != value else { return }
        parked = value
        if value {
            enter(.idle)
        } else {
            nextDecisionTime = 0 // resume: decide on the very next tick
        }
    }

    /// Manually trigger a state from the menu (mirrors the web control panel).
    public func triggerActivity(_ state: PetState) {
        if state == .drink {
            startWaterDrink()
        } else {
            enter(state)
        }
    }

    // MARK: - Frame tick

    public func tick() {
        let t = clock()
        if parked { return } // parked: no activity decisions, no sleep, stays idle

        // Force the cat to walk to a new location if 30 seconds have elapsed since the last walk/run started.
        if state != .walk && state != .run && state != .drink && (t - lastWalkTime) >= 30.0 {
            enter(.walk)
            return
        }

        // Finite-duration states expire.
        switch state {
        case .react, .drink, .sleep, .follow, .laugh, .jump:
            if t >= stateUntil {
                enter(.idle)
            }
        case .walk:
            if t >= walkDeadline {
                enter(.idle) // safety: don't walk forever
            }
        case .run:
            if t >= runDeadline {
                enter(.idle) // safety: don't run forever
            }
        case .roll:
            if t >= rollDeadline {
                enter(.idle) // safety: don't roll forever
            }
        case .woolball:
            if t >= woolballDeadline {
                enter(.idle) // safety: don't play with the ball forever
            }
        case .cheer:
            if t >= cheerDeadline {
                enter(.idle)
            }
        case .love:
            if t >= loveDeadline {
                enter(.idle)
            }
        case .idle, .play:
            break
        }

        // Idle / play → pick a new activity.
        if (state == .idle || state == .play), t >= nextDecisionTime {
            decideActivity(now: t)
        }

        // Idle long enough → fall asleep.
        if state == .idle, t >= nextSleepTime {
            enter(.sleep)
        }
    }

    // MARK: - Internals

    private func decideActivity(now t: TimeInterval) {
        nextDecisionTime = t + idleDecisionDelay()
        let roll = rollChance()
        if state == .play || state == .laugh || state == .jump {
            enter(.idle)
            return
        }
        // All 13 activities distributed more evenly
        if roll < 0.10 {
            enter(.walk)
        } else if roll < 0.18 {
            enter(.run)
        } else if roll < 0.26 {
            enter(.play)
        } else if roll < 0.34 {
            enter(.laugh)
        } else if roll < 0.42 {
            enter(.jump)
        } else if roll < 0.49 {
            enter(.roll)
        } else if roll < 0.56 {
            enter(.woolball)
        } else if roll < 0.63 {
            enter(.cheer)
        } else if roll < 0.70 {
            enter(.love)
        } else if roll < 0.76 {
            enter(.sleep)
        } else if roll < 0.82 {
            enter(.react)
        } else if roll < 0.89 {
            enter(.follow)
        } else {
            enter(.idle)
        }
    }

    private func enter(_ newState: PetState) {
        guard newState != state else { return }
        let t = clock()
        switch newState {
        case .react:
            stateUntil = t + 2.5
        case .drink:
            stateUntil = t + 6.0
        case .sleep:
            stateUntil = t + .random(in: 10...20)
        case .follow:
            stateUntil = t + 10.0
        case .play:
            stateUntil = t + .random(in: 5...9)
        case .laugh:
            stateUntil = t + .random(in: 3...5)
        case .jump:
            stateUntil = t + .random(in: 3...5)
        case .walk:
            lastWalkTime = t
            walkDeadline = t + .random(in: 10...25)
        case .run:
            lastWalkTime = t
            runDeadline = t + .random(in: 5...15)
        case .roll:
            rollDeadline = t + .random(in: 4...7)
        case .woolball:
            woolballDeadline = t + .random(in: 5...8)
        case .cheer:
            cheerDeadline = t + .random(in: 3...5)
        case .love:
            loveDeadline = t + .random(in: 4...6)
        case .idle:
            nextDecisionTime = t + idleDecisionDelay()
            nextSleepTime = t + sleepAfterIdle()
        }
        state = newState
        onStateChange?(newState)
    }
}
