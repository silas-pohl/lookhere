import AppKit
import AVFoundation
import Carbon.HIToolbox

// MARK: - System cursor

/// Hides the real cursor while Lookhere draws its own.
///
/// macOS re-shows the cursor on its own now and then (app switches, cursor shape
/// changes), so `reassert()` is called from the frame loop to catch that.
final class CursorHider {
    private typealias IsVisible = @convention(c) () -> Int32
    private var wanted = false
    private var hideCalls = 0
    private let isVisible: IsVisible?

    init() {
        // Background apps can't hide the cursor unless this private connection
        // property is set. Look it up dynamically; if it's missing, hiding just won't work.
        typealias DefaultConnection = @convention(c) () -> Int32
        typealias SetProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
        let any = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
        if let conn = dlsym(any, "_CGSDefaultConnection"), let set = dlsym(any, "CGSSetConnectionProperty") {
            let cid = unsafeBitCast(conn, to: DefaultConnection.self)()
            _ = unsafeBitCast(set, to: SetProperty.self)(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        }
        // CGCursorIsVisible is unavailable to Swift but still exported.
        isVisible = dlsym(any, "CGCursorIsVisible").map { unsafeBitCast($0, to: IsVisible.self) }
    }

    func setHidden(_ hide: Bool) {
        guard hide != wanted else { return }
        wanted = hide
        if hide {
            hideOnce()
        } else {
            // Hide calls are counted, so undo every one of them.
            for _ in 0..<hideCalls { CGDisplayShowCursor(CGMainDisplayID()) }
            hideCalls = 0
        }
    }

    func reassert() {
        guard wanted, let isVisible, isVisible() != 0 else { return }
        hideOnce()
    }

    private func hideOnce() {
        CGDisplayHideCursor(CGMainDisplayID())
        hideCalls += 1
    }
}

// MARK: - Hands-off mode click tap

/// Swallows mouse clicks system-wide (needs Accessibility permission) and reports left presses.
final class ClickTap {
    var onPress: (() -> Void)?
    /// Return true to let a click through, e.g. on Lookhere's own menu bar icon.
    var shouldPassThrough: (() -> Bool)?

    fileprivate var port: CFMachPort?
    private var source: CFRunLoopSource?

    var isRunning: Bool { port != nil }

    func start() -> Bool {
        guard port == nil else { return true }
        let types: [CGEventType] = [.leftMouseDown, .leftMouseUp, .leftMouseDragged,
                                    .rightMouseDown, .rightMouseUp, .rightMouseDragged,
                                    .otherMouseDown, .otherMouseUp, .otherMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let port = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                           options: .defaultTap, eventsOfInterest: mask,
                                           callback: clickTapCallback,
                                           userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        self.port = port
        source = CFMachPortCreateRunLoopSource(nil, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    func stop() {
        guard let port else { return }
        CGEvent.tapEnable(tap: port, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        CFMachPortInvalidate(port)
        self.port = nil
        source = nil
    }

    fileprivate var passing = false
}

private func clickTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                              refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<ClickTap>.fromOpaque(refcon).takeUnretainedValue()
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        if let port = tap.port { CGEvent.tapEnable(tap: port, enable: true) }
        return Unmanaged.passUnretained(event)
    case .leftMouseDown, .rightMouseDown, .otherMouseDown:
        // Decide once per press so the matching up/drag events follow the same path.
        tap.passing = tap.shouldPassThrough?() ?? false
        if tap.passing { return Unmanaged.passUnretained(event) }
        if type == .leftMouseDown { tap.onPress?() }
        return nil
    default:
        return tap.passing ? Unmanaged.passUnretained(event) : nil
    }
}

// MARK: - Global hotkeys

/// Carbon hotkeys: work system-wide without any permission prompt.
enum HotKeys {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var installed = false

    static func register(id: UInt32, keyCode: Int, modifiers: Int, _ handler: @escaping () -> Void) {
        install()
        handlers[id] = handler
        var ref: EventHotKeyRef?
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers),
                            EventHotKeyID(signature: OSType(0x4C4B_4852), id: id), // 'LKHR'
                            GetApplicationEventTarget(), 0, &ref)
    }

    private static func install() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            HotKeys.handlers[hk.id]?()
            return noErr
        }, 1, &spec, nil, nil)
    }
}
