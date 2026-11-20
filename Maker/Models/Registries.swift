//
//  Registries.swift
//  Maker
//
//  The vocabulary of the maker. Every action, rule and preset a kid can
//  use lives here as data, so adding one is never a code change.
//

import Foundation
import SwiftUI

// MARK: - Actions

enum ActionGroup: String, CaseIterable, Identifiable, Codable {
    case movement, combat, interaction, emotes, skills

    var id: String { rawValue }

    var title: String {
        switch self {
        case .movement: return "Moving"
        case .combat: return "Fighting"
        case .interaction: return "Using things"
        case .emotes: return "Showing off"
        case .skills: return "Magic"
        }
    }

    var symbol: String {
        switch self {
        case .movement: return "figure.walk"
        case .combat: return "flame.fill"
        case .interaction: return "hand.raised.fill"
        case .emotes: return "hand.wave.fill"
        case .skills: return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .movement: return Palette.mint
        case .combat: return Palette.coral
        case .interaction: return Palette.sky
        case .emotes: return Palette.amber
        case .skills: return Palette.plum
        }
    }

    var blurb: String {
        switch self {
        case .movement: return "Walking, jumping, climbing and swimming."
        case .combat: return "Punching, swords and blocking."
        case .interaction: return "Picking things up, talking and opening doors."
        case .emotes: return "Friendly moves for your character."
        case .skills: return "Magic spells and special moves."
        }
    }
}

struct CharacterAction: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let group: ActionGroup
    let blurb: String
    let button: String
}

