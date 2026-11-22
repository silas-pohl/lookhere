import SwiftUI

/// The panel's comic-strip look: cream paper, bold ink outlines, hard offset shadows.
enum Ink {
    static let ink = Color(red: 0.08, green: 0.07, blue: 0.09)
    static let paper = Color(red: 1.0, green: 0.965, blue: 0.9)
    static let card = Color.white
    static let tomato = Color(red: 1.0, green: 0.38, blue: 0.30)
    static let sun = Color(red: 1.0, green: 0.82, blue: 0.27)
    static let sky = Color(red: 0.45, green: 0.75, blue: 1.0)
    static let muted = Color(red: 0.42, green: 0.38, blue: 0.36)
    static let line: CGFloat = 2.5

    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .rounded) }
    static func body(_ size: CGFloat = 13, weight: Font.Weight = .semibold) -> Font { .system(size: size, weight: weight, design: .rounded) }
}

/// Fill + ink outline + a solid shadow offset down-right, like a sticker on paper.
struct Chunky: ViewModifier {
    var fill: Color = Ink.card
    var radius: CGFloat = 14
    var lift: CGFloat = 3

    func body(content: Content) -> some View {
        content.background(
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Ink.ink).offset(x: lift, y: lift)
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
                RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Ink.ink, lineWidth: Ink.line)
            }
        )
    }
}

extension View {
    func chunky(_ fill: Color = Ink.card, radius: CGFloat = 14, lift: CGFloat = 3) -> some View {
        modifier(Chunky(fill: fill, radius: radius, lift: lift))
    }
}

/// Text with a thick ink outline, for the title.
struct OutlinedText: View {
    let text: String
    let size: CGFloat
    var fill: Color = .white

    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                let a = Double(i) / 12 * 2 * .pi
                Text(text).font(Ink.display(size)).foregroundStyle(Ink.ink)
                    .offset(x: cos(a) * 2.6, y: sin(a) * 2.6)
            }
            Text(text).font(Ink.display(size)).foregroundStyle(Ink.ink).offset(x: 2.5, y: 3.5)
            Text(text).font(Ink.display(size)).foregroundStyle(fill)
        }
    }
}

/// Capsule switch with an ink outline; label on the left.
struct ChunkyToggle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 8)
            ChunkySwitch(isOn: configuration.$isOn)
        }
    }
}

struct ChunkySwitch: View {
    @Binding var isOn: Bool
    var onColor: Color = Ink.tomato

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule().fill(Ink.ink).offset(x: 2, y: 2)
            Capsule().fill(isOn ? onColor : Color(white: 0.88))
            Capsule().strokeBorder(Ink.ink, lineWidth: Ink.line)
            Circle().fill(.white)
                .overlay(Circle().strokeBorder(Ink.ink, lineWidth: Ink.line))
                .frame(width: 20, height: 20)
                .padding(3)
        }
        .frame(width: 46, height: 26)
        .contentShape(Capsule())
        .onTapGesture { withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { isOn.toggle() } }
    }
}

/// Fat slider with an ink-outlined track and knob. `steps` snaps to that many stops.
struct ChunkySlider: View {
    @Binding var value: Double
    var steps: Int? = nil
    var fill: Color = Ink.tomato

    private let knob: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x = knob / 2 + CGFloat(value) * (w - knob)
            ZStack(alignment: .leading) {
                Capsule().fill(Color(white: 0.9)).frame(height: 12)
                Capsule().fill(fill).frame(width: max(12, x + 6), height: 12)
                Capsule().strokeBorder(Ink.ink, lineWidth: Ink.line).frame(height: 12)
                if let steps {
                    ForEach(0..<steps, id: \.self) { i in
                        Circle().fill(Ink.ink).frame(width: 4, height: 4)
                            .position(x: knob / 2 + CGFloat(i) / CGFloat(steps - 1) * (w - knob), y: geo.size.height / 2)
                    }
                }
                ZStack {
                    Circle().fill(Ink.ink).offset(x: 2, y: 2)
                    Circle().fill(.white)
                    Circle().strokeBorder(Ink.ink, lineWidth: Ink.line)
                }
                .frame(width: knob, height: knob)
                .position(x: x, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                var v = Double((g.location.x - knob / 2) / (w - knob))
                v = min(1, max(0, v))
                if let steps { v = (v * Double(steps - 1)).rounded() / Double(steps - 1) }
                if v != value { value = v }
            })
        }
        .frame(height: knob + 4)
    }
}

/// A tilted sticker label.
struct Sticker: View {
    let text: String
    var fill: Color = Ink.sun
    var tilt: Double = -4

    var body: some View {
        Text(text)
            .font(Ink.body(11, weight: .heavy))
            .foregroundStyle(Ink.ink)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .chunky(fill, radius: 7, lift: 2)
            .rotationEffect(.degrees(tilt))
    }
}

struct Keycap: View {
    let keys: String

    var body: some View {
        Text(keys)
            .font(Ink.body(10, weight: .bold))
            .foregroundStyle(Ink.ink)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .chunky(.white, radius: 5, lift: 1.5)
    }
}

/// Round colour chip; the selected one pops up with a tick.
struct Swatch: View {
    let color: Color?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(Ink.ink).offset(x: selected ? 2.5 : 1.5, y: selected ? 2.5 : 1.5)
                if let color {
                    Circle().fill(color)
                } else {
                    Circle().fill(.white)
                    Path { p in
                        p.move(to: CGPoint(x: 5, y: 17))
                        p.addLine(to: CGPoint(x: 17, y: 5))
                    }
                    .stroke(Ink.tomato, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
                Circle().strokeBorder(Ink.ink, lineWidth: 2)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(color.map { isLight($0) ? Ink.ink : .white } ?? Ink.ink)
                }
            }
            .frame(width: 22, height: 22)
            .scaleEffect(selected ? 1.12 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: selected)
        }
        .buttonStyle(.plain)
    }

    private func isLight(_ c: Color) -> Bool {
        let n = NSColor(c).usingColorSpace(.sRGB) ?? .white
        return 0.3 * n.redComponent + 0.59 * n.greenComponent + 0.11 * n.blueComponent > 0.6
    }
}

/// Small comic-style section heading.
struct SectionTitle: View {
    let text: String
    let symbol: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 10, weight: .black))
            Text(text.uppercased()).font(Ink.body(11, weight: .black)).tracking(1)
        }
        .foregroundStyle(Ink.ink)
    }
}
