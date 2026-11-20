//
//  PlayRules.swift
//  Maker
//
//  The rules of a level, running for real: baddies that see you, chests
//  that pay out, doors that want a key, and a portal that waits.
//

import Foundation
import SceneKit
import simd

private struct EntityRuntime {
    var node: SCNNode
    var entity: LevelEntity
    var health: Int
    var maxHealth: Int
    var home: SIMD3<Float>
    var alive = true
    var touchCooldown: Float = 0
    var attackCooldown: Float = 0
    var fleeTimer: Float = 0
    var chaseTimer: Float = 0
    var patrolPhase: Float = 0
    var timerAccumulator: Float = 0
    var fired: Set<UUID> = []
    var removed = false
    var opened = false
    var sawPlayer = false
    var platformRunning = true
}

final class PlayRules {
    private let level: GameLevel
    private let terrainHeight: (Float, Float) -> Float
    private var runtimes: [UUID: EntityRuntime] = [:]

    private var flags: Set<String> = []
    private var baddiesBeaten = 0
    private var collected = 0
    private var levelHasKey = false
    private var announcedBaddiesGone = false
    private var lastUseWarnings: [String] = []

    private var acceptedQuests: Set<UUID> = []
    private var completedSteps: [UUID: Set<UUID>] = [:]
    private var completedQuests: Set<UUID> = []

    private(set) var health = 6
    private(set) var maxHealth = 6
    private(set) var coins = 0
    private(set) var keys = 0
    private(set) var isDown = false
    private(set) var checkpointPoint: SIMD3<Float>?

    var onMessage: (String) -> Void = { _ in }
    var onStatus: (Int, Int, Int) -> Void = { _, _, _ in }
    var onEffect: (SoundEffect) -> Void = { _ in }
    var onDeath: (String) -> Void = { _ in }
    var onConversation: (String, [ConversationLine]) -> Void = { _, _ in }
    var onRespawn: () -> Void = { }
    var onShake: () -> Void = { }
    var onFinish: () -> Void = { }

    init(
        level: GameLevel,
        nodes: [UUID: SCNNode],
        terrainHeight: @escaping (Float, Float) -> Float
    ) {
        self.level = level
        self.terrainHeight = terrainHeight

        for entity in level.entities {
            guard let node = nodes[entity.id] else { continue }
            let health = entity.kind == .baddie ? max(1, entity.health) : 1
            runtimes[entity.id] = EntityRuntime(
                node: node,
                entity: entity,
                health: health,
                maxHealth: health,
                home: node.simdPosition,
                platformRunning: entity.platformRunning
            )
        }

        levelHasKey = level.entities.contains { $0.kind == .key }
    }

    // MARK: Starting

    func start() {
        flags = []
        baddiesBeaten = 0
        collected = 0
        coins = 0
        keys = 0
        health = maxHealth
        isDown = false
        checkpointPoint = nil
        acceptedQuests = []
        completedSteps = [:]
        completedQuests = []
        announcedBaddiesGone = false

        for id in runtimes.keys {
            guard var runtime = runtimes[id] else { continue }
            runtime.health = runtime.maxHealth
            runtime.alive = true
            runtime.touchCooldown = 0
            runtime.attackCooldown = 0
            runtime.fleeTimer = 0
            runtime.chaseTimer = 0
            runtime.timerAccumulator = 0
            runtime.fired = []
            runtime.removed = false
            runtime.opened = false
            runtime.sawPlayer = false
            runtime.platformRunning = runtime.entity.platformRunning
            runtime.node.isHidden = false
            runtime.node.position = SCNVector3(runtime.home.x, runtime.home.y, runtime.home.z)
            runtimes[id] = runtime
        }

        onStatus(health, coins, keys)
        onMessage("The level starts. \(openingLine())")

        for warning in ruleWarnings() {
            onMessage(warning)
        }

        fireGlobal("levelStarts")
    }

