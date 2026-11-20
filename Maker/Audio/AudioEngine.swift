//
//  AudioEngine.swift
//  Maker
//
//  Every sound in Maker is made from scratch in code, so there is a whole
//  library of them and nothing to download.
//

import Foundation
import AVFoundation

final class AudioEngine {
    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private let sfxPlayer = AVAudioPlayerNode()
    private let musicPlayer = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

    private var started = false
    private var currentMood: MusicMood = .none
    private var musicOwner = ""
    private var musicRequest = UUID()
    private var musicCache: [MusicMood: AVAudioPCMBuffer] = [:]
    private var effectCache: [SoundEffect: AVAudioPCMBuffer] = [:]

    var volume: Float {
        didSet {
            sfxPlayer.volume = volume
            musicPlayer.volume = volume * 0.55
            UserDefaults.standard.set(volume, forKey: "maker.audio.volume")
        }
    }

    private init() {
        let saved = UserDefaults.standard.object(forKey: "maker.audio.volume") as? Float
        volume = saved ?? 0.6
    }

    // MARK: Starting

    @discardableResult
    private func startIfNeeded() -> Bool {
        if started { return true }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        engine.attach(sfxPlayer)
        engine.attach(musicPlayer)
        engine.connect(sfxPlayer, to: engine.mainMixerNode, format: format)
        engine.connect(musicPlayer, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
        } catch {
            return false
        }

        sfxPlayer.volume = volume
        musicPlayer.volume = volume * 0.55
        sfxPlayer.play()
        musicPlayer.play()
        started = true
        return true
    }

    // MARK: Sounds

    func play(_ effect: SoundEffect) {
        guard effect != .none, startIfNeeded() else { return }

        let buffer: AVAudioPCMBuffer
        if let cached = effectCache[effect] {
            buffer = cached
        } else {
            guard let made = makeBuffer(SoundSynth.effect(effect)) else { return }
            effectCache[effect] = made
            buffer = made
        }

        sfxPlayer.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
        if !sfxPlayer.isPlaying {
            sfxPlayer.play()
        }
    }

    // MARK: Music

    func playMusic(_ mood: MusicMood, owner: String) {
        musicOwner = owner
        guard mood != .none else {
            stopMusic(owner: owner)
            return
        }
        guard startIfNeeded() else { return }
        if mood == currentMood && musicPlayer.isPlaying { return }

        currentMood = mood

        if let cached = musicCache[mood] {
            schedule(cached)
            return
        }

        let token = UUID()
        musicRequest = token
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let samples = SoundSynth.music(mood)
            DispatchQueue.main.async {
                guard let self, self.musicRequest == token else { return }
                if let buffer = self.makeBuffer(samples) {
                    self.musicCache[mood] = buffer
                    self.schedule(buffer)
                }
            }
        }
    }

    func stopMusic(owner: String) {
        guard owner == musicOwner else { return }
        musicRequest = UUID()
        musicPlayer.stop()
        currentMood = .none
        musicOwner = ""
    }

    private func schedule(_ buffer: AVAudioPCMBuffer) {
        musicPlayer.stop()
        musicPlayer.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        musicPlayer.play()
    }

    // MARK: Buffers

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            return nil
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        for index in 0..<samples.count {
            channel[index] = min(1, max(-1, samples[index]))
        }
        return buffer
    }
}

// MARK: - Making the sounds

enum SoundSynth {
    static let sampleRate: Double = 44100

    private enum Wave {
        case sine, triangle, saw
    }

    private static func sample(for wave: Wave, frequency: Double, t: Double) -> Double {
        let phase = 2 * Double.pi * frequency * t
        switch wave {
        case .sine:
            return sin(phase)
        case .triangle:
            return (2 / Double.pi) * asin(sin(phase))
        case .saw:
            return (2 * (t * frequency - floor(t * frequency + 0.5)))
        }
    }

    // MARK: Effects

