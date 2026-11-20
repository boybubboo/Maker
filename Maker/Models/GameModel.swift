//
//  GameModel.swift
//  Maker
//
//  The document a kid builds: a game, its levels, the things in them,
//  the rules those things follow, and the interface drawn on top.
//

import Foundation
import SwiftUI

// MARK: - Stages

enum StageTab: String, CaseIterable, Identifiable, Codable {
    case world, cast, logic, actions, interface, publish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .world: return "World"
        case .cast: return "Cast"
        case .logic: return "Logic"
        case .actions: return "Actions"
        case .interface: return "Interface"
        case .publish: return "Publish"
        }
    }

    var symbol: String {
        switch self {
        case .world: return "map.fill"
        case .cast: return "person.3.fill"
        case .logic: return "arrow.triangle.branch"
        case .actions: return "figure.run"
        case .interface: return "rectangle.3.group"
        case .publish: return "paperplane.fill"
        }
    }

    var tint: Color {
        switch self {
        case .world: return Palette.mint
        case .cast: return Palette.sky
        case .logic: return Palette.plum
        case .actions: return Palette.amber
        case .interface: return Palette.accent
        case .publish: return Palette.coral
        }
    }

    var blurb: String {
        switch self {
        case .world: return "Terrain, scenery, and how levels link together."
        case .cast: return "Everyone and everything that lives in the level."
        case .logic: return "Rules that make things happen."
        case .actions: return "Everything your character can do."
        case .interface: return "Health bars, inventory, minimap."
        case .publish: return "Check it over and share it."
        }
    }
}

// MARK: - Project

struct GameProject: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var tagline: String = ""
    var symbol: String = "castle.fill"
    var colorHex: String = "#6C4CF1"
    var createdAt = Date()
    var updatedAt = Date()

    var levels: [GameLevel] = []
    var heroName: String = "Pip"
    var heroBody: String = "Adventurer"
    var heroCharacterID: UUID? = nil
    var importedCharacters: [ImportedCharacter]? = nil
    var enabledActions: Set<String> = ActionRegistry.starter
    var hud: HUDProfile = HUDProfile.adventure
    var currencies: [String] = ["Coins", "Gems", "Keys"]

    var coverTagline: String = ""
    var difficulty: String = "Easy"
    var published: Bool = false
    var sharedBy: String? = nil

    var tint: Color { Color(hex: colorHex) }

    var levelCount: Int { levels.count }

    var entityCount: Int {
        levels.reduce(0) { $0 + $1.entities.count }
    }

    var updatedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }

    func level(with id: UUID?) -> GameLevel? {
        guard let id else { return levels.first }
        return levels.first { $0.id == id } ?? levels.first
    }

    func levelIndex(of id: UUID?) -> Int? {
        guard let id else { return levels.isEmpty ? nil : 0 }
        return levels.firstIndex { $0.id == id }
    }
}

// MARK: - Level