    private func openingLine() -> String {
        let baddies = runtimes.values.filter { $0.entity.kind == .baddie }.count
        if baddies == 0 { return "There is nothing here to fight." }
        return baddies == 1 ? "One baddie is waiting." : "\(baddies) baddies are waiting."
    }

    // MARK: Every frame

    func update(deltaTime: Float, heroPosition: SIMD3<Float>, attack: Bool, use: Bool) {
        currentHero = heroPosition

        for id in Array(runtimes.keys) {
            guard var runtime = runtimes[id] else { continue }
            runtime.touchCooldown = max(0, runtime.touchCooldown - deltaTime)
            runtime.attackCooldown = max(0, runtime.attackCooldown - deltaTime)
            runtime.timerAccumulator += deltaTime
            runtimes[id] = runtime
        }

        updateBaddies(deltaTime: deltaTime, heroPosition: heroPosition)
        checkTouches(heroPosition: heroPosition)

        if attack {
            swingAtNearestBaddie(heroPosition: heroPosition)
        }
        if use {
            useNearestThing(heroPosition: heroPosition)
        }

        checkTimers()
        checkBaddiesGone()
    }

    // MARK: Baddies

    private func updateBaddies(deltaTime: Float, heroPosition: SIMD3<Float>) {
        for id in Array(runtimes.keys) {
            guard var runtime = runtimes[id], runtime.alive else { continue }
            guard runtime.entity.kind == .baddie else { continue }

            let position = runtime.node.position
            let toHero = SIMD2<Float>(heroPosition.x - position.x, heroPosition.z - position.z)
            let distance = simd_length(toHero)
            let sight: Float = runtime.entity.brain == "Lurker" ? 6 : (runtime.entity.isBoss ? 26 : 15)
            let speed = (1.5 + Float(runtime.entity.speed) * 0.25) * (runtime.entity.isBoss ? 1.1 : 1)

            runtime.fleeTimer = max(0, runtime.fleeTimer - deltaTime)
            runtime.chaseTimer = max(0, runtime.chaseTimer - deltaTime)

            var movement = SIMD2<Float>(0, 0)

            if runtime.fleeTimer > 0 && distance > 0.001 {
                movement = -toHero / distance
            } else if runtime.chaseTimer > 0 || distance < sight {
                if distance > 1.7 {
                    movement = distance > 0.001 ? toHero / distance : SIMD2(0, 0)
                } else if runtime.attackCooldown <= 0 {
                    runtime.attackCooldown = 1.5
                    hurtHero(max(1, runtime.entity.damage), reason: "The \(runtime.entity.name) hits you")
                }
            } else {
                // A slow wander around where it was placed.
                runtime.patrolPhase += deltaTime * 0.7
                let offset = SIMD2<Float>(cos(runtime.patrolPhase), sin(runtime.patrolPhase)) * 0.6
                let target = SIMD2<Float>(runtime.home.x + offset.x, runtime.home.z + offset.y)
                let towards = target - SIMD2<Float>(position.x, position.z)
                if simd_length(towards) > 0.05 {
                    movement = simd_normalize(towards) * 0.35
                }
            }

            if simd_length(movement) > 0.001 {
                let step = movement * speed * deltaTime
                var next = SIMD3<Float>(position.x + step.x, 0, position.z + step.y)
                let flat = SIMD2<Float>(next.x, next.z)
                let edge = IslandTerrain.radius + 0.6
                if simd_length(flat) > edge {
                    let clamped = flat / simd_length(flat) * edge
                    next.x = clamped.x
                    next.z = clamped.y
                }
                next.y = terrainHeight(next.x, next.z)
                runtime.node.position = SCNVector3(next.x, next.y, next.z)
                runtime.node.eulerAngles.y = atan2(movement.x, movement.y)
            }

            runtimes[id] = runtime

            if distance < sight && !runtime.sawPlayer {
                runtimes[id]?.sawPlayer = true
                fire("seesPlayer", id: id)
            }
        }
    }

