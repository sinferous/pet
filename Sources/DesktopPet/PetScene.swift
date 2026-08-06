import SpriteKit
import DesktopPetCore

/// The SpriteKit scene that displays the pet. Transparent background,
/// 60 fps, handles mouse input and reports current-frame alpha for
/// click-through hit testing.
final class PetScene: SKScene {

    // MARK: - Callbacks
    var onTick: (() -> Void)?
    var onMouseDown: ((NSPoint) -> Void)?
    var onMouseDragged: ((NSPoint) -> Void)?
    var onMouseUp: (() -> Void)?

    // MARK: - Sizing
    /// The cat sprite is 128×120 and sits at the bottom of the (taller) window;
    /// the 200px above it is an effects headroom so confetti/hearts rise freely
    /// instead of being cut off mid-air.
    private let petSize = CGSize(width: 128, height: 120)

    // MARK: - Sprite
    private let petSprite = PetSprite()
    private var zzzLabel: SKLabelNode?

    // MARK: - Celebration effects (confetti / hearts / wool ball)
    /// Set by the controller while the pet is cheering (drives the confetti trickle).
    var cheerActive = false

    private struct ConfettiPiece {
        let node: SKShapeNode
        var vx: CGFloat
        var vy: CGFloat
        var vr: CGFloat
        var life: TimeInterval
        let maxLife: TimeInterval
    }
    private struct HeartParticle {
        let node: SKLabelNode
        var vx: CGFloat
        var vy: CGFloat
        let wobble: CGFloat
        var life: TimeInterval
        let maxLife: TimeInterval
    }

    private var confettiPieces: [ConfettiPiece] = []
    private var heartParticles: [HeartParticle] = []
    private var woolBallNode: SKShapeNode?
    private var woolBallVX: CGFloat = 0
    private var woolBallVY: CGFloat = 0
    private var lastEffectsTime: TimeInterval = 0

