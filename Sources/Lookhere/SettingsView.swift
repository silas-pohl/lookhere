import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

/// The menu-bar panel, styled like a comic strip.
struct SettingsView: View {
    @ObservedObject var prefs: Prefs
    @ObservedObject var app: Lookhere
    let toggleHandsOff: () -> Void
    /// Whether the panel is on screen; the header only animates while it is.
    @ObservedObject var visibility: PanelVisibility

    static let width: CGFloat = 330

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            header
            pointerCard
            tapCard
            generalCard
            footer
        }
        .padding(14)
        .frame(width: Self.width)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Ink.ink).offset(x: 5, y: 5)
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Ink.paper)
                RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Ink.ink, lineWidth: 3)
            }
        )
        .padding(EdgeInsets(top: 4, leading: 4, bottom: 10, trailing: 10))
        .toggleStyle(ChunkyToggle())
        .foregroundStyle(Ink.ink)
    }

    // MARK: Header

    private var header: some View {
        ZStack(alignment: .topLeading) {
            PokeStage(style: prefs.style, color: prefs.gloveColor, stick: prefs.stick, animating: visibility.shown && app.running)
                .frame(height: 116)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Ink.ink, lineWidth: 3))
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Ink.ink).offset(x: 4, y: 4))

            VStack(alignment: .leading, spacing: 0) {
                OutlinedText(text: "LOOK", size: 26)
                OutlinedText(text: "HERE!", size: 26, fill: Ink.tomato).offset(x: 14, y: -7)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    ChunkySwitch(isOn: Binding(get: { app.running }, set: { app.setRunning($0) }))
                    Text(app.handsOff ? "Hands off!" : app.running ? "Poking" : "Napping")
                        .font(Ink.body(12, weight: .heavy))
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .chunky(.white, radius: 8, lift: 2)
                }
            }
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 14, trailing: 12))
        }
        .frame(height: 116)
    }

    // MARK: Cards

    private var pointerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Pointer", symbol: "hand.point.up.left.fill")
            HStack(spacing: 10) {
                ForEach(PointerStyle.allCases) { style in
                    let on = prefs.style == style
                    Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { prefs.style = style } } label: {
                        VStack(spacing: 4) {
                            Image(nsImage: Showcase.pointer(style: style, color: prefs.gloveColor, height: 38))
                                .frame(height: 40)
                            Text(style.title).font(Ink.body(12, weight: .heavy))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .chunky(on ? Ink.sun : .white, radius: 12, lift: on ? 4 : 2)
                        .rotationEffect(.degrees(on ? -3 : 0))
                        .offset(y: on ? -2 : 0)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if prefs.style == .glove {
                labelled("Glove") {
                    ForEach(GloveColor.allCases) { c in
                        Swatch(color: Color(nsColor: c.color), selected: prefs.gloveColor == c) { prefs.gloveColor = c }
                    }
                }
            }
            labelled("Stick") {
                ForEach(StickColor.allCases) { c in
                    Swatch(color: c.color.map { Color(nsColor: $0) }, selected: prefs.stick == c) { prefs.stick = c }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Size").font(Ink.body())
                    Spacer()
                    Sticker(text: "\(Int((ArtFactory.scale(forSize: prefs.size) / ArtFactory.scale(forSize: 0.25) * 100).rounded()))%",
                            fill: .white, tilt: 3)
                }
                ChunkySlider(value: $prefs.size)
            }
        }
        .padding(12)
        .chunky()
    }

    private var tapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Tap", symbol: "burst.fill")
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Mood").font(Ink.body())
                    Spacer()
                    Sticker(text: prefs.mood.title, fill: moodColor)
                        .animation(.spring(response: 0.25, dampingFraction: 0.5), value: prefs.mood)
                }
                ChunkySlider(value: Binding(get: { Double(prefs.mood.rawValue) / Double(Mood.allCases.count - 1) },
                                            set: { prefs.mood = Mood(rawValue: Int(($0 * Double(Mood.allCases.count - 1)).rounded())) ?? .peppy }),
                             steps: Mood.allCases.count, fill: moodColor)
            }
            HStack(spacing: 18) {
                Toggle(isOn: $prefs.flashes) { Text("Bursts").font(Ink.body()) }
                Toggle(isOn: $prefs.sound) { Text("Sound").font(Ink.body()) }
            }
            if prefs.sound {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4), spacing: 8) {
                    ForEach(SoundChoice.allCases) { choice in
                        soundChip(choice)
                    }
                }
                HStack(spacing: 8) {
                    Image(systemName: "speaker.wave.2.fill").font(.system(size: 10, weight: .bold))
                    ChunkySlider(value: $prefs.volume, fill: Ink.sky)
                }
            }
        }
        .padding(12)
        .chunky()
    }

    private var generalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "General", symbol: "gearshape.fill")
            Toggle(isOn: Binding(get: { app.handsOff }, set: { _ in toggleHandsOff() })) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Hands-off Mode").font(Ink.body())
                        Keycap(keys: "⌃⌥H")
                    }
                    Text("Clicks only poke. Nothing underneath gets clicked, so slides never skip by accident.")
                        .font(Ink.body(10.5, weight: .medium))
                        .foregroundStyle(Ink.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Toggle(isOn: $prefs.hideSystemCursor) { Text("Hide system cursor").font(Ink.body()) }
            if Bundle.main.bundleURL.pathExtension == "app" {
                LaunchAtLoginToggle()
            }
        }
        .padding(12)
        .chunky()
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Keycap(keys: "⌃⌥L")
            Text("on / off").font(Ink.body(11, weight: .medium)).foregroundStyle(Ink.muted)
            Spacer()
            if let url = Self.supportURL {
                chunkyButton("Tip jar ♥", fill: Ink.sun) { NSWorkspace.shared.open(url) }
                    .help("Lookhere is free. If it made your call better, chip in.")
            }
            chunkyButton("Quit", fill: Ink.tomato) { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 2)
    }

    /// Donation page from Info.plist (`LHSupportURL`); the button stays hidden while it's empty.
    private static let supportURL: URL? = (Bundle.main.object(forInfoDictionaryKey: "LHSupportURL") as? String)
        .flatMap { $0.isEmpty ? nil : URL(string: $0) }

    // MARK: Building blocks

    private var moodColor: Color {
        [Ink.sky, Color(red: 0.55, green: 0.85, blue: 0.6), Ink.sun, Color(red: 1, green: 0.6, blue: 0.3), Ink.tomato][prefs.mood.rawValue]
    }

    private func labelled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack {
            Text(label).font(Ink.body())
            Spacer()
            HStack(spacing: 6) { content() }
        }
    }

    private func chunkyButton(_ title: String, fill: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Ink.body(11, weight: .heavy))
                .foregroundStyle(Ink.ink)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .chunky(fill, radius: 8, lift: 2)
        }
        .buttonStyle(.plain)
    }

    private func soundChip(_ choice: SoundChoice) -> some View {
        let on = prefs.soundChoice == choice
        return Button {
            if choice == .custom && (prefs.customSoundPath == nil || on) {
                chooseSound()
            } else {
                prefs.soundChoice = choice
                // Let the prefs change land before previewing the new sound.
                DispatchQueue.main.async { app.previewSound() }
            }
        } label: {
            Text(choice == .custom && prefs.customSoundPath != nil && on ? "Change…" : choice.title)
                .font(Ink.body(11, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .chunky(on ? Ink.sun : .white, radius: 8, lift: on ? 3 : 1.5)
                .rotationEffect(.degrees(on ? -3 : 0))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(choice == .custom ? (prefs.customSoundPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Pick an audio file") : "Play \(choice.title)")
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: on)
    }

    private func chooseSound() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.message = "Pick a tap sound. Short clips work best."
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        prefs.customSoundPath = url.path
        prefs.soundChoice = .custom
        DispatchQueue.main.async {
            guard !app.reloadSound() else { app.previewSound(); return }
            prefs.customSoundPath = nil
            prefs.soundChoice = .clack
            let alert = NSAlert()
            alert.messageText = "Couldn’t play “\(url.lastPathComponent)”"
            alert.informativeText = "Lookhere is using the Clack sound instead."
            alert.runModal()
        }
    }
}

final class PanelVisibility: ObservableObject {
    @Published var shown = false
}

/// Mirrors the login-item state. A plain ObservableObject rather than `@State`, because the
/// `@State` macro's plugin ships only with full Xcode, not the Command Line Tools Homebrew uses.
final class LoginItem: ObservableObject {
    static let shared = LoginItem()
    @Published private(set) var enabled = SMAppService.mainApp.status == .enabled

    func set(_ want: Bool) {
        if want { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
        enabled = SMAppService.mainApp.status == .enabled
    }
}

private struct LaunchAtLoginToggle: View {
    @ObservedObject private var item = LoginItem.shared

    var body: some View {
        Toggle(isOn: Binding(get: { item.enabled }, set: { item.set($0) })) {
            Text("Launch at login").font(Ink.body())
        }
    }
}