enum ActionRegistry {
    static let all: [CharacterAction] = [
        // Moving
        CharacterAction(id: "idle", title: "Stand still", symbol: "figure.stand", group: .movement, blurb: "The resting pose when nobody moves.", button: "Always on"),
        CharacterAction(id: "walk", title: "Walk", symbol: "figure.walk", group: .movement, blurb: "A steady walk. The first thing every game needs.", button: "Stick"),
        CharacterAction(id: "run", title: "Run", symbol: "figure.run", group: .movement, blurb: "Faster than walking, and uses a little stamina.", button: "Stick + B"),
        CharacterAction(id: "sprint", title: "Sprint", symbol: "hare.fill", group: .movement, blurb: "A big burst of speed that drains stamina.", button: "Hold B"),
        CharacterAction(id: "jump", title: "Jump", symbol: "arrow.up.circle.fill", group: .movement, blurb: "Hop over gaps and onto ledges.", button: "A"),
        CharacterAction(id: "doubleJump", title: "Double jump", symbol: "arrow.up.arrow.down", group: .movement, blurb: "Jump again while in the air.", button: "A in air"),
        CharacterAction(id: "fall", title: "Fall", symbol: "arrow.down.circle.fill", group: .movement, blurb: "Plays while dropping off a ledge.", button: "Automatic"),
        CharacterAction(id: "land", title: "Land", symbol: "arrow.down.to.line", group: .movement, blurb: "A little squash when you hit the ground.", button: "Automatic"),
        CharacterAction(id: "crouch", title: "Crouch", symbol: "figure.stand", group: .movement, blurb: "Duck under low gaps and move quietly.", button: "Hold X"),
        CharacterAction(id: "crawl", title: "Crawl", symbol: "figure.walk", group: .movement, blurb: "Squeeze through gaps too small to crouch.", button: "Hold X + Stick"),
        CharacterAction(id: "climb", title: "Climb", symbol: "mountain.2.fill", group: .movement, blurb: "Climb ladders, vines and rocky walls.", button: "A near wall"),
        CharacterAction(id: "swim", title: "Swim", symbol: "drop.fill", group: .movement, blurb: "Paddle across water without sinking.", button: "Automatic"),
        CharacterAction(id: "glide", title: "Glide", symbol: "wind", group: .movement, blurb: "Float slowly down from high places.", button: "Hold A"),
        CharacterAction(id: "ride", title: "Ride", symbol: "car.fill", group: .movement, blurb: "Sit on a horse, cart or creature and steer it.", button: "A near mount"),
        CharacterAction(id: "sit", title: "Sit down", symbol: "chair.lounge.fill", group: .movement, blurb: "Rest on a chair, bench or the grass.", button: "A near seat"),
        CharacterAction(id: "sleep", title: "Sleep", symbol: "bed.double.fill", group: .movement, blurb: "Snooze to skip to morning or refill health.", button: "A near bed"),

        // Fighting
        CharacterAction(id: "punch", title: "Punch", symbol: "hand.raised.fill", group: .combat, blurb: "A quick jab with no weapon needed.", button: "Y"),
        CharacterAction(id: "kick", title: "Kick", symbol: "figure.run", group: .combat, blurb: "A heavier hit that can knock things back.", button: "Y + B"),
        CharacterAction(id: "swordLight", title: "Swing sword", symbol: "bolt.fill", group: .combat, blurb: "A fast swing. Chain three together for a combo.", button: "Y"),
        CharacterAction(id: "swordHeavy", title: "Heavy swing", symbol: "hammer.fill", group: .combat, blurb: "A big slow swing that breaks shields.", button: "Hold Y"),
        CharacterAction(id: "block", title: "Block", symbol: "shield.fill", group: .combat, blurb: "Raise a shield to stop hits from the front.", button: "Hold X"),
        CharacterAction(id: "parry", title: "Parry", symbol: "shield.lefthalf.filled", group: .combat, blurb: "Block at the perfect moment to bounce a hit back.", button: "X just in time"),
        CharacterAction(id: "dodge", title: "Dodge roll", symbol: "arrow.right.circle.fill", group: .combat, blurb: "Roll out of the way in any direction.", button: "B"),
        CharacterAction(id: "shoot", title: "Shoot", symbol: "scope", group: .combat, blurb: "Fire an arrow or bolt at something far away.", button: "Y with bow"),
        CharacterAction(id: "throw", title: "Throw", symbol: "arrow.up.right", group: .combat, blurb: "Lob a rock, bomb or anything you are carrying.", button: "Y with item"),
        CharacterAction(id: "takeDamage", title: "Get hit", symbol: "heart.slash.fill", group: .combat, blurb: "The flinch when something hurts you.", button: "Automatic"),
        CharacterAction(id: "die", title: "Fall over", symbol: "heart.fill", group: .combat, blurb: "What happens when health runs out.", button: "Automatic"),

        // Using things
        CharacterAction(id: "pickUp", title: "Pick up", symbol: "hand.point.up.fill", group: .interaction, blurb: "Grab coins, keys and treasure.", button: "A near item"),
        CharacterAction(id: "carry", title: "Carry", symbol: "bag.fill", group: .interaction, blurb: "Hold a heavy thing while you walk.", button: "Automatic"),
        CharacterAction(id: "drop", title: "Drop", symbol: "arrow.down.circle.fill", group: .interaction, blurb: "Let go of what you are carrying.", button: "A while carrying"),
        CharacterAction(id: "push", title: "Push", symbol: "arrow.right.to.line", group: .interaction, blurb: "Shove crates, blocks and boulders.", button: "Stick into object"),
        CharacterAction(id: "pull", title: "Pull", symbol: "arrow.left.to.line", group: .interaction, blurb: "Drag levers and ropes towards you.", button: "Hold A + back"),
        CharacterAction(id: "open", title: "Open", symbol: "lock.open.fill", group: .interaction, blurb: "Open doors, chests and gates.", button: "A near door"),
        CharacterAction(id: "talk", title: "Talk", symbol: "bubble.left.fill", group: .interaction, blurb: "Start a chat with an NPC.", button: "A near friend"),
        CharacterAction(id: "useItem", title: "Use item", symbol: "wand.and.stars", group: .interaction, blurb: "Use whatever is in your hand.", button: "X with item"),
        CharacterAction(id: "eat", title: "Eat", symbol: "fork.knife", group: .interaction, blurb: "Eat food to get health back.", button: "X with food"),
        CharacterAction(id: "drink", title: "Drink", symbol: "cup.and.saucer.fill", group: .interaction, blurb: "Drink a potion for magic or health.", button: "X with potion"),
        CharacterAction(id: "read", title: "Read", symbol: "book.fill", group: .interaction, blurb: "Read signs and books for hints.", button: "A near sign"),

        // Showing off
        CharacterAction(id: "wave", title: "Wave", symbol: "hand.wave.fill", group: .emotes, blurb: "A friendly hello.", button: "Emote wheel"),
        CharacterAction(id: "dance", title: "Dance", symbol: "figure.dance", group: .emotes, blurb: "A silly dance. Kids will press this a lot.", button: "Emote wheel"),
        CharacterAction(id: "cheer", title: "Cheer", symbol: "hand.thumbsup.fill", group: .emotes, blurb: "Throw your arms up and celebrate.", button: "Emote wheel"),
        CharacterAction(id: "laugh", title: "Laugh", symbol: "face.smiling.fill", group: .emotes, blurb: "A big cartoon laugh.", button: "Emote wheel"),
        CharacterAction(id: "cry", title: "Cry", symbol: "drop.fill", group: .emotes, blurb: "A dramatic sob.", button: "Emote wheel"),
        CharacterAction(id: "point", title: "Point", symbol: "hand.point.right.fill", group: .emotes, blurb: "Point at something important.", button: "Emote wheel"),

        // Magic
        CharacterAction(id: "magicBolt", title: "Magic bolt", symbol: "sparkles", group: .skills, blurb: "Fires a glowing bolt. Costs magic.", button: "Y + magic"),
        CharacterAction(id: "heal", title: "Heal", symbol: "cross.case.fill", group: .skills, blurb: "Get some health back. Costs magic.", button: "Hold X + magic"),
        CharacterAction(id: "shieldSpell", title: "Magic shield", symbol: "shield.checkerboard", group: .skills, blurb: "A bubble that blocks hits for a while.", button: "B + magic"),
        CharacterAction(id: "teleport", title: "Teleport", symbol: "sparkles", group: .skills, blurb: "Blink a short distance forwards.", button: "B + magic"),
        CharacterAction(id: "groundPound", title: "Ground pound", symbol: "arrow.down.to.line", group: .skills, blurb: "Slam down and shake the ground.", button: "A in air"),
        CharacterAction(id: "spinAttack", title: "Spin attack", symbol: "arrow.triangle.2.circlepath", group: .skills, blurb: "Spin with your sword out to hit everything nearby.", button: "Hold Y")
    ]