    private func swingAtNearestBaddie(heroPosition: SIMD3<Float>) {
        var nearest: (id: UUID, distance: Float)?
        for (id, runtime) in runtimes where runtime.alive && runtime.entity.kind == .baddie {
            let position = runtime.node.position
            let distance = simd_length(SIMD2<Float>(heroPosition.x - position.x, heroPosition.z - position.z))
            if distance < 2.6, nearest == nil || distance < nearest!.distance {
                nearest = (id, distance)
            }
        }
        guard let target = nearest else { return }
        damageBaddie(target.id, amount: 1)
    }

    private func damageBaddie(_ id: UUID, amount: Int) {
        guard var runtime = runtimes[id], runtime.alive else { return }
        runtime.health -= amount
        runtime.chaseTimer = 8
        runtimes[id] = runtime
        play(\.hit)

        fire("takesDamage", id: id)

        guard let updated = runtimes[id] else { return }
        if updated.health <= 0 {
            defeat(id)
            return
        }

        if updated.health * 2 <= updated.maxHealth {
            if updated.entity.brain != "Boss" {
                runtimes[id]?.fleeTimer = 3.5
                onMessage("The \(updated.entity.name) is hurt and runs away.")
            }
            fire("healthLow", id: id)
        } else {
            onMessage("You hit the \(updated.entity.name). \(updated.health) left.")
        }
    }

    private func defeat(_ id: UUID) {
        guard var runtime = runtimes[id], runtime.alive else { return }
        runtime.alive = false
        runtime.node.isHidden = true
        runtimes[id] = runtime
        baddiesBeaten += 1
        onMessage("The \(runtime.entity.name) is beaten!")
        questEvent(.beatBaddie)
        onStatus(health, coins, keys)
    }

    // MARK: Touching things

    private func checkTouches(heroPosition: SIMD3<Float>) {
        for id in Array(runtimes.keys) {
            guard let runtime = runtimes[id], runtime.alive, runtime.touchCooldown <= 0 else { continue }
            let position = runtime.node.position
            let distance = simd_length(SIMD2<Float>(heroPosition.x - position.x, heroPosition.z - position.z))
            guard distance < 1.7 else { continue }

            runtimes[id]?.touchCooldown = 0.7
            touch(id)
        }
    }

    private func touch(_ id: UUID) {
        guard let runtime = runtimes[id] else { return }
        fire("playerTouches", id: id)

        if runtime.entity.kind == .puzzle {
            flags.insert("puzzle")
            fireGlobal("switch")
        }

        guard runtimes[id]?.alive == true, !runtime.hasTouchCards else { return }

        switch runtime.entity.kind {
        case .treasure:
            coins += 3
            collected += 1
            play(\.coin)
            onMessage("You found a treasure chest. 3 coins.")
            questEvent(.openedTreasure)
            remove(id)
        case .key:
            keys += 1
            play(\.coin)
            onMessage("You picked up a \(runtime.entity.name).")
            questEvent(.foundKey)
            remove(id)
        case .pickup:
            coins += 1
            play(\.coin)
            onMessage("You picked something up.")
            remove(id)
        case .trap:
            hurtHero(1, reason: "A \(runtime.entity.name) catches you")
        case .checkpoint:
            checkpointPoint = runtime.node.simdPosition
            health = maxHealth
            play(\.coin)
            onStatus(health, coins, keys)
            onMessage("Checkpoint! Your hearts are full again.")
            questEvent(.touchedCheckpoint)
        default:
            break
        }
        onStatus(health, coins, keys)
    }

    private func remove(_ id: UUID) {
        guard var runtime = runtimes[id] else { return }
        runtime.alive = false
        runtime.removed = true
        runtime.node.isHidden = true
        runtimes[id] = runtime
    }

    // MARK: Using things

