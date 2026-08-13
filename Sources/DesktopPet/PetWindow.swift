import AppKit
import SpriteKit

/// An always-on-top, borderless, transparent panel that hosts the pet sprite.
///
/// Clicks on transparent pixels fall through to the app underneath:
/// `hitTest` on `PetSKView` samples the pet sprite's alpha and returns `nil` for
/// fully-transparent regions, so the pet never "steals" clicks from other windows.
final class PetWindow: NSPanel {

    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .init(rawValue: Int(CGWindowLevelForKey(.statusWindow)))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
    }
}

/// A transparent SpriteKit view that intercepts mouse events at the pixel level.
final class PetSKView: SKView {
    /// The SpriteKit scene provides pixel-level alpha for the current frame.
    var alphaProvider: ((_ windowPoint: NSPoint) -> UInt8)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        if let scene = self.scene {
            let scenePt = convert(point, to: scene)
            let nodes = scene.nodes(at: scenePt)
            if nodes.contains(where: { $0.name == "closeButton" || $0.parent?.name == "closeButton" }) {
                return super.hitTest(point)
            }
        }
        
        if let alpha = alphaProvider?(point), alpha < 8 {
            return nil // click falls through
        }
        return super.hitTest(point)
    }
}