struct GameLevel: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var style: LevelStyle = .openWorld
    var biome: Biome = .meadow
    var sky: SkyPreset = .sunny
    var sunAngle: Double = 45
    var fog: Double = 0.15
    var hasStart: Bool = true
    var hasPortal: Bool = true
    var completeCondition: CompleteCondition = .reachPortal
    var requiredCount: Int = 3
    var nextLevelID: UUID? = nil
    var objectives: [LevelObjective] = []
    var entities: [LevelEntity] = []
    var terrain: TerrainData? = nil
    var audio: LevelAudio? = nil
    var stickers: [Sticker]? = nil
    var weather: String? = nil
    var wind: Double? = nil
    var swimming: Bool? = nil
    var notes: String = ""

    /// The weather, the wind and whether the sea can be swum, read the way
    /// older levels expect them to be.
    var weatherKind: WeatherKind {
        WeatherKind(rawValue: weather ?? WeatherKind.none.rawValue) ?? .none
    }

    var windStrength: Double { wind ?? 0.3 }

    var canSwim: Bool { swimming ?? true }

    var baddies: [LevelEntity] { entities.filter { $0.kind == .baddie } }
    var npcs: [LevelEntity] { entities.filter { $0.kind == .npc } }
    var hazards: [LevelEntity] { entities.filter { $0.kind.section == .hazards } }
    var treasures: [LevelEntity] { entities.filter { $0.kind.section == .things } }

    func entities(in section: EntitySection) -> [LevelEntity] {
        entities.filter { $0.kind.section == section }
    }

    func entity(with id: UUID?) -> LevelEntity? {
        guard let id else { return nil }
        return entities.first { $0.id == id }
    }

    /// A small, kid-readable summary of how a level plays.
    var playSummary: String {
        let enemies = baddies.count
        let loot = treasures.count
        var parts: [String] = []
        if enemies > 0 { parts.append("\(enemies) baddie\(enemies == 1 ? "" : "s")") }
        if loot > 0 { parts.append("\(loot) treasure\(loot == 1 ? "" : "s")") }
        if hazardCount > 0 { parts.append("\(hazardCount) hazard\(hazardCount == 1 ? "" : "s")") }
        if parts.isEmpty { parts.append("a quiet place to explore") }
        return parts.joined(separator: " · ")
    }

    var hazardCount: Int { entities.filter { $0.kind == .trap }.count }
}

enum WeatherKind: String, CaseIterable, Identifiable, Codable {
    case none, rain, snow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Clear"
        case .rain: return "Rain"
        case .snow: return "Snow"
        }
    }

    var symbol: String {
        switch self {
        case .none: return "sun.max.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "snowflake"
        }
    }
}

enum LevelStyle: String, Codable, CaseIterable, Identifiable {
    case openWorld, roomChain
    var id: String { rawValue }

    var title: String {
        switch self {
        case .openWorld: return "Open world"
        case .roomChain: return "Room chain"
        }
    }

    var symbol: String {
        switch self {
        case .openWorld: return "map.fill"
        case .roomChain: return "square.grid.2x2.fill"
        }
    }

    var blurb: String {
        switch self {
        case .openWorld: return "One big place to roam around."
        case .roomChain: return "A row of rooms joined by doors."
        }
    }
}

enum Biome: String, Codable, CaseIterable, Identifiable {
    case meadow, island, forest, snow, desert, cave, swamp, night

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meadow: return "Meadow"
        case .island: return "Island"
        case .forest: return "Forest"
        case .snow: return "Snow"
        case .desert: return "Desert"
        case .cave: return "Cave"
        case .swamp: return "Swamp"
        case .night: return "Night"
        }
    }

    var symbol: String {
        switch self {
        case .meadow: return "leaf.fill"
        case .island: return "sun.max.fill"
        case .forest: return "tree.fill"
        case .snow: return "snowflake"
        case .desert: return "sun.dust.fill"
        case .cave: return "mountain.2.fill"
        case .swamp: return "drop.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var ground: Color {
        switch self {
        case .meadow: return Color(hex: "#A8D672")
        case .island: return Color(hex: "#F0DDA6")
        case .forest: return Color(hex: "#6E9E5A")
        case .snow: return Color(hex: "#E6EEF5")
        case .desert: return Color(hex: "#F0C98A")
        case .cave: return Color(hex: "#6B6478")
        case .swamp: return Color(hex: "#7E8C5A")
        case .night: return Color(hex: "#4B5478")
        }
    }

    var detail: Color {
        switch self {
        case .meadow: return Color(hex: "#7BB84A")
        case .island: return Color(hex: "#CBB26A")
        case .forest: return Color(hex: "#46703A")
        case .snow: return Color(hex: "#C3D3E0")
        case .desert: return Color(hex: "#D9A45E")
        case .cave: return Color(hex: "#48425A")
        case .swamp: return Color(hex: "#55663C")
        case .night: return Color(hex: "#333A57")
        }
    }

    var water: Color {
        switch self {
        case .meadow: return Color(hex: "#7CC6F2")
        case .island: return Color(hex: "#4FC3E8")
        case .forest: return Color(hex: "#5FB0C9")
        case .snow: return Color(hex: "#9FCBE0")
        case .desert: return Color(hex: "#6FC2D6")
        case .cave: return Color(hex: "#4A6E8A")
        case .swamp: return Color(hex: "#6B7F55")
        case .night: return Color(hex: "#3E6B8A")
        }
    }
}