    private func useNearestThing(heroPosition: SIMD3<Float>) {
        let usable: Set<EntityKind> = [.npc, .door, .sign, .treasure, .puzzle, .pickup]
        var nearest: (id: UUID, distance: Float)?
        for (id, runtime) in runtimes where runtime.alive && usable.contains(runtime.entity.kind) {
            let position = runtime.node.position
            let distance = simd_length(SIMD2<Float>(heroPosition.x - position.x, heroPosition.z - position.z))
            if distance < 2.8, nearest == nil || distance < nearest!.distance {
                nearest = (id, distance)
            }
        }
        guard let target = nearest, let runtime = runtimes[target.id] else {
            onMessage("There is nothing close enough to use.")
            return
        }

        let entity = runtime.entity
        switch entity.kind {
        case .npc:
            flags.insert("talked")
            questEvent(.talkedTo, from: target.id)
            acceptQuest(target.id)
            fire("playerTalks", id: target.id)
            if !entity.conversation.isEmpty {
                onConversation(entity.name, entity.conversation)
            } else if !hasCards(entity, event: "playerTalks") {
                onMessage("\(entity.dialogue.isEmpty ? entity.name : entity.dialogue)")
            }
        case .door:
            fire("playerUses", id: target.id)
            if !hasCards(entity, event: "playerUses") {
                tryOpenDoor(target.id)
            }
        default:
            fire("playerUses", id: target.id)
            if !hasCards(entity, event: "playerUses") {
                onMessage("The \(entity.name) does nothing yet.")
            }
        }
    }

    private func tryOpenDoor(_ id: UUID) {
        guard let runtime = runtimes[id], !runtime.opened else { return }
        if keys > 0 {
            keys -= 1
            openDoor(id)
            onMessage("You used a key. The door swings open.")
            onStatus(health, coins, keys)
        } else if !levelHasKey {
            onMessage("The door is locked, and there is no key anywhere in this level.")
        } else {
            onMessage("The door is locked. You need a key first.")
        }
    }

    private func openDoor(_ id: UUID) {
        guard var runtime = runtimes[id] else { return }
        runtime.opened = true
        runtimes[id] = runtime
        play(\.door)
        runtime.node.runAction(.rotateBy(x: 0, y: .pi / 2, z: 0, duration: 0.5))
    }

    private func play(_ keyPath: WritableKeyPath<LevelAudio, SoundEffect>) {
        let effect = (level.audio ?? LevelAudio())[keyPath: keyPath]
        if effect != .none {
            onEffect(effect)
        }
    }

    // MARK: Timers and global events

    private func checkTimers() {
        for id in Array(runtimes.keys) {
            guard let runtime = runtimes[id], runtime.alive else { continue }
            guard runtime.entity.cards.contains(where: { $0.when.key == "timer" }) else { continue }
            if runtime.timerAccumulator >= 3 {
                runtimes[id]?.timerAccumulator = 0
                fire("timer", id: id)
            }
        }
    }

    private func checkBaddiesGone() {
        guard !announcedBaddiesGone else { return }
        guard aliveBaddieCount == 0 else { return }
        announcedBaddiesGone = true
        fireGlobal("baddiesGone")
        if level.completeCondition == .defeatAll {
            onMessage("Every baddie is gone. The portal is open.")
        }
    }

    private func fireGlobal(_ event: String) {
        for id in Array(runtimes.keys) {
            fire(event, id: id)
        }
    }

    // MARK: Cards

    private func hasCards(_ entity: LevelEntity, event: String) -> Bool {
        entity.cards.contains { $0.isEnabled && $0.when.key == event }
    }

    private func fire(_ event: String, id: UUID) {
        guard let runtime = runtimes[id], runtime.alive else { return }
        for card in runtime.entity.cards where card.isEnabled && card.when.key == event {
            if card.isOnce && runtime.fired.contains(card.id) { continue }
            guard conditionsHold(card, id: id) else { continue }
            runtimes[id]?.fired.insert(card.id)
            perform(card.actions, id: id)
        }
    }

