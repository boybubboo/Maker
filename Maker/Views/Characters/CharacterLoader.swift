//
//  CharacterLoader.swift
//  Maker
//
//  Reading a character file, measuring it, finding its bones, and walking
//  it with the same steps the maker's own hero uses.
//

import Foundation
import SceneKit
import UIKit
import simd

enum CharacterLoader {
    // MARK: Loading

    static func scene(at url: URL) -> SCNScene? {
        if url.pathExtension.lowercased() == "glb" {
            return GLBLoader.scene(at: url)
        }
        return try? SCNScene(url: url)
    }

    /// A copy of the model scaled to the height you asked for, standing
    /// on the ground.
    static func prepared(_ scene: SCNScene, height: Float) -> SCNNode {
        let container = SCNNode()
        let measurement = measure(scene.rootNode)
        let scale = measurement.height > 0.001 ? height / measurement.height : 1
        container.scale = SCNVector3(scale, scale, scale)
        scene.rootNode.position = SCNVector3(0, -measurement.minY, 0)
        container.addChildNode(scene.rootNode)
        return container
    }

    /// The node a character is played with, straight from its file.
    static func heroNode(for character: ImportedCharacter) -> SCNNode? {
        guard let scene = scene(at: character.url) else { return nil }
        return prepared(scene, height: Float(character.height))
    }

    // MARK: Measuring

    static func measure(_ root: SCNNode) -> (height: Float, minY: Float, triangles: Int) {
        var minY = Float.greatestFiniteMagnitude
        var maxY = -Float.greatestFiniteMagnitude
        var triangles = 0

        root.enumerateHierarchy { node, _ in
            if let geometry = node.geometry {
                for element in geometry.elements {
                    if element.primitiveType == .triangles {
                        triangles += element.primitiveCount
                    }
                }
            }
            guard node.geometry != nil else { return }
            let (minBound, maxBound) = node.boundingBox
            for x in [minBound.x, maxBound.x] {
                for y in [minBound.y, maxBound.y] {
                    for z in [minBound.z, maxBound.z] {
                        let world = node.convertPosition(SCNVector3(x, y, z), to: nil)
                        minY = min(minY, world.y)
                        maxY = max(maxY, world.y)
                    }
                }
            }
        }

        if minY == .greatestFiniteMagnitude {
            return (1, 0, triangles)
        }
        return (max(0.01, maxY - minY), minY, triangles)
    }

    static func boneNames(in root: SCNNode) -> [String] {
        var names: Set<String> = []
        root.enumerateHierarchy { node, _ in
            if let skinner = node.skinner {
                for bone in skinner.bones {
                    if let name = bone.name, !name.isEmpty {
                        names.insert(name)
                    }
                }
            }
        }
        return Array(names).sorted()
    }
}

// MARK: - Walking an imported skeleton

final class ImportedHeroRig {
    let root: SCNNode

    private var bones: [String: SCNNode] = [:]
    private var restPose: [String: SCNVector3] = [:]

    private var phase: Float = 0
    private var strideBlend: Float = 0
    private var jumpBlend: Float = 0
    private var swimBlend: Float = 0
    private var actionTimer: Float = 0

    init?(character: ImportedCharacter) {
        guard let node = CharacterLoader.heroNode(for: character) else { return nil }
        root = node

        var byName: [String: SCNNode] = [:]
        node.enumerateHierarchy { child, _ in
            if let name = child.name {
                byName[name] = child
            }
        }

        for (rigBone, modelBone) in character.boneMap {
            if let bone = byName[modelBone] {
                bones[rigBone] = bone
                restPose[rigBone] = bone.eulerAngles
            }
        }
    }

    var mappedBoneCount: Int { bones.count }

    func play(kind: Int) {
        actionTimer = 0.35
    }

