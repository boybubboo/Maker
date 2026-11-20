//
//  PlatformMotion.swift
//  Maker
//
//  How a moving platform travels: there and back with a wait at each end,
//  or turning on the spot.
//

import Foundation
import simd

enum PlatformMotion {
    static let presets: [(id: String, title: String)] = [
        ("stoneLift", "Stone lift"),
        ("swingingBridge", "Swinging bridge"),
        ("spinningDisc", "Spinning disc")
    ]

    static func title(for preset: String) -> String {
        presets.first { $0.id == preset }?.title ?? "Stone lift"
    }

    /// How high the platform's top sits above the ground.
    static func hover(for preset: String) -> Float {
        preset == "spinningDisc" ? 0.40 : 0.45
    }

    /// How far from the middle you can stand and still be on it.
    static func halfExtent(for preset: String) -> Float {
        switch preset {
        case "swingingBridge": return 1.25
        case "spinningDisc": return 1.05
        default: return 1.0
        }
    }

    static func isSpin(_ motion: String) -> Bool {
        motion == "spin"
    }

    /// Where the platform is at a moment in its cycle.
    static func pose(
        time: Float,
        start: SIMD3<Float>,
        end: SIMD3<Float>,
        speed: Float,
        wait: Float,
        spin: Bool
    ) -> (position: SIMD3<Float>, yaw: Float) {
        if spin {
            let yaw = fmod(time * max(0.2, speed) * 1.3, 2 * .pi)
            return (start, yaw)
        }

        let distance = simd_distance(start, end)
        guard distance > 0.05 else { return (start, 0) }

        let travel = distance / max(0.15, speed)
        let pause = max(0, wait)
        let cycle = max(0.2, travel * 2 + pause * 2)
        let t = fmod(max(0, time), cycle)

        var fraction: Float
        if t < travel {
            fraction = smooth(t / travel)
        } else if t < travel + pause {
            fraction = 1
        } else if t < travel * 2 + pause {
            fraction = 1 - smooth((t - travel - pause) / travel)
        } else {
            fraction = 0
        }
        fraction = min(1, max(0, fraction))

        return (start + (end - start) * fraction, 0)
    }

    private static func smooth(_ value: Float) -> Float {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }
}
