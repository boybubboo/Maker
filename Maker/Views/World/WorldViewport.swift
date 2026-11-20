//
//  WorldViewport.swift
//  Maker
//
//  The 3D view of a level: a floating island shaped by the biome, under
//  the level's sky, with everything in the level standing on it.
//

import SwiftUI
import SceneKit
import UIKit
import simd

// MARK: - The island

struct IslandHill: Hashable {
    var center: SIMD2<Float>
    var radii: SIMD2<Float>
    var height: Float
}

enum IslandTerrain {
    static let radius: Float = 28
    static let baseTop: Float = 0.18
    /// The sand rim the island is standing on. Past it the ground is the
    /// sea floor, and the water surface is at `waterLevel` between.
    static let shoreRadius: Float = 30.5
    static let waterLevel: Float = -1.48
    static let seaFloor: Float = -3.4

    /// Gentle hills. Each one is a squashed sphere, so the height under a
    /// prop is exactly the surface the player sees.
    static let hills: [IslandHill] = [
        IslandHill(center: SIMD2(-6.8, -4.3), radii: SIMD2(14.3, 11.8), height: 3.2),
        IslandHill(center: SIMD2(10.5, -8.4), radii: SIMD2(11.2, 9.9), height: 4.1),
        IslandHill(center: SIMD2(1.9, 9.0), radii: SIMD2(13.0, 10.5), height: 1.9),
        IslandHill(center: SIMD2(-14.3, 9.6), radii: SIMD2(8.7, 8.1), height: 2.5),
        IslandHill(center: SIMD2(16.1, 6.8), radii: SIMD2(8.1, 7.4), height: 2.8)
    ]

    static func height(at x: Float, _ z: Float) -> Float {
        let distance = (x * x + z * z).squareRoot()
        guard distance < shoreRadius else { return seaFloor }
        var result = baseTop
        for hill in hills {
            let dx = (x - hill.center.x) / hill.radii.x
            let dz = (z - hill.center.y) / hill.radii.y
            let r2 = dx * dx + dz * dz
            if r2 < 1 {
                result = max(result, baseTop + hill.height * (1 - r2).squareRoot())
            }
        }
        return result
    }

    static func worldPoint(for point: BoardPoint) -> SIMD3<Float> {
        let x = (Float(point.x) - 0.5) * 2 * radius
        let z = (Float(point.y) - 0.5) * 2 * radius
        return SIMD3(x, height(at: x, z), z)
    }

    static func boardPoint(for world: SIMD3<Float>) -> BoardPoint {
        let x = CGFloat(world.x / (2 * radius) + 0.5)
        let y = CGFloat(world.z / (2 * radius) + 0.5)
        return BoardPoint(x: min(0.94, max(0.06, x)), y: min(0.94, max(0.06, y)))
    }
}

// MARK: - Camera

struct ViewportCamera: Equatable {
    var yaw: Float = 0.62
    var pitch: Float = 0.60
    var distance: Float = 48
    var target: SIMD3<Float> = SIMD3(0, 0.9, 0)
    var fieldOfView: Float = 52

    var eye: SIMD3<Float> {
        target + distance * SIMD3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
    }

    var forward: SIMD3<Float> { simd_normalize(target - eye) }
    var right: SIMD3<Float> { simd_normalize(simd_cross(forward, SIMD3<Float>(0, 1, 0))) }
    var up: SIMD3<Float> { simd_cross(right, forward) }

    /// The camera-to-world matrix this camera would have.
    var matrix: simd_float4x4 {
        var result = matrix_identity_float4x4
        result.columns.0 = SIMD4<Float>(right, 0)
        result.columns.1 = SIMD4<Float>(up, 0)
        result.columns.2 = SIMD4<Float>(-forward, 0)
        result.columns.3 = SIMD4<Float>(eye, 1)
        return result
    }

