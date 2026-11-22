import AVFoundation
import Foundation

/// The built-in tap sounds, all synthesized at launch (no recorded samples), plus a custom file.
enum SoundChoice: String, CaseIterable, Identifiable {
    case clack, knock, boop, pop, squeak, boing, custom

    var id: String { rawValue }

    var title: String { self == .custom ? "File…" : rawValue.capitalized }

    static var builtIn: [SoundChoice] { allCases.filter { $0 != .custom } }

    /// Synthesized mono samples in -1...1 at `Synth.rate`.
    fileprivate func samples() -> [Double] {
        switch self {
        case .clack, .custom: return Synth.clack()
        case .knock: return Synth.knock()
        case .boop: return Synth.boop()
        case .pop: return Synth.pop()
        case .squeak: return Synth.squeak()
        case .boing: return Synth.boing()
        }
    }
}

/// Plays the tap sound. Several players so rapid taps overlap instead of cutting off,
/// and a little random pitch so a run of taps doesn't sound like a machine gun.
final class TapSound {
    private var players: [AVAudioPlayer] = []
    private var next = 0

    /// Returns false if a custom file couldn't be loaded (Clack is used instead).
    @discardableResult
    func load(_ choice: SoundChoice, customPath: String?) -> Bool {
        var ok = true
        var data: Data
        if choice == .custom {
            if let path = customPath, let custom = try? Data(contentsOf: URL(fileURLWithPath: path)),
               (try? AVAudioPlayer(data: custom)) != nil {
                data = custom
            } else {
                data = Synth.wav(SoundChoice.clack.samples())
                ok = false
            }
        } else {
            data = Synth.wav(choice.samples())
        }
        players = (0..<5).compactMap { _ in try? AVAudioPlayer(data: data) }
        players.forEach {
            $0.enableRate = true
            $0.prepareToPlay()
        }
        return ok
    }

    func play(volume: Float, vary: Bool = true) {
        guard !players.isEmpty else { return }
        let p = players[next]
        next = (next + 1) % players.count
        p.volume = volume
        p.rate = vary ? Float.random(in: 0.94...1.07) : 1
        p.currentTime = 0
        p.play()
    }
}

// MARK: - Synthesis

private enum Synth {
    static let rate = 44_100

    private static func buffer(_ seconds: Double) -> [Double] {
        [Double](repeating: 0, count: Int(Double(rate) * seconds))
    }

    /// Deterministic white noise so each sound is identical every launch.
    private struct Noise {
        var state: UInt32 = 0x2545_F491
        mutating func next() -> Double {
            state = state &* 1_664_525 &+ 1_013_904_223
            return Double(Int32(bitPattern: state)) / Double(Int32.max)
        }
    }

    /// Default: a hard plastic tip striking glass. Two contacts a few ms apart ("cl-ack"),
    /// each a highpassed noise snap plus a few fast-decaying bright resonances.
    static func clack() -> [Double] {
        var out = buffer(0.075)
        var noise = Noise()
        let contacts: [(at: Double, amp: Double)] = [(0, 1), (0.0065, 0.6)]
        let modes: [(f: Double, decay: Double, amp: Double)] = [(1180, 0.011, 0.75), (2450, 0.0065, 0.5), (3900, 0.004, 0.32), (340, 0.018, 0.28)]
        var prev = 0.0
        for i in out.indices {
            let t = Double(i) / Double(rate)
            var v = 0.0
            for c in contacts where t >= c.at {
                let e = t - c.at
                let n = noise.next()
                let hp = n - prev  // first-difference highpass: crisp, not hissy
                prev = n
                v += c.amp * hp * exp(-e / 0.0014) * 0.9
                for m in modes {
                    v += c.amp * m.amp * exp(-e / m.decay) * sin(2 * .pi * m.f * e)
                }
            }
            out[i] = v
        }
        return out
    }

