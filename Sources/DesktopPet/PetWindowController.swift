import AppKit
import SpriteKit
import DesktopPetCore

/// Owns the transparent window, SpriteKit view, and wires the pet scene
/// to the behaviour state machine and screen navigation.
final class PetWindowController {

    private let window: PetWindow
    private let skView: PetSKView
    private let scene: PetScene
    private let behavior: BehaviorMachine
    private var cursorMonitor: Any?
    private var meowTimer: Timer?

    // ── Right click callback ──
    var onRightClick: (() -> Void)?

    // ── Walk/roll state ──
    private var facing: Facing = .right
    private var currentScreenIndex: Int = 0
    private var walkTarget: WalkTarget?
    private var parkWalkTarget: (x: Double, y: Double)? // stroll-to corner before parking
    private var hydrationWalkTarget: (x: Double, y: Double)?
    private var isHydrating = false
    private let walkSpeed: Double = 1.5 // points per frame (~90 px/s at 60 fps)
    private let runSpeed: Double = 4.0
    private let rollSpeed: Double = 1.5 // slow, relaxed tumbling while rolling
    private var rollDir: Double = 1

    // ── Drag state ──
    private var isDragging = false
    private var dragOffset: NSPoint = .zero
    private var baseWindowY: CGFloat = 0
    private var isManuallyParked = false

    // ── Constants ──
    private let petScale: CGFloat = 8.0   // 16px sprite → 128pt on screen
    private let petWidth: CGFloat = 128
    private let petHeight: CGFloat = 120
    private let winWidth: CGFloat = 256    // total window width to accommodate speech bubble
    private let headroom: CGFloat = 200    // vertical space above the cat for effects
    private let winHeight: CGFloat = 320   // total pet-window height (petHeight + headroom)
    private let margin: CGFloat = 60      // don't walk into corners

    init(behavior: BehaviorMachine) {
        self.behavior = behavior

        // Initial position: primary screen, bottom-center. The window is taller
        // than the cat (petHeight + headroom); the cat sprite sits at the bottom
        // of the window, so it stands on the floor while effects rise above it.
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let origin = NSPoint(x: screenFrame.midX - winWidth / 2,
                             y: screenFrame.minY)
        let frameRect = NSRect(origin: origin, size: NSSize(width: winWidth, height: winHeight))

        window = PetWindow(contentRect: frameRect)
        baseWindowY = origin.y

        skView = PetSKView(frame: NSRect(origin: .zero, size: frameRect.size))
        skView.allowsTransparency = true
        window.contentView = skView

        scene = PetScene(size: frameRect.size)
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        skView.presentScene(scene)

        // Alpha passthrough.
        skView.alphaProvider = { [weak self] pt in
            self?.scene.currentAlpha(at: pt) ?? 0
        }

        // Scene callbacks.
        scene.onTick = { [weak self] in self?.tick() }
        scene.onMouseDown = { [weak self] in self?.handleMouseDown(at: $0) }
        scene.onMouseDragged = { [weak self] in self?.handleMouseDragged(to: $0) }
        scene.onMouseUp = { [weak self] in self?.handleMouseUp() }
        scene.onCloseSpeechBubble = { [weak self] in
            guard let self else { return }
            self.isHydrating = false
            if self.isManuallyParked {
                self.park()
            } else {
                self.behavior.setParked(false)
                self.behavior.triggerActivity(.run) // run somewhere else immediately!
            }
        }
        scene.onRightClick = { [weak self] in self?.onRightClick?() }

        // Identify the current screen index.
        let screens = ScreenAdapter.screenRects()
        currentScreenIndex = ScreenAdapter.screenIndex(
            containing: NSPoint(x: window.frame.midX, y: window.frame.minY),
            in: screens) ?? 0

        // Wire behaviour state changes to animation.
        behavior.onStateChange = { [weak self] state in
            guard let self else { return }
            
            if state == .drink {
                if !self.isHydrating {
                    self.triggerWaterHydrationFlow()
                    return
                }
                self.isHydrating = false
            }
            
            let anim = state.animation
            let frames = PixelPetGenerator.frames(for: anim)
            self.scene.play(animation: anim, frames: frames)

            if state == .walk || state == .run {
                self.startWalk()
            } else if state == .react {
                // Silenced meow/purr bubbles on click
            }

            // Celebration effects.
            if state == .cheer {
                self.scene.spawnConfettiBurst(count: 48)
            } else if state == .love {
                self.scene.spawnHeartEmojis(count: 6)
            } else if state == .woolball {
                self.scene.startWoolBall()
            } else {
                self.scene.stopWoolBall()
            }
        }

        // Kick off the initial idle animation.
        let idleFrames = PixelPetGenerator.frames(for: .idle)
        scene.play(animation: .idle, frames: idleFrames)

        // Install global mouse-move monitor to detect cursor proximity.
        cursorMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            guard let self else { return }
            let mouseLoc = NSEvent.mouseLocation
            let petRect = self.window.frame.insetBy(dx: -40, dy: -40)
            let inRange = petRect.contains(mouseLoc)
            self.behavior.setCursor(inRange: inRange)
        }