    func project(_ point: SIMD3<Float>, in size: CGSize) -> CGPoint? {
        guard size.width > 1, size.height > 1 else { return nil }
        let relative = point - eye
        let depth = simd_dot(relative, forward)
        guard depth > 0.1 else { return nil }
        let tanHalf = tan(fieldOfView * .pi / 360)
        let aspect = Float(size.width) / Float(size.height)
        let x = simd_dot(relative, right) / (depth * tanHalf * aspect)
        let y = simd_dot(relative, up) / (depth * tanHalf)
        return CGPoint(x: CGFloat(x * 0.5 + 0.5) * size.width,
                       y: CGFloat(1 - (y * 0.5 + 0.5)) * size.height)
    }

    func ray(through point: CGPoint, in size: CGSize) -> (origin: SIMD3<Float>, direction: SIMD3<Float>) {
        let ndcX = Float(point.x) / Float(max(size.width, 1)) * 2 - 1
        let ndcY = 1 - Float(point.y) / Float(max(size.height, 1)) * 2
        let tanHalf = tan(fieldOfView * .pi / 360)
        let aspect = Float(max(size.width, 1)) / Float(max(size.height, 1))
        let direction = simd_normalize(forward + right * (ndcX * aspect * tanHalf) + up * (ndcY * tanHalf))
        return (eye, direction)
    }
}

enum GroundPicker {
    /// Walks along the finger's ray and finds where it meets the island.
    static func point(for location: CGPoint, camera: ViewportCamera, in size: CGSize, level: GameLevel) -> SIMD3<Float>? {
        let ray = camera.ray(through: location, in: size)
        var travelled: Float = 0
        var previousGap = ray.origin.y - TerrainSampler.height(level, at: ray.origin.x, ray.origin.z)
        while travelled < 160 {
            travelled += 0.3
            let point = ray.origin + ray.direction * travelled
            let gap = point.y - TerrainSampler.height(level, at: point.x, point.z)
            if gap <= 0 && previousGap > 0 {
                var low = travelled - 0.3
                var high = travelled
                for _ in 0..<10 {
                    let middle = (low + high) / 2
                    let sample = ray.origin + ray.direction * middle
                    if sample.y - TerrainSampler.height(level, at: sample.x, sample.z) > 0 {
                        low = middle
                    } else {
                        high = middle
                    }
                }
                return ray.origin + ray.direction * high
            }
            previousGap = gap
        }
        return nil
    }
}

// MARK: - Tools

enum ViewportTool: String, CaseIterable, Identifiable {
    case add, move, rotate, scale, terrain, sticker, texture

    var id: String { rawValue }

    var title: String {
        switch self {
        case .add: return "Add"
        case .move: return "Move"
        case .rotate: return "Turn"
        case .scale: return "Resize"
        case .terrain: return "Ground"
        case .sticker: return "Sticker"
        case .texture: return "Texture"
        }
    }

    var symbol: String {
        switch self {
        case .add: return "plus"
        case .move: return "arrow.up.and.down.and.arrow.left.and.right"
        case .rotate: return "arrow.triangle.2.circlepath"
        case .scale: return "arrow.up.left.and.arrow.down.right"
        case .terrain: return "paintbrush.fill"
        case .sticker: return "seal.fill"
        case .texture: return "square.grid.3x3.fill"
        }
    }
}

// MARK: - Colours for the sky

extension SkyPreset {
    var viewportSky: UIColor {
        switch self {
        case .sunny: return UIColor(red: 0.55, green: 0.80, blue: 0.96, alpha: 1)
        case .golden: return UIColor(red: 0.96, green: 0.72, blue: 0.48, alpha: 1)
        case .night: return UIColor(red: 0.12, green: 0.15, blue: 0.28, alpha: 1)
        case .mist: return UIColor(red: 0.74, green: 0.79, blue: 0.83, alpha: 1)
        case .storm: return UIColor(red: 0.34, green: 0.38, blue: 0.44, alpha: 1)
        case .cave: return UIColor(red: 0.15, green: 0.13, blue: 0.21, alpha: 1)
        }
    }

