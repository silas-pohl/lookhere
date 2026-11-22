import SwiftUI

/// The panel's header: a little comic panel where the current pointer pokes on a loop.
struct PokeStage: View {
    let style: PointerStyle
    let color: GloveColor
    let stick: StickColor
    let animating: Bool

    private static let rigCanvas = CGSize(width: 120, height: 130)
    private static let tipFraction = CGPoint(x: 0.32, y: 0.88)
    private static let cycle = 2.4
    /// Two taps per loop; the second one escalates to a starburst.
    private static let taps: [(start: Double, level: Int)] = [(0.2, 1), (0.55, 4)]

    var body: some View {
        let rig = Image(nsImage: Showcase.rig(style: style, color: color, stick: stick, size: 0.1,
                                              canvas: Self.rigCanvas, tipFraction: Self.tipFraction))
        let calm = Image(decorative: ArtFactory.starburst(hot: false), scale: 1)
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !animating)) { timeline in
            let t = animating ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.cycle) : 0
            Canvas { ctx, size in
                halftone(ctx, size)
                let tip = CGPoint(x: size.width * 0.66, y: size.height * 0.36)

                for tap in Self.taps {
                    let e = t - tap.start - 0.09
                    if e >= 0 && e < 0.46 { burst(ctx, at: tip, e: e, level: tap.level, star: calm) }
                }

                // Wind up, then snap through on a decaying spring (the same shape as the real poke).
                var swing = 0.0, grow = 0.0
                for tap in Self.taps {
                    let e = t - tap.start
                    guard e >= 0, e < 0.6 else { continue }
                    let wind = 0.05
                    let k = e < wind ? sin(.pi / 2 * e / wind) : exp(-(e - wind) / 0.07) * cos(2 * .pi * (e - wind) / 0.16 + 0.0)
                    let amp = 1 + 0.18 * Double(tap.level)
                    swing += 0.11 * amp * k
                    grow += k >= 0 ? 0.1 * amp * k : 0.16 * k
                }
                // Swing about a pivot far down the stick, grow about the fingertip.
                var g = ctx
                let pivot = CGPoint(x: tip.x + 55, y: tip.y + 150)
                g.translateBy(x: pivot.x, y: pivot.y)
                g.rotate(by: .radians(swing))
                g.translateBy(x: tip.x - pivot.x, y: tip.y - pivot.y)
                g.scaleBy(x: 1 + grow, y: 1 + grow)
                let c = Self.rigCanvas, f = Self.tipFraction
                g.draw(rig, in: CGRect(x: -c.width * f.x, y: -c.height * (1 - f.y), width: c.width, height: c.height))
            }
        }
    }

    private func halftone(_ ctx: GraphicsContext, _ size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Ink.sun))
        let step: CGFloat = 9
        var dots = Path()
        var row = 0
        for y in stride(from: 0, through: size.height, by: step) {
            let shift = row % 2 == 0 ? 0 : step / 2
            for x in stride(from: shift, through: size.width, by: step) {
                // Dots grow towards the bottom-right corner, like printed comic shading.
                let k = (x / size.width + y / size.height) / 2
                let r = 0.4 + 2.2 * k * k
                dots.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
            }
            row += 1
        }
        ctx.fill(dots, with: .color(Ink.tomato.opacity(0.45)))
    }

    /// The same ring, speed lines and starburst as the on-screen tap, drawn with Canvas.
    private func burst(_ ctx: GraphicsContext, at c: CGPoint, e: Double, level: Int, star: Image) {
        let s: CGFloat = 78
        let ease = { (x: Double) in 1 - pow(1 - max(0, min(1, x)), 3) }

        if level >= 3 {
            let k: Double = e < 0.07 ? 0.25 + (1.14 - 0.25) * e / 0.07 : e < 0.16 ? 1.14 - 0.2 * (e - 0.07) / 0.09 : 0.94 + 0.06 * min(1, (e - 0.16) / 0.1)
            let d = s * 0.55 * CGFloat(k)
            var g = ctx
            g.opacity = e < 0.24 ? 1 : max(0, 1 - (e - 0.24) / 0.22)
            g.translateBy(x: c.x, y: c.y)
            g.rotate(by: .radians(e * 0.6))
            g.draw(star, in: CGRect(x: -d / 2, y: -d / 2, width: d, height: d))
        }

        let rp = min(1, e / 0.36)
        let r = s * (0.07 + 0.32 * CGFloat(ease(rp)))
        let ring = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        var rg = ctx
        rg.opacity = 1 - rp * rp
        let w = s * 0.045 * CGFloat(1 - rp) + 0.5
        rg.stroke(ring, with: .color(.white), lineWidth: w + 2.5)
        rg.stroke(ring, with: .color(Ink.ink), lineWidth: w)

        let n = 4 + 2 * level
        let head = CGFloat(ease(e / 0.2)), tail = CGFloat(ease((e - 0.07) / 0.22))
        guard head - tail > 0.01 else { return }
        let r0 = s * 0.17, len = s * (0.24 + 0.035 * CGFloat(level))
        var rays = Path()
        for i in 0..<n {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi + 0.3
            let reach: CGFloat = i % 2 == 0 ? 1 : 0.75
            let d = CGPoint(x: cos(a), y: sin(a))
            rays.move(to: CGPoint(x: c.x + d.x * (r0 + len * reach * tail), y: c.y + d.y * (r0 + len * reach * tail)))
            rays.addLine(to: CGPoint(x: c.x + d.x * (r0 + len * reach * head), y: c.y + d.y * (r0 + len * reach * head)))
        }
        let lw = s * (0.034 + 0.004 * CGFloat(level))
        ctx.stroke(rays, with: .color(.white), style: StrokeStyle(lineWidth: lw + 2.5, lineCap: .round))
        ctx.stroke(rays, with: .color(Ink.ink), style: StrokeStyle(lineWidth: lw, lineCap: .round))
    }
}
