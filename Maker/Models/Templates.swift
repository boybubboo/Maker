//
//  Templates.swift
//  Maker
//
//  Starting points so nobody ever faces an empty project.
//

import Foundation
import SwiftUI

struct GameTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let colorHex: String
    let blurb: String
}

enum TemplateLibrary {
    static let all: [GameTemplate] = [
        GameTemplate(id: "castle", name: "Castle Adventure", symbol: "castle.fill", colorHex: "#6C4CF1",
                     blurb: "Three levels, a gold key and a grumpy guard."),
        GameTemplate(id: "island", name: "Island Explorer", symbol: "sun.max.fill", colorHex: "#22B573",
                     blurb: "Palm trees, a hidden cave and a friendly crab."),
        GameTemplate(id: "manor", name: "Spooky Manor", symbol: "moon.stars.fill", colorHex: "#9B5DE5",
                     blurb: "Creaky floors, bats and a very polite ghost."),
        GameTemplate(id: "space", name: "Space Base", symbol: "sparkles", colorHex: "#3AA0FF",
                     blurb: "Low gravity, robots and a wobbly airlock."),
        GameTemplate(id: "dojo", name: "Ninja Dojo", symbol: "figure.run", colorHex: "#F2545B",
                     blurb: "Sneak past guards and ring the big bell."),
        GameTemplate(id: "blank", name: "Blank world", symbol: "square.dashed", colorHex: "#8E8E93",
                     blurb: "One empty level with a start and a portal.")
    ]

    static let blank = GameTemplate(id: "blank", name: "Blank world", symbol: "square.dashed", colorHex: "#8E8E93",
                                    blurb: "One empty level with a start and a portal.")

    // MARK: Building

    static func project(for template: GameTemplate, name: String) -> GameProject {
        switch template.id {
        case "castle": return castle(name: name)
        case "island": return themed(name: name, biome: .island, levels: ["Palm Beach", "Hidden Cave"],
                                     baddie: "Crab", npc: "Skipper", symbol: "sun.max.fill", color: "#22B573",
                                     tagline: "Find the treasure before the tide comes in.")
        case "manor": return themed(name: name, biome: .night, levels: ["The Hallway", "The Cellar"],
                                    baddie: "Bat", npc: "Ghost", symbol: "moon.stars.fill", color: "#9B5DE5",
                                    tagline: "A spooky house with one friendly ghost.")
        case "space": return themed(name: name, biome: .cave, levels: ["Landing Bay", "Reactor Room"],
                                    baddie: "Robot", npc: "Pilot", symbol: "sparkles", color: "#3AA0FF",
                                    tagline: "Fix the base and get home.")
        case "dojo": return themed(name: name, biome: .forest, levels: ["The Courtyard", "The Bell Tower"],
                                   baddie: "Ninja", npc: "Master", symbol: "figure.run", color: "#F2545B",
                                   tagline: "Sneak in and ring the bell.")
        default:
            var project = GameProject(name: name, tagline: "Your very own world.", symbol: template.symbol, colorHex: template.colorHex)
            var level = GameLevel(name: "Level 1", biome: .meadow)
            level.audio = LevelAudio(mood: .calm)
            level.objectives = [LevelObjective(text: "Reach the portal")]
            project.levels = [level]
            project.coverTagline = "A brand new adventure."
            return project
        }
    }

    static func starterProjects() -> [GameProject] {
        [
            castle(name: "Castle Adventure"),
            themed(name: "Island Explorer", biome: .island, levels: ["Palm Beach", "Hidden Cave"],
                   baddie: "Crab", npc: "Skipper", symbol: "sun.max.fill", color: "#22B573",
                   tagline: "Find the treasure before the tide comes in.")
        ]
    }

    // MARK: Castle

