import AppKit
import QuartzCore

/// One tap burst: an impact ring, speed lines that shoot outward, and for bigger taps
/// a popping starburst and flying dots. Driven by the frame loop via `update(to:)`,
/// so the same code also renders offline previews.
final class TapEffect {
    let layer = CALayer()
    let duration: Double

    private let ringHalo = CAShapeLayer(), ring = CAShapeLayer()
    private let raysHalo = CAShapeLayer(), rays = CAShapeLayer()
    private let dots = CAShapeLayer()
    private let star = CALayer()

    private let start: Double
    private let size: CGFloat
    private let intensity: Int
    private let bounce: Bool
    private let rayAngles: [(angle: CGFloat, reach: CGFloat)]
    private let dotAngles: [CGFloat]

    private static let ink = GloveArt.ink
    private static let halo = CGColor(gray: 1, alpha: 0.92)
    private static var stars: (calm: CGImage, hot: CGImage)?

    /// `intensity` 0 is a plain tap; 1...5 follow the click escalation.
    init(at point: CGPoint, size: CGFloat, intensity: Int, bounce: Bool, start: Double, contentsScale: CGFloat) {
        self.start = start
        self.size = bounce ? size * 0.7 : size
        self.intensity = bounce ? 0 : intensity
        self.bounce = bounce
        duration = intensity >= 3 && !bounce ? 0.46 : 0.38

        var rng = SplitMix(seed: UInt64(start * 1000) | 1)
        let n = self.intensity == 0 ? 0 : 4 + 2 * self.intensity
        let offset = CGFloat(rng.unit()) * .pi
        rayAngles = (0..<n).map { i in
            (offset + CGFloat(i) / CGFloat(n) * 2 * .pi + CGFloat(rng.unit() - 0.5) * 0.25,
             i % 2 == 0 ? 1 : 0.72 + CGFloat(rng.unit()) * 0.12)
        }
        dotAngles = self.intensity >= 4 ? (0..<7).map { _ in CGFloat(rng.unit()) * 2 * .pi } : []

        if Self.stars == nil {
            Self.stars = (ArtFactory.starburst(hot: false), ArtFactory.starburst(hot: true))
        }

        layer.position = point
        for l in [star, ringHalo, ring, raysHalo, rays, dots] as [CALayer] {
            l.contentsScale = contentsScale
            l.actions = ["position": NSNull(), "transform": NSNull(), "opacity": NSNull(), "path": NSNull(),
                         "lineWidth": NSNull(), "bounds": NSNull(), "contents": NSNull()]
            layer.addSublayer(l)
        }
        for (l, color) in [(ringHalo, Self.halo), (ring, Self.ink), (raysHalo, Self.halo), (rays, Self.ink)] {
            l.fillColor = nil
            l.strokeColor = color
            l.lineCap = .round
        }
        dots.fillColor = Self.ink
        dots.strokeColor = Self.halo
        dots.lineWidth = 2

        if self.intensity >= 3 {
            let d = self.size * (0.52 + 0.07 * CGFloat(self.intensity - 3))
            star.contents = self.intensity >= 5 ? Self.stars!.hot : Self.stars!.calm
            star.bounds = CGRect(x: 0, y: 0, width: d, height: d)
            star.position = .zero
        } else {
            star.isHidden = true
        }
        update(to: start)
    }

    /// Advances to time `t`; returns false once the effect has finished.
    @discardableResult
    func update(to t: Double) -> Bool {
        let e = t - start
        guard e <= duration else { return false }
        let s = size

        // Impact ring.
        let ringDur = bounce ? 0.28 : 0.36
        let rp = min(1, e / ringDur)
        let r = s * (0.07 + (intensity == 0 ? 0.22 : 0.32) * CGFloat(easeOutCubic(rp)))
        let ringPath = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil)
        let w = s * 0.045 * CGFloat(1 - rp) + 0.5
        ring.path = ringPath
        ringHalo.path = ringPath
        ring.lineWidth = w
        ringHalo.lineWidth = w + s * 0.03
        ring.opacity = Float(1 - rp * rp)
        ringHalo.opacity = ring.opacity

        // Speed lines: the head shoots out first, the tail chases it.
        if !rayAngles.isEmpty {
            let r0 = s * 0.17, len = s * (0.24 + 0.035 * CGFloat(intensity))
            let head = CGFloat(easeOutCubic(min(1, e / 0.2)))
            let tail = CGFloat(easeOutCubic(max(0, min(1, (e - 0.07) / 0.22))))
            let path = CGMutablePath()
            for (a, reach) in rayAngles where head - tail > 0.01 {
                let d = CGPoint(x: cos(a), y: sin(a))
                let from = r0 + len * reach * tail, to = r0 + len * reach * head
                path.move(to: CGPoint(x: d.x * from, y: d.y * from))
                path.addLine(to: CGPoint(x: d.x * to, y: d.y * to))
            }
            let lw = s * (0.034 + 0.004 * CGFloat(intensity))
            rays.path = path
            raysHalo.path = path
            rays.lineWidth = lw
            raysHalo.lineWidth = lw + s * 0.03
        }

        // Starburst pops with an overshoot, spins a little, then fades.
        if !star.isHidden {
            let k: Double
            switch e {
            case ..<0.07: k = lerp(0.25, 1.14, e / 0.07)
            case ..<0.16: k = lerp(1.14, 0.94, (e - 0.07) / 0.09)
            case ..<0.26: k = lerp(0.94, 1.0, (e - 0.16) / 0.1)
            default: k = lerp(1.0, 1.06, (e - 0.26) / (duration - 0.26))
            }
            star.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(e * 0.6)).scaledBy(x: CGFloat(k), y: CGFloat(k)))
            star.opacity = Float(e < 0.24 ? 1 : max(0, 1 - (e - 0.24) / (duration - 0.24)))
        }

        // Confetti dots for the wildest taps.
        if !dotAngles.isEmpty {
            let p = min(1, e / 0.4)
            let dr = s * 0.026 * CGFloat(1 - p) + 0.5
            let reach = s * (0.24 + 0.36 * CGFloat(easeOutCubic(p)))
            let path = CGMutablePath()
            for a in dotAngles {
                let c = CGPoint(x: cos(a) * reach, y: sin(a) * reach)
                path.addEllipse(in: CGRect(x: c.x - dr, y: c.y - dr, width: 2 * dr, height: 2 * dr))
            }
            dots.path = path
            dots.lineWidth = dr * 0.5
            dots.opacity = Float(1 - p * p)
        }
        return true
    }
}

private func easeOutCubic(_ x: Double) -> Double { 1 - pow(1 - max(0, min(1, x)), 3) }
private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * max(0, min(1, t)) }