    static func effect(_ effect: SoundEffect) -> [Float] {
        switch effect {
        case .coin:
            return notes([(1318.5, 0.00, 0.10), (1975.5, 0.07, 0.18)], wave: .sine, level: 0.45)
        case .chime:
            return notes([(1046.5, 0.00, 0.55), (1568.0, 0.02, 0.65)], wave: .sine, level: 0.32)
        case .hit:
            return thud()
        case .creak:
            return creak()
        case .whoosh:
            return whoosh()
        case .jump:
            return notes([(440.0, 0.00, 0.07), (660.0, 0.05, 0.13)], wave: .triangle, level: 0.32)
        case .step:
            return step()
        case .fanfare:
            return notes([(523.25, 0.00, 0.15), (659.25, 0.13, 0.15), (783.99, 0.26, 0.45)], wave: .triangle, level: 0.38)
        case .sparkle:
            return notes([(1568.0, 0.00, 0.10), (2093.0, 0.08, 0.10), (2637.0, 0.16, 0.28)], wave: .sine, level: 0.28)
        case .hurt:
            return notes([(300.0, 0.00, 0.18), (200.0, 0.12, 0.24)], wave: .saw, level: 0.3)
        case .none:
            return []
        }
    }

    private static func notes(_ notes: [(Double, Double, Double)], wave: Wave, level: Float) -> [Float] {
        let end = notes.map { $0.1 + $0.2 }.max() ?? 0.3
        let count = max(1, Int(end * sampleRate))
        var samples = [Float](repeating: 0, count: count)

        for (frequency, start, duration) in notes {
            let startIndex = Int(start * sampleRate)
            let length = max(1, Int(duration * sampleRate))
            for index in 0..<length {
                let position = startIndex + index
                guard position < count else { break }
                let t = Double(index) / sampleRate
                let attack = min(1, t / 0.008)
                let decay = exp(-t * (3.2 / duration))
                let value = sample(for: wave, frequency: frequency * (1 + 0.002 * sin(t * 30)), t: t) * attack * decay
                samples[position] += Float(value * Double(level))
            }
        }
        return samples
    }

    private static func thud() -> [Float] {
        let duration = 0.22
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var filtered = 0.0

        for index in 0..<count {
            let t = Double(index) / sampleRate
            filtered += (Double.random(in: -1...1) - filtered) * 0.12
            let noise = filtered * exp(-t * 26)
            let thump = sin(2 * Double.pi * 95 * t) * exp(-t * 14)
            samples[index] = Float((noise * 0.55 + thump * 0.7) * 0.55)
        }
        return samples
    }

    private static func step() -> [Float] {
        let duration = 0.09
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var filtered = 0.0

        for index in 0..<count {
            let t = Double(index) / sampleRate
            filtered += (Double.random(in: -1...1) - filtered) * 0.25
            let envelope = exp(-t * 40)
            let low = sin(2 * Double.pi * 70 * t) * exp(-t * 30)
            samples[index] = Float((filtered * 0.5 + low * 0.5) * envelope * 0.4)
        }
        return samples
    }

    private static func creak() -> [Float] {
        let duration = 0.55
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var filtered = 0.0

        for index in 0..<count {
            let t = Double(index) / sampleRate
            let glide = 220.0 - 80.0 * (t / duration)
            let wobble = glide * (1 + 0.02 * sin(2 * Double.pi * 7 * t))
            filtered += (Double.random(in: -1...1) - filtered) * 0.3
            let envelope = min(1, t / 0.05) * exp(-t * 2.4)
            let tone = sin(2 * Double.pi * wobble * t)
            samples[index] = Float((tone * 0.5 + filtered * 0.35) * envelope * 0.4)
        }
        return samples
    }

    private static func whoosh() -> [Float] {
        let duration = 0.6
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)
        var filtered = 0.0