    private func conditionsHold(_ card: BehaviorCard, id: UUID) -> Bool {
        guard let runtime = runtimes[id] else { return false }
        for condition in card.conditions {
            switch condition.key {
            case "hasKey":
                if keys == 0 { return false }
            case "healthHalf":
                if runtime.health * 2 > runtime.maxHealth { return false }
            case "crouching":
                return false
            case "playerClose":
                if distanceToHero(id) > 3 { return false }
            case "flagSet":
                if !flags.contains(condition.detail.lowercased()) { return false }
            case "isNight":
                if level.sky != .night { return false }
            case "noBaddies":
                if aliveBaddieCount > 0 { return false }
            case "hasCoins":
                if coins < (Int(condition.detail) ?? 10) { return false }
            case "isBoss":
                if !runtime.entity.isBoss { return false }
            default:
                break
            }
        }
        return true
    }

    private func perform(_ actions: [CardClause], id: UUID) {
        for action in actions {
            guard let runtime = runtimes[id] else { return }
            switch action.key {
            case "chase":
                runtimes[id]?.chaseTimer = 10
            case "patrol":
                runtimes[id]?.chaseTimer = 0
            case "flee":
                runtimes[id]?.fleeTimer = 3.5
                onMessage("The \(runtime.entity.name) runs away.")
            case "attack":
                if distanceToHero(id) < 2.6 {
                    hurtHero(max(1, runtime.entity.damage), reason: "The \(runtime.entity.name) attacks")
                }
            case "shootAt":
                if distanceToHero(id) < 16 {
                    hurtHero(max(1, runtime.entity.damage), reason: "The \(runtime.entity.name) shoots at you")
                }
            case "say":
                let line = action.detail.isEmpty ? "Hello there!" : action.detail
                onMessage("\(runtime.entity.name): “\(line)”")
            case "playAnimation":
                onMessage("\(runtime.entity.name) \(action.detail.isEmpty ? "does a little dance" : action.detail).")
            case "playSound":
                onMessage("A sound plays: \(action.detail.isEmpty ? "chime" : action.detail).")
            case "openDoor":
                openDoor(id)
                onMessage("The \(runtime.entity.name) opens.")
            case "giveTreasure":
                let amount = coinAmount(action.detail)
                coins += amount
                collected += 1
                onMessage("You found \(amount) coins.")
                onStatus(health, coins, keys)
            case "giveItem":
                keys += 1
                onMessage("You were given a \(action.detail.isEmpty ? "key" : action.detail).")
                onStatus(health, coins, keys)
            case "spawn":
                onMessage("\(runtime.entity.name) calls for help!")
            case "hide":
                runtime.node.isHidden = true
            case "show":
                runtime.node.isHidden = false
            case "heal":
                health = min(maxHealth, health + 1)
                onMessage("You feel better. \(health) hearts left.")
                onStatus(health, coins, keys)
            case "takeDamage":
                hurtHero(1, reason: "The \(runtime.entity.name) hurts you")
            case "setFlag":
                flags.insert(action.detail.lowercased())
                if action.detail.lowercased().contains("puzzle") {
                    onMessage("The puzzle clicks into place.")
                }
            case "teleport":
                onRespawn()
                onMessage("Something pulls you somewhere else.")
            case "endLevel":
                onFinish()
            case "shakeCamera":
                onShake()
            case "changeSky":
                onMessage("The sky changes.")
            case "showMessage":
                onMessage(action.detail.isEmpty ? "Something happens." : action.detail)
            case "wait":
                break
            case "unlockPortal":
                flags.insert("portal-open")
                onMessage("The portal glows. It is open.")
            case "startPlatform":
                if let target = platformTarget(from: runtime, detail: action.detail) {
                    runtimes[target]?.platformRunning = true
                    onMessage("The \(name(of: target)) starts to move.")
                }
            case "stopPlatform":
                if let target = platformTarget(from: runtime, detail: action.detail) {
                    runtimes[target]?.platformRunning = false
                    onMessage("The \(name(of: target)) stops.")
                }
            case "destroySelf":
                remove(id)
            default:
                break
            }
        }
    }

