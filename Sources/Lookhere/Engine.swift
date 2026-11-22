import CoreGraphics
import Foundation

/// Resting lean of the stick from vertical; positive puts the handle towards the bottom-right.
let restLean = 26.0 * .pi / 180

// MARK: - Spring

/// Damped spring integrated with small fixed substeps for stability at any frame rate.
struct Spring {
    var value: Double
    var velocity = 0.0
    let stiffness: Double
    let damping: Double

    init(_ value: Double, stiffness: Double, damping: Double) {
        self.value = value
        self.stiffness = stiffness
        self.damping = damping
    }

    mutating func step(toward target: Double, dt: Double) {
        var left = min(max(dt, 0), 0.1)
        while left > 0 {
            let h = min(left, 1.0 / 480)
            velocity += (stiffness * (target - value) - damping * velocity) * h
            value += velocity * h
            left -= h
        }
    }

    func isResting(at target: Double) -> Bool {
        abs(value - target) < 0.0005 && abs(velocity) < 0.005
    }
}

// MARK: - Mood

/// How quickly repeated clicks build up energy, and so how big the bursts get.
enum Mood: Int, CaseIterable {
    case mellow, friendly, peppy, rowdy, unhinged

    var title: String {
        switch self {
        case .mellow: return "Mellow"
        case .friendly: return "Friendly"
        case .peppy: return "Peppy"
        case .rowdy: return "Rowdy"
        case .unhinged: return "Unhinged"
        }
    }

    /// Energy added per click.
    var gain: Double {
        switch self {
        case .mellow: return 0
        case .friendly: return 0.13
        case .peppy: return 0.2
        case .rowdy: return 0.28
        case .unhinged: return 0.34
        }
    }

    /// Energy never drops below this, so even a single click lands with some punch.
    var floor: Double { self == .unhinged ? 0.5 : 0 }
}

// MARK: - Engine

struct PointerFrame {
    var lean: Double
    var swing: Double
    var scale: Double
    /// One entry per impact this frame: burst intensity 0 (plain ring) to 5.
    var impacts: [Int]
    var settled: Bool
}

/// The pointer's motion. The stick leans with a little inertia as the cursor moves, and
/// each click winds the pointer back and snaps it into the screen on a spring. Clicking
/// quickly builds "energy", which makes the poke bigger and the bursts more dramatic.
final class PointerEngine {
    var mood = Mood.peppy
    var reduceMotion = false

    private var lean = Spring(restLean, stiffness: 120, damping: 15)
    private var poke = Spring(0, stiffness: 1500, damping: 36)
    private var energy = 0.0
    private var level = 0
    private var lastX: Double?
    private var velocityX = 0.0

    /// Click choreography: hold wound-up until `windupEnd`, push through until `pressEnd`, then settle.
    private var windupEnd = -Double.infinity
    private var pressEnd = -Double.infinity
    private var pendingImpact: Int?
    private var instantImpacts: [Int] = []

    func enter(_ p: CGPoint, _ size: CGSize) {
        lastX = Double(p.x)
        velocityX = 0
        lean = Spring(targetLean(p, size), stiffness: lean.stiffness, damping: lean.damping)
        poke = Spring(0, stiffness: poke.stiffness, damping: poke.damping)
        pendingImpact = nil
    }

    func press(at t: Double) {
        energy = min(1, max(energy, mood.floor) + mood.gain)
        let intensity = mood == .mellow ? 0 : min(5, Int(energy * 6))
        if reduceMotion {
            instantImpacts.append(intensity)
            return
        }
        // A click that interrupts an unfinished poke still gets its own burst.
        if let pending = pendingImpact { instantImpacts.append(pending) }
        level = intensity
        pendingImpact = intensity
        let windup = 0.04 + 0.006 * Double(intensity)
        windupEnd = t + windup
        pressEnd = windupEnd + 0.05
    }

    func frame(_ p: CGPoint, _ size: CGSize, t: Double, dt: Double) -> PointerFrame {
        energy *= exp(-max(dt, 0) / 0.6)
        var impacts = instantImpacts
        instantImpacts = []
        if reduceMotion {
            return PointerFrame(lean: restLean, swing: 0, scale: 1, impacts: impacts, settled: true)
        }

        // Horizontal velocity, low-passed so the lean reacts to motion rather than jitter.
        let x = Double(p.x)
        if let lx = lastX, dt > 0 {
            let raw = (x - lx) / dt
            velocityX += (raw - velocityX) * (1 - exp(-dt / 0.06))
        }
        lastX = x
        let target = targetLean(p, size)
        lean.step(toward: target, dt: dt)

        let pokeTarget: Double = t < windupEnd ? 1 : t < pressEnd ? -0.45 : 0
        let before = poke.value
        poke.step(toward: pokeTarget, dt: dt)
        // The impact is the moment the pointer passes through the screen surface.
        if let pending = pendingImpact, t >= windupEnd, before > 0, poke.value <= 0 {
            impacts.append(pending)
            pendingImpact = nil
        }

        let amp = 1 + 0.18 * Double(level)
        let swing = 0.11 * amp * poke.value
        let scale = poke.value >= 0 ? 1 + 0.1 * amp * poke.value : 1 + 0.16 * poke.value
        let settled = pendingImpact == nil && t >= pressEnd && poke.isResting(at: 0) && lean.isResting(at: target)
            && abs(velocityX) < 1
        return PointerFrame(lean: lean.value, swing: swing, scale: scale, impacts: impacts, settled: settled)
    }

    /// Leans further on the left of the screen and stands straighter on the right, so the
    /// handle stays on screen; moving sideways drags the handle behind the hand.
    private func targetLean(_ p: CGPoint, _ size: CGSize) -> Double {
        let across = size.width > 0 ? Double(p.x / size.width) - 0.5 : 0
        let drag = -0.3 * max(-1, min(1, velocityX / 2200))
        return max(-0.5, min(1.2, restLean - 0.3 * across + drag))
    }
}
