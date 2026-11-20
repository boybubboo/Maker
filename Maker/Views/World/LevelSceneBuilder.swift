//
//  LevelSceneBuilder.swift
//  Maker
//
//  Builds the island a level stands on, for the editor and the game alike.
//

import Foundation
import SceneKit
import UIKit
import simd

enum LevelSceneBuilder {
    /// The beach, the cliffs and the sea. These never change.
    static func groundNodes(for level: GameLevel) -> [SCNNode] {
        let biome = level.biome
        var nodes: [SCNNode] = []

        let sand = UIColor(biome.detail).mixed(with: .white, amount: 0.42)
        let rock = UIColor(biome.detail).mixed(with: .black, amount: 0.22)
        let water = UIColor(biome.water)

        let sandDisc = PropNodeFactory.disc(radius: 30.7, height: 0.5, color: sand)
        sandDisc.position = SCNVector3(0, -0.09, 0)
        nodes.append(sandDisc)

        let cliff = PropNodeFactory.disc(radius: 29.0, height: 2.6, color: rock)
        cliff.position = SCNVector3(0, -1.42, 0)
        nodes.append(cliff)

        let sea = PropNodeFactory.disc(radius: 200, height: 0.2, color: water)
        sea.position = SCNVector3(0, -1.58, 0)
        nodes.append(sea)

        return nodes
    }

    /// The ground you can sculpt, the path across it, and everything
    /// scattered on it.
    static func surfaceNodes(for level: GameLevel) -> [SCNNode] {
        let data = level.terrain ?? TerrainData()
        var nodes: [SCNNode] = []

        if let mesh = terrainMesh(data, biome: level.biome) {
            nodes.append(mesh)
        }
        if let water = waterSurface(level: level, data: data) {
            nodes.append(water)
        }
        nodes.append(contentsOf: pathNodes(data: data))
        nodes.append(contentsOf: scatterNodes(data: data))
        return nodes
    }