    var viewportLight: UIColor {
        switch self {
        case .sunny: return UIColor(white: 1, alpha: 1)
        case .golden: return UIColor(red: 1, green: 0.88, blue: 0.72, alpha: 1)
        case .night: return UIColor(red: 0.62, green: 0.70, blue: 0.95, alpha: 1)
        case .mist: return UIColor(white: 0.92, alpha: 1)
        case .storm: return UIColor(red: 0.78, green: 0.82, blue: 0.88, alpha: 1)
        case .cave: return UIColor(red: 0.70, green: 0.66, blue: 0.86, alpha: 1)
        }
    }

    var viewportBrightness: Float {
        switch self {
        case .sunny: return 1000
        case .golden: return 820
        case .night: return 420
        case .mist: return 720
        case .storm: return 560
        case .cave: return 480
        }
    }
}

extension UIColor {
    func mixed(with other: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = max(0, min(1, amount))
        return UIColor(red: r1 + (r2 - r1) * t,
                       green: g1 + (g2 - g1) * t,
                       blue: b1 + (b2 - b1) * t,
                       alpha: a1 + (a2 - a1) * t)
    }
}

// MARK: - The scene

struct WorldSceneView: UIViewRepresentable {
    let level: GameLevel
    let camera: ViewportCamera
    let selectedID: UUID?

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.antialiasingMode = .multisampling4X
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        view.isPlaying = true
        view.scene = SCNScene()
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.update(level: level, camera: camera, selectedID: selectedID)
    }

    func makeCoordinator() -> WorldSceneCoordinator {
        WorldSceneCoordinator()
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: WorldSceneCoordinator) {
        uiView.isPlaying = false
        uiView.scene = nil
    }
}

final class WorldSceneCoordinator {
    private weak var view: SCNView?
    private let scene = SCNScene()

    private let cameraNode = SCNNode()
    private let sunNode = SCNNode()
    private let ambientNode = SCNNode()
    private let groundHolder = SCNNode()
    private let surfaceHolder = SCNNode()
    private let propHolder = SCNNode()
    private let stickerHolder = SCNNode()

    private var props: [UUID: SCNNode] = [:]
    private var propTextures: [UUID: String] = [:]
    private var startFlag: SCNNode?
    private var portalNode: SCNNode?
    private var selectionRing: SCNNode?

    private var groundKey = ""
    private var surfaceKey = ""
    private var skyKey = ""
    private var stickerKey = ""

    // MARK: Set up

    func attach(to view: SCNView) {
        self.view = view

        let camera = SCNCamera()
        camera.fieldOfView = 52
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

        scene.rootNode.addChildNode(groundHolder)
        scene.rootNode.addChildNode(surfaceHolder)
        scene.rootNode.addChildNode(propHolder)
        scene.rootNode.addChildNode(stickerHolder)

        let ringGeometry = SCNCylinder(radius: 0.66, height: 0.05)
        ringGeometry.radialSegmentCount = 32
        ringGeometry.firstMaterial = MakerMaterials.glowing(UIColor(red: 1, green: 0.98, blue: 0.55, alpha: 1))
        let ring = SCNNode(geometry: ringGeometry)
        ring.isHidden = true
        propHolder.addChildNode(ring)
        selectionRing = ring

        let flag = PropNodeFactory.make(for: LevelEntity(kind: .checkpoint, name: "Start"))
        flag.isHidden = true
        propHolder.addChildNode(flag)
        startFlag = flag

        let portal = PropNodeFactory.portal()
        portal.isHidden = true
        propHolder.addChildNode(portal)
        portalNode = portal

        view.scene = scene
        view.pointOfView = cameraNode
    }

    // MARK: Update

    func update(level: GameLevel, camera: ViewportCamera, selectedID: UUID?) {
        applyCamera(camera)
        applySky(level)
        applyGround(level)
        applySurface(level)
        applyProps(level)
        applyStickers(level)
        applyMarkers(level)
        applySelection(selectedID, level: level)
    }

    private func applyCamera(_ camera: ViewportCamera) {
        cameraNode.simdTransform = camera.matrix
        cameraNode.camera?.fieldOfView = CGFloat(camera.fieldOfView)
    }