    // MARK: Player

    private func hurtHero(_ amount: Int, reason: String) {
        guard !isDown else { return }

        health = max(0, health - amount)
        play(\.hit)
        onShake()

        if health == 0 {
            isDown = true
            onStatus(health, coins, keys)
            onMessage("You fell over.")
            onDeath(reason)
            return
        }

        let hearts = health == 1 ? "1 heart" : "\(health) hearts"
        onMessage("\(reason). \(hearts) left.")
        onStatus(health, coins, keys)
    }

    // MARK: Quests

    func questLines() -> [String] {
        var lines: [String] = []
        for id in acceptedQuests {
            guard let runtime = runtimes[id], let quest = runtime.entity.quest else { continue }
            let done = completedSteps[id] ?? []
            lines.append("★ \(quest.title)")
            for step in quest.steps {
                lines.append((done.contains(step.id) ? "✓ " : "○ ") + step.text)
            }
        }
        return lines
    }

    private func acceptQuest(_ id: UUID) {
        guard let runtime = runtimes[id], let quest = runtime.entity.quest, !quest.title.isEmpty else { return }
        guard !acceptedQuests.contains(id), !completedQuests.contains(id) else { return }
        acceptedQuests.insert(id)
        completedSteps[id] = []
        onMessage("New quest: \(quest.title)")
        onEffect(.chime)
    }

    private func questEvent(_ trigger: QuestStepTrigger, from npc: UUID? = nil) {
        guard !acceptedQuests.isEmpty else { return }

        for id in Array(acceptedQuests) {
            guard let runtime = runtimes[id], let quest = runtime.entity.quest else { continue }
            if trigger == .talkedTo && npc != id { continue }

            var done = completedSteps[id] ?? []
            var changed = false
            for step in quest.steps where !done.contains(step.id) && step.trigger == trigger {
                done.insert(step.id)
                changed = true
                onMessage("Done: \(step.text)")
            }
            guard changed else { continue }

            completedSteps[id] = done
            if !quest.steps.isEmpty && quest.steps.allSatisfy({ done.contains($0.id) }) {
                completeQuest(id)
            }
        }
    }

    private func completeQuest(_ id: UUID) {
        guard let runtime = runtimes[id], let quest = runtime.entity.quest, !quest.steps.isEmpty else { return }

        acceptedQuests.remove(id)
        completedQuests.insert(id)
        coins += max(0, quest.rewardCoins)
        if quest.rewardKey { keys += 1 }

        onEffect(.fanfare)
        onStatus(health, coins, keys)

        var reward = quest.rewardCoins > 0 ? "\(quest.rewardCoins) coins" : ""
        if quest.rewardKey { reward += reward.isEmpty ? "a key" : " and a key" }
        onMessage(reward.isEmpty ? "Quest complete: \(quest.title)!" : "Quest complete: \(quest.title)! You get \(reward).")
    }

    // MARK: Moving platforms

    func platformIsRunning(_ id: UUID) -> Bool {
        runtimes[id]?.platformRunning ?? true
    }

    private func platformTarget(from runtime: EntityRuntime, detail: String) -> UUID? {
        let wanted = detail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !wanted.isEmpty {
            for (id, candidate) in runtimes where candidate.entity.kind == .platform {
                if candidate.entity.name.lowercased().contains(wanted) {
                    return id
                }
            }
        }
        if runtime.entity.kind == .platform {
            return runtime.entity.id
        }
        guard let hero = currentHero else { return nil }
        var closest: (id: UUID, distance: Float)?
        for (id, candidate) in runtimes where candidate.entity.kind == .platform {
            let position = candidate.node.position
            let distance = simd_length(SIMD2<Float>(hero.x - position.x, hero.z - position.z))
            if closest == nil || distance < closest!.distance {
                closest = (id, distance)
            }
        }
        return closest?.id
    }

