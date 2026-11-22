import AppKit
import Combine

enum PointerStyle: String, CaseIterable, Identifiable {
    case glove, arrow, fish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glove: return "Glove"
        case .arrow: return "Arrow"
        case .fish: return "Fishy"
        }
    }

    /// Fingertip and where the stick attaches, in the SVG-style authoring space (nil for the arrow).
    var anchors: (tip: CGPoint, stick: CGPoint)? {
        switch self {
        case .glove: return (GloveArt.tip, GloveArt.cuffCentre)
        case .fish: return (FishArt.tip, FishArt.stickAnchor)
        case .arrow: return nil
        }
    }
}

enum GloveColor: String, CaseIterable, Identifiable {
    case white, sunny, cherry, bubblegum, mint, sky

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var color: NSColor {
        switch self {
        case .white: return NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)
        case .sunny: return NSColor(srgbRed: 1.00, green: 0.84, blue: 0.30, alpha: 1)
        case .cherry: return NSColor(srgbRed: 0.95, green: 0.33, blue: 0.33, alpha: 1)
        case .bubblegum: return NSColor(srgbRed: 1.00, green: 0.62, blue: 0.80, alpha: 1)
        case .mint: return NSColor(srgbRed: 0.52, green: 0.88, blue: 0.70, alpha: 1)
        case .sky: return NSColor(srgbRed: 0.50, green: 0.76, blue: 1.00, alpha: 1)
        }
    }
}

enum StickColor: String, CaseIterable, Identifiable {
    case ink, wood, chalk, cherry, ocean, none

    var id: String { rawValue }

    var title: String { self == .none ? "No stick" : rawValue.capitalized }

    var color: NSColor? {
        switch self {
        case .ink: return NSColor(srgbRed: 0.10, green: 0.10, blue: 0.11, alpha: 1)
        case .wood: return NSColor(srgbRed: 0.55, green: 0.36, blue: 0.20, alpha: 1)
        case .chalk: return NSColor(srgbRed: 0.96, green: 0.96, blue: 0.95, alpha: 1)
        case .cherry: return NSColor(srgbRed: 0.86, green: 0.18, blue: 0.22, alpha: 1)
        case .ocean: return NSColor(srgbRed: 0.16, green: 0.42, blue: 0.90, alpha: 1)
        case .none: return nil
        }
    }
}


/// UserDefaults-backed preferences; `changes` fires after any edit so the overlay can rebuild.
final class Prefs: ObservableObject {
    static let shared = Prefs()
    private let d = UserDefaults.standard
    let changes = PassthroughSubject<Void, Never>()

    @Published var style: PointerStyle { didSet { save("style", style.rawValue) } }
    @Published var gloveColor: GloveColor { didSet { save("gloveColor", gloveColor.rawValue) } }
    /// 0...1 along the Small-to-Huge slider.
    @Published var size: Double { didSet { save("size", size) } }
    @Published var mood: Mood { didSet { save("mood", mood.rawValue) } }
    @Published var stick: StickColor { didSet { save("stick", stick.rawValue) } }
    @Published var flashes: Bool { didSet { save("flashes", flashes) } }
    @Published var sound: Bool { didSet { save("sound", sound) } }
    @Published var volume: Double { didSet { save("volume", volume) } }
    @Published var soundChoice: SoundChoice { didSet { save("soundChoice", soundChoice.rawValue) } }
    @Published var customSoundPath: String? { didSet { save("customSoundPath", customSoundPath) } }
    @Published var hideSystemCursor: Bool { didSet { save("hideSystemCursor", hideSystemCursor) } }
    @Published var enabled: Bool { didSet { d.set(enabled, forKey: "enabled") } }

    private init() {
        style = PointerStyle(rawValue: d.string(forKey: "style") ?? "") ?? .glove
        gloveColor = GloveColor(rawValue: d.string(forKey: "gloveColor") ?? "") ?? .white
        size = min(max(d.object(forKey: "size") as? Double ?? 0.25, 0), 1)
        mood = Mood(rawValue: d.object(forKey: "mood") as? Int ?? Mood.peppy.rawValue) ?? .peppy
        stick = StickColor(rawValue: d.string(forKey: "stick") ?? "") ?? .ink
        flashes = d.object(forKey: "flashes") as? Bool ?? true
        sound = d.object(forKey: "sound") as? Bool ?? true
        volume = d.object(forKey: "volume") as? Double ?? 0.7
        soundChoice = SoundChoice(rawValue: d.string(forKey: "soundChoice") ?? "") ?? .clack
        customSoundPath = d.string(forKey: "customSoundPath")
        hideSystemCursor = d.object(forKey: "hideSystemCursor") as? Bool ?? true
        enabled = d.object(forKey: "enabled") as? Bool ?? true
    }

    private func save(_ key: String, _ value: Any?) {
        d.set(value, forKey: key)
        changes.send()
    }
}
