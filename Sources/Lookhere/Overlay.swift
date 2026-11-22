import AppKit
import QuartzCore

/// Transparent, click-through window covering one display, above everything including menus.
final class OverlayWindow: NSPanel {
    let overlay: OverlayView
    let screenFrame: CGRect

    init(screen: NSScreen) {
        screenFrame = screen.frame
        overlay = OverlayView(frame: CGRect(origin: .zero, size: screen.frame.size), scale: screen.backingScaleFactor)
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.cursorWindow)))
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        contentView = overlay
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class OverlayView: NSView {
    private let rig = CALayer()
    private let stick = CALayer()
    private let hand = CALayer()
    private let scale: CGFloat

    init(frame: CGRect, scale: CGFloat) {
        self.scale = scale
        super.init(frame: frame)
        layer = CALayer()
        wantsLayer = true
        layer?.contentsScale = scale

        for l in [rig, stick, hand] as [CALayer] {
            l.contentsScale = scale
            l.actions = ["position": NSNull(), "transform": NSNull(), "bounds": NSNull(), "contents": NSNull()]
        }
        hand.minificationFilter = .trilinear
        stick.minificationFilter = .trilinear
        rig.addSublayer(stick)
        rig.addSublayer(hand)
        layer?.addSublayer(rig)
    }

    required init?(coder: NSCoder) { fatalError() }

    func apply(_ art: RigArt) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        hand.contents = art.hand
        hand.bounds = CGRect(origin: .zero, size: art.handSize)
        hand.anchorPoint = CGPoint(x: art.tip.x / art.handSize.width, y: art.tip.y / art.handSize.height)
        hand.position = .zero

        stick.isHidden = art.stick == nil
        stick.contents = art.stick
        stick.frame = art.stickFrame
        CATransaction.commit()
    }

    /// `tip` is the cursor in this view's coordinates; must be called inside a CATransaction.
    func update(tip: CGPoint, transform: CGAffineTransform, handScale: CGFloat) {
        rig.position = tip
        rig.setAffineTransform(transform)
        hand.setAffineTransform(CGAffineTransform(scaleX: handScale, y: handScale))
    }

    var contentsScale: CGFloat { scale }

    func addEffect(_ effect: TapEffect) {
        layer?.insertSublayer(effect.layer, below: rig)
    }
}