    func update(delta: Float, speed: Float, grounded: Bool, swimming: Bool = false) {
        let targetStride = min(1, speed / 4.8)
        strideBlend += (targetStride - strideBlend) * min(1, delta * 6)

        let targetJump: Float = (grounded || swimming) ? 0 : 1
        jumpBlend += (targetJump - jumpBlend) * min(1, delta * 9)

        let targetSwim: Float = swimming ? 1 : 0
        swimBlend += (targetSwim - swimBlend) * min(1, delta * 5)

        phase += delta * (3.4 + strideBlend * 7.5 + swimBlend * 2.6)

        if actionTimer > 0 {
            actionTimer = max(0, actionTimer - delta)
        }

        let swing = sin(phase) * (0.55 * strideBlend)
        let gesture = sin(max(0, actionTimer) / 0.35 * .pi) * 1.4 * (actionTimer > 0 ? 1 : 0)
        let flutter = sin(phase * 2.6) * 0.5 * swimBlend
        let paddle = sin(phase * 1.7) * 0.5 * swimBlend
        let legsIn = swimBlend * 0.32

        if let bone = bones["Spine"] { rotate(bone, "Spine", swimBlend * 0.3) }
        if let bone = bones["UpperLeg.L"] { rotate(bone, "UpperLeg.L", swing - jumpBlend * 0.5 + legsIn + flutter) }
        if let bone = bones["UpperLeg.R"] { rotate(bone, "UpperLeg.R", -swing - jumpBlend * 0.28 + legsIn - flutter) }
        if let bone = bones["LowerLeg.L"] { rotate(bone, "LowerLeg.L", max(0, -swing) * 0.6 + swimBlend * 0.2) }
        if let bone = bones["LowerLeg.R"] { rotate(bone, "LowerLeg.R", max(0, swing) * 0.6 + swimBlend * 0.2) }
        if let bone = bones["UpperArm.L"] {
            rotate(bone, "UpperArm.L", -swing * 0.8 - jumpBlend * 1.5 - gesture * 0.4 - swimBlend * 1.1 + paddle)
        }
        if let bone = bones["UpperArm.R"] {
            rotate(bone, "UpperArm.R", swing * 0.8 - jumpBlend * 1.5 + gesture - swimBlend * 1.1 - paddle)
        }
        if let bone = bones["LowerArm.L"] { rotate(bone, "LowerArm.L", jumpBlend * -0.5 - swimBlend * 0.5) }
        if let bone = bones["LowerArm.R"] { rotate(bone, "LowerArm.R", jumpBlend * -0.5 - swimBlend * 0.5) }
    }

    /// The pose used in the wizard to check a bone mapping by eye.
    func applyTestPose(_ on: Bool) {
        let amounts: [String: Float] = [
            "UpperLeg.L": on ? 0.5 : 0,
            "UpperLeg.R": on ? -0.4 : 0,
            "UpperArm.L": on ? -0.7 : 0,
            "UpperArm.R": on ? 0.7 : 0,
            "LowerArm.L": on ? -0.4 : 0,
            "LowerArm.R": on ? 0.4 : 0
        ]
        for (rigBone, angle) in amounts {
            if let bone = bones[rigBone] {
                rotate(bone, rigBone, angle)
            }
        }
    }

    private func rotate(_ bone: SCNNode, _ rigBone: String, _ angle: Float) {
        guard let rest = restPose[rigBone] else { return }
        bone.eulerAngles = SCNVector3(rest.x + angle, rest.y, rest.z)
    }
}

// MARK: - glTF binary (static meshes)