    static let starter: Set<String> = [
        "idle", "walk", "run", "jump", "pickUp", "talk", "punch", "swordLight", "block", "wave", "dance"
    ]

    static func action(_ id: String) -> CharacterAction? {
        all.first { $0.id == id }
    }

    static func actions(in group: ActionGroup) -> [CharacterAction] {
        all.filter { $0.group == group }
    }
}

// MARK: - Presets

enum PresetLibrary {
    static let brains = ["Patroller", "Chaser", "Charger", "Shooter", "Flyer", "Lurker", "Boss"]

    static let puzzles = [
        "Pressure plate", "Lever", "Key & lock", "Push block",
        "Torch light", "Rune order", "Timer gate", "Counter lock"
    ]

    static let loot = ["Coins", "Gems", "Keys", "Health", "Magic", "Nothing"]

    static let personalities = ["Friendly", "Grumpy", "Sleepy", "Excited", "Shy", "Brave", "Sneaky"]

    static let heroBodies = ["Adventurer", "Knight", "Explorer", "Ninja", "Wizard", "Robot"]

    static let themes = ["Adventure", "Candy", "Spooky", "Sci-Fi", "Paper", "Neon", "Nature", "Pirate"]
}

// MARK: - Rule vocabulary

struct Clause: Identifiable, Hashable {
    let key: String
    let label: String
    let needsDetail: Bool
    let detailHint: String
    let symbol: String

    var id: String { key }

    func phrase(_ detail: String) -> String {
        detail.isEmpty ? label : "\(label) (\(detail))"
    }
}