        for index in 0..<count {
            let t = Double(index) / sampleRate
            let progress = t / duration
            filtered += (Double.random(in: -1...1) - filtered) * (0.05 + 0.35 * progress)
            let envelope = sin(Double.pi * progress)
            samples[index] = Float(filtered * envelope * 0.6)
        }
        return samples
    }

    // MARK: Music

    private struct MoodPreset {
        var bpm: Double
        var root: Int
        var scale: [Int]
        var chords: [[Int]]
        var melody: [Int]
        var padLevel: Float
        var bassLevel: Float
        var melodyLevel: Float
    }

    private static func preset(_ mood: MusicMood) -> MoodPreset? {
        switch mood {
        case .calm:
            return MoodPreset(bpm: 72, root: 60, scale: [0, 2, 4, 7, 9],
                              chords: [[0, 4, 7], [5, 9, 12], [7, 11, 14], [0, 4, 7]],
                              melody: [0, 2, 4, 2, 3, 4, 2, 0],
                              padLevel: 0.16, bassLevel: 0.18, melodyLevel: 0.12)
        case .adventure:
            return MoodPreset(bpm: 112, root: 62, scale: [0, 2, 4, 7, 9],
                              chords: [[0, 4, 7], [7, 11, 14], [9, 12, 16], [5, 9, 12]],
                              melody: [0, 2, 4, 2, 3, 4, 2, 0],
                              padLevel: 0.14, bassLevel: 0.2, melodyLevel: 0.16)
        case .tense:
            return MoodPreset(bpm: 96, root: 57, scale: [0, 2, 3, 5, 7, 8],
                              chords: [[0, 3, 7], [1, 5, 8], [0, 3, 7], [3, 7, 10]],
                              melody: [0, 1, 0, 2, 0, 1, 3, 1],
                              padLevel: 0.13, bassLevel: 0.22, melodyLevel: 0.12)
        case .battle:
            return MoodPreset(bpm: 138, root: 50, scale: [0, 2, 3, 5, 7],
                              chords: [[0, 3, 7], [5, 8, 12], [3, 7, 10], [0, 3, 7]],
                              melody: [0, 3, 2, 4, 0, 3, 1, 2],
                              padLevel: 0.1, bassLevel: 0.24, melodyLevel: 0.17)
        case .mystery:
            return MoodPreset(bpm: 80, root: 59, scale: [0, 2, 4, 6, 8, 10],
                              chords: [[0, 4, 8], [2, 6, 10], [1, 5, 9], [0, 4, 8]],
                              melody: [0, 3, 1, 4, 2, 5, 3, 1],
                              padLevel: 0.15, bassLevel: 0.14, melodyLevel: 0.1)
        case .triumph:
            return MoodPreset(bpm: 124, root: 62, scale: [0, 2, 4, 5, 7, 9],
                              chords: [[0, 4, 7], [5, 9, 12], [7, 11, 14], [0, 4, 7]],
                              melody: [4, 4, 3, 2, 4, 3, 2, 0],
                              padLevel: 0.15, bassLevel: 0.2, melodyLevel: 0.17)
        case .none:
            return nil
        }
    }

    static func music(_ mood: MusicMood) -> [Float] {
        guard let preset = preset(mood) else { return [] }

        let beat = 60.0 / preset.bpm
        let barLength = beat * 4
        let bars = 4
        let duration = barLength * Double(bars)
        let count = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: count)

        func addNote(_ midi: Int, start: Double, length: Double, level: Float, wave: Wave) {
            let frequency = 440.0 * pow(2.0, (Double(midi) - 69) / 12)
            let startIndex = Int(start * sampleRate)
            let size = max(1, Int(length * sampleRate))
            for index in 0..<size {
                let position = startIndex + index
                guard position < count else { break }
                let t = Double(index) / sampleRate
                let attack = min(1, t / 0.04)
                let release = min(1, (length - t) / 0.18)
                let envelope = attack * max(0, release)
                let value = sample(for: wave, frequency: frequency, t: t) * envelope
                samples[position] += Float(value * Double(level))
            }
        }

        for bar in 0..<bars {
            let start = Double(bar) * barLength
            let chord = preset.chords[bar % preset.chords.count]

            for interval in chord {
                addNote(preset.root + interval, start: start, length: barLength, level: preset.padLevel, wave: .sine)
            }
            addNote(preset.root - 12 + chord[0], start: start, length: barLength * 0.85, level: preset.bassLevel, wave: .sine)

            for step in 0..<8 {
                let noteIndex = preset.melody[(bar * 8 + step) % preset.melody.count]
                addNote(preset.root + 12 + preset.scale[noteIndex % preset.scale.count],
                        start: start + Double(step) * beat / 2,
                        length: beat * 0.42,
                        level: preset.melodyLevel,
                        wave: .triangle)
            }
        }

        // A gentle fade at both ends so the loop joins without a click.
        let fade = Int(0.02 * sampleRate)
        for index in 0..<min(fade, count) {
            let amount = Float(index) / Float(fade)
            samples[index] *= amount
            samples[count - 1 - index] *= amount
        }
        return samples
    }
}
