//
//  HeroPlayScene.swift
//  Maker
//
//  The game: the same island, seen over the hero's shoulder. Touch and a
//  paired controller both drive it.
//

import SwiftUI
import SceneKit
import UIKit
import simd
import GameController

final class PlayInput {
    var touchMove = SIMD2<Float>(0, 0)
    var gamepadMove = SIMD2<Float>(0, 0)
    var jump = false
    var attack = false
    var use = false
    var cameraYaw: Float = 0
    var cameraPitch: Float = 0.30
    var cameraDistance: Float = 5.8
    var isPaused = false
}

struct HeroPlayScene: UIViewRepresentable {
    let level: GameLevel
    let project: GameProject
    let input: PlayInput
    let resetToken: Int
    let respawnToken: Int
    let onFinish: (TimeInterval) -> Void
    let onPause: () -> Void
    let onMessage: (String) -> Void
    let onStatus: (Int, Int, Int) -> Void
    let onHUD: (HUDState) -> Void
    let onDeath: (String, Bool) -> Void
    let onConversation: (String, [ConversationLine]) -> Void

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.isPlaying = true
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.onMessage = onMessage
        context.coordinator.onStatus = onStatus
        context.coordinator.onHUD = onHUD
        context.coordinator.onDeath = onDeath
        context.coordinator.onConversation = onConversation
        context.coordinator.onFinish = onFinish
        context.coordinator.onPause = onPause
        context.coordinator.apply(level: level, project: project, resetToken: resetToken, respawnToken: respawnToken)
    }

    func makeCoordinator() -> HeroPlayCoordinator {
        HeroPlayCoordinator(input: input,
                            onFinish: onFinish,
                            onPause: onPause,
                            onMessage: onMessage,
                            onStatus: onStatus,
                            onHUD: onHUD,
                            onDeath: onDeath,
                            onConversation: onConversation)
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: HeroPlayCoordinator) {
        coordinator.stop()
        uiView.isPlaying = false
        uiView.scene = nil
    }
}

final class HeroPlayCoordinator: NSObject {
    private weak var view: SCNView?
    private let scene = SCNScene()

    private let cameraNode = SCNNode()
    private let sunNode = SCNNode()
    private let ambientNode = SCNNode()
    private let levelHolder = SCNNode()
    private let heroHolder = SCNNode()

    private var avatar: HeroAvatar?
    private var importedRig: ImportedHeroRig?
    private var heroRoot: SCNNode?
    private var level: GameLevel?
    private var project: GameProject?
    private var levelKey = ""
    private var lastResetToken = -1

    private var displayLink: CADisplayLink?
    private var lastTime: CFTimeInterval = 0

    private let input: PlayInput
    var onFinish: (TimeInterval) -> Void
    var onPause: () -> Void
    var onMessage: (String) -> Void
    var onStatus: (Int, Int, Int) -> Void
    var onHUD: (HUDState) -> Void
    var onDeath: (String, Bool) -> Void
    var onConversation: (String, [ConversationLine]) -> Void

    private var rules: PlayRules?
    private var shake: Float = 0
    private var portalHintCooldown: Float = 0
    private var stamina: Float = 1
    private var tired = false
    private var stepTimer: Float = 0
    private var dead = false
    private var lastRespawnToken = -1

    private struct PlatformRuntime {
        var node: SCNNode
        var start: SIMD3<Float>
        var end: SIMD3<Float>
        var speed: Float
        var wait: Float
        var spin: Bool
        var halfExtent: Float
        var time: Float = 0
        var position: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
        var delta: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    }

    private var platforms: [UUID: PlatformRuntime] = [:]
    private var ridingPlatform: UUID?
    private var flashTimer: Float = 0
    private var hudTimer: Float = 0

    // Water, weather and the wind
    private let weatherHolder = SCNNode()
    private var weatherNodes: [SCNNode] = []
    private var weatherOffsets: [SIMD3<Float>] = []
    private var cloudNodes: [SCNNode] = []
    private var swayNodes: [SCNNode] = []
    private var rippleNodes: [SCNNode] = []
    private var weatherKind: WeatherKind = .none
    private var windStrength: Float = 0.3
    private var swimming = false
    private var wasSwimming = false
    private var sceneTime: Float = 0