    private static func castle(name: String) -> GameProject {
        var project = GameProject(name: name, tagline: "Save the castle from the grumpy guard.",
                                  symbol: "castle.fill", colorHex: "#6C4CF1")
        project.heroName = "Pip"
        project.heroBody = "Adventurer"
        project.coverTagline = "One key. Three levels. A very grumpy guard."

        // Level 1
        var courtyard = GameLevel(name: "The Courtyard", biome: .meadow, sky: .sunny)
        courtyard.audio = LevelAudio(mood: .adventure)
        courtyard.objectives = [
            LevelObjective(text: "Find the gold key"),
            LevelObjective(text: "Open the big door")
        ]
        courtyard.entities = [
            make(.npc, "Mira the Merchant", x: 0.24, y: 0.62,
                 dialogue: "A key? The guard dropped one by the well.",
                 cards: [card("playerTalks", ["say", "playAnimation"], detail: "A key? The guard dropped one by the well.")]),
            make(.key, "Gold key", x: 0.58, y: 0.72),
            make(.baddie, "Guard", x: 0.42, y: 0.34, health: 3, brain: "Patroller",
                 cards: [card("seesPlayer", ["chase", "say"], detail: "Oi! Come back here!")]),
            make(.treasure, "Wooden chest", x: 0.72, y: 0.58,
                 cards: [card("playerTouches", ["giveTreasure", "playSound", "destroySelf"], detail: "3 coins")]),
            make(.trap, "Spike trap", x: 0.34, y: 0.48),
            make(.prop, "Barrel", x: 0.18, y: 0.42),
            make(.scenery, "Oak tree", x: 0.82, y: 0.34),
            make(.door, "Big door", x: 0.86, y: 0.5,
                 cards: [card("playerUses", ["openDoor", "showMessage"], detail: "The door creaks open.")])
        ]
        courtyard.nextLevelID = nil

        // Level 2
        var dungeon = GameLevel(name: "The Dungeon", biome: .cave, sky: .cave)
        dungeon.audio = LevelAudio(mood: .tense)
        dungeon.objectives = [
            LevelObjective(text: "Light the two torches"),
            LevelObjective(text: "Get past the bats")
        ]
        dungeon.completeCondition = .defeatAll
        dungeon.entities = [
            make(.baddie, "Bat", x: 0.32, y: 0.3, health: 2, brain: "Flyer"),
            make(.baddie, "Bat", x: 0.55, y: 0.42, health: 2, brain: "Flyer"),
            make(.puzzle, "Torch light", x: 0.24, y: 0.66, puzzleType: "Torch light",
                 cards: [card("playerTouches", ["playSound", "setFlag"], detail: "torch lit")]),
            make(.trap, "Dart wall", x: 0.66, y: 0.6),
            make(.treasure, "Old chest", x: 0.78, y: 0.3,
                 cards: [card("playerTouches", ["giveTreasure", "playSound", "destroySelf"], detail: "6 coins")]),
            make(.light, "Torch", x: 0.2, y: 0.28),
            make(.checkpoint, "Checkpoint", x: 0.5, y: 0.72)
        ]

        // Level 3
        var throne = GameLevel(name: "The Throne Room", biome: .cave, sky: .night)
        throne.audio = LevelAudio(mood: .battle)
        throne.objectives = [
            LevelObjective(text: "Defeat the guard captain"),
            LevelObjective(text: "Reach the portal")
        ]
        throne.completeCondition = .defeatAll
        throne.entities = [
            make(.baddie, "Captain", x: 0.6, y: 0.36, health: 8, brain: "Boss",
                 isBoss: true,
                 cards: [card("healthLow", ["say", "shakeCamera", "chase"], detail: "You are stronger than you look!")]),
            make(.treasure, "Crown", x: 0.8, y: 0.62),
            make(.prop, "Throne", x: 0.74, y: 0.26),
            make(.light, "Candle", x: 0.3, y: 0.3),
            make(.light, "Candle", x: 0.46, y: 0.3)
        ]

        courtyard.nextLevelID = dungeon.id
        dungeon.nextLevelID = throne.id
        project.levels = [courtyard, dungeon, throne]
        project.difficulty = "Easy"
        project.coverTagline = "One key. Three levels. A very grumpy guard."
        return project
    }

    // MARK: Themed

    private static func themed(
        name: String,
        biome: Biome,
        levels: [String],
        baddie: String,
        npc: String,
        symbol: String,
        color: String,
        tagline: String
    ) -> GameProject {
        var project = GameProject(name: name, tagline: tagline, symbol: symbol, colorHex: color)
        project.coverTagline = tagline

        var built: [GameLevel] = []
        for (index, title) in levels.enumerated() {
            var level = GameLevel(name: title, biome: biome)
            level.audio = LevelAudio(mood: .adventure)
            level.objectives = [LevelObjective(text: "Find the treasure"), LevelObjective(text: "Reach the portal")]
            level.completeCondition = .reachPortal
            level.entities = [
                make(.npc, npc, x: 0.22, y: 0.62,
                     dialogue: "Careful out there!",
                     cards: [card("playerTalks", ["say", "playAnimation"], detail: "Careful out there!")]),
                make(.baddie, baddie, x: 0.5, y: 0.36, health: 3, brain: "Chaser",
                     cards: [card("seesPlayer", ["chase"])]),
                make(.treasure, "Hidden treasure", x: 0.74, y: 0.3,
                     cards: [card("playerTouches", ["giveTreasure", "playSound", "destroySelf"], detail: "5 coins")]),
                make(.trap, "Trap", x: 0.38, y: 0.56),
                make(.prop, "Crate", x: 0.62, y: 0.66),
                make(.scenery, "Bush", x: 0.82, y: 0.6)
            ]
            if index > 0 {
                level.entities.append(make(.key, "Old key", x: 0.3, y: 0.3))
                level.objectives.append(LevelObjective(text: "Find the old key", isOptional: true))
            }
            built.append(level)
        }

        for index in built.indices.dropLast() {
            built[index].nextLevelID = built[index + 1].id
        }

        project.levels = built
        return project
    }

    // MARK: Helpers

    private static func make(
        _ kind: EntityKind,
        _ name: String,
        x: CGFloat,
        y: CGFloat,
        health: Int = 3,
        brain: String = "Patroller",
        isBoss: Bool = false,
        puzzleType: String = "Pressure plate",
        dialogue: String = "",
        cards: [BehaviorCard] = []
    ) -> LevelEntity {
        var entity = LevelEntity(kind: kind, name: name)
        entity.position = BoardPoint(x: x, y: y)
        entity.health = health
        entity.brain = brain
        entity.isBoss = isBoss
        entity.puzzleType = puzzleType
        entity.dialogue = dialogue
        entity.cards = cards
        return entity
    }

    private static func card(
        _ whenKey: String,
        _ actionKeys: [String],
        detail: String = "",
        conditionKeys: [String] = []
    ) -> BehaviorCard {
        BehaviorCard(
            when: CardClause(key: whenKey),
            conditions: conditionKeys.map { CardClause(key: $0) },
            actions: actionKeys.map { CardClause(key: $0, detail: $0 == "say" || $0 == "giveTreasure" || $0 == "playAnimation" ? detail : "") }
        )
    }
}