enum SkyPreset: String, Codable, CaseIterable, Identifiable {
    case sunny, golden, night, mist, storm, cave

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sunny: return "Sunny noon"
        case .golden: return "Golden hour"
        case .night: return "Starry night"
        case .mist: return "Foggy morning"
        case .storm: return "Storm"
        case .cave: return "Underground"
        }
    }

    var symbol: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .golden: return "sunset.fill"
        case .night: return "moon.stars.fill"
        case .mist: return "cloud.fog.fill"
        case .storm: return "cloud.bolt.fill"
        case .cave: return "mountain.2.fill"
        }
    }

    var tint: Color {
        switch self {
        case .sunny: return Palette.sky
        case .golden: return Palette.amber
        case .night: return Palette.plum
        case .mist: return Palette.inkSoft
        case .storm: return Color(hex: "#5A6472")
        case .cave: return Palette.plum
        }
    }
}

enum CompleteCondition: String, Codable, CaseIterable, Identifiable {
    case reachPortal, collectAll, defeatAll, solvePuzzle, collectKeys, talkToNPC

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reachPortal: return "Reach the portal"
        case .collectAll: return "Collect treasures"
        case .defeatAll: return "Defeat every baddie"
        case .solvePuzzle: return "Solve the puzzle"
        case .collectKeys: return "Find the keys"
        case .talkToNPC: return "Talk to someone"
        }
    }

    var symbol: String {
        switch self {
        case .reachPortal: return "sparkles"
        case .collectAll: return "gift.fill"
        case .defeatAll: return "bolt.fill"
        case .solvePuzzle: return "square.grid.2x2.fill"
        case .collectKeys: return "key.fill"
        case .talkToNPC: return "bubble.left.fill"
        }
    }

    var needsCount: Bool { self == .collectAll || self == .defeatAll || self == .collectKeys }
}

struct LevelObjective: Identifiable, Codable, Hashable {
    var id = UUID()
    var text: String
    var isOptional: Bool = false
}

// MARK: - Things in a level

enum EntitySection: String, CaseIterable, Identifiable, Codable {
    case cast, things, hazards, puzzles, scenery, markers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cast: return "Cast"
        case .things: return "Things"
        case .hazards: return "Hazards"
        case .puzzles: return "Puzzles"
        case .scenery: return "Scenery"
        case .markers: return "Markers"
        }
    }

    var symbol: String {
        switch self {
        case .cast: return "person.3.fill"
        case .things: return "gift.fill"
        case .hazards: return "exclamationmark.triangle.fill"
        case .puzzles: return "square.grid.2x2.fill"
        case .scenery: return "leaf.fill"
        case .markers: return "flag.fill"
        }
    }

    var blurb: String {
        switch self {
        case .cast: return "Who lives here: your hero, helpful NPCs and baddies."
        case .things: return "Treasure, keys, doors and pickups."
        case .hazards: return "Traps and spawners that make a level tricky."
        case .puzzles: return "Switches, plates and locks to solve."
        case .scenery: return "Props, plants and lights that make it pretty."
        case .markers: return "The start, the portal and checkpoints."
        }
    }

    var memberKinds: [EntityKind] {
        EntityKind.allCases.filter { $0.section == self }
    }
}

