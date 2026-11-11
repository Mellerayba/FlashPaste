import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Renders Resources/menubar.pdf, Resources/AppIcon.icns and PNG previews from Resources/src/IconDesign.swift.
/// Run via scripts/make-icons.sh (which compiles both files together).
@main
struct MakeIcons {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? ".")
        let resources = root.appendingPathComponent("Resources")
        let previews = resources.appendingPathComponent("src/previews")
        try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)

        try writeMenubarPDF(to: resources.appendingPathComponent("menubar.pdf"))
        try writeIconset(at: resources, previews: previews)
        for size in [18, 36] {
            try writePNG(renderGlyph(pixels: size, onLight: true), to: previews.appendingPathComponent("menubar-\(size)px.png"))
        }
        print("icons written to \(resources.path)")
    }

    static func writeMenubarPDF(to url: URL) throws {
        var box = CGRect(x: 0, y: 0, width: 18, height: 18)
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { throw Failure("cannot create PDF context") }
        ctx.beginPDFPage(nil)
        IconDesign.drawGlyph(in: ctx, rect: box.insetBy(dx: 1, dy: 1), color: CGColor(gray: 0, alpha: 1))
        ctx.endPDFPage()
        ctx.closePDF()
    }

    static func writeIconset(at resources: URL, previews: URL) throws {
        let iconset = resources.appendingPathComponent("src/AppIcon.iconset")
        try? FileManager.default.removeItem(at: iconset)
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        for base in [16, 32, 128, 256, 512] {
            try writePNG(renderAppIcon(pixels: base), to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
            try writePNG(renderAppIcon(pixels: base * 2), to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
        }
        try writePNG(renderAppIcon(pixels: 256), to: previews.appendingPathComponent("appicon-256px.png"))
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        task.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { throw Failure("iconutil failed") }
    }

    static func makeContext(_ pixels: Int) -> CGContext {
        CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }

    static func renderAppIcon(pixels: Int) -> CGImage {
        let ctx = makeContext(pixels)
        IconDesign.drawAppIcon(in: ctx, size: CGFloat(pixels))
        return ctx.makeImage()!
    }

    static func renderGlyph(pixels: Int, onLight: Bool) -> CGImage {
        let ctx = makeContext(pixels)
        ctx.setFillColor(CGColor(gray: onLight ? 0.93 : 0.15, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))
        let inset = CGFloat(pixels) / 18
        IconDesign.drawGlyph(in: ctx, rect: CGRect(x: 0, y: 0, width: pixels, height: pixels).insetBy(dx: inset, dy: inset),
                             color: CGColor(gray: onLight ? 0 : 1, alpha: 1))
        return ctx.makeImage()!
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw Failure("cannot write \(url.path)")
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw Failure("cannot finalize \(url.path)") }
    }

    struct Failure: Error, CustomStringConvertible {
        let description: String
        init(_ d: String) { description = d }
    }
}
