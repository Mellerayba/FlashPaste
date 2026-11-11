import CoreGraphics

/// The FlashPaste glyph: a flashcard with a "paste into" arrow cut out of it.
/// Tweak colours and proportions here, then run scripts/make-icons.sh.
enum IconDesign {
    // App icon colours (sRGB 0-1).
    static let backgroundTop    = CGColor(srgbRed: 0.42, green: 0.60, blue: 1.00, alpha: 1)
    static let backgroundBottom = CGColor(srgbRed: 0.17, green: 0.33, blue: 0.85, alpha: 1)
    static let cardColor        = CGColor(srgbRed: 1.00, green: 1.00, blue: 1.00, alpha: 1)
    static let backCardColor    = CGColor(srgbRed: 1.00, green: 1.00, blue: 1.00, alpha: 0.35)
    static let shadowColor      = CGColor(srgbRed: 0.05, green: 0.10, blue: 0.35, alpha: 0.35)

    /// Fraction of the app icon canvas covered by the rounded square (macOS grid is ~0.8).
    static let squircleScale: CGFloat = 0.80
    /// Fraction of the squircle covered by the glyph.
    static let glyphScale: CGFloat = 0.62

    /// Builds the glyph path in a unit square (0...1, origin bottom-left) scaled into `rect`.
    /// Uses the even-odd rule: the arrow is a hole in the card.
    static func glyphPath(in rect: CGRect) -> CGPath {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        let path = CGMutablePath()
        // Card: landscape rounded rectangle.
        let card = CGRect(x: rect.minX + 0.02 * rect.width, y: rect.minY + 0.14 * rect.height,
                          width: 0.96 * rect.width, height: 0.72 * rect.height)
        path.addRoundedRect(in: card, cornerWidth: 0.14 * rect.width, cornerHeight: 0.14 * rect.height)
        // Arrow pointing down into the card (shaft then head), drawn as one polygon.
        let shaftHalf: CGFloat = 0.11, headHalf: CGFloat = 0.28
        let top: CGFloat = 0.80, headBase: CGFloat = 0.50, tip: CGFloat = 0.21
        path.move(to: p(0.5 - shaftHalf, top))
        path.addLine(to: p(0.5 + shaftHalf, top))
        path.addLine(to: p(0.5 + shaftHalf, headBase))
        path.addLine(to: p(0.5 + headHalf, headBase))
        path.addLine(to: p(0.5, tip))
        path.addLine(to: p(0.5 - headHalf, headBase))
        path.addLine(to: p(0.5 - shaftHalf, headBase))
        path.closeSubpath()
        return path
    }

    /// Monochrome glyph (menu-bar template image).
    static func drawGlyph(in ctx: CGContext, rect: CGRect, color: CGColor) {
        ctx.saveGState()
        ctx.addPath(glyphPath(in: rect))
        ctx.setFillColor(color)
        ctx.fillPath(using: .evenOdd)
        ctx.restoreGState()
    }

    /// Full-colour app icon on the macOS rounded square.
    static func drawAppIcon(in ctx: CGContext, size: CGFloat) {
        let side = size * squircleScale
        let square = CGRect(x: (size - side) / 2, y: (size - side) / 2, width: side, height: side)
        let radius = side * 0.225
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: square, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.clip()
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  colors: [backgroundTop, backgroundBottom] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: square.midX, y: square.maxY),
                               end: CGPoint(x: square.midX, y: square.minY), options: [])
        ctx.restoreGState()

        let glyphSide = side * glyphScale
        let glyph = CGRect(x: square.midX - glyphSide / 2, y: square.midY - glyphSide / 2, width: glyphSide, height: glyphSide)
        // A second card peeking out behind, for the "stack of flashcards" feel.
        let back = glyph.offsetBy(dx: glyphSide * 0.06, dy: glyphSide * 0.08)
        ctx.saveGState()
        ctx.setFillColor(backCardColor)
        ctx.addPath(CGPath(roundedRect: CGRect(x: back.minX + 0.02 * back.width, y: back.minY + 0.14 * back.height,
                                               width: 0.96 * back.width, height: 0.72 * back.height),
                           cornerWidth: 0.14 * back.width, cornerHeight: 0.14 * back.height, transform: nil))
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.02), blur: size * 0.04, color: shadowColor)
        drawGlyph(in: ctx, rect: glyph, color: cardColor)
        ctx.restoreGState()
    }
}