enum EntityKind: String, Codable, CaseIterable, Identifiable {
    case hero, npc, baddie, treasure, key, door, pickup
    case trap, spawner, puzzle
    case prop, scenery, platform, sign, light
    case portal, checkpoint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hero: return "Hero"
        case .npc: return "NPC"
        case .baddie: return "Baddie"
        case .treasure: return "Treasure"
        case .key: return "Key"
        case .door: return "Door"
        case .pickup: return "Pickup"
        case .trap: return "Trap"
        case .spawner: return "Spawner"
        case .puzzle: return "Puzzle"
        case .prop: return "Prop"
        case .scenery: return "Scenery"
        case .platform: return "Platform"
        case .sign: return "Sign"
        case .light: return "Light"
        case .portal: return "Portal"
        case .checkpoint: return "Checkpoint"
        }
    }

    var symbol: String {
        switch self {
        case .hero: return "figure.stand"
        case .npc: return "bubble.left.fill"
        case .baddie: return "bolt.fill"
        case .treasure: return "gift.fill"
        case .key: return "key.fill"
        case .door: return "lock.open.fill"
        case .pickup: return "bag.fill"
        case .trap: return "exclamationmark.triangle.fill"
        case .spawner: return "arrow.triangle.2.circlepath"
        case .puzzle: return "square.grid.2x2.fill"
        case .prop: return "cube.fill"
        case .scenery: return "leaf.fill"
        case .platform: return "square.stack.3d.up.fill"
        case .sign: return "text.bubble.fill"
        case .light: return "lightbulb.fill"
        case .portal: return "sparkles"
        case .checkpoint: return "flag.fill"
        }
    }

    var tint: Color {
        switch self {
        case .hero: return Palette.accent
        case .npc: return Palette.sky
        case .baddie: return Palette.coral
        case .treasure: return Palette.gold
        case .key: return Palette.amber
        case .door: return Color(hex: "#A9744F")
        case .pickup: return Palette.mint
        case .trap: return Color(hex: "#E4572E")
        case .spawner: return Palette.coral
        case .puzzle: return Palette.plum
        case .prop: return Palette.mint
        case .scenery: return Color(hex: "#3E8E5A")
        case .platform: return Palette.inkSoft
        case .sign: return Color(hex: "#C08A3E")
        case .light: return Palette.amber
        case .portal: return Palette.accent
        case .checkpoint: return Palette.mint
        }
    }

    var section: EntitySection {
        switch self {
        case .hero, .npc, .baddie: return .cast
        case .treasure, .key, .door, .pickup: return .things
        case .trap, .spawner: return .hazards
        case .puzzle: return .puzzles
        case .prop, .scenery, .platform, .sign, .light: return .scenery
        case .portal, .checkpoint: return .markers
        }
    }

    var defaultName: String {
        switch self {
        case .hero: return "Hero"
        case .npc: return "Friend"
        case .baddie: return "Baddie"
        case .treasure: return "Treasure chest"
        case .key: return "Gold key"
        case .door: return "Locked door"
        case .pickup: return "Pickup"
        case .trap: return "Spike trap"
        case .spawner: return "Spawner"
        case .puzzle: return "Pressure plate"
        case .prop: return "Barrel"
        case .scenery: return "Tree"
        case .platform: return "Moving platform"
        case .sign: return "Sign"
        case .light: return "Torch"
        case .portal: return "Portal"
        case .checkpoint: return "Checkpoint"
        }
    }

    /// Kinds a kid can drop into a level by hand.
    var isAddable: Bool { self != .hero && self != .portal }

    var usesStats: Bool { self == .npc || self == .baddie }
}

struct BoardPoint: Codable, Hashable {
    var x: CGFloat
    var y: CGFloat
}

struct LevelEntity: Identifiable, Codable, Hashable {
    enum CodingKeys: String, CodingKey {
        case id, kind, name, position, rotation, scale
        case isBoss, brain, health, speed, damage
        case loot, puzzleType, dialogue, notes, cards
        case platformPreset, platformMotion, platformSpeed, platformWait, platformEnd, platformRunning
        case quest, conversation
        case texture
    }

    var id = UUID()
    var kind: EntityKind
    var name: String
    var position = BoardPoint(x: 0.5, y: 0.5)
    var rotation: Double = 0
    var scale: Double = 1

    // Cast
    var isBoss: Bool = false
    var brain: String = "Patroller"
    var health: Int = 3
    var speed: Int = 3
    var damage: Int = 1

