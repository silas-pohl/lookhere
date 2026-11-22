import AppKit

/// Static renders of the pointer for UI: settings previews, the menu bar icon and the app icon.
enum Showcase {
    /// The rig at its resting lean, as it appears on screen, with the tip at `tipFraction` of the canvas.
    static func rig(style: PointerStyle, color: GloveColor, stick: StickColor, size: Double = 0.25,
                    canvas: CGSize, tipFraction: CGPoint = CGPoint(x: 0.4, y: 0.86), scale: CGFloat = 2) -> NSImage {
        let art = ArtFactory.rig(style: style, color: color, size: size, stick: stick)
        let ctx = ArtFactory.bitmap(Int(canvas.width * scale), Int(canvas.height * scale))
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: canvas.width * tipFraction.x, y: canvas.height * tipFraction.y)
        ctx.rotate(by: CGFloat(restLean))
        if let stick = art.stick { ctx.draw(stick, in: art.stickFrame) }
        ctx.draw(art.hand, in: CGRect(x: -art.tip.x, y: -art.tip.y, width: art.handSize.width, height: art.handSize.height))
        return NSImage(cgImage: ctx.makeImage()!, size: canvas)
    }

    /// Just the pointer, upright, fitted to `height` points.
    static func pointer(style: PointerStyle, color: GloveColor, height: CGFloat) -> NSImage {
        let (image, _) = ArtFactory.renderPointer(style: style, color: color, unit: 3)
        let w = height * CGFloat(image.width) / CGFloat(image.height)
        return NSImage(cgImage: image, size: CGSize(width: w, height: height))
    }

    /// Template silhouette of the hand for the menu bar.
    static func menuBarIcon() -> NSImage {
        let (image, _) = ArtFactory.renderPointer(style: .glove, color: .white, unit: 1)
        let ctx = ArtFactory.bitmap(image.width, image.height)
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        ctx.clip(to: rect, mask: image)
        ctx.setFillColor(.black)
        ctx.fill(rect)
        let h: CGFloat = 17
        let icon = NSImage(cgImage: ctx.makeImage()!, size: CGSize(width: h * CGFloat(image.width) / CGFloat(image.height), height: h))
        icon.isTemplate = true
        return icon
    }

    /// App icon: the leaning hand on a warm rounded square.
    static func appIcon(pixels: Int) -> CGImage {
        let s = CGFloat(pixels)
        let ctx = ArtFactory.bitmap(pixels, pixels)
        let inset = s * 0.1, side = s - 2 * inset
        let square = CGPath(roundedRect: CGRect(x: inset, y: inset, width: side, height: side),
                            cornerWidth: side * 0.225, cornerHeight: side * 0.225, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.03, color: CGColor(gray: 0, alpha: 0.3))
        ctx.addPath(square)
        ctx.setFillColor(.white)
        ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(square)
        ctx.clip()
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [
            CGColor(srgbRed: 1.0, green: 0.80, blue: 0.36, alpha: 1),
            CGColor(srgbRed: 1.0, green: 0.45, blue: 0.38, alpha: 1),
        ] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

        let (hand, tip) = ArtFactory.renderPointer(style: .glove, color: .white, unit: 6)
        let k = side * 0.62 / CGFloat(hand.height)
        ctx.translateBy(x: s * 0.44, y: s * 0.8)
        ctx.rotate(by: CGFloat(restLean))
        let stickW = side * 0.07
        let stick = ArtFactory.stickImage(color: StickColor.ink.color!, size: CGSize(width: stickW, height: side * 0.7))
        ctx.draw(stick, in: CGRect(x: CGFloat(hand.width) * k * 0.48 - tip.x * k - stickW / 2, y: -side * 0.95, width: stickW, height: side * 0.7))
        ctx.draw(hand, in: CGRect(x: -tip.x * k, y: -tip.y * k, width: CGFloat(hand.width) * k, height: CGFloat(hand.height) * k))
        ctx.restoreGState()
        return ctx.makeImage()!
    }

    static func writeIconset(to dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for base in [16, 32, 128, 256, 512] {
            for (mult, suffix) in [(1, ""), (2, "@2x")] {
                let rep = NSBitmapImageRep(cgImage: appIcon(pixels: base * mult))
                let url = URL(fileURLWithPath: dir).appendingPathComponent("icon_\(base)x\(base)\(suffix).png")
                try? rep.representation(using: .png, properties: [:])?.write(to: url)
            }
        }
    }

    /// `Lookhere --preview out.png`: pointers, glove colours, tap effects over time, and icons on one sheet.
    static func writePreviewSheet(to path: String) {
        let cell = CGSize(width: 220, height: 260)
        let cols = 6
        let sheet = NSImage(size: CGSize(width: cell.width * CGFloat(cols), height: cell.height * 4))
        sheet.lockFocus()
        NSColor(white: 0.94, alpha: 1).setFill()
        NSRect(origin: .zero, size: sheet.size).fill()

        let rigs: [(PointerStyle, GloveColor, StickColor)] = [(.glove, .white, .ink), (.fish, .white, .wood), (.arrow, .white, .ink), (.rude, .sunny, .wood)]
        for (i, (style, color, stick)) in rigs.enumerated() {
            rig(style: style, color: color, stick: stick, size: 0.5, canvas: cell)
                .draw(in: NSRect(x: CGFloat(i) * cell.width, y: cell.height * 3, width: cell.width, height: cell.height))
        }
        NSImage(cgImage: appIcon(pixels: 512), size: CGSize(width: 200, height: 200))
            .draw(in: NSRect(x: cell.width * 4, y: cell.height * 3 + 30, width: 200, height: 200))
        menuBarIcon().draw(in: NSRect(x: cell.width * 5 + 90, y: cell.height * 3 + 110, width: 30, height: 34))

        for (i, color) in GloveColor.allCases.enumerated() {
            pointer(style: .glove, color: color, height: 210)
                .draw(in: NSRect(x: CGFloat(i) * cell.width + 25, y: cell.height * 2 + 25, width: 170, height: 210))
        }

        // Row 2: each intensity mid-burst. Row 1: the wildest tap over time.
        let samples: [(intensity: Int, t: Double, row: Int)] =
            (0...5).map { ($0, 0.11, 1) } + [0.03, 0.07, 0.13, 0.22, 0.33, 0.44].map { (5, $0, 0) }
        for (i, sample) in samples.enumerated() {
            let ctx = ArtFactory.bitmap(Int(cell.width * 2), Int(cell.height * 2))
            ctx.scaleBy(x: 2, y: 2)
            // render(in:) ignores the root layer's own position, so centre via the context instead.
            ctx.translateBy(x: cell.width / 2, y: cell.height / 2)
            let effect = TapEffect(at: .zero, size: 160, intensity: sample.intensity, start: 0, contentsScale: 2)
            effect.update(to: sample.t)
            effect.layer.render(in: ctx)
            NSImage(cgImage: ctx.makeImage()!, size: cell)
                .draw(in: NSRect(x: CGFloat(i % cols) * cell.width, y: CGFloat(sample.row) * cell.height, width: cell.width, height: cell.height))
        }
        sheet.unlockFocus()
        if let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
    }

    /// `Lookhere --taps out.png`: every tap level (rows, top to bottom) over time (columns),
    /// at the default pointer size, on alternating light and dark backgrounds.
    static func writeTapSheet(to path: String) {
        let cell = CGSize(width: 200, height: 200)
        let times = [0.02, 0.06, 0.1, 0.15, 0.22, 0.3]
        let size = ArtFactory.rig(style: .glove, color: .white, size: 0.25, stick: .ink).flashDiameter
        let sheet = NSImage(size: CGSize(width: cell.width * CGFloat(times.count), height: cell.height * 6))
        sheet.lockFocus()
        for level in 0...5 {
            let y = CGFloat(5 - level) * cell.height
            NSColor(white: level % 2 == 0 ? 0.95 : 0.16, alpha: 1).setFill()
            NSRect(x: 0, y: y, width: sheet.size.width, height: cell.height).fill()
            for (col, t) in times.enumerated() {
                let ctx = ArtFactory.bitmap(Int(cell.width * 2), Int(cell.height * 2))
                ctx.scaleBy(x: 2, y: 2)
                ctx.translateBy(x: cell.width / 2, y: cell.height / 2)
                let effect = TapEffect(at: .zero, size: size, intensity: level, start: 1, contentsScale: 2)
                guard effect.update(to: 1 + t) else { continue }
                effect.layer.render(in: ctx)
                NSImage(cgImage: ctx.makeImage()!, size: cell)
                    .draw(in: NSRect(x: CGFloat(col) * cell.width, y: y, width: cell.width, height: cell.height))
            }
        }
        sheet.unlockFocus()
        if let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
    }
}