    /// Ponds and channels: wherever the ground has been dug below the sea
    /// level, a sheet of water fills it.
    private static func waterSurface(level: GameLevel, data: TerrainData) -> SCNNode? {
        guard data.isValid else { return nil }
        let n = data.size
        let width = n + 1
        let radius = IslandTerrain.radius
        let step = (2 * radius) / Float(n)
        let surface = IslandTerrain.waterLevel

        var positions: [SCNVector3] = []
        var indices: [UInt32] = []

        for row in 0..<n {
            for col in 0..<n {
                let i00 = row * width + col
                let i10 = i00 + 1
                let i01 = i00 + width
                let i11 = i01 + 1
                let highest = max(max(data.heights[i00], data.heights[i10]),
                                  max(data.heights[i01], data.heights[i11]))
                guard highest < surface - 0.02 else { continue }

                let x0 = -radius + Float(col) * step
                let z0 = -radius + Float(row) * step
                let x1 = x0 + step
                let z1 = z0 + step
                let inside = (x0 * x0 + z0 * z0) < radius * radius
                    && (x1 * x1 + z0 * z0) < radius * radius
                    && (x0 * x0 + z1 * z1) < radius * radius
                    && (x1 * x1 + z1 * z1) < radius * radius
                guard inside else { continue }

                let base = UInt32(positions.count)
                positions.append(SCNVector3(x0, surface, z0))
                positions.append(SCNVector3(x1, surface, z0))
                positions.append(SCNVector3(x0, surface, z1))
                positions.append(SCNVector3(x1, surface, z1))
                indices.append(contentsOf: [base, base + 2, base + 1, base + 1, base + 2, base + 3])
            }
        }
        guard !indices.isEmpty else { return nil }

        let geometry = SCNGeometry(
            sources: [SCNGeometrySource(vertices: positions)],
            elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)]
        )

        let material = SCNMaterial()
        material.diffuse.contents = UIColor(level.biome.water)
        material.lightingModel = .lambert
        material.isDoubleSided = true
        material.transparency = 0.78
        geometry.materials = [material]
        return SCNNode(geometry: geometry)
    }

    /// Everything in the level, standing on the ground where it was placed.
    static func propNodes(for level: GameLevel) -> [SCNNode] {
        var nodes: [SCNNode] = []

        for entity in level.entities {
            let node = PropNodeFactory.make(for: entity)
            let world = TerrainSampler.worldPoint(for: entity.position, in: level)
            let hover: Float = entity.kind == .platform ? PlatformMotion.hover(for: entity.platformPreset) : 0
            node.position = SCNVector3(world.x, world.y + hover, world.z)
            node.eulerAngles.y = Float(entity.rotation * .pi / 180)
            let size = Float(max(0.3, min(4, entity.scale)))
            node.scale = SCNVector3(size, size, size)
            nodes.append(node)
        }

        if level.hasStart {
            let flag = PropNodeFactory.make(for: LevelEntity(kind: .checkpoint, name: "Start"))
            let world = TerrainSampler.worldPoint(for: BoardPoint(x: 0.12, y: 0.82), in: level)
            flag.position = SCNVector3(world.x, world.y, world.z)
            nodes.append(flag)
        }

        if level.hasPortal {
            let portal = PropNodeFactory.portal()
            let world = TerrainSampler.worldPoint(for: BoardPoint(x: 0.88, y: 0.24), in: level)
            portal.position = SCNVector3(world.x, world.y, world.z)
            nodes.append(portal)
        }

        return nodes
    }

    /// Sky colour, haze, fog and the light that falls on the island.
    static func applySky(_ level: GameLevel, to scene: SCNScene, sun: SCNNode, ambient: SCNNode) {
        let sky = level.sky.viewportSky
        let haze = UIColor(white: level.sky == .night || level.sky == .cave ? 0.22 : 0.94, alpha: 1)
        let fogColor = sky.mixed(with: haze, amount: 0.55)
        let fogAmount = CGFloat(level.fog)

        scene.background.contents = sky.mixed(with: haze, amount: fogAmount * 0.75)
        scene.fogColor = fogColor
        scene.fogStartDistance = 60 - fogAmount * 30
        scene.fogEndDistance = 220 - fogAmount * 120

        guard let sunlight = sun.light, let ambientLight = ambient.light else { return }
        sunlight.color = level.sky.viewportLight
        sunlight.intensity = CGFloat(level.sky.viewportBrightness)
        ambientLight.color = level.sky.viewportLight
        ambientLight.intensity = CGFloat(level.sky.viewportBrightness) * 0.55

        let azimuth = Float(level.sunAngle) * .pi / 180
        let direction = simd_normalize(SIMD3<Float>(cos(azimuth) * 0.7, -0.85, sin(azimuth) * 0.7))
        sun.simdOrientation = orientationToward(direction)
    }

    static func orientationToward(_ direction: SIMD3<Float>) -> simd_quatf {
        let z = -simd_normalize(direction)
        let reference: SIMD3<Float> = abs(z.y) > 0.98 ? SIMD3(1, 0, 0) : SIMD3(0, 1, 0)
        let x = simd_normalize(simd_cross(reference, z))
        let y = simd_cross(z, x)
        return simd_quatf(simd_float3x3(columns: (x, y, z)))
    }

    // MARK: The heightmap mesh

    private static func terrainMesh(_ data: TerrainData, biome: Biome) -> SCNNode? {
        guard data.isValid else { return nil }
        let n = data.size
        let width = n + 1
        let radius = IslandTerrain.radius
        let step = (2 * radius) / Float(n)

        var positions: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var colors: [SIMD4<Float>] = []
        var uvs: [CGPoint] = []
        positions.reserveCapacity(width * width)
        normals.reserveCapacity(width * width)
        colors.reserveCapacity(width * width)
        uvs.reserveCapacity(width * width)

        for row in 0..<width {
            for col in 0..<width {
                let x = -radius + Float(col) * step
                let z = -radius + Float(row) * step
                let index = row * width + col
                positions.append(SCNVector3(x, data.heights[index], z))
                uvs.append(CGPoint(x: CGFloat(x) / textureTile, y: CGFloat(z) / textureTile))

                let left = data.heights[row * width + max(0, col - 1)]
                let right = data.heights[row * width + min(n, col + 1)]
                let back = data.heights[max(0, row - 1) * width + col]
                let front = data.heights[min(n, row + 1) * width + col]
                let normal = simd_normalize(SIMD3<Float>(-(right - left) / (2 * step), 1, -(front - back) / (2 * step)))
                normals.append(SCNVector3(normal.x, normal.y, normal.z))

                let layer = TerrainLayer(rawValue: data.layers[index]) ?? .grass
                let color = layer.color(biome: biome)
                var red: CGFloat = 0
                var green: CGFloat = 0
                var blue: CGFloat = 0
                var alpha: CGFloat = 0
                color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                colors.append(SIMD4<Float>(Float(red), Float(green), Float(blue), 1))
            }
        }

        // Triangles are grouped by the texture painted on them, so each
        // pattern gets one piece of the ground and its own material.
        var grouped: [Int: [UInt32]] = [:]
        for row in 0..<n {
            for col in 0..<n {
                let x0 = -radius + Float(col) * step
                let z0 = -radius + Float(row) * step
                let x1 = x0 + step
                let z1 = z0 + step
                let inside = (x0 * x0 + z0 * z0) < radius * radius
                    && (x1 * x1 + z0 * z0) < radius * radius
                    && (x0 * x0 + z1 * z1) < radius * radius
                    && (x1 * x1 + z1 * z1) < radius * radius
                guard inside else { continue }

                let pattern = cellPattern(data, row: row, col: col)
                let a = UInt32(row * width + col)
                let b = a + 1
                let c = UInt32((row + 1) * width + col)
                let d = c + 1
                grouped[pattern, default: []].append(contentsOf: [a, c, b, b, c, d])
            }
        }
        guard !grouped.isEmpty else { return nil }

        let order = grouped.keys.sorted()
        let elements = order.compactMap { index -> SCNGeometryElement? in
            guard let indices = grouped[index], !indices.isEmpty else { return nil }
            return SCNGeometryElement(indices: indices, primitiveType: .triangles)
        }
        guard !elements.isEmpty else { return nil }

        let geometry = SCNGeometry(
            sources: [
                SCNGeometrySource(vertices: positions),
                SCNGeometrySource(normals: normals),
                SCNGeometrySource(textureCoordinates: uvs),
                colorSource(colors)
            ],
            elements: elements
        )
        geometry.materials = order.map { groundMaterial(for: SurfacePattern.from(index: $0)) }
        return SCNNode(geometry: geometry)
    }

    /// How many metres one tile of a painted texture covers.
    private static let textureTile: CGFloat = 2.4

    private static func cellPattern(_ data: TerrainData, row: Int, col: Int) -> Int {
        let width = data.size + 1
        guard let patterns = data.patterns, patterns.count == width * width else { return 0 }
        let corners = [
            patterns[row * width + col],
            patterns[row * width + col + 1],
            patterns[(row + 1) * width + col],
            patterns[(row + 1) * width + col + 1]
        ]
        return corners.max() ?? 0
    }

    private static func groundMaterial(for pattern: SurfacePattern) -> SCNMaterial {
        let material = SCNMaterial()
        if let image = pattern.image {
            material.diffuse.contents = image
            material.diffuse.wrapS = .repeat
            material.diffuse.wrapT = .repeat
            material.diffuse.mipFilter = .linear
        } else {
            material.diffuse.contents = UIColor.white
        }
        material.lightingModel = .lambert
        material.isDoubleSided = true
        return material
    }

    private static func colorSource(_ colors: [SIMD4<Float>]) -> SCNGeometrySource {
        let data = colors.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
        return SCNGeometrySource(
            data: data,
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: 4,
            dataOffset: 0,
            dataStride: MemoryLayout<SIMD4<Float>>.size
        )
    }

    private static func pathNodes(data: TerrainData) -> [SCNNode] {
        let sand = UIColor(red: 0.86, green: 0.78, blue: 0.58, alpha: 1)
        var nodes: [SCNNode] = []

        for point in TerrainPaths.samples {
            let y = data.height(at: point.x, point.y)
            let tile = PropNodeFactory.box(SIMD3(1.3, 0.12, 1.3), sand)
            tile.position = SCNVector3(point.x, y + 0.05, point.y)
            nodes.append(tile)
        }
        return nodes
    }

    private static func scatterNodes(data: TerrainData) -> [SCNNode] {
        var nodes: [SCNNode] = []

        for item in data.scatter {
            let node: SCNNode
            if item.kind == "tree" {
                node = PropNodeFactory.tree()
                // Named so the wind can find the trees and sway them.
                node.name = "sway"
            } else if item.kind == "rock" {
                node = PropNodeFactory.rock()
            } else {
                node = PropNodeFactory.flower()
            }
            node.scale = SCNVector3(item.size, item.size, item.size)
            node.eulerAngles.y = item.rotation
            node.position = SCNVector3(item.x, data.height(at: item.x, item.z), item.z)
            nodes.append(node)
        }
        return nodes
    }
}