enum BehaviorVocabulary {
    static let events: [Clause] = [
        Clause(key: "levelStarts", label: "the level starts", needsDetail: false, detailHint: "", symbol: "flag.fill"),
        Clause(key: "playerTouches", label: "the player touches me", needsDetail: false, detailHint: "", symbol: "hand.tap.fill"),
        Clause(key: "playerNear", label: "the player comes near", needsDetail: false, detailHint: "", symbol: "figure.walk"),
        Clause(key: "seesPlayer", label: "I see the player", needsDetail: false, detailHint: "", symbol: "eye.fill"),
        Clause(key: "takesDamage", label: "I get hit", needsDetail: false, detailHint: "", symbol: "heart.slash.fill"),
        Clause(key: "healthLow", label: "my health gets low", needsDetail: false, detailHint: "", symbol: "heart.fill"),
        Clause(key: "baddiesGone", label: "all the baddies are gone", needsDetail: false, detailHint: "", symbol: "bolt.fill"),
        Clause(key: "playerTalks", label: "the player talks to me", needsDetail: false, detailHint: "", symbol: "bubble.left.fill"),
        Clause(key: "playerUses", label: "the player presses use near me", needsDetail: false, detailHint: "", symbol: "hand.point.up.fill"),
        Clause(key: "timer", label: "a timer ticks", needsDetail: true, detailHint: "every 3 seconds", symbol: "timer"),
        Clause(key: "reachesWaypoint", label: "I reach a waypoint", needsDetail: false, detailHint: "", symbol: "mappin.and.ellipse"),
        Clause(key: "pushed", label: "something pushes me", needsDetail: false, detailHint: "", symbol: "arrow.right.to.line"),
        Clause(key: "collects", label: "the player collects something", needsDetail: false, detailHint: "", symbol: "gift.fill"),
        Clause(key: "switch", label: "a switch changes", needsDetail: false, detailHint: "", symbol: "square.grid.2x2.fill"),
        Clause(key: "random", label: "a random chance happens", needsDetail: false, detailHint: "", symbol: "dice.fill"),
        Clause(key: "levelDone", label: "the player finishes the level", needsDetail: false, detailHint: "", symbol: "sparkles")
    ]

    static let conditions: [Clause] = [
        Clause(key: "hasKey", label: "the player has a key", needsDetail: true, detailHint: "Gold key", symbol: "key.fill"),
        Clause(key: "healthHalf", label: "my health is below half", needsDetail: false, detailHint: "", symbol: "heart.fill"),
        Clause(key: "crouching", label: "the player is crouching", needsDetail: false, detailHint: "", symbol: "figure.stand"),
        Clause(key: "playerClose", label: "the player is close", needsDetail: true, detailHint: "3 steps", symbol: "figure.walk"),
        Clause(key: "flagSet", label: "a flag is set", needsDetail: true, detailHint: "found the sword", symbol: "flag.fill"),
        Clause(key: "isNight", label: "it is night time", needsDetail: false, detailHint: "", symbol: "moon.stars.fill"),
        Clause(key: "noBaddies", label: "there are no baddies left", needsDetail: false, detailHint: "", symbol: "bolt.fill"),
        Clause(key: "hasCoins", label: "the player has enough coins", needsDetail: true, detailHint: "10", symbol: "circle.fill"),
        Clause(key: "isBoss", label: "this is a boss", needsDetail: false, detailHint: "", symbol: "crown.fill")
    ]