    // Things
    var loot: String = "Coins"
    var puzzleType: String = "Pressure plate"
    var dialogue: String = ""

    /// A texture painted over the prop, from the sticker and texture tools.
    var texture: String? = nil

    // Moving platforms
    var platformPreset: String = "stoneLift"
    var platformMotion: String = "slide"
    var platformSpeed: Double = 1.0
    var platformWait: Double = 1.0
    var platformEnd: BoardPoint? = nil
    var platformRunning: Bool = true

    // Quests and conversations
    var quest: Quest? = nil
    var conversation: [ConversationLine] = []

    var notes: String = ""
    var cards: [BehaviorCard] = []

    var tint: Color { kind.tint }

    /// The pattern painted over this prop, if any.
    var surfacePattern: SurfacePattern? {
        guard let texture, texture != SurfacePattern.bare.rawValue else { return nil }
        return SurfacePattern(rawValue: texture)
    }
}

// MARK: - Rules

struct CardClause: Identifiable, Codable, Hashable {
    var id = UUID()
    var key: String
    var detail: String = ""
}

// MARK: - Quests and conversations

enum QuestStepTrigger: String, Codable, CaseIterable, Identifiable {
    case talkedTo, foundKey, openedTreasure, beatBaddie, touchedCheckpoint

    var id: String { rawValue }

    var title: String {
        switch self {
        case .talkedTo: return "Talk to me again"
        case .foundKey: return "A key is picked up"
        case .openedTreasure: return "A treasure is opened"
        case .beatBaddie: return "A baddie is beaten"
        case .touchedCheckpoint: return "A checkpoint is reached"
        }
    }

    var symbol: String {
        switch self {
        case .talkedTo: return "bubble.left.fill"
        case .foundKey: return "key.fill"
        case .openedTreasure: return "gift.fill"
        case .beatBaddie: return "bolt.fill"
        case .touchedCheckpoint: return "flag.fill"
        }
    }
}

struct QuestStep: Identifiable, Codable, Hashable {
    var id = UUID()
    var text: String = "Find the key"
    var trigger: QuestStepTrigger = .foundKey
}

struct Quest: Codable, Hashable {
    var title: String = "A new quest"
    var steps: [QuestStep] = []
    var rewardCoins: Int = 5
    var rewardKey: Bool = false
}

struct ConversationLine: Identifiable, Codable, Hashable {
    var id = UUID()
    var isHero: Bool = false
    var words: String = ""
    var replies: [String] = []
}

struct BehaviorCard: Identifiable, Codable, Hashable {
    var id = UUID()
    var when: CardClause
    var conditions: [CardClause] = []
    var actions: [CardClause] = []
    var isOnce: Bool = false
    var isEnabled: Bool = true
}

// MARK: - Interface

enum WidgetAnchor: String, Codable, CaseIterable, Identifiable {
    case topLeading, top, topTrailing, bottomLeading, bottom, bottomTrailing, center

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeading: return "Top left"
        case .top: return "Top"
        case .topTrailing: return "Top right"
        case .bottomLeading: return "Bottom left"
        case .bottom: return "Bottom"
        case .bottomTrailing: return "Bottom right"
        case .center: return "Centre"
        }
    }

    var symbol: String {
        switch self {
        case .topLeading: return "arrow.up.left"
        case .top: return "arrow.up"
        case .topTrailing: return "arrow.up.right"
        case .bottomLeading: return "arrow.down.left"
        case .bottom: return "arrow.down"
        case .bottomTrailing: return "arrow.down.right"
        case .center: return "circle"
        }
    }

    var alignment: Alignment {
        switch self {
        case .topLeading: return .topLeading
        case .top: return .top
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottom: return .bottom
        case .bottomTrailing: return .bottomTrailing
        case .center: return .center
        }
    }
}

