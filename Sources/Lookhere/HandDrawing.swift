import AppKit

/// The arrow pointer, drawn in a y-up unit space with its tip near the top.
enum HandDrawing {
    /// The classic macOS arrow, counter-rotated so it sits upright once the rig leans.
    static func drawArrow(in ctx: CGContext) {
        let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, 17), (4, 13.2), (6.8, 19.6), (9.4, 18.5), (6.7, 12.2), (12, 12.2)]
        let u: CGFloat = 6.4
        let tip = CGPoint(x: 45, y: 150)
        let path = CGMutablePath()
        for (i, p) in pts.enumerated() {
            let pt = CGPoint(x: tip.x + p.0 * u, y: tip.y - p.1 * u)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        var t = CGAffineTransform(translationX: tip.x, y: tip.y)
            .rotated(by: -CGFloat(restLean))
            .translatedBy(x: -tip.x, y: -tip.y)
        let upright = path.copy(using: &t)!

        ctx.setLineJoin(.round)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -3), blur: 7, color: CGColor(gray: 0, alpha: 0.35))
        ctx.addPath(upright)
        ctx.setStrokeColor(.white)
        ctx.setLineWidth(11)
        ctx.strokePath()
        ctx.restoreGState()
        ctx.addPath(upright)
        ctx.setFillColor(.black)
        ctx.fillPath()
    }
}