    static let actions: [Clause] = [
        Clause(key: "chase", label: "chase the player", needsDetail: false, detailHint: "", symbol: "figure.run"),
        Clause(key: "patrol", label: "walk my patrol path", needsDetail: false, detailHint: "", symbol: "arrow.triangle.2.circlepath"),
        Clause(key: "flee", label: "run away", needsDetail: false, detailHint: "", symbol: "arrow.left.circle.fill"),
        Clause(key: "attack", label: "attack", needsDetail: false, detailHint: "", symbol: "flame.fill"),
        Clause(key: "shootAt", label: "shoot at the player", needsDetail: false, detailHint: "", symbol: "scope"),
        Clause(key: "playAnimation", label: "play an action", needsDetail: true, detailHint: "dance", symbol: "figure.dance"),
        Clause(key: "say", label: "say something", needsDetail: true, detailHint: "Welcome, traveller!", symbol: "bubble.left.fill"),
        Clause(key: "playSound", label: "play a sound", needsDetail: true, detailHint: "coin chime", symbol: "speaker.wave.2.fill"),
        Clause(key: "openDoor", label: "open the door", needsDetail: false, detailHint: "", symbol: "lock.open.fill"),
        Clause(key: "giveTreasure", label: "give a treasure", needsDetail: true, detailHint: "3 coins", symbol: "gift.fill"),
        Clause(key: "giveItem", label: "give the player an item", needsDetail: true, detailHint: "Gold key", symbol: "bag.fill"),
        Clause(key: "spawn", label: "make a baddie appear", needsDetail: true, detailHint: "Slime", symbol: "plus.circle.fill"),
        Clause(key: "hide", label: "hide myself", needsDetail: false, detailHint: "", symbol: "eye.slash.fill"),
        Clause(key: "show", label: "show myself", needsDetail: false, detailHint: "", symbol: "eye.fill"),
        Clause(key: "heal", label: "get some health back", needsDetail: false, detailHint: "", symbol: "heart.fill"),
        Clause(key: "takeDamage", label: "take damage", needsDetail: true, detailHint: "1 heart", symbol: "heart.slash.fill"),
        Clause(key: "setFlag", label: "remember something happened", needsDetail: true, detailHint: "found the sword", symbol: "flag.fill"),
        Clause(key: "teleport", label: "move the player here", needsDetail: false, detailHint: "", symbol: "sparkles"),
        Clause(key: "endLevel", label: "finish the level", needsDetail: false, detailHint: "", symbol: "sparkles"),
        Clause(key: "shakeCamera", label: "shake the camera", needsDetail: false, detailHint: "", symbol: "waveform.path"),
        Clause(key: "changeSky", label: "change the sky", needsDetail: true, detailHint: "night", symbol: "cloud.sun.fill"),
        Clause(key: "showMessage", label: "show a message", needsDetail: true, detailHint: "The gate is locked!", symbol: "text.bubble.fill"),
        Clause(key: "wait", label: "wait a moment", needsDetail: true, detailHint: "1 second", symbol: "hourglass"),
        Clause(key: "unlockPortal", label: "open the portal", needsDetail: false, detailHint: "", symbol: "sparkles"),
        Clause(key: "startPlatform", label: "start a moving platform", needsDetail: true, detailHint: "the platform's name", symbol: "arrow.right"),
        Clause(key: "stopPlatform", label: "stop a moving platform", needsDetail: true, detailHint: "the platform's name", symbol: "pause.fill"),
        Clause(key: "destroySelf", label: "disappear", needsDetail: false, detailHint: "", symbol: "xmark.circle.fill")
    ]

    static func event(_ key: String) -> Clause? { events.first { $0.key == key } }
    static func condition(_ key: String) -> Clause? { conditions.first { $0.key == key } }
    static func action(_ key: String) -> Clause? { actions.first { $0.key == key } }
}

enum RuleSentence {
    static func text(for card: BehaviorCard) -> String {
        let when = BehaviorVocabulary.event(card.when.key)?.phrase(card.when.detail) ?? "something happens"

        var pieces: [String] = ["When \(when)"]

        if !card.conditions.isEmpty {
            let words = card.conditions.map { clause in
                BehaviorVocabulary.condition(clause.key)?.phrase(clause.detail) ?? "something is true"
            }
            pieces.append("if " + list(words))
        }

        if card.actions.isEmpty {
            pieces.append("then nothing yet")
        } else {
            let words = card.actions.map { clause in
                BehaviorVocabulary.action(clause.key)?.phrase(clause.detail) ?? "do something"
            }
            pieces.append("then " + list(words))
        }

        var sentence = pieces.joined(separator: ", ") + "."
        if card.isOnce { sentence += " Only the first time." }
        return sentence
    }

