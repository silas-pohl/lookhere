import AppKit
import QuartzCore

/// One tap, drawn like comic inking: black line work with a thin white halo so it reads
/// on any background. Kept restrained; each level of click escalation adds one idea:
///   0  a ring that pops out and thins away
///   1  plus slim action lines flicking outward
///   2  more, longer action lines
///   3  plus a couple of four-point sparkles
///   4  plus a fine second ring following the first
///   5  a little bigger and bolder all round
/// Driven by the frame loop via `update(to:)`, so the same code also renders offline
/// previews and the panel header.
final class TapEffect {
    let layer = container()
    let duration: Double

    private let start: Double
    private let size: CGFloat
    private let level: Int
    private let ringHalo: CAShapeLayer, ring: CAShapeLayer
    private let echoHalo: CAShapeLayer, echo: CAShapeLayer
    private let linesHalo: CAShapeLayer, lines: CAShapeLayer
    private let sparklesHalo: CAShapeLayer, sparkles: CAShapeLayer
    /// Where along the ring the brush is heaviest.
    private let brushAngle: CGFloat
    private let lineAngles: [(angle: CGFloat, reach: CGFloat)]
    private let sparkleSpots: [(angle: CGFloat, radius: CGFloat, size: CGFloat, delay: Double, spin: CGFloat)]

    private static let ink = GloveArt.ink
    private static let halo = CGColor(gray: 1, alpha: 0.9)
    private static let lineCounts = [0, 6, 8, 8, 10, 10]
    private static let sparkleCounts = [0, 0, 0, 2, 3, 4]

    /// `intensity` 0 is a plain tap; 1...5 follow the click escalation.
    init(at point: CGPoint, size s: CGFloat, intensity: Int, start: Double, contentsScale: CGFloat) {
        self.start = start
        size = s
        let level = max(0, min(5, intensity))
        self.level = level
        duration = 0.32 + 0.025 * Double(level)
        var rng = SplitMix(seed: UInt64(start * 1000) | 1)
        // Heaviest towards the lower right, like the shading on the glove.
        brushAngle = -.pi / 4 + CGFloat(rng.unit() - 0.5) * 0.6

        let n = Self.lineCounts[level]
        let offset = CGFloat(rng.unit()) * 2 * .pi
        lineAngles = (0..<n).map { k in
            (offset + CGFloat(k) / CGFloat(n) * 2 * .pi, level >= 3 && k % 2 == 1 ? 0.65 : 1)
        }
        // Sparkles sit between action lines, spread around the ring.
        let m = Self.sparkleCounts[level]
        let first = Int(rng.unit() * 1000)
        sparkleSpots = (0..<m).map { k in
            let slot = (first + k * max(1, n / max(m, 1))) % max(n, 1)
            return (offset + (CGFloat(slot) + 0.5) / CGFloat(max(n, 1)) * 2 * .pi,
                    s * (0.52 + 0.05 * CGFloat(rng.unit())), s * (0.045 + 0.015 * CGFloat(rng.unit())),
                    0.03 + 0.04 * rng.unit(), CGFloat(rng.unit() - 0.5) * 2)
        }

        func shape(_ fill: CGColor?, _ stroke: CGColor? = nil, _ width: CGFloat = 0) -> CAShapeLayer {
            let l = CAShapeLayer()
            l.contentsScale = contentsScale
            l.actions = noActions
            l.fillColor = fill
            l.strokeColor = stroke
            l.lineWidth = width
            l.lineJoin = .round
            l.lineCap = .round
            return l
        }
        let haloWidth = s * 0.06
        ringHalo = shape(nil, Self.halo)
        ring = shape(Self.ink)
        echoHalo = shape(nil, Self.halo)
        echo = shape(nil, Self.ink)
        linesHalo = shape(nil, Self.halo, haloWidth)
        lines = shape(Self.ink)
        sparklesHalo = shape(nil, Self.halo, haloWidth)
        sparkles = shape(Self.ink)

        // Halos sit underneath everything, so the ink never gets cut by another halo.
        for l in [ringHalo, echoHalo, linesHalo, sparklesHalo, echo, ring, lines, sparkles] { layer.addSublayer(l) }
        layer.position = point
        update(to: start)
    }

    /// Advances to time `t`; returns false once the effect has finished.
    @discardableResult
    func update(to t: Double) -> Bool {
        let e = t - start
        guard e <= duration else { return false }
        let s = size, i = CGFloat(level)

        // Ring: appears at once at full weight, eases out and thins to nothing. The halo
        // thins with it, so no white ghost is left behind.
        let p = e / duration
        let thin = CGFloat(pow(max(0, 1 - p), 1.5))
        let radius = s * (0.085 + (0.15 + 0.022 * i) * CGFloat(easeOutQuart(p)))
        show(brushRing(radius: radius, width: s * (0.05 + 0.004 * i) * thin), in: ring, ringHalo)
        ringHalo.lineWidth = s * 0.06 * thin

        // Echo: a fine, even line that follows a beat behind and a little outside.
        let q = (e - 0.07) / (duration - 0.07)
        if level >= 4 && q > 0 && q < 1 {
            let k = CGFloat(pow(1 - q, 1.2))
            let r = radius + s * (0.06 + 0.045 * CGFloat(easeOutQuart(q)))
            let path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil)
            echo.lineWidth = s * 0.014 * k
            echoHalo.lineWidth = echo.lineWidth + s * 0.05 * k
            show(path, in: echo, echoHalo)
        } else {
            show(nil, in: echo, echoHalo)
        }

