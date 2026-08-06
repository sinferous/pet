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
    private var stateUntil: TimeInterval = 0
    private var walkDeadline: TimeInterval = 0
    private var runDeadline: TimeInterval = 0
    private var rollDeadline: TimeInterval = 0
    private var woolballDeadline: TimeInterval = 0
    private var cheerDeadline: TimeInterval = 0
    private var loveDeadline: TimeInterval = 0

    private var cursorInRange = false
    private var dragging = false

    public init(clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
                rollChance: @escaping () -> Double = { Double.random(in: 0...1) },
                idleDecisionDelay: @escaping () -> TimeInterval = { .random(in: 20...60) },
                sleepAfterIdle: @escaping () -> TimeInterval = { .random(in: 90...150) }) {
        self.clock = clock
        self.rollChance = rollChance
        self.idleDecisionDelay = idleDecisionDelay
        self.sleepAfterIdle = sleepAfterIdle

        let t = clock()
        nextDecisionTime = t + idleDecisionDelay()
        nextSleepTime = t + sleepAfterIdle()
    }

    // MARK: - External events

    /// Cursor proximity update from the app layer (`true` = within follow range).
    public func setCursor(inRange: Bool) {
        cursorInRange = inRange
        if inRange, state == .idle || state == .walk || state == .run {
            enter(.follow)
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

    // MARK: - Frame tick

    public func tick() {
        let t = clock()

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
        if roll < 0.20 {
            enter(.run)
        } else if roll < 0.55 {
            enter(.walk)
        } else if roll < 0.70 {
            enter(.play)
        } else if roll < 0.80 {
            enter(.laugh)
        } else if roll < 0.90 {
            enter(.jump)
        } else if roll < 0.93 {
            enter(.roll)       // tumble across the screen
        } else if roll < 0.96 {
            enter(.woolball)   // play with the wool ball
        } else if roll < 0.98 {
            enter(.cheer)      // jump + confetti
        } else if roll < 0.995 {
            enter(.love)       // heart eyes + heart emoji
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
            stateUntil = t + .random(in: 20...40)
        case .follow:
            stateUntil = t + 10.0
        case .play:
            stateUntil = t + .random(in: 5...9)
        case .laugh:
            stateUntil = t + .random(in: 3...5)
        case .jump:
            stateUntil = t + .random(in: 3...5)
        case .walk:
            walkDeadline = t + .random(in: 10...25)
        case .run:
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