    private static func list(_ words: [String]) -> String {
        guard words.count > 1 else { return words.first ?? "" }
        if words.count == 2 { return "\(words[0]) and \(words[1])" }
        let head = words.dropLast().joined(separator: ", ")
        return "\(head) and \(words.last ?? "")"
    }
}

// MARK: - Recipes

struct RuleRecipe: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let blurb: String
    let whenKey: String
    let conditionKeys: [String]
    let actionKeys: [String]
    let kinds: [EntityKind]
}

enum RecipeLibrary {
    static let all: [RuleRecipe] = [
        RuleRecipe(id: "chase", title: "Chase the player", symbol: "figure.run", blurb: "Sees you, then runs after you.", whenKey: "seesPlayer", conditionKeys: [], actionKeys: ["chase", "say"], kinds: [.baddie]),
        RuleRecipe(id: "patrol", title: "Guard a path", symbol: "arrow.triangle.2.circlepath", blurb: "Walks back and forth, then attacks.", whenKey: "seesPlayer", conditionKeys: ["playerClose"], actionKeys: ["attack"], kinds: [.baddie]),
        RuleRecipe(id: "lockedDoor", title: "Locked door", symbol: "lock.open.fill", blurb: "Only opens with a key.", whenKey: "playerUses", conditionKeys: ["hasKey"], actionKeys: ["openDoor", "playSound"], kinds: [.door]),
        RuleRecipe(id: "openWhenDone", title: "Opens when all gone", symbol: "bolt.fill", blurb: "Opens once every baddie is beaten.", whenKey: "baddiesGone", conditionKeys: [], actionKeys: ["openDoor", "showMessage"], kinds: [.door, .portal]),
        RuleRecipe(id: "chest", title: "Treasure chest", symbol: "gift.fill", blurb: "Gives coins when you touch it.", whenKey: "playerTouches", conditionKeys: [], actionKeys: ["giveTreasure", "playSound", "destroySelf"], kinds: [.treasure]),
        RuleRecipe(id: "chat", title: "Friendly hello", symbol: "bubble.left.fill", blurb: "Says a line when you talk.", whenKey: "playerTalks", conditionKeys: [], actionKeys: ["say", "playAnimation"], kinds: [.npc]),
        RuleRecipe(id: "quest", title: "Give a quest", symbol: "list.bullet", blurb: "Asks for help and gives a key.", whenKey: "playerTalks", conditionKeys: ["flagSet"], actionKeys: ["say", "giveItem"], kinds: [.npc]),
        RuleRecipe(id: "trap", title: "Hidden trap", symbol: "exclamationmark.triangle.fill", blurb: "Hurts whoever steps on it.", whenKey: "playerTouches", conditionKeys: [], actionKeys: ["takeDamage", "playSound"], kinds: [.trap]),
        RuleRecipe(id: "plate", title: "Plate opens door", symbol: "square.grid.2x2.fill", blurb: "Stand on it and a door opens.", whenKey: "playerTouches", conditionKeys: [], actionKeys: ["setFlag", "playSound"], kinds: [.puzzle]),
        RuleRecipe(id: "checkpoint", title: "Checkpoint", symbol: "flag.fill", blurb: "Remembers you were here.", whenKey: "playerTouches", conditionKeys: [], actionKeys: ["setFlag", "playSound", "showMessage"], kinds: [.checkpoint]),
        RuleRecipe(id: "bossPhase", title: "Boss second phase", symbol: "crown.fill", blurb: "Gets angry when health is low.", whenKey: "healthLow", conditionKeys: ["isBoss"], actionKeys: ["say", "shakeCamera", "chase"], kinds: [.baddie]),
        RuleRecipe(id: "spawnWave", title: "Summon a wave", symbol: "plus.circle.fill", blurb: "Calls for help when hurt.", whenKey: "takesDamage", conditionKeys: [], actionKeys: ["spawn", "say"], kinds: [.baddie, .spawner])
    ]

    static func recipes(for kind: EntityKind) -> [RuleRecipe] {
        all.filter { $0.kinds.contains(kind) }
    }
}