    /// The original wooden knock: a pitch-dropping thump plus a noise click.
    static func knock() -> [Double] {
        var out = buffer(0.11)
        var noise = Noise()
        var phase1 = 0.0, phase2 = 0.0
        for i in out.indices {
            let t = Double(i) / Double(rate)
            phase1 += 2 * .pi * 170 * (1 + 0.8 * exp(-t / 0.008)) / Double(rate)
            phase2 += 2 * .pi * 520 * (1 + 0.3 * exp(-t / 0.006)) / Double(rate)
            out[i] = exp(-t / 0.022) * sin(phase1) * 0.8
                + exp(-t / 0.012) * sin(phase2) * 0.35
                + exp(-t / 0.0018) * noise.next() * 0.6
        }
        return out
    }

    /// Cartoon "boop": a soft sine that slides down in pitch.
    static func boop() -> [Double] {
        var out = buffer(0.12)
        var phase = 0.0
        for i in out.indices {
            let t = Double(i) / Double(rate)
            let f = 320 + 620 * exp(-t / 0.03)
            phase += 2 * .pi * f / Double(rate)
            let env = min(1, t / 0.003) * exp(-t / 0.045)
            out[i] = env * (sin(phase) + 0.18 * sin(2 * phase))
        }
        return out
    }

    /// Bubble pop: a very short upward chirp with a click at the start.
    static func pop() -> [Double] {
        var out = buffer(0.05)
        var phase = 0.0
        for i in out.indices {
            let t = Double(i) / Double(rate)
            let f = 420 + 1500 * (1 - exp(-t / 0.008))
            phase += 2 * .pi * f / Double(rate)
            out[i] = min(1, t / 0.0006) * exp(-t / 0.011) * sin(phase)
        }
        return out
    }

    /// Rubber-toy squeak: a nasal, buzzy tone that rises then wobbles.
    static func squeak() -> [Double] {
        var out = buffer(0.14)
        var phase = 0.0
        for i in out.indices {
            let t = Double(i) / Double(rate)
            let f = 1500 + 900 * min(1, t / 0.04) + 120 * sin(2 * .pi * 28 * t)
            phase += 2 * .pi * f / Double(rate)
            let env = min(1, t / 0.008) * exp(-max(0, t - 0.05) / 0.03)
            // Odd harmonics give the reedy rubber character.
            out[i] = env * (sin(phase) + 0.45 * sin(3 * phase) + 0.2 * sin(5 * phase))
        }
        return out
    }

    /// Spring "boing": a low tone with fast, decaying vibrato.
    static func boing() -> [Double] {
        var out = buffer(0.32)
        var phase = 0.0
        for i in out.indices {
            let t = Double(i) / Double(rate)
            let f = 210 + 90 * exp(-t / 0.12) * sin(2 * .pi * 17 * t) + 60 * exp(-t / 0.02)
            phase += 2 * .pi * f / Double(rate)
            let env = min(1, t / 0.002) * exp(-t / 0.11)
            out[i] = env * (sin(phase) + 0.3 * sin(2 * phase))
        }
        return out
    }

    /// Normalizes to 90% peak and wraps as a 16-bit mono WAV.
    static func wav(_ samples: [Double]) -> Data {
        let peak = samples.map(abs).max() ?? 1
        var pcm = Data(capacity: samples.count * 2)
        // Short fade-out so no sound ends on a click.
        let fade = min(samples.count, rate / 200)
        for (i, s) in samples.enumerated() {
            let tail = i >= samples.count - fade ? Double(samples.count - i) / Double(fade) : 1
            var v = Int16(max(-1, min(1, s / peak * 0.9 * tail)) * Double(Int16.max)).littleEndian
            withUnsafeBytes(of: &v) { pcm.append(contentsOf: $0) }
        }
        var wav = Data()
        func u32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { wav.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { wav.append(contentsOf: $0) } }
        wav.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + pcm.count))
        wav.append(contentsOf: Array("WAVEfmt ".utf8)); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        wav.append(contentsOf: Array("data".utf8)); u32(UInt32(pcm.count))
        wav.append(pcm)
        return wav
    }

    /// Writes every built-in sound as a WAV, for listening while tuning.
    static func export(to dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for c in SoundChoice.builtIn {
            try? wav(c.samples()).write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(c.rawValue).wav"))
        }
    }
}

/// `Lookhere --export-sounds DIR`.
func exportSounds(to dir: String) { Synth.export(to: dir) }
