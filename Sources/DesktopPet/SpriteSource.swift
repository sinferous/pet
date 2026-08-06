import AppKit
import CoreGraphics
import SpriteKit
import DesktopPetCore

/// Converts a `RenderedFrame` (RGBA pixel buffer) into a `CGImage` suitable
/// for SpriteKit textures. Also supports loading custom PNG and SVG frames.
enum SpriteSource {

    /// Creates a CGImage from a `RenderedFrame` (pixel buffer, RGBA, 8 bpc).
    static func cgImage(from frame: RenderedFrame) -> CGImage? {
        let width = frame.width
        let height = frame.height
        let bitsPerComponent = 8
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let provider = CGDataProvider(data: Data(frame.pixels) as CFData) else {
            return nil
        }

        return CGImage(
            width: width, height: height,
            bitsPerComponent: bitsPerComponent, bitsPerPixel: 32,
            bytesPerRow: bytesPerRow, space: colorSpace,
            bitmapInfo: bitmapInfo, provider: provider,
            decode: nil, shouldInterpolate: false,
            intent: .defaultIntent)
    }

    /// Returns the user's custom sprite folder if it exists:
    ///   ~/Library/Application Support/DesktopPet/Sprites/
    static var customFolder: URL? {
        guard let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let folder = appSupport
            .appendingPathComponent("DesktopPet", isDirectory: true)
            .appendingPathComponent("Sprites", isDirectory: true)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDir),
              isDir.boolValue else { return nil }
        return folder
    }

    /// Resolves textures for a given animation, checking the custom folder first (SVG, then PNG),
    /// then checking the app bundle (SVG). Returns `nil` to fall back to procedurally generated frames.
    static func loadTextures(for animation: PetAnimation, targetSize: CGSize) -> [SKTexture]? {
        // "follow" shares the same animation frames as "walk"
        let name = animation == .follow ? "walk" : animation.rawValue

        // 1. Custom SVGs
        if let customSVGs = loadCustomSVGFrames(animation: name, targetSize: targetSize) {
            return customSVGs.map {
                let tex = SKTexture(cgImage: $0)
                tex.filteringMode = .linear
                return tex
            }
        }

        // 2. Custom PNGs
        if let customPNGs = loadCustomPNGFrames(animation: name) {
            return customPNGs.map {
                let tex = SKTexture(cgImage: $0)
                tex.filteringMode = .nearest
                return tex
            }
        }

        // 3. Bundle SVGs
        if let bundleSVGs = loadBundleSVGFrames(animation: name, targetSize: targetSize) {
            return bundleSVGs.map {
                let tex = SKTexture(cgImage: $0)
                tex.filteringMode = .linear
                return tex
            }
        }

        return nil
    }

    // MARK: - Loading helpers

    private static func loadCustomSVGFrames(animation name: String, targetSize: CGSize) -> [CGImage]? {
        guard let base = customFolder else { return nil }
        let dir = base.appendingPathComponent(name, isDirectory: true)
        guard FileManager.default.fileExists(atPath: dir.path) else { return nil }

        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let svgs = files
            .filter { $0.pathExtension.lowercased() == "svg" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        guard !svgs.isEmpty else { return nil }
        return svgs.compactMap { cgImageFromSVG(at: $0, targetSize: targetSize) }
    }

    private static func loadCustomPNGFrames(animation name: String) -> [CGImage]? {
        guard let base = customFolder else { return nil }
        let dir = base.appendingPathComponent(name, isDirectory: true)
        guard FileManager.default.fileExists(atPath: dir.path) else { return nil }

        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let pngs = files
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        guard !pngs.isEmpty else { return nil }
        return pngs.compactMap { url in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
    }

    private static func loadBundleSVGFrames(animation name: String, targetSize: CGSize) -> [CGImage]? {
        var frames: [CGImage] = []
        var index = 0
        while true {
            guard let url = Bundle.main.url(
                forResource: String(index),
                withExtension: "svg",
                subdirectory: "Artwork/\(name)"
            ) else {
                break
            }
            guard let cgImage = cgImageFromSVG(at: url, targetSize: targetSize) else {
                break
            }
            frames.append(cgImage)
            index += 1
        }
        return frames.isEmpty ? nil : frames
    }

    private static func cgImageFromSVG(at url: URL, targetSize: CGSize) -> CGImage? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        image.size = targetSize
        var rect = NSRect(origin: .zero, size: targetSize)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
