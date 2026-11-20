//
//  LevelAudio.swift
//  Maker
//
//  The music and the little sounds a level is made of.
//

import Foundation

enum MusicMood: String, Codable, CaseIterable, Identifiable {
    case none, calm, adventure, tense, battle, mystery, triumph

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "No music"
        case .calm: return "Calm"
        case .adventure: return "Adventure"
        case .tense: return "Tense"
        case .battle: return "Battle"
        case .mystery: return "Mystery"
        case .triumph: return "Triumph"
        }
    }

    var symbol: String {
        switch self {
        case .none: return "speaker.slash.fill"
        case .calm: return "leaf.fill"
        case .adventure: return "map.fill"
        case .tense: return "exclamationmark.triangle.fill"
        case .battle: return "flame.fill"
        case .mystery: return "moon.stars.fill"
        case .triumph: return "crown.fill"
        }
    }
}

enum SoundEffect: String, Codable, CaseIterable, Identifiable {
    case none, coin, chime, hit, creak, whoosh, jump, step, fanfare, sparkle, hurt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Silent"
        case .coin: return "Coin chime"
        case .chime: return "Bell"
        case .hit: return "Thud"
        case .creak: return "Door creak"
        case .whoosh: return "Whoosh"
        case .jump: return "Hop"
        case .step: return "Footstep"
        case .fanfare: return "Fanfare"
        case .sparkle: return "Sparkle"
        case .hurt: return "Ouch"
        }
    }

    var symbol: String {
        switch self {
        case .none: return "speaker.slash"
        case .coin: return "circle.fill"
        case .chime: return "bell.fill"
        case .hit: return "hammer.fill"
        case .creak: return "lock.open.fill"
        case .whoosh: return "wind"
        case .jump: return "arrow.up"
        case .step: return "figure.walk"
        case .fanfare: return "crown.fill"
        case .sparkle: return "sparkles"
        case .hurt: return "heart.slash.fill"
        }
    }
}

struct LevelAudio: Codable, Hashable {
    var mood: MusicMood = .none

    var coin: SoundEffect = .coin
    var hit: SoundEffect = .hit
    var door: SoundEffect = .creak
    var portal: SoundEffect = .whoosh
    var jump: SoundEffect = .jump
    var step: SoundEffect = .step
}