    private func name(of id: UUID) -> String {
        runtimes[id]?.entity.name ?? "platform"
    }

    // MARK: Being beaten

    var hasCheckpoint: Bool { checkpointPoint != nil }
    func respawnPoint(fallback: SIMD3<Float>) -> SIMD3<Float> {
        checkpointPoint ?? fallback
    }

    func revive() {
        isDown = false
        health = maxHealth
        onStatus(health, coins, keys)
    }

    private func distanceToHero(_ id: UUID) -> Float {
        guard let runtime = runtimes[id], let hero = currentHero else { return .greatestFiniteMagnitude }
        let position = runtime.node.position
        return simd_length(SIMD2<Float>(hero.x - position.x, hero.z - position.z))
    }

    private var currentHero: SIMD3<Float>?

    // MARK: Portal

    var aliveBaddieCount: Int {
        runtimes.values.filter { $0.entity.kind == .baddie && $0.alive }.count
    }

    var bossHealthFraction: Float? {
        for runtime in runtimes.values where runtime.entity.kind == .baddie && runtime.entity.isBoss && runtime.alive {
            return Float(runtime.health) / Float(max(1, runtime.maxHealth))
        }
        return nil
    }

    var baddiePositions: [SIMD3<Float>] {
        runtimes.values
            .filter { $0.entity.kind == .baddie && $0.alive }
            .map { $0.node.simdPosition }
    }

    var portalIsOpen: Bool {
        if flags.contains("portal-open") { return true }
        switch level.completeCondition {
        case .reachPortal:
            return true
        case .defeatAll:
            return aliveBaddieCount == 0
        case .collectAll:
            return collected >= max(1, level.requiredCount)
        case .collectKeys:
            return keys >= max(1, level.requiredCount)
        case .solvePuzzle:
            return flags.contains("puzzle") || flags.contains("puzzle solved")
        case .talkToNPC:
            return flags.contains("talked")
        }
    }

    func portalMessage() -> String {
        switch level.completeCondition {
        case .reachPortal:
            return "The portal is open. Step into it."
        case .defeatAll:
            return "The portal is waiting for every baddie to be beaten. \(aliveBaddieCount) left."
        case .collectAll:
            return "The portal wants \(max(1, level.requiredCount)) treasures. You have \(collected)."
        case .collectKeys:
            return "The portal wants \(max(1, level.requiredCount)) keys. You have \(keys)."
        case .solvePuzzle:
            return "The portal is waiting for the puzzle to be solved."
        case .talkToNPC:
            return "The portal is waiting for you to talk to someone."
        }
    }

    // MARK: Explanations

    private func ruleWarnings() -> [String] {
        var warnings: [String] = []
        var flagSetters: Set<String> = []
        for entity in level.entities {
            for card in entity.cards {
                for action in card.actions where action.key == "setFlag" {
                    flagSetters.insert(action.detail.lowercased())
                }
            }
        }

        for entity in level.entities {
            for card in entity.cards where card.isEnabled {
                if card.actions.isEmpty {
                    warnings.append("“\(entity.name)” has a rule that doesn't do anything yet.")
                    continue
                }
                for condition in card.conditions {
                    if condition.key == "hasKey", !levelHasKey {
                        warnings.append("“\(entity.name)” waits for a key, but there's no key in this level.")
                    }
                    if condition.key == "flagSet", !flagSetters.contains(condition.detail.lowercased()) {
                        warnings.append("“\(entity.name)” waits for something that never happens.")
                    }
                }
            }
        }

        var seen = Set<String>()
        return warnings.filter { seen.insert($0).inserted }.prefix(3).map { $0 }
    }

    private func coinAmount(_ detail: String) -> Int {
        let digits = detail.filter { $0.isNumber }
        return Int(digits) ?? 3
    }
}

private extension EntityRuntime {
    var hasTouchCards: Bool {
        entity.cards.contains { $0.isEnabled && $0.when.key == "playerTouches" }
    }
}