    private func applySky(_ level: GameLevel) {
        let key = "\(level.biome.rawValue)|\(level.sky.rawValue)|\(Int(level.sunAngle))|\(Int(level.fog * 100))"
        guard key != skyKey else { return }
        skyKey = key
        LevelSceneBuilder.applySky(level, to: scene, sun: sunNode, ambient: ambientNode)
    }

    private func applyGround(_ level: GameLevel) {
        let key = level.biome.rawValue
        guard key != groundKey else { return }
        groundKey = key
        for child in groundHolder.childNodes {
            child.removeFromParentNode()
        }
        for node in LevelSceneBuilder.groundNodes(for: level) {
            groundHolder.addChildNode(node)
        }
    }

    private func applySurface(_ level: GameLevel) {
        let revision = level.terrain?.revision ?? -1
        let key = "\(level.biome.rawValue)|\(revision)"
        guard key != surfaceKey else { return }
        surfaceKey = key
        for child in surfaceHolder.childNodes {
            child.removeFromParentNode()
        }
        for node in LevelSceneBuilder.surfaceNodes(for: level) {
            surfaceHolder.addChildNode(node)
        }
    }

    private func applyProps(_ level: GameLevel) {
        var seen = Set<UUID>()

        for entity in level.entities {
            seen.insert(entity.id)
            let texture = entity.texture ?? ""
            let node: SCNNode
            if let existing = props[entity.id], propTextures[entity.id] == texture {
                node = existing
            } else {
                props[entity.id]?.removeFromParentNode()
                node = PropNodeFactory.make(for: entity)
                propHolder.addChildNode(node)
                props[entity.id] = node
                propTextures[entity.id] = texture
            }
            let world = TerrainSampler.worldPoint(for: entity.position, in: level)
            node.position = SCNVector3(world.x, world.y, world.z)
            node.eulerAngles.y = Float(entity.rotation * .pi / 180)
            let size = Float(max(0.3, min(4, entity.scale)))
            node.scale = SCNVector3(size, size, size)
        }

        let stale = props.keys.filter { !seen.contains($0) }
        for id in stale {
            props[id]?.removeFromParentNode()
            props.removeValue(forKey: id)
            propTextures.removeValue(forKey: id)
        }
    }

    /// Stickers are rebuilt when one is added or changed, and when a prop
    /// they are stuck to moves.
    private func applyStickers(_ level: GameLevel) {
        var parts: [String] = []
        for sticker in level.stickers ?? [] {
            parts.append("\(sticker.id)|\(sticker.kind)|\(sticker.size)|\(sticker.rotation)|\(sticker.fade)|\(sticker.position.x),\(sticker.position.y)")
            if let id = sticker.entityID, let entity = level.entity(with: id) {
                parts.append("\(entity.position.x),\(entity.position.y),\(entity.rotation),\(entity.scale)")
            } else {
                parts.append("-")
            }
        }
        let key = parts.joined(separator: ";")
        guard key != stickerKey else { return }
        stickerKey = key

        for child in stickerHolder.childNodes {
            child.removeFromParentNode()
        }
        for node in StickerNodes.nodes(for: level) {
            stickerHolder.addChildNode(node)
        }
    }

    private func applyMarkers(_ level: GameLevel) {
        if let startFlag {
            let world = TerrainSampler.worldPoint(for: BoardPoint(x: 0.12, y: 0.82), in: level)
            startFlag.position = SCNVector3(world.x, world.y, world.z)
            startFlag.isHidden = !level.hasStart
        }
        if let portalNode {
            let world = TerrainSampler.worldPoint(for: BoardPoint(x: 0.88, y: 0.24), in: level)
            portalNode.position = SCNVector3(world.x, world.y, world.z)
            portalNode.isHidden = !level.hasPortal
        }
    }

    private func applySelection(_ id: UUID?, level: GameLevel) {
        guard let selectionRing else { return }
        guard let entity = level.entity(with: id) else {
            selectionRing.isHidden = true
            return
        }
        let world = TerrainSampler.worldPoint(for: entity.position, in: level)
        selectionRing.position = SCNVector3(world.x, world.y + 0.04, world.z)
        selectionRing.isHidden = false
    }
}
