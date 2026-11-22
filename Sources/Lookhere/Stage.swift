import SwiftUI

/// The panel's header: a little comic panel where the current pointer pokes on a loop.
struct PokeStage: View {
    let style: PointerStyle
    let color: GloveColor
    let stick: StickColor
    /// Whether taps show the ring.
    let ring: Bool
    let animating: Bool

    private static let rigCanvas = CGSize(width: 120, height: 130)
    private static let tipFraction = CGPoint(x: 0.32, y: 0.88)
    private static let cycle = 2.4
    /// Two taps per loop; the second one hits harder.
    private static let taps: [(start: Double, level: Int)] = [(0.2, 1), (0.55, 4)]

    var body: some View {
        let rig = Image(nsImage: Showcase.rig(style: style, color: color, stick: stick, size: 0.1,
                                              canvas: Self.rigCanvas, tipFraction: Self.tipFraction))
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !animating)) { timeline in
            let t = animating ? timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.cycle) : 0
            Canvas { ctx, size in
                halftone(ctx, size)
                let tip = CGPoint(x: size.width * 0.66, y: size.height * 0.36)

                if ring {
                    for (k, tap) in Self.taps.enumerated() {
                        let e = t - tap.start - 0.09
                        if e >= 0, let frame = Self.effectFrame(tap: k, level: tap.level, e: e) {
                            ctx.draw(Image(decorative: frame, scale: 2), at: tip)
                        }
                    }
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

    // The header plays the real effect. It's a pure function of time, so one instance per
    // tap is reused for every loop.
    private static var effects: [Int: TapEffect] = [:]
    private static let effectSize: CGFloat = 78, frameSide: CGFloat = 200

    /// The effect `e` seconds in, rendered at 2x, or nil once it has finished.
    private static func effectFrame(tap: Int, level: Int, e: Double) -> CGImage? {
        // Fixed start times keep each tap's random layout the same on every loop.
        let start = Double(tap + 1) * 7
        let effect = effects[tap] ?? {
            let made = TapEffect(at: .zero, size: effectSize, intensity: level, start: start, contentsScale: 2)
            effects[tap] = made
            return made
        }()
        guard effect.update(to: start + e) else { return nil }
        let ctx = ArtFactory.bitmap(Int(frameSide * 2), Int(frameSide * 2))
        ctx.scaleBy(x: 2, y: 2)
        ctx.translateBy(x: frameSide / 2, y: frameSide / 2)
        effect.layer.render(in: ctx)
        return ctx.makeImage()
    }
}
