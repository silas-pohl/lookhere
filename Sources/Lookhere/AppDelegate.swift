import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI
import QuartzCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let prefs = Prefs.shared
    private var lookhere: Lookhere!
    private var statusItem: NSStatusItem!
    private var panel: StatusPanel!
    private var host: NSHostingView<SettingsView>!
    private var outsideClickMonitor: Any?
    private let visibility = PanelVisibility()
    /// When the panel last closed; a click on the icon right after is the same click that closed it.
    private var lastClose = Date.distantPast
    private var bag: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        lookhere = Lookhere()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Showcase.menuBarIcon()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)
        // Act on mouse-down so a single click always toggles, without waiting for mouse-up.
        statusItem.button?.sendAction(on: [.leftMouseDown, .rightMouseDown])

        host = NSHostingView(rootView: SettingsView(prefs: prefs, app: lookhere,
                                                    toggleHandsOff: { [weak self] in self?.toggleHandsOff() },
                                                    visibility: visibility))
        panel = StatusPanel(content: host)
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: panel,
                                               queue: .main) { [weak self] _ in self?.closePanel(reason: "resigned key") }
        // Sections appear and disappear (glove colours, sound options), so keep the panel fitted.
        prefs.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] in self?.fitPanel() }.store(in: &bag)

        lookhere.clickTap.shouldPassThrough = { [weak self] in
            guard let frame = self?.statusItem.button?.window?.frame else { return false }
            return NSMouseInRect(NSEvent.mouseLocation, frame, false)
        }

        let ctrlOpt = controlKey | optionKey
        HotKeys.register(id: 1, keyCode: kVK_ANSI_L, modifiers: ctrlOpt) { [weak self] in
            guard let self else { return }
            lookhere.setRunning(!lookhere.running)
        }
        HotKeys.register(id: 2, keyCode: kVK_ANSI_H, modifiers: ctrlOpt) { [weak self] in self?.toggleHandsOff() }

        lookhere.$running.combineLatest(lookhere.$handsOff)
            .sink { [weak self] running, presenting in
                self?.statusItem.button?.appearsDisabled = !running
                self?.statusItem.button?.title = presenting ? " ●" : ""
            }
            .store(in: &bag)

        lookhere.setRunning(prefs.enabled)

        if !UserDefaults.standard.bool(forKey: "welcomed") {
            UserDefaults.standard.set(true, forKey: "welcomed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.openPanel() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        lookhere.shutdown()
    }

    @objc private func togglePanel() {
        let sinceClose = Date().timeIntervalSince(lastClose)
        inputLog.notice("icon clicked; panel visible: \(self.panel.isVisible), since close: \(sinceClose, format: .fixed(precision: 3))s")
        if panel.isVisible {
            closePanel(reason: "icon")
        } else if sinceClose > 0.3 {
            openPanel()
        }
    }

    private func openPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        host.layoutSubtreeIfNeeded()
        panel.setContentSize(host.fittingSize)
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen?.visibleFrame ?? NSScreen.main!.visibleFrame
        var origin = CGPoint(x: anchor.midX - panel.frame.width / 2, y: anchor.minY - panel.frame.height - 2)
        origin.x = min(max(origin.x, screen.minX + 6), screen.maxX - panel.frame.width - 6)
        panel.setFrameOrigin(origin)
        visibility.shown = true
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }
        button.highlight(true)
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel(reason: "outside click")
        }
        inputLog.notice("panel opened")
    }

    private func closePanel(reason: String) {
        guard panel.isVisible else { return }
        let start = CACurrentMediaTime()
        lastClose = Date()
        panel.orderOut(nil)
        visibility.shown = false
        statusItem.button?.highlight(false)
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m) }
        outsideClickMonitor = nil
        inputLog.notice("panel closed (\(reason, privacy: .public)) in \((CACurrentMediaTime() - start) * 1000, format: .fixed(precision: 1))ms")
    }

    /// Resize to the SwiftUI content, keeping the top edge pinned under the menu bar.
    private func fitPanel() {
        DispatchQueue.main.async { [self] in
            host.layoutSubtreeIfNeeded()
            let size = host.fittingSize
            guard size != panel.frame.size else { return }
            let top = panel.frame.maxY
            panel.setFrame(CGRect(x: panel.frame.minX, y: top - size.height, width: size.width, height: size.height), display: true)
        }
    }

    private func toggleHandsOff() {
        if !lookhere.setHandsOff(!lookhere.handsOff) {
            requestAccessibility()
        }
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) { return }
        closePanel(reason: "accessibility prompt")
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Hands-off Mode needs Accessibility access"
        alert.informativeText = "Turn on Lookhere in System Settings → Privacy & Security → Accessibility, then press ⌃⌥H again."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Borderless, transparent panel that hosts the comic-style settings. It can take key
/// focus for its controls without activating the app or stealing focus from the frontmost one.
final class StatusPanel: NSPanel {
    init(content: NSView) {
        super.init(contentRect: CGRect(origin: .zero, size: content.fittingSize),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        contentView = content
    }

    override var canBecomeKey: Bool { true }
}