enum WidgetKind: String, Codable, CaseIterable, Identifiable {
    case bar, counter, inventoryGrid, minimap, objectiveList, dialogue, pauseButton, timer, bossBar, tutorial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bar: return "Bar"
        case .counter: return "Counter"
        case .inventoryGrid: return "Inventory"
        case .minimap: return "Minimap"
        case .objectiveList: return "Objectives"
        case .dialogue: return "Dialogue"
        case .pauseButton: return "Pause button"
        case .timer: return "Timer"
        case .bossBar: return "Boss bar"
        case .tutorial: return "Tip bubble"
        }
    }

    var symbol: String {
        switch self {
        case .bar: return "chart.bar.fill"
        case .counter: return "number.circle.fill"
        case .inventoryGrid: return "square.grid.3x3.fill"
        case .minimap: return "map.fill"
        case .objectiveList: return "list.bullet"
        case .dialogue: return "bubble.left.fill"
        case .pauseButton: return "pause.fill"
        case .timer: return "timer"
        case .bossBar: return "figure.arms.open"
        case .tutorial: return "hand.tap.fill"
        }
    }

    var blurb: String {
        switch self {
        case .bar: return "Shows health, stamina or magic."
        case .counter: return "Counts coins, gems or keys."
        case .inventoryGrid: return "A row of slots for items."
        case .minimap: return "A little map of where you are."
        case .objectiveList: return "What to do next."
        case .dialogue: return "What a character is saying."
        case .pauseButton: return "Stops the game."
        case .timer: return "Counts down or up."
        case .bossBar: return "Big health bar for a boss."
        case .tutorial: return "A hint that pops up."
        }
    }

    var defaultSize: CGSize {
        switch self {
        case .bar: return CGSize(width: 190, height: 26)
        case .counter: return CGSize(width: 108, height: 34)
        case .inventoryGrid: return CGSize(width: 216, height: 52)
        case .minimap: return CGSize(width: 122, height: 88)
        case .objectiveList: return CGSize(width: 230, height: 62)
        case .dialogue: return CGSize(width: 300, height: 74)
        case .pauseButton: return CGSize(width: 46, height: 46)
        case .timer: return CGSize(width: 92, height: 30)
        case .bossBar: return CGSize(width: 260, height: 34)
        case .tutorial: return CGSize(width: 210, height: 44)
        }
    }

    var usesBinding: Bool { self == .bar || self == .counter || self == .bossBar }
}

struct HUDWidget: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: WidgetKind
    var anchor: WidgetAnchor
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0
    var width: CGFloat
    var height: CGFloat
    var binding: String = "health"
    var fillHex: String = "#6C4CF1"
    var label: String = ""

    var fill: Color { Color(hex: fillHex) }

    static func make(
        _ kind: WidgetKind,
        anchor: WidgetAnchor,
        binding: String = "health",
        fillHex: String = "#6C4CF1",
        label: String = "",
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 0
    ) -> HUDWidget {
        HUDWidget(
            kind: kind,
            anchor: anchor,
            offsetX: offsetX,
            offsetY: offsetY,
            width: kind.defaultSize.width,
            height: kind.defaultSize.height,
            binding: binding,
            fillHex: fillHex,
            label: label
        )
    }
}

struct HUDProfile: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String = "Adventure"
    var themeName: String = "Adventure"
    var widgets: [HUDWidget] = []

    func widget(with id: UUID?) -> HUDWidget? {
        guard let id else { return nil }
        return widgets.first { $0.id == id }
    }

    static var adventure: HUDProfile {
        HUDProfile(name: "Adventure", themeName: "Adventure", widgets: [
            .make(.bar, anchor: .topLeading, binding: "health", fillHex: "#F2545B", label: "Health"),
            .make(.bar, anchor: .topLeading, binding: "stamina", fillHex: "#22B573", label: "Stamina", offsetY: 32),
            .make(.bar, anchor: .topLeading, binding: "magic", fillHex: "#3AA0FF", label: "Magic", offsetY: 62),
            .make(.counter, anchor: .topTrailing, binding: "coins", fillHex: "#F2C230", label: "Coins"),
            .make(.minimap, anchor: .topTrailing, binding: "map", fillHex: "#6C4CF1", label: "Map", offsetY: 44),
            .make(.objectiveList, anchor: .bottomLeading, binding: "objectives", fillHex: "#6C4CF1", label: "Objectives"),
            .make(.inventoryGrid, anchor: .bottomLeading, binding: "inventory", fillHex: "#6C4CF1", label: "Bag", offsetY: -74),
            .make(.pauseButton, anchor: .bottomTrailing, binding: "pause", fillHex: "#F2545B", label: "Pause")
        ])
    }
}

