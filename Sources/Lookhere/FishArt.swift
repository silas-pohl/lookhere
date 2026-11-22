import AppKit

/// A goldfish on a stick that pokes with its puckered lips. Same SVG-style
/// authoring space as `GloveArt` (y down, fits `GloveArt.canvas`).
enum FishArt {
    static let tip = CGPoint(x: 135, y: 6)
    static let stickAnchor = CGPoint(x: 140, y: 300)

    private static let ink = GloveArt.ink
    private static let line: CGFloat = 10

    private static let body = """
    M 135 22 C 184 34 208 98 202 160 C 198 214 170 250 140 264 C 110 250 76 214 70 160 \
    C 64 98 86 34 135 22 Z
    """
    private static let tail = """
    M 140 250 C 122 268 98 288 84 314 C 110 310 128 302 140 292 C 152 302 170 310 196 314 \
    C 182 288 158 268 140 250 Z
    """
    private static let finRight = "M 196 128 C 226 136 242 166 234 198 C 222 188 210 180 198 178 Z"
    private static let finLeft = "M 76 148 C 50 158 38 186 46 210 C 58 198 68 192 78 190 Z"
    private static let lips = "M 110 28 C 108 2 162 2 160 28 C 158 46 112 46 110 28 Z"
    private static let gill = "M 84 112 C 108 128 162 128 188 112"
    private static let scales = """
    M 104 152 C 112 164 124 164 132 152 M 132 152 C 140 164 152 164 160 152 \
    M 160 152 C 166 162 174 162 180 154 M 116 184 C 124 196 136 196 144 184 \
    M 144 184 C 152 196 164 196 170 186 M 130 214 C 138 224 148 224 154 214
    """
    private static let finRays = "M 206 150 C 214 160 220 172 222 184 M 66 172 C 60 182 56 192 56 202 M 130 284 C 122 290 112 298 102 306 M 150 284 C 158 290 168 298 178 306"

    static func draw(in ctx: CGContext) {
        let orange = NSColor(srgbRed: 1.0, green: 0.58, blue: 0.20, alpha: 1)
        let fin = NSColor(srgbRed: 1.0, green: 0.44, blue: 0.22, alpha: 1)
        let belly = NSColor(srgbRed: 1.0, green: 0.80, blue: 0.48, alpha: 1)
        let lipPink = NSColor(srgbRed: 1.0, green: 0.42, blue: 0.55, alpha: 1)
        let shade: (NSColor) -> NSColor = { $0.blended(withFraction: 0.25, of: NSColor(srgbRed: 0.55, green: 0.15, blue: 0.2, alpha: 1))! }

        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)

        let parts: [(String, NSColor)] = [(tail, fin), (finRight, fin), (finLeft, fin), (body, orange)]
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -5), blur: 12, color: CGColor(gray: 0, alpha: 0.32))
        for (d, _) in parts { ctx.addPath(SVGPath.parse(d)) }
        ctx.setFillColor(ink)
        ctx.fillPath()
        ctx.restoreGState()

        for (d, color) in parts {
            GloveArt.celShaded(ctx, SVGPath.parse(d), color, shade(color), offset: CGSize(width: -10, height: -8))
        }

        // Pale belly, clipped to the body so it follows its curve.
        let bodyPath = SVGPath.parse(body)
        ctx.saveGState()
        ctx.addPath(bodyPath)
        ctx.clip()
        ctx.addPath(SVGPath.parse("M 96 196 C 110 236 170 236 184 196 C 176 250 104 250 96 196 Z"))
        ctx.setFillColor(belly.cgColor)
        ctx.fillPath()
        ctx.restoreGState()
        ctx.addPath(bodyPath)
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(line)
        ctx.strokePath()

        stroke(ctx, gill, line * 0.65)
        stroke(ctx, scales, line * 0.5)
        stroke(ctx, finRays, line * 0.45)

        // Googly eye.
        ctx.setFillColor(.white)
        ctx.fillEllipse(in: CGRect(x: 92, y: 50, width: 40, height: 40))
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(line * 0.7)
        ctx.strokeEllipse(in: CGRect(x: 92, y: 50, width: 40, height: 40))
        ctx.setFillColor(ink)
        ctx.fillEllipse(in: CGRect(x: 108, y: 62, width: 20, height: 20))
        ctx.setFillColor(.white)
        ctx.fillEllipse(in: CGRect(x: 118, y: 64, width: 7, height: 7))

        // The kissy lips are the hotspot.
        let lipsPath = SVGPath.parse(lips)
        GloveArt.celShaded(ctx, lipsPath, lipPink, shade(lipPink), offset: CGSize(width: -5, height: -5), lineWidth: line * 0.7)
        ctx.addPath(SVGPath.parse("M 120 26 C 128 31 142 31 150 26"))
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(line * 0.45)
        ctx.strokePath()
    }

    private static func stroke(_ ctx: CGContext, _ d: String, _ width: CGFloat) {
        ctx.addPath(SVGPath.parse(d))
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(width)
        ctx.strokePath()
    }
}
