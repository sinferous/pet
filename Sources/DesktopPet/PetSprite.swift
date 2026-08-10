import SpriteKit
import DesktopPetCore

/// A sprite node that plays looping frame animations for the pet.
final class PetSprite: SKSpriteNode {

    /// The rendered frames for the currently playing animation, used for
    /// pixel-level alpha hit testing.
    private var renderedFrames: [RenderedFrame] = []
    private var currentFrameIndex: Int = 0
    private var currentAnimation: SKAction?

    var frameIndex: Int {
        return currentFrameIndex
    }

    init() {
        super.init(texture: nil, color: .clear, size: CGSize(width: 16, height: 15))
        anchorPoint = CGPoint(x: 0.5, y: 0)
    }

    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    // MARK: - Playback

    func play(textures: [SKTexture], fps: Double, targetSize: CGSize) {
        removeAllActions()
        guard !textures.isEmpty else { return }

        // Build rendered frames for alpha queries.
        renderedFrames = [] // rebuilt from textures' backing pixel data
        currentFrameIndex = 0

        let timePerFrame = 1.0 / fps
        let frameCount = textures.count

        // Determine base scaling to fit targetSize.
        let firstTexSize = textures[0].size()
        let baseScaleX = targetSize.width / firstTexSize.width
        let baseScaleY = targetSize.height / firstTexSize.height

        // Track current frame index during playback.
        let animAction = SKAction.repeatForever(
            SKAction.customAction(withDuration: timePerFrame * Double(frameCount)) { [weak self] _, elapsed in
                guard let self else { return }
                let idx = Int(elapsed / timePerFrame) % frameCount
                let tex = textures[idx]
                self.texture = tex
                self.size = tex.size()

                // Keep facing direction while scaling
                let facingSign: CGFloat = self.xScale < 0 ? -1.0 : 1.0
                self.xScale = facingSign * baseScaleX
                self.yScale = baseScaleY

                self.currentFrameIndex = idx
            }
        )
        run(animAction, withKey: "anim")
        
        texture = textures[0]
        size = textures[0].size()
        let facingSign: CGFloat = self.xScale < 0 ? -1.0 : 1.0
        self.xScale = facingSign * baseScaleX
        self.yScale = baseScaleY
    }

    // MARK: - Alpha hit-test helper

    /// Returns alpha at a window-coordinate point by sampling the current texture.
    func alpha(at windowPt: NSPoint, sceneSize: CGSize) -> UInt8 {
        guard let tex = texture else { return 0 }
        let texW = tex.size().width
        let texH = tex.size().height

        let scaleX = abs(xScale)
        let scaleY = yScale

        guard scaleX > 0, scaleY > 0 else { return 0 }

        // Convert window coords (scene coords) to sprite-local pixel coords.
        // Scene anchor is at (0.5, 0), so the sprite extends from -sceneSize.width/2 to sceneSize.width/2.
        var spriteLocalX = (windowPt.x - sceneSize.width / 2) / scaleX + texW / 2
        let spriteLocalY = windowPt.y / scaleY

        // Handle mirror horizontal flip when facing left (xScale is negative).
        if xScale < 0 {
            spriteLocalX = texW - 1.0 - spriteLocalX
        }

        let px = Int(spriteLocalX)
        let py = Int(texH) - 1 - Int(spriteLocalY) // flip y (texture is top-down)

        guard px >= 0, px < Int(texW), py >= 0, py < Int(texH) else { return 0 }

        // Read alpha from underlying CGImage.
        let cgImg = tex.cgImage()
        guard let data = cgImg.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return 0 }

        let bpp = cgImg.bitsPerPixel / 8
        let bpr = cgImg.bytesPerRow
        let offset = py * bpr + px * bpp

        // Alpha is the last component in RGBA.
        if bpp >= 4 {
            return ptr[offset + 3]
        } else {
            return 255
        }
    }
}