        // Random background meows timer removed to keep the cat quiet as requested.
    }

    /// Triggered from the menu "Say" item — shows "Sathya Sathya" bubble.
    func say() {
        scene.showSayBubble()
    }

    deinit {
        if let cursorMonitor { NSEvent.removeMonitor(cursorMonitor) }
        meowTimer?.invalidate()
    }

    func show() {
        window.orderFrontRegardless()
    }

    func setHidden(_ hidden: Bool) {
        if hidden {
            window.orderOut(nil)
        } else {
            window.orderFrontRegardless()
        }
    }

    // MARK: - Frame tick (60 Hz from PetScene)

    private func tick() {
        defer {
            updateIgnoreMouseEvents()
        }

        if scene.hasActiveSpeechBubble {
            // Keep the cat stationary while a speech bubble is active
            let targetY = baseWindowY
            if abs(window.frame.origin.y - targetY) > 0.1 {
                window.setFrameOrigin(NSPoint(x: window.frame.origin.x, y: targetY))
            }
            return
        }

        behavior.tick()
        scene.cheerActive = (behavior.state == .cheer)

        if let target = hydrationWalkTarget {
            advanceHydrationWalk(to: target)
        } else if let target = parkWalkTarget {
            advanceParkWalk(to: target)
        } else {
            switch behavior.state {
            case .walk:
                advanceWalk(speed: walkSpeed)
            case .run:
                advanceWalk(speed: runSpeed)
            case .roll:
                advanceRoll()
            case .follow:
                advanceFollow()
            default:
                break
            }
        }

        // Apply vertical jumping offset on screen coordinates (cheer reuses the jump bounce)
        var yOffset: CGFloat = 0
        if behavior.state == .jump || behavior.state == .cheer {
            let idx = scene.frameIndex
            if idx == 1 {
                yOffset = 70
            } else if idx == 2 {
                yOffset = 35
            }
        }
        let targetY = baseWindowY + yOffset
        if abs(window.frame.origin.y - targetY) > 0.1 {
            window.setFrameOrigin(NSPoint(x: window.frame.origin.x, y: targetY))
        }
    }

    private func updateIgnoreMouseEvents() {
        // If currently dragging or any mouse button is pressed, do not ignore mouse events.
        if isDragging || NSEvent.pressedMouseButtons != 0 {
            window.ignoresMouseEvents = false
            return
        }

        let mouseLoc = NSEvent.mouseLocation // screen coordinates
        let windowRect = window.frame
        if windowRect.contains(mouseLoc) {
            let winPt = NSPoint(x: mouseLoc.x - windowRect.origin.x,
                                y: mouseLoc.y - windowRect.origin.y)
            let interactive = scene.isPointInteractive(at: winPt)
            window.ignoresMouseEvents = !interactive
        } else {
            window.ignoresMouseEvents = true
        }
    }

    // MARK: - Walking

    private func startWalk() {
        let screens = ScreenAdapter.screenRects()
        guard !screens.isEmpty else { return }
        guard let target = ScreenNavigator.pickTarget(screens: screens, margin: Double(margin), winWidth: Double(winWidth), petHeight: Double(petHeight)) else { return }
        walkTarget = target
    }

    private func advanceWalk(speed: Double) {
        guard let target = walkTarget else { return }
        let screens = ScreenAdapter.screenRects()
        guard !screens.isEmpty else { return }

        let curX = Double(window.frame.origin.x)
        let curY = Double(window.frame.origin.y)
        let step = ScreenNavigator.step(currentX: curX, currentY: curY,
                                   targetX: target.x, targetY: target.y,
                                   facing: facing, speed: speed,
                                   screens: screens,
                                   width: Double(winWidth))
        facing = step.facing
        scene.setFacing(step.facing)
        window.setFrameOrigin(NSPoint(x: step.x, y: step.y))
        baseWindowY = CGFloat(step.y)

        if step.crossedScreen, let idx = ScreenAdapter.screenIndex(
            containing: NSPoint(x: step.x + Double(winWidth) / 2, y: step.y),
            in: screens) {
            currentScreenIndex = idx
        }

        // Arrived?
        let dx = step.x - target.x
        let dy = step.y - target.y
        let dist = (dx * dx + dy * dy).squareRoot()
        if dist < speed * 1.5 {
            walkTarget = nil
            behavior.completeWalk()
        }
    }

    /// Tumble horizontally across the display, bouncing off the edges.
    private func advanceRoll() {
        let screens = ScreenAdapter.screenRects()
        guard !screens.isEmpty else { return }
        let curY = Double(window.frame.origin.y)
        guard let screen = screens.first(where: { $0.contains(x: Double(window.frame.origin.x), y: curY) }) else { return }

        var x = Double(window.frame.origin.x) + rollDir * rollSpeed
        if x <= screen.minX {
            x = screen.minX + 0.1
            rollDir = 1
        } else if x >= screen.maxX - Double(winWidth) {
            x = screen.maxX - Double(winWidth) - 0.1
            rollDir = -1
        }
        facing = rollDir > 0 ? .right : .left
        scene.setFacing(facing)
        window.setFrameOrigin(NSPoint(x: x, y: curY))
    }

    // MARK: - Parking (Idle / Poke)

    /// "Idle (Park)": stroll the cat to the bottom-left corner of the primary
    /// screen, then freeze it there. The state machine is parked, so the cat
    /// does not wander, follow, or fall asleep.
    func park() {
        guard let screen = NSScreen.main else { return }
        parkWalkTarget = (x: Double(screen.frame.minX) + 12, y: Double(screen.frame.minY))
        behavior.setParked(true)
        walkTarget = nil
        isManuallyParked = true
        let walkFrames = PixelPetGenerator.frames(for: .walk)
        scene.play(animation: .walk, frames: walkFrames)
    }

    /// "Poke": clear the parked state so the cat starts moving normally again.
    func unpark() {
        parkWalkTarget = nil
        isManuallyParked = false
        behavior.setParked(false)
    }

    /// Steers the cat diagonally toward the park corner. The machine is frozen
    /// while parked, so this stroll is app-driven (mirrors the web preview).
    private func advanceParkWalk(to target: (x: Double, y: Double)) {
        let curX = Double(window.frame.origin.x)
        let curY = Double(window.frame.origin.y)
        let dx = target.x - curX
        let dy = target.y - curY
        let len = (dx * dx + dy * dy).squareRoot()
        if len > 0 {
            let s = min(walkSpeed, len)
            window.setFrameOrigin(NSPoint(x: curX + dx / len * s,
                                          y: curY + dy / len * s))
            facing = dx >= 0 ? .right : .left
            scene.setFacing(facing)
            baseWindowY = window.frame.origin.y
        }
        if len < walkSpeed * 1.5 {
            parkWalkTarget = nil // arrived: park in place
            baseWindowY = window.frame.origin.y
            let idleFrames = PixelPetGenerator.frames(for: .idle)
            scene.play(animation: .idle, frames: idleFrames)
        }
    }

    // MARK: - Following the cursor

    private func advanceFollow() {
        let mouse = NSEvent.mouseLocation
        let targetX = mouse.x - petWidth / 2
        let dx = targetX - window.frame.origin.x
        let maxStep = CGFloat(walkSpeed * 1.5)
        let clampedDx = max(-maxStep, min(maxStep, dx))

        if abs(dx) > 2 {
            facing = dx > 0 ? .right : .left
            scene.setFacing(facing)
        }

        window.setFrameOrigin(NSPoint(x: window.frame.origin.x + clampedDx,
                                      y: window.frame.origin.y))
        baseWindowY = window.frame.origin.y
    }

    private func advanceHydrationWalk(to target: (x: Double, y: Double)) {
        let curX = Double(window.frame.origin.x)
        let curY = Double(window.frame.origin.y)
        let dx = target.x - curX
        let dy = target.y - curY
        let len = (dx * dx + dy * dy).squareRoot()
        if len > 0 {
            let s = min(runSpeed, len)
            window.setFrameOrigin(NSPoint(x: curX + dx / len * s,
                                          y: curY + dy / len * s))
            facing = dx >= 0 ? .right : .left
            scene.setFacing(facing)
            baseWindowY = window.frame.origin.y
        }
        if len < runSpeed * 1.5 {
            hydrationWalkTarget = nil
            isHydrating = true
            if scene.pendingCustomMessage != nil {
                behavior.triggerActivity(.cheer)
            } else {
                behavior.triggerActivity(.drink)
            }
        }
    }

    func triggerWaterHydrationFlow() {
        let screens = ScreenAdapter.screenRects()
        guard !screens.isEmpty else { return }
        let s = screens[0]
        
        let targetX = s.minX + (s.width - Double(winWidth)) / 2
        let targetY = s.minY + (s.height - Double(winHeight)) / 2 - 100
        
        hydrationWalkTarget = (x: targetX, y: targetY)
        
        let runFrames = PixelPetGenerator.frames(for: .run)
        scene.play(animation: .run, frames: runFrames)
        behavior.setParked(true)
    }

    func triggerCustomReminder(message: String) {
        scene.pendingCustomMessage = message
        
        let screens = ScreenAdapter.screenRects()
        guard !screens.isEmpty else { return }
        let s = screens[0]
        
        let targetX = s.minX + (s.width - Double(winWidth)) / 2
        let targetY = s.minY + (s.height - Double(winHeight)) / 2 - 100
        
        hydrationWalkTarget = (x: targetX, y: targetY)
        
        let runFrames = PixelPetGenerator.frames(for: .run)
        scene.play(animation: .run, frames: runFrames)
        behavior.setParked(true)
    }

    // MARK: - Click / Drag

    private func handleMouseDown(at scenePoint: NSPoint) {
        let mouseLoc = NSEvent.mouseLocation
        dragOffset = NSPoint(x: mouseLoc.x - window.frame.origin.x,
                             y: mouseLoc.y - window.frame.origin.y)
    }

    private func handleMouseDragged(to scenePoint: NSPoint) {
        if !isDragging {
            isDragging = true
            behavior.handleDragStart()
        }
        let mouseLoc = NSEvent.mouseLocation
        var newX = mouseLoc.x - dragOffset.x
        var newY = mouseLoc.y - dragOffset.y

        // Clamp to screen bounds to prevent dragging off-screen
        let screens = ScreenAdapter.screenRects()
        if !screens.isEmpty {
            let idx = ScreenAdapter.screenIndex(containing: mouseLoc, in: screens) ?? 0
            if idx < screens.count {
                let s = screens[idx]
                newX = max(CGFloat(s.minX), min(CGFloat(s.maxX) - winWidth, newX))
                newY = max(CGFloat(s.minY), min(CGFloat(s.maxY) - winHeight, newY))
            }
        }
        window.setFrameOrigin(NSPoint(x: newX, y: newY))
    }

    private func handleMouseUp() {
        if isDragging {
            isDragging = false
            behavior.handleDragEnd()
            // Re-identify screen after drag.
            let screens = ScreenAdapter.screenRects()
            let idx = ScreenAdapter.screenIndex(
                containing: NSPoint(x: window.frame.midX, y: window.frame.minY),
                in: screens) ?? 0
            currentScreenIndex = idx
            baseWindowY = window.frame.origin.y
            
            if isManuallyParked {
                park()
            }
        } else {
            behavior.handleClick()
        }
    }
}
