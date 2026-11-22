import AppKit
import SwiftUI

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--preview"), i + 1 < args.count {
    Showcase.writePreviewSheet(to: args[i + 1])
    exit(0)
}
if let i = args.firstIndex(of: "--taps"), i + 1 < args.count {
    Showcase.writeTapSheet(to: args[i + 1])
    exit(0)
}
if let i = args.firstIndex(of: "--glove"), i + 1 < args.count {
    // Large single-glove render on white and dark, for art iteration.
    let style: PointerStyle = args.contains("fish") ? .fish : .glove
    let img = Showcase.pointer(style: style, color: .white, height: 560)
    let sheet = NSImage(size: CGSize(width: img.size.width * 2 + 120, height: 640))
    sheet.lockFocus()
    NSColor.white.setFill(); NSRect(x: 0, y: 0, width: sheet.size.width / 2, height: 640).fill()
    NSColor(white: 0.16, alpha: 1).setFill(); NSRect(x: sheet.size.width / 2, y: 0, width: sheet.size.width / 2, height: 640).fill()
    img.draw(in: NSRect(x: 30, y: 40, width: img.size.width, height: 560))
    img.draw(in: NSRect(x: sheet.size.width / 2 + 30, y: 40, width: img.size.width, height: 560))
    sheet.unlockFocus()
    if let tiff = sheet.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: args[i + 1]))
    }
    exit(0)
}
if args.contains("--simulate") {
    // Prints the engine's response to a burst of clicks at 120 fps, for checking motion.
    let engine = PointerEngine()
    let size = CGSize(width: 1440, height: 900), p = CGPoint(x: 700, y: 450)
    engine.enter(p, size)
    let clicks: Set<Int> = [12, 40, 60, 80, 100, 220]
    var impacts = 0
    for frame in 0..<330 {
        let t = Double(frame) / 120
        if clicks.contains(frame) { engine.press(at: t); print(String(format: "%.3f click", t)) }
        let f = engine.frame(p, size, t: t, dt: 1.0 / 120)
        impacts += f.impacts.count
        if !f.impacts.isEmpty || frame % 12 == 0 {
            print(String(format: "%.3f swing %+.3f scale %.3f lean %.1f° impacts %@ settled %@", t, f.swing, f.scale,
                         f.lean * 180 / .pi, f.impacts.description, f.settled ? "yes" : "no"))
        }
    }
    print("total impacts: \(impacts) for \(clicks.count) clicks")
    exit(0)
}
if let i = args.firstIndex(of: "--export-sounds"), i + 1 < args.count {
    exportSounds(to: args[i + 1])
    exit(0)
}
if let i = args.firstIndex(of: "--iconset"), i + 1 < args.count {
    Showcase.writeIconset(to: args[i + 1])
    exit(0)
}

if let i = args.firstIndex(of: "--settings-snapshot"), i + 1 < args.count {
    // Renders the popover content offscreen to a PNG, for checking the layout.
    _ = NSApplication.shared
    let view = NSHostingView(rootView: SettingsView(prefs: .shared, app: Lookhere(), toggleHandsOff: {}, visibility: PanelVisibility()))
    view.frame = CGRect(origin: .zero, size: view.fittingSize)
    let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = view
    view.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.5))
    let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
    view.cacheDisplay(in: view.bounds, to: rep)
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: args[i + 1]))
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