// MARK: - Stats a HUD can read

struct BindableStat: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let isLive: Bool
}

enum StatLibrary {
    static let all: [BindableStat] = [
        BindableStat(id: "health", title: "Health", symbol: "heart.fill", isLive: true),
        BindableStat(id: "stamina", title: "Stamina", symbol: "figure.run", isLive: true),
        BindableStat(id: "magic", title: "Magic", symbol: "sparkles", isLive: true),
        BindableStat(id: "coins", title: "Coins", symbol: "circle.fill", isLive: true),
        BindableStat(id: "gems", title: "Gems", symbol: "diamond.fill", isLive: false),
        BindableStat(id: "keys", title: "Keys", symbol: "key.fill", isLive: true),
        BindableStat(id: "timer", title: "Timer", symbol: "timer", isLive: true),
        BindableStat(id: "objectives", title: "Objectives", symbol: "list.bullet", isLive: true),
        BindableStat(id: "inventory", title: "Inventory", symbol: "bag.fill", isLive: false),
        BindableStat(id: "map", title: "Minimap", symbol: "map.fill", isLive: true),
        BindableStat(id: "pause", title: "Pause", symbol: "pause.fill", isLive: false)
    ]

    static func stat(_ id: String) -> BindableStat? {
        all.first { $0.id == id }
    }
}


// MARK: - Tolerant decoding for entities

extension LevelEntity {
    /// Projects made before the 3D viewport existed have no rotation or
    /// scale, so every field is read leniently and missing ones take the
    /// value a new entity would have.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try container.decodeIfPresent(EntityKind.self, forKey: .kind) ?? .prop
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Prop"
        position = try container.decodeIfPresent(BoardPoint.self, forKey: .position) ?? BoardPoint(x: 0.5, y: 0.5)
        rotation = try container.decodeIfPresent(Double.self, forKey: .rotation) ?? 0
        scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1
        isBoss = try container.decodeIfPresent(Bool.self, forKey: .isBoss) ?? false
        brain = try container.decodeIfPresent(String.self, forKey: .brain) ?? "Patroller"
        health = try container.decodeIfPresent(Int.self, forKey: .health) ?? 3
        speed = try container.decodeIfPresent(Int.self, forKey: .speed) ?? 3
        damage = try container.decodeIfPresent(Int.self, forKey: .damage) ?? 1
        loot = try container.decodeIfPresent(String.self, forKey: .loot) ?? "Coins"
        puzzleType = try container.decodeIfPresent(String.self, forKey: .puzzleType) ?? "Pressure plate"
        dialogue = try container.decodeIfPresent(String.self, forKey: .dialogue) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        cards = try container.decodeIfPresent([BehaviorCard].self, forKey: .cards) ?? []
        platformPreset = try container.decodeIfPresent(String.self, forKey: .platformPreset) ?? "stoneLift"
        platformMotion = try container.decodeIfPresent(String.self, forKey: .platformMotion) ?? "slide"
        platformSpeed = try container.decodeIfPresent(Double.self, forKey: .platformSpeed) ?? 1.0
        platformWait = try container.decodeIfPresent(Double.self, forKey: .platformWait) ?? 1.0
        platformEnd = try container.decodeIfPresent(BoardPoint.self, forKey: .platformEnd)
        platformRunning = try container.decodeIfPresent(Bool.self, forKey: .platformRunning) ?? true
        quest = try container.decodeIfPresent(Quest.self, forKey: .quest)
        conversation = try container.decodeIfPresent([ConversationLine].self, forKey: .conversation) ?? []
        texture = try container.decodeIfPresent(String.self, forKey: .texture)
    }
}