enum GLBLoader {
    static func scene(at url: URL) -> SCNScene? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return scene(from: data)
    }

    static func scene(from data: Data) -> SCNScene? {
        guard data.count > 20 else { return nil }
        guard let magic = String(data: data.prefix(4), encoding: .ascii), magic == "glTF" else { return nil }
        guard let jsonLength = uint32(data, 12), uint32(data, 16) == 0x4E4F534A else { return nil }

        let jsonStart = 20
        let jsonEnd = jsonStart + Int(jsonLength)
        guard data.count >= jsonEnd else { return nil }
        let jsonData = data.subdata(in: jsonStart..<jsonEnd)
        guard let json = (try? JSONSerialization.jsonObject(with: jsonData)) as? [String: Any] else { return nil }

        var binary: Data?
        if data.count >= jsonEnd + 8,
           let binLength = uint32(data, jsonEnd),
           uint32(data, jsonEnd + 4) == 0x004E4942 {
            let start = jsonEnd + 8
            let end = min(data.count, start + Int(binLength))
            binary = data.subdata(in: start..<end)
        }

        return build(json: json, binary: binary)
    }

    // MARK: Building

    private static func build(json: [String: Any], binary: Data?) -> SCNScene? {
        let scene = SCNScene()
        let nodes = json["nodes"] as? [[String: Any]] ?? []
        let meshes = json["meshes"] as? [[String: Any]] ?? []
        let materials = json["materials"] as? [[String: Any]] ?? []
        let scenes = json["scenes"] as? [[String: Any]] ?? []
        let accessors = json["accessors"] as? [[String: Any]] ?? []
        let bufferViews = json["bufferViews"] as? [[String: Any]] ?? []

        guard !nodes.isEmpty, let bin = binary else { return nil }

        func makeNode(_ index: Int, depth: Int) -> SCNNode? {
            guard depth < 32, index < nodes.count else { return nil }
            let info = nodes[index]
            let node = SCNNode()

            if let meshIndex = info["mesh"] as? Int, meshIndex < meshes.count {
                let mesh = meshes[meshIndex]
                let primitives = mesh["primitives"] as? [[String: Any]] ?? []
                for primitive in primitives {
                    if let geometry = makeGeometry(primitive, accessors: accessors, bufferViews: bufferViews, materials: materials, bin: bin) {
                        let child = SCNNode(geometry: geometry)
                        node.addChildNode(child)
                    }
                }
            }

            if let translation = info["translation"] as? [Double], translation.count == 3 {
                node.position = SCNVector3(Float(translation[0]), Float(translation[1]), Float(translation[2]))
            }
            if let rotation = info["rotation"] as? [Double], rotation.count == 4 {
                node.orientation = SCNQuaternion(Float(rotation[0]), Float(rotation[1]), Float(rotation[2]), Float(rotation[3]))
            }
            if let scale = info["scale"] as? [Double], scale.count == 3 {
                node.scale = SCNVector3(Float(scale[0]), Float(scale[1]), Float(scale[2]))
            }

            if let children = info["children"] as? [Int] {
                for childIndex in children {
                    if let child = makeNode(childIndex, depth: depth + 1) {
                        node.addChildNode(child)
                    }
                }
            }
            return node
        }

        let roots = (scenes.first?["nodes"] as? [Int]) ?? Array(0..<min(nodes.count, 8))
        for root in roots {
            if let node = makeNode(root, depth: 0) {
                scene.rootNode.addChildNode(node)
            }
        }
        return scene.rootNode.childNodes.isEmpty ? nil : scene
    }

    private static func makeGeometry(
        _ primitive: [String: Any],
        accessors: [[String: Any]],
        bufferViews: [[String: Any]],
        materials: [[String: Any]],
        bin: Data
    ) -> SCNGeometry? {
        guard let attributes = primitive["attributes"] as? [String: Int],
              let positionAccessor = attributes["POSITION"] else { return nil }

        guard let positions = floats(accessor: positionAccessor, accessors: accessors, bufferViews: bufferViews, bin: bin, components: 3) else { return nil }

        var sources: [SCNGeometrySource] = [
            SCNGeometrySource(vertices: positions.map { SCNVector3($0[0], $0[1], $0[2]) })
        ]

        if let normalAccessor = attributes["NORMAL"],
           let normals = floats(accessor: normalAccessor, accessors: accessors, bufferViews: bufferViews, bin: bin, components: 3),
           normals.count == positions.count {
            sources.append(SCNGeometrySource(normals: normals.map { SCNVector3($0[0], $0[1], $0[2]) }))
        }

        let indices: [UInt32]
        if let indexAccessor = primitive["indices"] as? Int,
           let read = uints(accessor: indexAccessor, accessors: accessors, bufferViews: bufferViews, bin: bin) {
            indices = read
        } else {
            indices = (0..<UInt32(positions.count)).map { $0 }
        }
        guard indices.count >= 3 else { return nil }

        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: sources, elements: [element])

        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.isDoubleSided = true
        if let materialIndex = primitive["material"] as? Int,
           materialIndex < materials.count,
           let pbr = materials[materialIndex]["pbrMetallicRoughness"] as? [String: Any],
           let color = pbr["baseColorFactor"] as? [Double], color.count >= 4 {
            material.diffuse.contents = UIColor(red: color[0], green: color[1], blue: color[2], alpha: color[3])
        } else {
            material.diffuse.contents = UIColor(white: 0.82, alpha: 1)
        }
        geometry.materials = [material]
        return geometry
    }

    // MARK: Accessors

    private static func floats(
        accessor: Int,
        accessors: [[String: Any]],
        bufferViews: [[String: Any]],
        bin: Data,
        components: Int
    ) -> [[Float]]? {
        guard accessor < accessors.count,
              let info = accessors[accessor] as? [String: Any],
              let count = info["count"] as? Int,
              let componentType = info["componentType"] as? Int,
              let viewIndex = info["bufferView"] as? Int,
              viewIndex < bufferViews.count,
              let view = bufferViews[viewIndex] as? [String: Any] else { return nil }

        let viewOffset = (view["byteOffset"] as? Int) ?? 0
        let stride = (view["byteStride"] as? Int) ?? components * 4
        var result: [[Float]] = []
        result.reserveCapacity(count)

        for index in 0..<count {
            var values: [Float] = []
            for component in 0..<components {
                let offset = viewOffset + index * stride + component * 4
                guard componentType == 5126, offset + 4 <= bin.count else { return nil }
                let value = bin.withUnsafeBytes { raw -> Float in
                    raw.loadUnaligned(fromByteOffset: offset, as: Float.self)
                }
                values.append(value)
            }
            result.append(values)
        }
        return result
    }

    private static func uints(
        accessor: Int,
        accessors: [[String: Any]],
        bufferViews: [[String: Any]],
        bin: Data
    ) -> [UInt32]? {
        guard accessor < accessors.count,
              let info = accessors[accessor] as? [String: Any],
              let count = info["count"] as? Int,
              let componentType = info["componentType"] as? Int,
              let viewIndex = info["bufferView"] as? Int,
              viewIndex < bufferViews.count,
              let view = bufferViews[viewIndex] as? [String: Any] else { return nil }

        let viewOffset = (view["byteOffset"] as? Int) ?? 0
        var result: [UInt32] = []
        result.reserveCapacity(count)

        for index in 0..<count {
            switch componentType {
            case 5123:
                let offset = viewOffset + index * 2
                guard offset + 2 <= bin.count else { return nil }
                let value = bin.withUnsafeBytes { raw -> UInt16 in
                    raw.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
                }
                result.append(UInt32(value))
            case 5125:
                let offset = viewOffset + index * 4
                guard offset + 4 <= bin.count else { return nil }
                let value = bin.withUnsafeBytes { raw -> UInt32 in
                    raw.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
                }
                result.append(value)
            case 5121:
                let offset = viewOffset + index
                guard offset < bin.count else { return nil }
                result.append(UInt32(bin[bin.startIndex + offset]))
            default:
                return nil
            }
        }
        return result
    }

    private static func uint32(_ data: Data, _ offset: Int) -> UInt32? {
        guard offset + 4 <= data.count else { return nil }
        return data.withUnsafeBytes { raw in
            UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
        }
    }
}