    private var heroPosition = SIMD3<Float>(0, 0, 0)
    private var heroYaw: Float = 0
    private var verticalSpeed: Float = 0
    private var grounded = true
    private var finished = false
    private var elapsed: TimeInterval = 0
    private var speedNow: Float = 0

    private var lastA = false
    private var lastX = false
    private var lastY = false

    init(
        input: PlayInput,
        onFinish: @escaping (TimeInterval) -> Void,
        onPause: @escaping () -> Void,
        onMessage: @escaping (String) -> Void,
        onStatus: @escaping (Int, Int, Int) -> Void,
        onHUD: @escaping (HUDState) -> Void,
        onDeath: @escaping (String, Bool) -> Void,
        onConversation: @escaping (String, [ConversationLine]) -> Void
    ) {
        self.input = input
        self.onFinish = onFinish
        self.onPause = onPause
        self.onMessage = onMessage
        self.onStatus = onStatus
        self.onHUD = onHUD
        self.onDeath = onDeath
        self.onConversation = onConversation
        super.init()
    }

    // MARK: Set up

    func attach(to view: SCNView) {
        self.view = view

        let camera = SCNCamera()
        camera.fieldOfView = 55
        camera.projectionDirection = .vertical
        camera.zNear = 0.05
        camera.zFar = 400
        camera.wantsHDR = false
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.intensity = 1000
        sun.castsShadow = true
        sun.shadowRadius = 3
        sun.shadowColor = UIColor(white: 0, alpha: 0.32)
        sunNode.light = sun
        scene.rootNode.addChildNode(sunNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 520
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        scene.rootNode.addChildNode(levelHolder)
        scene.rootNode.addChildNode(heroHolder)
        scene.rootNode.addChildNode(weatherHolder)

        view.scene = scene
        view.pointOfView = cameraNode

        GCController.startWirelessControllerDiscovery(completionHandler: nil)

        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        AudioEngine.shared.stopMusic(owner: "play")
        displayLink?.invalidate()
        displayLink = nil
        GCController.stopWirelessControllerDiscovery()
    }

    func apply(level: GameLevel, project: GameProject, resetToken: Int, respawnToken: Int) {
        self.level = level
        self.project = project
        self.windStrength = Float(level.windStrength)

        let key = level.id.uuidString + "|" + level.biome.rawValue + "|" + level.weatherKind.rawValue
        if key != levelKey {
            levelKey = key
            rebuild(level)
            reset(level)
        }
        if resetToken != lastResetToken {
            lastResetToken = resetToken
            reset(level)
        }

        if lastRespawnToken == -1 {
            lastRespawnToken = respawnToken
        } else if respawnToken != lastRespawnToken {
            lastRespawnToken = respawnToken
            respawn()
        }
    }

    private func handleDeath(_ reason: String) {
        dead = true
        onDeath(reason, rules?.hasCheckpoint ?? false)
    }

    private func respawn() {
        guard let level else { return }
        let fallback = TerrainSampler.worldPoint(for: BoardPoint(x: 0.12, y: 0.82), in: level)
        let target = rules?.respawnPoint(fallback: fallback) ?? fallback

        heroPosition = SIMD3<Float>(target.x, TerrainSampler.height(level, at: target.x, target.z), target.z)
        verticalSpeed = 0
        grounded = true
        speedNow = 0
        stepTimer = 0
        dead = false
        swimming = false
        wasSwimming = false
        rules?.revive()
        applyHeroTransform()
        updateCamera()
        onMessage("Back on your feet.")
    }

    private func rebuild(_ level: GameLevel) {
        for child in levelHolder.childNodes {
            child.removeFromParentNode()
        }
        for node in LevelSceneBuilder.groundNodes(for: level) {
            levelHolder.addChildNode(node)
        }
        for node in LevelSceneBuilder.surfaceNodes(for: level) {
            levelHolder.addChildNode(node)
        }
        for node in StickerNodes.nodes(for: level) {
            levelHolder.addChildNode(node)
        }

        swayNodes.removeAll()
        levelHolder.enumerateChildNodes { node, _ in
            if node.name == "sway" { self.swayNodes.append(node) }
        }

        var entityNodes: [UUID: SCNNode] = [:]
        for entity in level.entities {
            let node = PropNodeFactory.make(for: entity)
            let world = TerrainSampler.worldPoint(for: entity.position, in: level)
            node.position = SCNVector3(world.x, world.y, world.z)
            node.eulerAngles.y = Float(entity.rotation * .pi / 180)
            let size = Float(max(0.3, min(4, entity.scale)))
            node.scale = SCNVector3(size, size, size)
            levelHolder.addChildNode(node)
            entityNodes[entity.id] = node
        }

        platforms.removeAll()
        ridingPlatform = nil
        for entity in level.entities where entity.kind == .platform {
            guard let node = entityNodes[entity.id] else { continue }
            let hover = PlatformMotion.hover(for: entity.platformPreset)
            let startWorld = TerrainSampler.worldPoint(for: entity.position, in: level)
            let start = SIMD3<Float>(startWorld.x, startWorld.y + hover, startWorld.z)

            var end = start
            if let endPoint = entity.platformEnd {
                let endWorld = TerrainSampler.worldPoint(for: endPoint, in: level)
                end = SIMD3<Float>(endWorld.x, endWorld.y + hover, endWorld.z)
            }

            platforms[entity.id] = PlatformRuntime(
                node: node,
                start: start,
                end: end,
                speed: Float(max(0.2, entity.platformSpeed)),
                wait: Float(max(0, entity.platformWait)),
                spin: PlatformMotion.isSpin(entity.platformMotion),
                halfExtent: PlatformMotion.halfExtent(for: entity.platformPreset),
                position: start
            )
            node.position = SCNVector3(start.x, start.y, start.z)
        }

        if level.hasStart {
            let flag = PropNodeFactory.make(for: LevelEntity(kind: .checkpoint, name: "Start"))
            let world = TerrainSampler.worldPoint(for: BoardPoint(x: 0.12, y: 0.82), in: level)
            flag.position = SCNVector3(world.x, world.y, world.z)
            levelHolder.addChildNode(flag)
        }
        if level.hasPortal {
            let portal = PropNodeFactory.portal()
            let world = TerrainSampler.worldPoint(for: BoardPoint(x: 0.88, y: 0.24), in: level)
            portal.position = SCNVector3(world.x, world.y, world.z)
            levelHolder.addChildNode(portal)
        }

        let newRules = PlayRules(level: level, nodes: entityNodes) { [weak self] x, z in
            guard let self, let current = self.level else { return 0 }
            return TerrainSampler.height(current, at: x, z)
        }
        newRules.onMessage = { [weak self] text in
            guard let self else { return }
            DispatchQueue.main.async { self.onMessage(text) }
        }
        newRules.onStatus = { [weak self] hearts, coins, keys in
            guard let self else { return }
            DispatchQueue.main.async { self.onStatus(hearts, coins, keys) }
        }
        newRules.onRespawn = { [weak self] in self?.returnHeroToStart() }
        newRules.onShake = { [weak self] in
            self?.shake = 0.4
            self?.flashTimer = 0.5
        }
        newRules.onFinish = { [weak self] in self?.finishFromRules() }
        newRules.onDeath = { [weak self] reason in self?.handleDeath(reason) }
        newRules.onConversation = { [weak self] name, lines in self?.onConversation(name, lines) }
        newRules.onEffect = { effect in
            AudioEngine.shared.play(effect)
        }
        rules = newRules

        if heroRoot == nil {
            var imported: ImportedHeroRig?
            if let project,
               let id = project.heroCharacterID,
               let character = (project.importedCharacters ?? []).first(where: { $0.id == id }) {
                imported = ImportedHeroRig(character: character)
            }

            if let imported {
                importedRig = imported
                heroRoot = imported.root
                heroHolder.addChildNode(imported.root)
            } else {
                let jacket = UIColor(project?.tint ?? Palette.accent)
                let hero = HeroAvatar(
                    jacket: jacket,
                    skin: UIColor(red: 0.95, green: 0.82, blue: 0.70, alpha: 1),
                    trousers: UIColor(red: 0.22, green: 0.25, blue: 0.36, alpha: 1),
                    boots: UIColor(red: 0.35, green: 0.26, blue: 0.20, alpha: 1)
                )
                heroHolder.addChildNode(hero.root)
                avatar = hero
                heroRoot = hero.root
            }
        }

        weatherKind = level.weatherKind
        LevelSceneBuilder.applySky(level, to: scene, sun: sunNode, ambient: ambientNode)
        if weatherKind == .rain {
            sunNode.light?.intensity *= 0.72
            ambientNode.light?.intensity *= 0.85
        } else if weatherKind == .snow {
            sunNode.light?.intensity *= 0.88
        }
        view?.backgroundColor = level.sky.viewportSky
        AudioEngine.shared.playMusic(level.audio?.mood ?? MusicMood.none, owner: "play")

        buildRipples()
        buildWeather()
    }

    private func reset(_ level: GameLevel) {
        let start = TerrainSampler.worldPoint(for: BoardPoint(x: 0.12, y: 0.82), in: level)
        heroPosition = SIMD3<Float>(start.x, start.y, start.z)
        heroYaw = atan2(-start.x, -start.z)
        verticalSpeed = 0
        grounded = true
        finished = false
        elapsed = 0
        speedNow = 0
        stamina = 1
        tired = false
        stepTimer = 0
        dead = false
        ridingPlatform = nil
        swimming = false
        wasSwimming = false
        sceneTime = 0

        for id in Array(platforms.keys) {
            guard var platform = platforms[id] else { continue }
            platform.time = 0
            platform.position = platform.start
            platform.delta = SIMD3<Float>(0, 0, 0)
            platform.node.position = SCNVector3(platform.start.x, platform.start.y, platform.start.z)
            platform.node.eulerAngles = SCNVector3(0, 0, 0)
            platforms[id] = platform
        }

        input.cameraYaw = heroYaw
        input.cameraPitch = 0.30
        input.cameraDistance = 5.8
        input.jump = false
        input.attack = false
        input.use = false

        applyHeroTransform()
        updateCamera()
        rules?.start()
    }

    private func updatePlatforms(deltaTime: Float) {
        for id in Array(platforms.keys) {
            guard var platform = platforms[id] else { continue }

            if rules?.platformIsRunning(id) ?? true {
                platform.time += deltaTime
            }

            let pose = PlatformMotion.pose(
                time: platform.time,
                start: platform.start,
                end: platform.end,
                speed: platform.speed,
                wait: platform.wait,
                spin: platform.spin
            )

            platform.delta = pose.position - platform.position
            platform.position = pose.position
            platform.node.position = SCNVector3(pose.position.x, pose.position.y, pose.position.z)
            platform.node.eulerAngles = SCNVector3(0, pose.yaw, 0)
            platforms[id] = platform
        }
    }

    // MARK: Water and weather

    /// The hero swims once the ground under them is well below the surface,
    /// and stops swimming at the shore or when they run out of puff.
    private func updateWater(_ level: GameLevel) {
        let ground = TerrainSampler.height(level, at: heroPosition.x, heroPosition.z)
        let overWater = IslandTerrain.waterLevel - ground > 0.4
        let exhausted = stamina <= 0.02
        // Getting back into the water takes some puff, so a tired hero
        // bobs about instead of flickering in and out of swimming.
        let needsBreath = !swimming && stamina < 0.35
        let next = level.canSwim && overWater && !exhausted && !needsBreath
            && heroPosition.y < IslandTerrain.waterLevel + 0.3

        guard next != swimming else { return }
        swimming = next

        if swimming {
            verticalSpeed = 0
            AudioEngine.shared.play(.whoosh)
            onMessage("Splash! Paddle back to the shore.")
        } else if !overWater {
            onMessage("Back on dry land.")
        }
    }

    private func buildRipples() {
        for node in rippleNodes {
            node.removeFromParentNode()
        }
        rippleNodes.removeAll()

        for _ in 0..<3 {
            let torus = SCNTorus(ringRadius: 0.6, pipeRadius: 0.045)
            torus.ringSegmentCount = 40
            torus.pipeSegmentCount = 6

            let material = SCNMaterial()
            material.diffuse.contents = UIColor.white.withAlphaComponent(0.5)
            material.lightingModel = .constant
            material.isDoubleSided = true
            torus.firstMaterial = material

            let node = SCNNode(geometry: torus)
            node.isHidden = true
            node.castsShadow = false
            levelHolder.addChildNode(node)
            rippleNodes.append(node)
        }
    }

    private func buildWeather() {
        for child in weatherHolder.childNodes {
            child.removeFromParentNode()
        }
        weatherNodes.removeAll()
        weatherOffsets.removeAll()
        cloudNodes.removeAll()

        let isRain = weatherKind == .rain
        let isSnow = weatherKind == .snow

        if isRain || isSnow {
            let count = isRain ? 120 : 90
            for _ in 0..<count {
                let node: SCNNode
                if isRain {
                    node = PropNodeFactory.box(SIMD3(0.05, 0.62, 0.05),
                                               UIColor(white: 0.88, alpha: 0.8))
                } else {
                    let sphere = SCNSphere(radius: 0.06)
                    sphere.segmentCount = 6
                    sphere.firstMaterial = MakerMaterials.solid(UIColor.white.withAlphaComponent(0.95))
                    node = SCNNode(geometry: sphere)
                }
                node.geometry?.firstMaterial?.lightingModel = .constant
                node.castsShadow = false

                let offset = SIMD3<Float>(Float.random(in: -16...16),
                                          Float.random(in: 0.5...13),
                                          Float.random(in: -16...16))
                node.position = SCNVector3(offset.x, offset.y, offset.z)
                weatherHolder.addChildNode(node)
                weatherNodes.append(node)
                weatherOffsets.append(offset)
            }
        }

        // A few clouds for the wind to push along.
        let cloudColor = isRain
            ? UIColor(white: 0.74, alpha: 0.96)
            : UIColor.white.withAlphaComponent(0.94)

        for index in 0..<7 {
            let cloud = SCNNode()
            let size = 1.5 + Float(index % 3) * 0.55

            for part in 0..<3 {
                let sphere = SCNSphere(radius: CGFloat(part == 1 ? size : size * 0.72))
                sphere.segmentCount = 12
                let material = SCNMaterial()
                material.diffuse.contents = cloudColor
                material.lightingModel = .lambert
                material.isDoubleSided = true
                sphere.firstMaterial = material

                let puff = SCNNode(geometry: sphere)
                puff.castsShadow = false
                puff.position = SCNVector3(Float(part - 1) * size * 0.85,
                                           part == 1 ? size * 0.18 : 0,
                                           Float(part % 2) * size * 0.35)
                cloud.addChildNode(puff)
            }

            let angle = Float(index) * 0.9
            cloud.position = SCNVector3(cos(angle) * Float.random(in: 6...26),
                                        15 + Float(index % 4) * 1.6,
                                        sin(angle) * Float.random(in: 6...26))
            weatherHolder.addChildNode(cloud)
            cloudNodes.append(cloud)
        }
    }

    private func updateRipples() {
        for (index, node) in rippleNodes.enumerated() {
            guard swimming else {
                node.isHidden = true
                continue
            }

            node.isHidden = false
            let spread = (sceneTime * 0.6 + Float(index) / Float(max(1, rippleNodes.count)))
                .truncatingRemainder(dividingBy: 1)
            let scale = 0.7 + spread * 2.3
            node.position = SCNVector3(heroPosition.x, IslandTerrain.waterLevel + 0.03, heroPosition.z)
            node.scale = SCNVector3(scale, 0.7, scale)
            node.opacity = CGFloat(max(0, 0.55 * (1 - spread)))
        }
    }

    private func updateWeather(_ delta: Float) {
        guard weatherKind != .none, !weatherNodes.isEmpty else { return }

        let fall: Float = weatherKind == .rain ? 15.5 : 2.3
        for index in weatherNodes.indices {
            var offset = weatherOffsets[index]
            offset.y -= fall * delta
            offset.x += windStrength * 5.5 * delta
            offset.z += windStrength * 2.2 * delta

            if offset.y < 0 {
                offset.y += 13
                offset.x = Float.random(in: -16...16)
                offset.z = Float.random(in: -16...16)
            }
            if offset.x > 16 { offset.x -= 32 }
            if offset.x < -16 { offset.x += 32 }
            if offset.z > 16 { offset.z -= 32 }
            if offset.z < -16 { offset.z += 32 }

            weatherOffsets[index] = offset
            weatherNodes[index].position = SCNVector3(heroPosition.x + offset.x,
                                                      heroPosition.y + offset.y,
                                                      heroPosition.z + offset.z)
        }
    }

    private func updateClouds(_ delta: Float) {
        guard !cloudNodes.isEmpty else { return }

        let drift = windStrength * 3.4 * delta
        for (index, cloud) in cloudNodes.enumerated() {
            cloud.position.x += drift
            if cloud.position.x > 34 { cloud.position.x = -34 }
            cloud.position.y += sin(sceneTime * 0.6 + Float(index)) * 0.02
        }
    }

    private func updateSway() {
        guard !swayNodes.isEmpty else { return }

        for (index, node) in swayNodes.enumerated() {
            node.eulerAngles.z = sin(sceneTime * 1.7 + Float(index) * 0.7) * windStrength * 0.14
        }
    }

    // MARK: Interface

    private func emitHUD(level: GameLevel) {
        var state = HUDState()
        state.health = rules?.health ?? 6
        state.maxHealth = rules?.maxHealth ?? 6
        state.stamina = stamina
        state.magic = 1
        state.coins = rules?.coins ?? 0
        state.keys = rules?.keys ?? 0
        state.timeText = timeText(for: elapsed)
        state.objectives = (rules?.questLines() ?? []) + level.objectives.map { $0.text }
        state.heroPoint = mapPoint(for: heroPosition)
        state.portalPoint = mapPoint(for: TerrainSampler.worldPoint(for: BoardPoint(x: 0.88, y: 0.24), in: level))
        state.baddiePoints = (rules?.baddiePositions ?? []).compactMap { position in
            let dx = position.x - heroPosition.x
            let dz = position.z - heroPosition.z
            guard (dx * dx + dz * dz).squareRoot() < 28 else { return nil }
            return mapPoint(for: position)
        }
        state.bossHealth = rules?.bossHealthFraction
        state.flashHealth = flashTimer > 0
        onHUD(state)
    }

    private func playSlot(_ keyPath: WritableKeyPath<LevelAudio, SoundEffect>) {
        guard let level else { return }
        let effect = (level.audio ?? LevelAudio())[keyPath: keyPath]
        if effect != .none {
            AudioEngine.shared.play(effect)
        }
    }

    private func mapPoint(for position: SIMD3<Float>) -> CGPoint {
        let x = CGFloat(position.x / (2 * IslandTerrain.radius) + 0.5)
        let y = CGFloat(position.z / (2 * IslandTerrain.radius) + 0.5)
        return CGPoint(x: min(1, max(0, x)), y: min(1, max(0, y)))
    }

    private func timeText(for interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func returnHeroToStart() {
        guard let level = self.level else { return }
        let start = TerrainSampler.worldPoint(for: BoardPoint(x: 0.12, y: 0.82), in: level)
        heroPosition = SIMD3<Float>(start.x, start.y, start.z)
        verticalSpeed = 0
        grounded = true
        speedNow = 0
        heroYaw = atan2(-start.x, -start.z)
        applyHeroTransform()
        updateCamera()
    }

    private func finishFromRules() {
        guard !finished else { return }
        finished = true
        onFinish(elapsed)
    }

    private func applyHeroTransform() {
        guard let heroRoot else { return }
        heroRoot.position = SCNVector3(heroPosition.x, heroPosition.y, heroPosition.z)
        heroRoot.eulerAngles = SCNVector3(0, heroYaw, 0)
    }

    // MARK: Every frame

    @objc private func step(_ link: CADisplayLink) {
        let now = CACurrentMediaTime()
        let delta = lastTime == 0 ? 1.0 / 60.0 : min(0.05, now - lastTime)
        lastTime = now
        tick(deltaTime: delta)
    }

    private func tick(deltaTime: TimeInterval) {
        guard heroRoot != nil, let level = self.level else { return }
        let dt = Float(min(max(deltaTime, 0.001), 0.05))

        readGamepad()

        guard !input.isPaused else { return }
        if finished { return }
        if dead { return }

        elapsed += Double(dt)
        sceneTime += dt

        updatePlatforms(deltaTime: dt)
        if let riding = ridingPlatform, let platform = platforms[riding] {
            heroPosition += platform.delta
        }

        wasSwimming = swimming
        updateWater(level)

        var move = input.gamepadMove
        if simd_length(move) < 0.15 {
            move = input.touchMove
        }
        let magnitude = min(1, simd_length(move))

        let actions = project?.enabledActions ?? []
        let canWalk = actions.contains("walk")
        let canRun = actions.contains("run")
        let canJump = actions.contains("jump")

        if stamina <= 0.02 { tired = true }
        if tired && stamina >= 0.5 { tired = false }
        let topSpeed: Float = swimming ? 2.0 : ((canRun && magnitude > 0.7 && !tired) ? 4.8 : 2.4)
        var targetSpeed: Float = (canWalk || swimming) ? magnitude * topSpeed : 0

        let camForward = SIMD3<Float>(sin(input.cameraYaw), 0, cos(input.cameraYaw))
        let camRight = simd_cross(camForward, SIMD3<Float>(0, 1, 0))
        var direction = camForward * move.y + camRight * move.x

        if simd_length(direction) > 0.0001 {
            direction = simd_normalize(direction)
            heroYaw = smooth(heroYaw, toward: atan2(direction.x, direction.z), factor: min(1, dt * 10))
        } else {
            targetSpeed = 0
        }

        speedNow += (targetSpeed - speedNow) * min(1, dt * 8)

        let running = speedNow > 3.2
        let staminaRate: Float = swimming ? -0.075 : (running ? -0.22 : 0.18)
        stamina = min(1, max(0, stamina + staminaRate * dt))

        if speedNow > 0.01 {
            heroPosition.x += direction.x * speedNow * dt
            heroPosition.z += direction.z * speedNow * dt
        }

        let flat = SIMD2<Float>(heroPosition.x, heroPosition.z)
        let distanceFromCentre = simd_length(flat)
        // Swimmers can paddle out into the sea; everyone else stops at the shore.
        let edge = level.canSwim ? 58 : IslandTerrain.shoreRadius - 0.25
        if distanceFromCentre > edge {
            let scaled = flat / distanceFromCentre * edge
            heroPosition.x = scaled.x
            heroPosition.z = scaled.y
        }

        if input.jump {
            input.jump = false
            if grounded && canJump {
                verticalSpeed = 6.4
                grounded = false
                playSlot(\.jump)
            }
        }
        var didAttack = false
        var didUse = false

        if input.attack {
            input.attack = false
            didAttack = true
            if let importedRig { importedRig.play(kind: 1) } else { avatar?.play(kind: 1) }
        }
        if input.use {
            input.use = false
            didUse = true
            if let importedRig { importedRig.play(kind: 2) } else { avatar?.play(kind: 2) }
        }

        verticalSpeed -= 18 * dt
        heroPosition.y += verticalSpeed * dt

        let groundHeight: Float = {
            var height = TerrainSampler.height(level, at: heroPosition.x, heroPosition.z)
            for platform in platforms.values {
                let dx = heroPosition.x - platform.position.x
                let dz = heroPosition.z - platform.position.z
                if abs(dx) < platform.halfExtent && abs(dz) < platform.halfExtent {
                    height = max(height, platform.position.y)
                }
            }
            return height
        }()
        let ground = groundHeight

        if swimming {
            // Floating: the hero rides the surface, or the lake bed if it is
            // shallower than the sea.
            verticalSpeed = 0
            heroPosition.y = max(ground + 0.3, IslandTerrain.waterLevel - 0.7)
            grounded = false
        } else {
            if wasSwimming && heroPosition.y < ground - 0.2 {
                // Climbing out: up to the surface, then stand on the shore.
                heroPosition.y = min(ground, IslandTerrain.waterLevel + 0.05)
                verticalSpeed = 2.9
            }
            if heroPosition.y <= ground {
                heroPosition.y = ground
                verticalSpeed = 0
                grounded = true
            } else {
                grounded = false
            }
        }

        ridingPlatform = nil
        if grounded {
            for (id, platform) in platforms {
                let dx = heroPosition.x - platform.position.x
                let dz = heroPosition.z - platform.position.z
                if abs(dx) < platform.halfExtent,
                   abs(dz) < platform.halfExtent,
                   abs(heroPosition.y - platform.position.y) < 0.35 {
                    ridingPlatform = id
                    break
                }
            }
        }

        if grounded && speedNow > 0.6 {
            stepTimer += dt
            let interval: Float = speedNow > 3.2 ? 0.3 : 0.45
            if stepTimer >= interval {
                stepTimer = 0
                playSlot(\.step)
            }
        } else {
            stepTimer = 0
        }

        applyHeroTransform()
        if let importedRig {
            importedRig.update(delta: dt, speed: speedNow, grounded: grounded, swimming: swimming)
        } else {
            avatar?.update(delta: dt, speed: speedNow, grounded: grounded, swimming: swimming)
        }
        shake = max(0, shake - dt * 2)
        portalHintCooldown = max(0, portalHintCooldown - dt)
        updateCamera()
        updateRipples()
        updateWeather(dt)
        updateClouds(dt)
        updateSway()

        rules?.update(deltaTime: dt, heroPosition: heroPosition, attack: didAttack, use: didUse)

        flashTimer = max(0, flashTimer - dt)
        hudTimer += dt
        if hudTimer >= 0.1 {
            hudTimer = 0
            emitHUD(level: level)
        }

        if level.hasPortal {
            let portal = TerrainSampler.worldPoint(for: BoardPoint(x: 0.88, y: 0.24), in: level)
            let dx = heroPosition.x - portal.x
            let dz = heroPosition.z - portal.z
            if (dx * dx + dz * dz).squareRoot() < 1.9 {
                if rules?.portalIsOpen ?? true {
                    playSlot(\.portal)
                    finished = true
                    onFinish(elapsed)
                } else if portalHintCooldown <= 0 {
                    portalHintCooldown = 5
                    if let message = rules?.portalMessage() {
                        onMessage(message)
                    }
                }
            }
        }
    }

    // MARK: Camera

    private func updateCamera() {
        guard let level = self.level else { return }

        // The water is somewhere the camera should never sink into.
        func floorHeight(_ x: Float, _ z: Float) -> Float {
            max(TerrainSampler.height(level, at: x, z), IslandTerrain.waterLevel)
        }

        let target = heroPosition + SIMD3<Float>(0, 1.15, 0)
        let pitch = input.cameraPitch
        let distance = input.cameraDistance
        let backward = SIMD3<Float>(-sin(input.cameraYaw), 0, -cos(input.cameraYaw))
        let desired = target + backward * (distance * cos(pitch)) + SIMD3<Float>(0, distance * sin(pitch), 0)

        var allowed: Float = 1
        let steps = 12
        for index in 1...steps {
            let fraction = Float(index) / Float(steps)
            let sample = target + (desired - target) * fraction
            let ground = floorHeight(sample.x, sample.z)
            if sample.y < ground + 0.4 {
                allowed = max(0.22, Float(index - 1) / Float(steps))
                break
            }
        }

        var eye = target + (desired - target) * allowed
        let groundUnderEye = floorHeight(eye.x, eye.z)
        if eye.y < groundUnderEye + 0.45 {
            eye.y = groundUnderEye + 0.45
        }
        if shake > 0 {
            eye.x += Float.random(in: -0.18...0.18) * shake
            eye.y += Float.random(in: -0.12...0.12) * shake
        }

        let forward = simd_normalize(target - eye)
        var right = simd_cross(forward, SIMD3<Float>(0, 1, 0))
        if simd_length(right) < 0.001 {
            right = SIMD3<Float>(1, 0, 0)
        }
        right = simd_normalize(right)
        let up = simd_cross(right, forward)

        var matrix = matrix_identity_float4x4
        matrix.columns.0 = SIMD4<Float>(right, 0)
        matrix.columns.1 = SIMD4<Float>(up, 0)
        matrix.columns.2 = SIMD4<Float>(-forward, 0)
        matrix.columns.3 = SIMD4<Float>(eye, 1)

        cameraNode.simdTransform = matrix
    }

    // MARK: Pad

    private func readGamepad() {
        guard let pad = GCController.controllers().first?.extendedGamepad else {
            input.gamepadMove = SIMD2<Float>(0, 0)
            return
        }

        let x = pad.leftThumbstick.xAxis.value
        let y = pad.leftThumbstick.yAxis.value
        input.gamepadMove = (abs(x) > 0.15 || abs(y) > 0.15) ? SIMD2<Float>(x, y) : SIMD2<Float>(0, 0)

        let a = pad.buttonA.isPressed
        if a && !lastA { input.jump = true }
        lastA = a

        let xButton = pad.buttonX.isPressed
        if xButton && !lastX { input.attack = true }
        lastX = xButton

        let yButton = pad.buttonY.isPressed
        if yButton && !lastY { input.use = true }
        lastY = yButton

        if pad.buttonMenu.isPressed {
            onPause()
        }
    }

    // MARK: Helpers

    private func smooth(_ current: Float, toward target: Float, factor: Float) -> Float {
        var delta = target - current
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        return current + delta * factor
    }
}
