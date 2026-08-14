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

        let cgImg = tex.cgImage()

        // Scale to CGImage's actual pixel dimensions (handles Retina/backing scale differences)
        let sampleX = Int(round(CGFloat(px) * CGFloat(cgImg.width) / texW))
        let sampleY = Int(round(CGFloat(py) * CGFloat(cgImg.height) / texH))

        guard sampleX >= 0, sampleX < cgImg.width,
              sampleY >= 0, sampleY < cgImg.height else { return 0 }

        // Draw 1x1 pixel into a known RGBA buffer to be 100% independent of CGImage byte-order / format
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: &pixel,
                  width: 1,
                  height: 1,
                  bitsPerComponent: 8,
                  bytesPerRow: 4,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return 0 }

        context.setBlendMode(.copy)
        guard let cropped = cgImg.cropping(to: CGRect(x: sampleX, y: sampleY, width: 1, height: 1)) else { return 0 }
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        return pixel[3] // alpha is the 4th component in premultipliedLast (RGBA)
    }
}