        // Action lines: long, slim streaks, pointed inside and rounded at the outer end, that
        // flick outward and shorten away.
        if !lineAngles.isEmpty {
            let head = CGFloat(easeOutQuart(e / 0.16)), tail = CGFloat(easeOutCubic((e - 0.04) / 0.2))
            let r0 = s * (0.21 + 0.015 * i), len = s * (0.17 + 0.03 * i)
            let w = s * (0.011 + 0.0012 * i)
            let path = CGMutablePath()
            // Dropped once short, before a streak shrinks into a stub.
            for (a, reach) in lineAngles where head - tail > 0.14 {
                streak(angle: a, from: r0 + len * reach * tail, to: r0 + len * reach * head,
                       width: w * min(1, (head - tail) * 2), into: path)
            }
            show(path, in: lines, linesHalo)
        }

        // Sparkles: each pops in a moment after the hit, turns a little and shrinks away.
        if !sparkleSpots.isEmpty {
            let path = CGMutablePath()
            for spot in sparkleSpots {
                let u = (e - spot.delay) / 0.26
                guard u > 0 && u < 1 else { continue }
                let k = CGFloat(u < 0.3 ? easeOutCubic(u / 0.3) * 1.1 : 1.1 * (1 - easeInQuad((u - 0.3) / 0.7)))
                // Gone while still recognisable, rather than shrinking to a speck.
                guard k > 0.3 else { continue }
                let c = CGPoint(x: cos(spot.angle) * spot.radius, y: sin(spot.angle) * spot.radius)
                let transform = CGAffineTransform(translationX: c.x, y: c.y)
                    .rotated(by: spot.spin * CGFloat(u) * 0.6).scaledBy(x: k * spot.size, y: k * spot.size)
                path.addPath(Self.sparkle, transform: transform)
            }
            show(path, in: sparkles, sparklesHalo)
        }
        return true
    }

    private func show(_ path: CGPath?, in ink: CAShapeLayer, _ halo: CAShapeLayer) {
        ink.isHidden = path == nil
        halo.isHidden = path == nil
        guard let path else { return }
        ink.path = path
        halo.path = path
    }

    /// A ring whose stroke is heaviest at `brushAngle`, easing to three quarters opposite.
    private func brushRing(radius r: CGFloat, width w: CGFloat) -> CGPath {
        let n = 96
        var outer: [CGPoint] = [], inner: [CGPoint] = []
        for k in 0..<n {
            let a = CGFloat(k) / CGFloat(n) * 2 * .pi
            let half = w * (0.875 + 0.125 * cos(a - brushAngle)) / 2
            outer.append(CGPoint(x: cos(a) * (r + half), y: sin(a) * (r + half)))
            inner.append(CGPoint(x: cos(a) * max(0, r - half), y: sin(a) * max(0, r - half)))
        }
        let path = CGMutablePath()
        path.addLines(between: outer)
        path.closeSubpath()
        path.addLines(between: inner.reversed())
        path.closeSubpath()
        return path
    }

    /// A streak from radius `from` to `to` along `angle`: a point inside, `w` either side and a
    /// round end outside.
    private func streak(angle a: CGFloat, from: CGFloat, to: CGFloat, width w: CGFloat, into path: CGMutablePath) {
        // Never fatter than a fifth of its length, so a short streak doesn't end as a dot.
        let w = min(w, (to - from) * 0.2)
        let d = CGPoint(x: cos(a), y: sin(a)), n = CGPoint(x: -d.y, y: d.x)
        path.move(to: CGPoint(x: d.x * from, y: d.y * from))
        path.addLine(to: CGPoint(x: d.x * to + n.x * w, y: d.y * to + n.y * w))
        path.addArc(center: CGPoint(x: d.x * to, y: d.y * to), radius: w,
                    startAngle: a + .pi / 2, endAngle: a - .pi / 2, clockwise: true)
        path.closeSubpath()
    }

    /// A unit four-point sparkle with gently pinched sides.
    private static let sparkle: CGPath = {
        let path = CGMutablePath()
        let tips = [CGPoint(x: 0, y: 1), CGPoint(x: 1, y: 0), CGPoint(x: 0, y: -1), CGPoint(x: -1, y: 0)]
        path.move(to: tips[0])
        for k in 0..<4 {
            let a = tips[k], b = tips[(k + 1) % 4]
            path.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) * 0.16, y: (a.y + b.y) * 0.16))
        }
        path.closeSubpath()
        return path
    }()
}

private let noActions: [String: CAAction] = [
    "position": NSNull(), "transform": NSNull(), "opacity": NSNull(), "path": NSNull(),
    "lineWidth": NSNull(), "bounds": NSNull(), "hidden": NSNull(),
]

private func container() -> CALayer {
    let l = CALayer()
    l.actions = noActions
    return l
}

func easeOutCubic(_ x: Double) -> Double { 1 - pow(1 - max(0, min(1, x)), 3) }
func easeOutQuart(_ x: Double) -> Double { 1 - pow(1 - max(0, min(1, x)), 4) }
func easeInQuad(_ x: Double) -> Double { pow(max(0, min(1, x)), 2) }
