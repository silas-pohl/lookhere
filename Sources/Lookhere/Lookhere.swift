import AppKit
import Combine
import QuartzCore
import os

let inputLog = Logger(subsystem: "com.silaspohl.lookhere", category: "input")

/// Owns the overlays and drives the pointer every frame.
final class Lookhere: ObservableObject {
    private let prefs = Prefs.shared
    private let engine = PointerEngine()
    private let sound = TapSound()
    private let hider = CursorHider()
    let clickTap = ClickTap()

    @Published private(set) var running = false
    @Published private(set) var handsOff = false

    private var overlays: [OverlayWindow] = []
    private var art: RigArt!
    private var effects: [TapEffect] = []
    private var timer: Timer?
    private var monitors: [Any] = []
    private var bag: Set<AnyCancellable> = []
    private var lastTime = 0.0
    private var lastPoint = CGPoint(x: -1, y: -1)
    private var lastClick = CGPoint.zero
    private var entered = false
    private var needsRedraw = true
    private var frameCount = 0
    private var loadedSound: (SoundChoice, String?)?

    init() {
        clickTap.onPress = { [weak self] in self?.press(from: "tap") }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.rebuildOverlays() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in self?.applyPrefs() }
        // Switching apps is the most common moment for macOS to bring the cursor back.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main) { [weak self] _ in self?.hider.reassert() }
        // Hop via GCD rather than RunLoop.main, which stalls while a slider is being dragged.
        prefs.changes.receive(on: DispatchQueue.main).sink { [weak self] in self?.applyPrefs() }.store(in: &bag)
        applyPrefs()
    }

    // MARK: Lifecycle

    func setRunning(_ on: Bool) {
        guard on != running else { return }
        running = on
        prefs.enabled = on
        if on {
            rebuildOverlays()
            entered = false
            needsRedraw = true
            // Global monitors miss clicks in our own windows (e.g. Settings), so watch both.
            if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] _ in
                guard let self, !self.handsOff else { return }
                self.press(from: "global")
            }) { monitors.append(m) }
            if let m = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] e in
                self?.press(from: "local")
                return e
            }) { monitors.append(m) }
            let t = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in self?.tick() }
            RunLoop.main.add(t, forMode: .common)
            timer = t
            tick()
        } else {
            timer?.invalidate()
            timer = nil
            monitors.forEach(NSEvent.removeMonitor)
            monitors = []
            overlays.forEach { $0.orderOut(nil) }
            overlays = []
            if handsOff { _ = setHandsOff(false) }
        }
        hider.setHidden(on && prefs.hideSystemCursor)
    }

    /// Returns false if the click tap couldn't be created (no Accessibility permission).
    func setHandsOff(_ on: Bool) -> Bool {
        if on {
            if !running { setRunning(true) }
            guard clickTap.start() else { return false }
        } else {
            clickTap.stop()
        }
        handsOff = on
        return true
    }

    func shutdown() {
        clickTap.stop()
        hider.setHidden(false)
    }

    /// Returns false if the custom sound file couldn't be loaded.
    @discardableResult
    func reloadSound() -> Bool {
        loadedSound = (prefs.soundChoice, prefs.customSoundPath)
        return sound.load(prefs.soundChoice, customPath: prefs.customSoundPath)
    }

    /// Plays the current sound once at normal pitch, e.g. when picking it in the panel.
    func previewSound() {
        if loadedSound.map({ $0 != prefs.soundChoice || $1 != prefs.customSoundPath }) ?? true { reloadSound() }
        sound.play(volume: Float(prefs.volume), vary: false)
    }

    private func applyPrefs() {
        engine.mood = prefs.mood
        engine.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        art = ArtFactory.rig(style: prefs.style, color: prefs.gloveColor, size: prefs.size, stick: prefs.stick)
        overlays.forEach { $0.overlay.apply(art) }
        if loadedSound.map({ $0 != prefs.soundChoice || $1 != prefs.customSoundPath }) ?? true { reloadSound() }
        hider.setHidden(running && prefs.hideSystemCursor)
        needsRedraw = true
    }

    private func rebuildOverlays() {
        guard running else { return }
        overlays.forEach { $0.orderOut(nil) }
        overlays = NSScreen.screens.map { screen in
            let w = OverlayWindow(screen: screen)
            w.overlay.apply(art)
            w.orderFrontRegardless()
            return w
        }
        needsRedraw = true
    }

    // MARK: Frame loop

    /// One physical click can arrive through more than one monitor (menu-bar clicks are
    /// routed via a system process on recent macOS), so ignore repeats within a few ms.
    private var lastPress = -1.0

    private func press(from source: String) {
        let now = CACurrentMediaTime()
        guard now - lastPress > 0.04 else {
            inputLog.notice("press from \(source, privacy: .public) ignored as duplicate")
            return
        }
        lastPress = now
        inputLog.notice("press from \(source, privacy: .public)")
        lastClick = NSEvent.mouseLocation
        // The sound goes with the click itself; waiting for the pointer's impact made it lag.
        if prefs.sound { sound.play(volume: Float(prefs.volume)) }
        engine.press(at: CACurrentMediaTime())
        needsRedraw = true
    }

    private func tick() {
        frameCount += 1
        if frameCount % 6 == 0 { hider.reassert() }
        let t = CACurrentMediaTime()
        let dt = lastTime == 0 ? 0 : t - lastTime
        lastTime = t

        let p = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(p, $0.frame, false) }) ?? NSScreen.main else { return }
        let local = CGPoint(x: p.x - screen.frame.minX, y: p.y - screen.frame.minY)
        if !entered {
            engine.enter(local, screen.frame.size)
            entered = true
        }

        let f = engine.frame(local, screen.frame.size, t: t, dt: dt)
        defer { needsRedraw = !f.settled || !effects.isEmpty }
        if f.settled && !needsRedraw && p == lastPoint && f.impacts.isEmpty && effects.isEmpty { return }
        lastPoint = p

        // Lean the rig, then swing it about a pivot up the stick.
        let tilt = CGFloat(f.lean), swing = CGFloat(f.swing)
        let pivot = CGPoint(x: sin(tilt) * art.pivotDistance, y: -cos(tilt) * art.pivotDistance)
        let transform = CGAffineTransform(rotationAngle: tilt)
            .concatenating(CGAffineTransform(translationX: -pivot.x, y: -pivot.y))
            .concatenating(CGAffineTransform(rotationAngle: -swing))
            .concatenating(CGAffineTransform(translationX: pivot.x, y: pivot.y))

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for w in overlays {
            let tip = CGPoint(x: p.x - w.screenFrame.minX, y: p.y - w.screenFrame.minY)
            w.overlay.update(tip: tip, transform: transform, handScale: CGFloat(f.scale))
        }
        CATransaction.commit()

        for intensity in f.impacts {
            guard prefs.flashes,
                  let w = overlays.first(where: { NSMouseInRect(lastClick, $0.screenFrame, false) }) else { continue }
            let at = CGPoint(x: lastClick.x - w.screenFrame.minX, y: lastClick.y - w.screenFrame.minY)
            let effect = TapEffect(at: at, size: art.flashDiameter, intensity: intensity,
                                   start: t, contentsScale: w.overlay.contentsScale)
            w.overlay.addEffect(effect)
            effects.append(effect)
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        effects.removeAll { effect in
            if effect.update(to: t) { return false }
            effect.layer.removeFromSuperlayer()
            return true
        }
        CATransaction.commit()
    }
}
