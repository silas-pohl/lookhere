import AppKit

/// Cartoon glove pointing up, authored as SVG path data (y down, ~250 × 310).
/// One continuous silhouette with a flat fill, cel shading and a few detail lines.
enum GloveArt {
    static let canvas = CGSize(width: 270, height: 340)
    /// Fingertip and the centre of the cuff, in SVG units.
    static let tip = CGPoint(x: 129, y: 11)
    static let cuffCentre = CGPoint(x: 161, y: 292)

    static let ink = CGColor(srgbRed: 0.07, green: 0.07, blue: 0.08, alpha: 1)
    private static let line: CGFloat = 10

    private static let hand = """
    M 106 150 C 99 120 96 78 104 44 C 108 16 150 12 154 40 C 160 74 158 112 152 140 \
    C 160 124 186 124 190 142 C 200 132 222 138 224 158 C 240 162 248 186 238 206 \
    C 244 228 234 248 216 258 L 206 266 L 112 266 C 104 256 100 242 100 228 \
    C 84 226 66 214 60 196 C 54 176 68 158 88 160 C 96 161 101 158 106 150 Z
    """
    private static let cuff = """
    M 106 250 C 140 242 182 242 214 250 C 224 262 232 274 234 284 \
    C 236 296 198 302 162 302 C 124 302 86 296 88 284 C 90 274 98 262 106 250 Z
    """
    private static let cuffSeam = "M 90 280 C 124 292 200 292 232 280 M 132 256 C 128 264 125 272 123 281 M 190 256 C 194 264 197 272 199 281"
    private static let fingerCreases = "M 190 142 C 188 154 182 162 174 166 M 224 158 C 222 170 215 178 206 182"
    private static let thumbCrease = "M 106 150 C 111 164 109 178 102 188"
    private static let stitches = "M 144 214 C 146 222 147 230 146 238 M 162 212 C 165 220 166 228 165 236 M 180 210 C 184 218 185 226 184 234"

    static func draw(in ctx: CGContext, fill: NSColor) {
        let base = fill.usingColorSpace(.sRGB) ?? fill
        let shade = base.blended(withFraction: 0.2, of: NSColor(srgbRed: 0.36, green: 0.40, blue: 0.56, alpha: 1))!
        let handPath = SVGPath.parse(hand), cuffPath = SVGPath.parse(cuff)

        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)

        // Soft drop shadow so the glove reads on any background.
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -5), blur: 12, color: CGColor(gray: 0, alpha: 0.32))
        ctx.addPath(handPath)
        ctx.addPath(cuffPath)
        ctx.setFillColor(ink)
        ctx.fillPath()
        ctx.restoreGState()

        celShaded(ctx, handPath, base, shade, offset: CGSize(width: -11, height: -9))
        stroke(ctx, fingerCreases, line * 0.62)
        stroke(ctx, thumbCrease, line * 0.62)
        stroke(ctx, stitches, line * 0.55)
        celShaded(ctx, cuffPath, base, shade, offset: CGSize(width: -9, height: -9))
        stroke(ctx, cuffSeam, line * 0.6)

        // Glints on the fingertip and thumb; invisible on white, so only for coloured gloves.
        if base.brightnessComponent < 0.99 || base.saturationComponent > 0.05 {
            ctx.addPath(SVGPath.parse("M 120 34 C 117 44 116 56 117 68 M 60 182 C 64 176 70 174 76 176"))
            ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.75))
            ctx.setLineWidth(6)
            ctx.strokePath()
        }
    }

    /// Flat fill with a shadow crescent on the lower-right edge, then the outline.
    static func celShaded(_ ctx: CGContext, _ path: CGPath, _ base: NSColor, _ shade: NSColor, offset: CGSize,
                          lineWidth: CGFloat = line) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.setFillColor(shade.cgColor)
        ctx.fill(path.boundingBox.insetBy(dx: -20, dy: -20))
        var t = CGAffineTransform(translationX: offset.width, y: offset.height)
        ctx.addPath(path.copy(using: &t)!)
        ctx.setFillColor(base.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.addPath(path)
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(lineWidth)
        ctx.strokePath()
    }

    private static func stroke(_ ctx: CGContext, _ d: String, _ width: CGFloat) {
        ctx.addPath(SVGPath.parse(d))
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(width)
        ctx.strokePath()
    }
}

/// Minimal SVG path-data parser: absolute M, L, C, Q and Z.
enum SVGPath {
    static func parse(_ d: String) -> CGPath {
        let path = CGMutablePath()
        var tokens = tokenize(d)[...]
        var command: Character = "M"
        func num() -> CGFloat { CGFloat(Double(tokens.popFirst() ?? "0") ?? 0) }
        func pt() -> CGPoint { let x = num(); return CGPoint(x: x, y: num()) }
        while let t = tokens.first {
            if let c = t.first, c.isLetter {
                command = c
                tokens.removeFirst()
                if c == "Z" || c == "z" { path.closeSubpath(); continue }
            }
            switch command {
            case "M":
                path.move(to: pt())
                command = "L"
            case "L": path.addLine(to: pt())
            case "C":
                let c1 = pt(), c2 = pt()
                path.addCurve(to: pt(), control1: c1, control2: c2)
            case "Q":
                let c = pt()
                path.addQuadCurve(to: pt(), control: c)
            default: tokens.removeFirst()
            }
        }
        return path
    }

    private static func tokenize(_ d: String) -> [String] {
        var out: [String] = [], cur = ""
        for ch in d {
            if ch.isLetter {
                if !cur.isEmpty { out.append(cur); cur = "" }
                out.append(String(ch))
            } else if ch == " " || ch == "," || ch == "\n" {
                if !cur.isEmpty { out.append(cur); cur = "" }
            } else if ch == "-" && !cur.isEmpty {
                out.append(cur); cur = "-"
            } else {
                cur.append(ch)
            }
        }
        if !cur.isEmpty { out.append(cur) }
        return out
    }
}
