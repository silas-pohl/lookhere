import AppKit

/// Pre-rendered pointer art. Lengths are in points; `tip` is in the hand image's
/// bottom-left-origin space so it can be used directly as a CALayer anchor point.
struct RigArt {
    let hand: CGImage
    let handSize: CGSize
    let tip: CGPoint
    /// Pre-rendered pole and where it sits in rig space (fingertip at the origin, stick pointing down).
    let stick: CGImage?
    let stickFrame: CGRect
    let flashDiameter: CGFloat

    /// The swing pivots this far up the stick from the fingertip.
    var pivotDistance: CGFloat { 2.5 * handSize.height }
}

enum ArtFactory {
    static let minScale: CGFloat = 0.6, maxScale: CGFloat = 3.5
    private static let baseHandHeight: CGFloat = 68
    /// Pixels per drawing unit when rasterising; high enough to stay crisp at the Huge size on Retina.
    private static let rasterScale: CGFloat = 2.2

    // Rasterising is the slow part, so cache it; resizing then only changes layer geometry.
    private static var pointerCache: [String: (CGImage, CGPoint)] = [:]
    private static var stickCache: [StickColor: CGImage] = [:]

    /// Pointer scale for a 0...1 size setting, on a log curve so each bit of slider feels even.
    static func scale(forSize size: Double) -> CGFloat {
        minScale * pow(maxScale / minScale, CGFloat(max(0, min(1, size))))
    }

    static func rig(style: PointerStyle, color: GloveColor, size: Double, stick: StickColor) -> RigArt {
        let s = scale(forSize: size)
        let key = "\(style.rawValue)-\(color.rawValue)"
        let (image, tipPx) = pointerCache[key] ?? {
            let r = renderPointer(style: style, color: color, unit: rasterScale)
            pointerCache[key] = r
            return r
        }()
        let pxToPt = baseHandHeight * s / CGFloat(image.height)
        let handSize = CGSize(width: CGFloat(image.width) * pxToPt, height: CGFloat(image.height) * pxToPt)
        let tip = CGPoint(x: tipPx.x * pxToPt, y: tipPx.y * pxToPt)

        // The pole starts hidden inside the cuff and runs down from its centre.
        // A chunky pole, about 11 pt at the default size.
        let w = 11.5 * s
        // Long enough to run off the bottom of the screen at any size.
        let length = max(900, 560 * s)
        let ptPerUnit = rasterScale * pxToPt
        let top: CGFloat, centreX: CGFloat
        if let a = style.anchors {
            top = (a.stick.y - 10 - a.tip.y) * ptPerUnit
            centreX = (a.stick.x - a.tip.x) * ptPerUnit
        } else {
            top = handSize.height * 0.5
            centreX = 0
        }
        let frame = CGRect(x: centreX - w / 2, y: -length, width: w, height: length - top)
        let stickImage = stick.color.map { c in
            stickCache[stick] ?? {
                let img = Self.stickImage(color: c, size: CGSize(width: 24, height: 1200))
                stickCache[stick] = img
                return img
            }()
        }
        return RigArt(
            hand: image,
            handSize: handSize,
            tip: tip,
            stick: stickImage,
            stickFrame: frame,
            flashDiameter: 130 * s
        )
    }

    /// A solid rounded pole, slightly darker at the edges for roundness, fading out only at the far end.
    static func stickImage(color: NSColor, size: CGSize) -> CGImage {
        let k: CGFloat = 3
        let ctx = bitmap(Int(size.width * k), Int(size.height * k))
        ctx.scaleBy(x: k, y: k)
        let rect = CGRect(origin: .zero, size: size)
        let r = size.width / 2
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil))
        ctx.clip()
        let base = color.usingColorSpace(.sRGB) ?? color
        let edge = (base.blended(withFraction: 0.25, of: .black) ?? base).cgColor
        let across = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                colors: [edge, base.cgColor, base.cgColor, edge] as CFArray,
                                locations: [0, 0.3, 0.6, 1])!
        ctx.drawLinearGradient(across, start: .zero, end: CGPoint(x: size.width, y: 0), options: [])

        // Only the last stretch fades, and it fades to transparent rather than towards white.
        ctx.setBlendMode(.destinationIn)
        let along = CGGradient(colorsSpace: nil, colors: [
            CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 1), CGColor(gray: 0, alpha: 1),
        ] as CFArray, locations: [0, 0.12, 1])!
        ctx.drawLinearGradient(along, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        return ctx.makeImage()!
    }

    /// The pointer alone, cropped, with its tip location in pixels (bottom-left origin).
    static func renderPointer(style: PointerStyle, color: GloveColor, unit: CGFloat) -> (CGImage, CGPoint) {
        let size = GloveArt.canvas
        let ctx = bitmap(Int(size.width * unit), Int(size.height * unit))
        ctx.scaleBy(x: unit, y: unit)
        if style == .arrow {
            ctx.translateBy(x: 15, y: 15)
            HandDrawing.drawArrow(in: ctx)
        } else {
            // Glove and fish paths are authored y-down like SVG.
            ctx.translateBy(x: 10, y: size.height - 10)
            ctx.scaleBy(x: 1, y: -1)
            switch style {
            case .fish: FishArt.draw(in: ctx)
            case .rude: GloveArt.draw(in: ctx, fill: color.color, picture: .middleFinger)
            default: GloveArt.draw(in: ctx, fill: color.color)
            }
        }
        return cropAndFindTip(ctx)
    }

    /// Crops to the opaque pixels; the tip is the centre of the topmost opaque rows.
    private static func cropAndFindTip(_ ctx: CGContext) -> (CGImage, CGPoint) {
        let w = ctx.width, h = ctx.height, stride = ctx.bytesPerRow
        let px = ctx.data!.assumingMemoryBound(to: UInt8.self)
        var minX = w, maxX = -1, minRow = h, maxRow = -1
        for row in 0..<h {
            for x in 0..<w where px[row * stride + x * 4 + 3] > 12 {
                minX = min(minX, x); maxX = max(maxX, x)
                minRow = min(minRow, row); maxRow = max(maxRow, row)
            }
        }
        let full = ctx.makeImage()!
        guard maxX >= 0 else { return (full, CGPoint(x: w / 2, y: h)) }

        // Find the tip on solid pixels only, ignoring the faint drop-shadow halo.
        var tipRow = minRow
        while tipRow < maxRow, !(minX...maxX).contains(where: { px[tipRow * stride + $0 * 4 + 3] > 128 }) { tipRow += 1 }
        let band = max(2, (maxRow - minRow) / 60)
        var sum = 0, n = 0
        for row in tipRow...min(tipRow + band, maxRow) {
            for x in minX...maxX where px[row * stride + x * 4 + 3] > 128 { sum += x; n += 1 }
        }
        let tipX = n > 0 ? Double(sum) / Double(n) : Double(minX + maxX) / 2

        // Bitmap rows run top-down; crop rects use the same orientation.
        let crop = CGRect(x: minX, y: minRow, width: maxX - minX + 1, height: maxRow - minRow + 1)
        let image = full.cropping(to: crop)!
        return (image, CGPoint(x: tipX - Double(minX), y: Double(maxRow - tipRow) + 1))
    }

    static func bitmap(_ w: Int, _ h: Int) -> CGContext {
        CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }
}

/// Deterministic PRNG so each flash variant always looks the same.
struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func unit() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
}