    private let confettiColors: [NSColor] = [
        NSColor(red: 1.00, green: 0.42, blue: 0.42, alpha: 1), // #ff6b6b
        NSColor(red: 1.00, green: 0.85, blue: 0.24, alpha: 1), // #ffd93d
        NSColor(red: 0.42, green: 0.80, blue: 0.47, alpha: 1), // #6bcb77
        NSColor(red: 0.30, green: 0.59, blue: 1.00, alpha: 1), // #4d96ff
        NSColor(red: 1.00, green: 0.62, blue: 0.27, alpha: 1), // #ff9f45
        NSColor(red: 0.78, green: 0.49, blue: 1.00, alpha: 1), // #c77dff
        NSColor(red: 1.00, green: 0.37, blue: 0.56, alpha: 1)  // #ff5d8f
    ]

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        anchorPoint = CGPoint(x: 0.5, y: 0)
        addChild(petSprite)
        petSprite.position = .zero // bottom-center: cat sits on the floor, headroom above
    }

    // MARK: - Animation

    func play(animation: PetAnimation, frames: [[String]]) {
        var textures: [SKTexture] = []

        // Try to load custom/bundle SVG/PNG textures first.
        if let resolvedTextures = SpriteSource.loadTextures(for: animation, targetSize: petSize) {
            textures = resolvedTextures
        } else {
            // Fallback to procedurally generated pixel art.
            let palette = PixelPalette.standard
            for rows in frames {
                guard let frame = try? PixelArtRenderer.render(rows: rows, palette: palette) else {
                    continue
                }
                guard let image = SpriteSource.cgImage(from: frame) else { continue }
                let tex = SKTexture(cgImage: image)
                tex.filteringMode = .nearest
                textures.append(tex)
            }
        }

        guard !textures.isEmpty else { return }

        // Show/hide overlays for sleep and drink animations.
        if animation == .sleep {
            showZzz()
        } else {
            hideZzz()
        }

        if animation == .drink {
            showWaterSpeechBubble()
        }

        petSprite.play(textures: textures, fps: animation.fps, targetSize: petSize)
    }

    func setFacing(_ facing: Facing) {
        petSprite.xScale = facing == .left
            ? -abs(petSprite.xScale)
            : abs(petSprite.xScale)
    }

    var frameIndex: Int {
        return petSprite.frameIndex
    }

    // MARK: - Speech Bubbles
    
    private let waterSentences = [
        "💧 Stay hydrated, human!",
        "💧 Glug glug! Water time!",
        "💧 Drink water now!",
        "💧 Keep your batteries full!",
        "💧 Hydrate or dry-rate!",
        "💧 Be like a plant: water!",
        "💧 System alert: Drink water!",
        "💧 Take a sip of water!",
        "💧 Hydration check!",
        "💧 Drink up!"
    ]

    private let catVoices = [
        "Purrrrr...",
        "Meow~",
        "Prrrp?",
        "Mrrrp!",
        "Nyaa~",
        "Prrrr...",
        "Meow! 🐾",
        "*stretches*",
        "Purrrrrrrrr..."
    ]

    private let catReactVoices = [
        "Purrrrr...",
        "Prrrr! ❤️",
        "Mrrrp! ♪",
        "Meow~",
        "Purrrrrr..."
    ]
    
    private var activeSpeechBubble: SKNode?
    
    func showSpeechBubble(text: String, duration: TimeInterval) {
        activeSpeechBubble?.removeFromParent()
        activeSpeechBubble = nil
        
        let bubble = SKShapeNode(rectOf: CGSize(width: 170, height: 44), cornerRadius: 10)
        bubble.fillColor = NSColor(red: 1.0, green: 1.0, blue: 0.94, alpha: 1.0) // retro cream
        bubble.strokeColor = .black
        bubble.lineWidth = 2.5
        bubble.position = CGPoint(x: 0, y: petSize.height + 30) // just above the cat's head
        bubble.zPosition = 100
        
        // Add hard retro black shadow
        let shadow = SKShapeNode(rectOf: CGSize(width: 170, height: 44), cornerRadius: 10)
        shadow.fillColor = .black
        shadow.strokeColor = .black
        shadow.lineWidth = 0
        shadow.position = CGPoint(x: 4, y: -4)
        shadow.zPosition = -1
        bubble.addChild(shadow)
        
        // Add text label
        let label = SKLabelNode(fontNamed: "CourierNewPS-BoldMT") // retro monospace
        label.fontSize = 11
        label.fontColor = .black
        label.text = text
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 0)
        label.zPosition = 1
        bubble.addChild(label)
        
        // Auto-remove and clear active reference
        bubble.run(SKAction.sequence([
            SKAction.wait(forDuration: duration),
            SKAction.run { [weak self, weak bubble] in
                if self?.activeSpeechBubble == bubble {
                    self?.activeSpeechBubble = nil
                }
            },
            SKAction.removeFromParent()
        ]))
        
        addChild(bubble)
        activeSpeechBubble = bubble
    }

    private func showWaterSpeechBubble() {
        let txt = waterSentences.randomElement() ?? "💧 Drink water!"
        showSpeechBubble(text: txt, duration: 6.0)
    }

    func showRandomMeowSpeechBubble() {
        guard activeSpeechBubble == nil else { return }
        let txt = catVoices.randomElement() ?? "Meow~"
        showSpeechBubble(text: txt, duration: 2.5)
    }

    func showRandomReactSpeechBubble() {
        let txt = catReactVoices.randomElement() ?? "Purrrrr..."
        showSpeechBubble(text: txt, duration: 3.0)
    }

    // MARK: - Zzz overlay

    private func showZzz() {
        guard zzzLabel == nil else { return }
        let label = SKLabelNode(text: "💤")
        label.fontSize = 18
        label.position = CGPoint(x: 12, y: petSize.height + 24) // above the head
        label.zPosition = 10
        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 5, duration: 0.8),
            SKAction.moveBy(x: 0, y: -5, duration: 0.8)
        ])
        label.run(SKAction.repeatForever(bob))
        addChild(label)
        zzzLabel = label
    }

    private func hideZzz() {
        zzzLabel?.removeFromParent()
        zzzLabel = nil
    }

    // MARK: - Celebration effects

    /// Big confetti burst around the cat (cheer).
    func spawnConfettiBurst(count: Int) {
        let winW = size.width
        for _ in 0..<count {
            let w = CGFloat.random(in: 4...8)
            let h = CGFloat.random(in: 6...11)
            let piece = SKShapeNode(rectOf: CGSize(width: w, height: h))
            piece.fillColor = confettiColors.randomElement() ?? .systemRed
            piece.strokeColor = .clear
            piece.lineWidth = 0
            piece.position = CGPoint(x: winW / 2 + CGFloat.random(in: -winW / 2 ... winW / 2),
                                     y: CGFloat.random(in: 20...90))
            piece.zPosition = 50
            addChild(piece)

            let life = TimeInterval.random(in: 0.8...2.2)
            confettiPieces.append(ConfettiPiece(node: piece,
                                                vx: CGFloat.random(in: -140...140),
                                                vy: CGFloat.random(in: 60...280), // rising (scene y is up)
                                                vr: CGFloat.random(in: -6...6),
                                                life: life,
                                                maxLife: life))
        }
    }

    /// Heart emojis that drift up around the cat (love).
    func spawnHeartEmojis(count: Int) {
        for _ in 0..<count {
            let label = SKLabelNode(text: "❤️")
            label.fontSize = CGFloat.random(in: 10...24)
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: petSize.width * CGFloat.random(in: 0.15...0.85),
                                     y: CGFloat.random(in: 20...60))
            label.zPosition = 50
            addChild(label)

            let life = TimeInterval.random(in: 1.2...2.3)
            heartParticles.append(HeartParticle(node: label,
                                                vx: CGFloat.random(in: -13...13),
                                                vy: CGFloat.random(in: 16...42),
                                                wobble: CGFloat.random(in: 0...6.28),
                                                life: life,
                                                maxLife: life))
        }
    }

    /// Spawn the bouncing wool ball near the cat's paws (woolball).
    func startWoolBall() {
        stopWoolBall()
        let ball = SKShapeNode(circleOfRadius: 10)
        ball.fillColor = NSColor(red: 0.91, green: 0.35, blue: 0.05, alpha: 1) // #e8590c
        ball.strokeColor = NSColor(red: 0.76, green: 0.15, blue: 0.36, alpha: 1) // #c2255c
        ball.lineWidth = 2
        ball.position = CGPoint(x: petSize.width / 2, y: 50)
        ball.zPosition = 40
        addChild(ball)
        woolBallNode = ball
        woolBallVX = (Bool.random() ? -1 : 1) * CGFloat.random(in: 70...130)
        woolBallVY = 70
    }

    func stopWoolBall() {
        woolBallNode?.removeFromParent()
        woolBallNode = nil
    }

    private func updateEffects(dt: TimeInterval) {
        let winW = size.width
        let winH = size.height

        // Confetti: gravity pulls it down; it bounces off the walls and settles
        // near the window top so nothing is ever cut off mid-air.
        for i in confettiPieces.indices.reversed() {
            var c = confettiPieces[i]
            c.life -= dt
            c.vy -= 260 * CGFloat(dt)
            var x = c.node.position.x + c.vx * CGFloat(dt)
            var y = c.node.position.y + c.vy * CGFloat(dt)
            c.node.zRotation += c.vr * CGFloat(dt)

            let w = c.node.frame.width
            let h = c.node.frame.height
            if x - w / 2 <= 0 { x = w / 2; c.vx = abs(c.vx) * 0.8 }
            if x + w / 2 >= winW { x = winW - w / 2; c.vx = -abs(c.vx) * 0.8 }
            if y <= 2 { y = 2; c.vy = abs(c.vy) * 0.6 }
            if y + h / 2 >= winH - 6 { y = winH - 6 - h / 2; c.vy = 0; c.vx *= 0.9 }

            c.node.position = CGPoint(x: x, y: y)
            c.node.alpha = CGFloat(min(1, c.life * 2))

            if c.life <= 0 {
                c.node.removeFromParent()
                confettiPieces.remove(at: i)
            } else {
                confettiPieces[i] = c
            }
        }

        // Hearts drift up with a wobble, clamped to the window sides.
        for i in heartParticles.indices.reversed() {
            var h = heartParticles[i]
            h.life -= dt
            h.node.position.x += (h.vx + sin(h.wobble + CGFloat(h.life) * 4) * 14) * CGFloat(dt)
            h.node.position.y += h.vy * CGFloat(dt)
            h.node.alpha = CGFloat(min(1, h.life * 2))

            if h.node.position.x <= 4 { h.node.position.x = 4 }
            if h.node.position.x >= winW - 4 { h.node.position.x = winW - 4 }

            if h.life <= 0 {
                h.node.removeFromParent()
                heartParticles.remove(at: i)
            } else {
                heartParticles[i] = h
            }
        }

        // Wool ball bounces around the window; the cat bats it near its paws.
        if let ball = woolBallNode {
            woolBallVY -= 500 * CGFloat(dt)
            var x = ball.position.x + woolBallVX * CGFloat(dt)
            var y = ball.position.y + woolBallVY * CGFloat(dt)

            if abs(x - petSize.width / 2) < petSize.width * 0.55 && y < petSize.height * 0.55 {
                woolBallVX += (x < petSize.width / 2 ? -1 : 1) * 300 * CGFloat(dt)
            }
            woolBallVX = max(-200, min(200, woolBallVX))

            if y + 10 >= winH - 6 { y = winH - 6 - 10; woolBallVY = -woolBallVY * 0.7; woolBallVX *= 0.98 }
            if y - 10 <= 2 { y = 2 + 10; woolBallVY = abs(woolBallVY) * 0.7 }
            if x - 10 <= 2 { x = 2 + 10; woolBallVX = abs(woolBallVX) * 0.9 }
            if x + 10 >= winW - 2 { x = winW - 2 - 10; woolBallVX = -abs(woolBallVX) * 0.9 }
            ball.position = CGPoint(x: x, y: y)

            // Face the ball while playing with it.
            petSprite.xScale = (x < petSize.width / 2 ? -1 : 1) * abs(petSprite.xScale)
        }

        // Gentle confetti trickle while the cat is cheering.
        if cheerActive, Double.random(in: 0...1) < dt * 10 {
            spawnConfettiBurst(count: 2)
        }
    }

    // MARK: - Alpha sampling for hit test

    /// Returns the alpha value at `windowPt` (window coords, origin bottom-left).
    func currentAlpha(at windowPt: NSPoint) -> UInt8 {
        return petSprite.alpha(at: windowPt, sceneSize: size)
    }

    // MARK: - Update loop

    override func update(_ currentTime: TimeInterval) {
        let dt = min(max(currentTime - lastEffectsTime, 0), 0.1)
        lastEffectsTime = currentTime
        updateEffects(dt: dt)
        onTick?()
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        onMouseDown?(event.location(in: self))
    }

    override func mouseDragged(with event: NSEvent) {
        onMouseDragged?(event.location(in: self))
    }

    override func mouseUp(with event: NSEvent) {
        onMouseUp?()
    }
}

// MARK: - PetAnimation helpers

extension PetAnimation {
    /// Frames per second for each animation style.
    var fps: Double {
        switch self {
        case .idle:   return 2
        case .walk:   return 6
        case .run:    return 12
        case .sleep:  return 1.5
        case .drink:  return 3
        case .play:   return 5
        case .react:  return 4
        case .follow: return 6
        case .laugh:  return 3
        case .jump:   return 9
        case .roll:   return 7
        case .love:   return 4
        }
    }
}
