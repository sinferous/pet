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

    // ── Walk/roll state ──
    private var facing: Facing = .right
    private var currentScreenIndex: Int = 0
    private var walkTarget: WalkTarget?
    private let walkSpeed: Double = 1.5 // points per frame (~90 px/s at 60 fps)
    private let runSpeed: Double = 4.0
    private let rollSpeed: Double = 1.5 // slow, relaxed tumbling while rolling
    private var rollDir: Double = 1

    // ── Drag state ──
    private var isDragging = false
    private var dragOffset: NSPoint = .zero
    private var baseWindowY: CGFloat = 0

    // ── Constants ──
    private let petScale: CGFloat = 8.0   // 16px sprite → 128pt on screen
    private let petWidth: CGFloat = 128
    private let petHeight: CGFloat = 120
    private let headroom: CGFloat = 200    // vertical space above the cat for effects
    private let winHeight: CGFloat = 320   // total pet-window height (petHeight + headroom)
    private let margin: CGFloat = 60      // don't walk into corners

    init(behavior: BehaviorMachine) {
        self.behavior = behavior

        // Initial position: primary screen, bottom-center. The window is taller
        // than the cat (petHeight + headroom); the cat sprite sits at the bottom
        // of the window, so it stands on the floor while effects rise above it.
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let origin = NSPoint(x: screenFrame.midX - petWidth / 2,
                             y: screenFrame.minY)
        let frameRect = NSRect(origin: origin, size: NSSize(width: petWidth, height: winHeight))

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

        // Identify the current screen index.
        let screens = ScreenAdapter.screenRects()
        currentScreenIndex = ScreenAdapter.screenIndex(
            containing: NSPoint(x: window.frame.midX, y: window.frame.minY),
            in: screens) ?? 0

        // Wire behaviour state changes to animation.
        behavior.onStateChange = { [weak self] state in
            guard let self else { return }
            let anim = state.animation
            let frames = PixelPetGenerator.frames(for: anim)
            self.scene.play(animation: anim, frames: frames)

            if state == .walk || state == .run {
                self.startWalk()
            } else if state == .react {
                self.scene.showRandomReactSpeechBubble()
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

        // Setup random meowing timer every 10 seconds (35% chance if idle/walking)
        self.meowTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.behavior.state == .idle || self.behavior.state == .walk {
                if Double.random(in: 0...1) < 0.35 {
                    self.scene.showRandomMeowSpeechBubble()
                }
            }
        }
    }

    deinit {
        if let cursorMonitor { NSEvent.removeMonitor(cursorMonitor) }
        meowTimer?.invalidate()
    }

    func show() {
        window.orderFrontRegardless()
    }

    // MARK: - Frame tick (60 Hz from PetScene)

    private func tick() {
        behavior.tick()
        scene.cheerActive = (behavior.state == .cheer)

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

    // MARK: - Walking

    private func startWalk() {
        let screens = ScreenAdapter.screenRects()
        guard !screens.isEmpty else { return }
        guard let target = ScreenNavigator.pickTarget(screens: screens, margin: Double(margin)) else { return }
        walkTarget = target
    }

    private func advanceWalk(speed: Double) {
        guard let target = walkTarget else { return }
        let screens = ScreenAdapter.screenRects()
        guard !screens.isEmpty else { return }

        let curX = Double(window.frame.origin.x)
        let curY = Double(window.frame.origin.y)
        let step = ScreenNavigator.step(currentX: curX, currentY: curY,
                                  facing: facing, speed: speed,
                                  screens: screens)
        facing = step.facing
        scene.setFacing(step.facing)
        window.setFrameOrigin(NSPoint(x: step.x, y: step.y))
        baseWindowY = CGFloat(step.y)

        if step.crossedScreen, let idx = ScreenAdapter.screenIndex(
            containing: NSPoint(x: step.x + Double(petWidth) / 2, y: step.y),
            in: screens) {
            currentScreenIndex = idx
        }

        // Arrived?
        if abs(step.x - Double(target.x)) < speed * 2 {
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
        } else if x >= screen.maxX - Double(petWidth) {
            x = screen.maxX - Double(petWidth) - 0.1
            rollDir = -1
        }
        facing = rollDir > 0 ? .right : .left
        scene.setFacing(facing)
        window.setFrameOrigin(NSPoint(x: x, y: curY))
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

    // MARK: - Click / Drag

    private func handleMouseDown(at scenePoint: NSPoint) {
        let screenPoint = window.convertPoint(toScreen:
            skView.convert(scenePoint, from: scene))
        dragOffset = NSPoint(x: screenPoint.x - window.frame.origin.x,
                             y: screenPoint.y - window.frame.origin.y)
    }

    private func handleMouseDragged(to scenePoint: NSPoint) {
        if !isDragging {
            isDragging = true
            behavior.handleDragStart()
        }
        let screenPoint = window.convertPoint(toScreen:
            skView.convert(scenePoint, from: scene))
        var newX = screenPoint.x - dragOffset.x
        var newY = screenPoint.y - dragOffset.y

        // Clamp to screen bounds to prevent dragging off-screen
        let screens = ScreenAdapter.screenRects()
        if !screens.isEmpty {
            let mouseLoc = NSEvent.mouseLocation
            let idx = ScreenAdapter.screenIndex(containing: mouseLoc, in: screens) ?? 0
            if idx < screens.count {
                let s = screens[idx]
                newX = max(CGFloat(s.minX), min(CGFloat(s.maxX) - petWidth, newX))
                newY = max(CGFloat(s.minY), min(CGFloat(s.maxY) - petHeight, newY))
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
        } else {
            behavior.handleClick()
        }
    }
}
