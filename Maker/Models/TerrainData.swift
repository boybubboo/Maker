//
//  TerrainData.swift
//  Maker
//
//  The ground a level stands on: a heightmap you can sculpt, a layer of
//  paint per corner, and the plants and rocks scattered on it.
//

import Foundation
import UIKit
import simd

enum TerrainLayer: UInt8, CaseIterable, Identifiable {
    case grass = 0
    case sand = 1
    case rock = 2
    case snow = 3

    var id: UInt8 { rawValue }

    var title: String {
        switch self {
        case .grass: return "Grass"
        case .sand: return "Sand"
        case .rock: return "Rock"
        case .snow: return "Snow"
        }
    }

    func color(biome: Biome) -> UIColor {
        switch self {
        case .grass: return UIColor(biome.ground)
        case .sand: return UIColor(biome.detail).mixed(with: .white, amount: 0.45)
        case .rock: return UIColor(biome.detail).mixed(with: .black, amount: 0.28)
        case .snow: return UIColor(white: 0.96, alpha: 1)
        }
    }
}

struct ScatterItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: String
    var x: Float
    var z: Float
    var size: Float
    var rotation: Float

    var isTree: Bool { kind == "tree" }
}

// MARK: - Brushes

enum TerrainBrush: String, CaseIterable, Identifiable {
    case raiseGround, lowerGround, smoothGround, flattenGround
    case paintGrass, paintSand, paintRock, paintSnow
    case scatterTree, scatterRock, scatterFlower

    var id: String { rawValue }

    var title: String {
        switch self {
        case .raiseGround: return "Raise"
        case .lowerGround: return "Lower"
        case .smoothGround: return "Smooth"
        case .flattenGround: return "Flatten"
        case .paintGrass: return "Grass"
        case .paintSand: return "Sand"
        case .paintRock: return "Rock"
        case .paintSnow: return "Snow"
        case .scatterTree: return "Trees"
        case .scatterRock: return "Rocks"
        case .scatterFlower: return "Flowers"
        }
    }

    var symbol: String {
        switch self {
        case .raiseGround: return "arrow.up.to.line"
        case .lowerGround: return "arrow.down.to.line"
        case .smoothGround: return "waveform.path"
        case .flattenGround: return "minus"
        case .paintGrass, .paintSand, .paintRock, .paintSnow: return "paintbrush.fill"
        case .scatterTree: return "leaf.fill"
        case .scatterRock: return "circle.fill"
        case .scatterFlower: return "sparkles"
        }
    }

    var isShape: Bool {
        switch self {
        case .raiseGround, .lowerGround, .smoothGround, .flattenGround: return true
        default: return false
        }
    }

    var isPaint: Bool {
        switch self {
        case .paintGrass, .paintSand, .paintRock, .paintSnow: return true
        default: return false
        }
    }

    var isScatter: Bool {
        switch self {
        case .scatterTree, .scatterRock, .scatterFlower: return true
        default: return false
        }
    }

    var layer: TerrainLayer? {
        switch self {
        case .paintGrass: return .grass
        case .paintSand: return .sand
        case .paintRock: return .rock
        case .paintSnow: return .snow
        default: return nil
        }
    }

    var scatterKind: String? {
        switch self {
        case .scatterTree: return "tree"
        case .scatterRock: return "rock"
        case .scatterFlower: return "flower"
        default: return nil
        }
    }

    var scatteredColor: UIColor {
        switch self {
        case .scatterTree: return UIColor(red: 0.28, green: 0.6, blue: 0.31, alpha: 1)
        case .scatterRock: return UIColor(red: 0.55, green: 0.57, blue: 0.6, alpha: 1)
        default: return UIColor(red: 0.94, green: 0.55, blue: 0.72, alpha: 1)
        }
    }
}

// MARK: - The path

enum TerrainPaths {
    static let start = SIMD2<Float>((0.12 - 0.5) * 2 * IslandTerrain.radius,
                                    (0.82 - 0.5) * 2 * IslandTerrain.radius)
    static let end = SIMD2<Float>((0.88 - 0.5) * 2 * IslandTerrain.radius,
                                  (0.24 - 0.5) * 2 * IslandTerrain.radius)
    static let control = SIMD2<Float>((start.x + end.x) * 0.5 + 7.5,
                                      (start.y + end.y) * 0.5 + 5.5)

    static let samples: [SIMD2<Float>] = {
        var points: [SIMD2<Float>] = []
        for index in 0..<60 {
            let t = Float(index) / 59
            let oneMinus = 1 - t
            points.append(SIMD2<Float>(
                oneMinus * oneMinus * start.x + 2 * oneMinus * t * control.x + t * t * end.x,
                oneMinus * oneMinus * start.y + 2 * oneMinus * t * control.y + t * t * end.y
            ))
        }
        return points
    }()

    static func distance(to point: SIMD2<Float>) -> Float {
        var closest = Float.greatestFiniteMagnitude
        for sample in samples {
            let dx = sample.x - point.x
            let dz = sample.y - point.y
            closest = min(closest, (dx * dx + dz * dz).squareRoot())
        }
        return closest
    }
}

// MARK: - The heightmap

struct TerrainData: Codable, Hashable {
    var size: Int = 48
    var heights: [Float] = []
    var layers: [UInt8] = []
    var scatter: [ScatterItem] = []
    var revision: Int = 0
    /// One texture per corner, 0 being the ground's own look. Levels made
    /// before textures existed simply have none.
    var patterns: [Int]? = nil

    init(size: Int = 48) {
        self.size = size
        let width = size + 1
        let radius = IslandTerrain.radius
        let step = (2 * radius) / Float(size)

        var newHeights = [Float](repeating: 0, count: width * width)
        var newLayers = [UInt8](repeating: TerrainLayer.grass.rawValue, count: width * width)

        for row in 0..<width {
            for col in 0..<width {
                let x = -radius + Float(col) * step
                let z = -radius + Float(row) * step
                let index = row * width + col
                newHeights[index] = IslandTerrain.height(at: x, z)
                let distance = (x * x + z * z).squareRoot()
                newLayers[index] = distance > radius * 0.88
                    ? TerrainLayer.sand.rawValue
                    : TerrainLayer.grass.rawValue
            }
        }

        heights = newHeights
        layers = newLayers
        scatter = TerrainData.defaultScatter()
    }

    var isValid: Bool {
        let width = size + 1
        return heights.count == width * width && layers.count == width * width
    }

    /// The ground under a point, blended between the four closest corners.
    func height(at x: Float, _ z: Float) -> Float {
        let width = size + 1
        guard heights.count >= width * width else { return 0 }
        let radius = IslandTerrain.radius
        let gx = (x + radius) / (2 * radius) * Float(size)
        let gz = (z + radius) / (2 * radius) * Float(size)
        guard gx >= 0, gz >= 0, gx < Float(size), gz < Float(size) else {
            return IslandTerrain.baseTop
        }

        let x0 = Int(gx)
        let z0 = Int(gz)
        let tx = gx - Float(x0)
        let tz = gz - Float(z0)

        let i00 = z0 * width + x0
        let i10 = i00 + 1
        let i01 = i00 + width
        let i11 = i01 + 1

        let top = heights[i00] * (1 - tx) + heights[i10] * tx
        let bottom = heights[i01] * (1 - tx) + heights[i11] * tx
        return top * (1 - tz) + bottom * tz
    }

    /// The texture painted at the corner nearest a point, 0 for bare ground.
    func pattern(at x: Float, _ z: Float) -> Int {
        let width = size + 1
        guard let patterns, patterns.count == width * width else { return 0 }
        let radius = IslandTerrain.radius
        let column = Int(((x + radius) / (2 * radius) * Float(size)).rounded())
        let row = Int(((z + radius) / (2 * radius) * Float(size)).rounded())
        guard column >= 0, row >= 0, column <= size, row <= size else { return 0 }
        return patterns[row * width + column]
    }

    /// Paints a texture into the grid, with a dithered edge so one pattern
    /// fades into the next.
    mutating func paintPattern(_ value: Int, x: Float, z: Float, radius: Float) {
        guard isValid else { return }
        let width = size + 1
        if patterns?.count != width * width {
            patterns = [Int](repeating: 0, count: width * width)
        }
        guard patterns != nil else { return }
        revision += 1

        let worldRadius = IslandTerrain.radius
        let step = (2 * worldRadius) / Float(size)

        for row in 0..<width {
            for col in 0..<width {
                let vx = -worldRadius + Float(col) * step
                let vz = -worldRadius + Float(row) * step
                let dx = vx - x
                let dz = vz - z
                let distance = (dx * dx + dz * dz).squareRoot()
                if distance > radius { continue }

                let falloff = 1 - distance / radius
                let chance = min(1, falloff * 3)
                if Float.random(in: 0...1) <= chance {
                    patterns?[row * width + col] = value
                }
            }
        }
    }

    // MARK: Brushes

    mutating func apply(_ brush: TerrainBrush, x: Float, z: Float, radius: Float) {
        guard isValid else { return }
        revision += 1

        if brush.isShape {
            let original = heights
            let width = size + 1
            let worldRadius = IslandTerrain.radius
            let step = (2 * worldRadius) / Float(size)
            let centre = height(at: x, z)
            var updated = heights

            for row in 0..<width {
                for col in 0..<width {
                    let vx = -worldRadius + Float(col) * step
                    let vz = -worldRadius + Float(row) * step
                    let dx = vx - x
                    let dz = vz - z
                    let distance = (dx * dx + dz * dz).squareRoot()
                    if distance > radius { continue }

                    let falloff = 1 - distance / radius
                    let soft = falloff * falloff * (3 - 2 * falloff)
                    let index = row * width + col

                    switch brush {
                    case .raiseGround:
                        updated[index] = original[index] + soft * 0.55
                    case .lowerGround:
                        updated[index] = original[index] - soft * 0.55
                    case .smoothGround:
                        let left = original[row * width + max(0, col - 1)]
                        let right = original[row * width + min(size, col + 1)]
                        let back = original[max(0, row - 1) * width + col]
                        let front = original[min(size, row + 1) * width + col]
                        let average = (left + right + back + front) / 4
                        updated[index] = original[index] + (average - original[index]) * soft * 0.6
                    default:
                        updated[index] = original[index] + (centre - original[index]) * soft * 0.4
                    }
                }
            }
            heights = updated
            return
        }

        if brush.isPaint, let layer = brush.layer {
            let width = size + 1
            let worldRadius = IslandTerrain.radius
            let step = (2 * worldRadius) / Float(size)
            var updated = layers

            for row in 0..<width {
                for col in 0..<width {
                    let vx = -worldRadius + Float(col) * step
                    let vz = -worldRadius + Float(row) * step
                    let dx = vx - x
                    let dz = vz - z
                    let distance = (dx * dx + dz * dz).squareRoot()
                    if distance > radius { continue }

                    // A dithered edge so one layer fades into the next.
                    let falloff = 1 - distance / radius
                    let chance = min(1, falloff * 3)
                    if Float.random(in: 0...1) <= chance {
                        updated[row * width + col] = layer.rawValue
                    }
                }
            }
            layers = updated
            return
        }

        if brush.isScatter, let kind = brush.scatterKind {
            for _ in 0..<3 {
                let angle = Float.random(in: 0..<(2 * .pi))
                let distance = Float.random(in: 0...radius)
                addScatter(kind: kind, x: x + cos(angle) * distance, z: z + sin(angle) * distance)
            }
        }
    }

    mutating func addScatter(kind: String, x: Float, z: Float) {
        guard scatter.count < 240 else { return }
        let distanceFromCentre = (x * x + z * z).squareRoot()
        guard distanceFromCentre < IslandTerrain.radius * 0.94 else { return }
        guard TerrainPaths.distance(to: SIMD2(x, z)) > 2.4 else { return }

        let spacing: Float = kind == "flower" ? 0.8 : 1.7
        for item in scatter {
            let dx = item.x - x
            let dz = item.z - z
            if (dx * dx + dz * dz).squareRoot() < spacing { return }
        }

        let size: Float
        switch kind {
        case "tree": size = Float.random(in: 0.8...1.35)
        case "rock": size = Float.random(in: 0.7...1.3)
        default: size = Float.random(in: 0.7...1.1)
        }

        scatter.append(ScatterItem(kind: kind,
                                   x: x,
                                   z: z,
                                   size: size,
                                   rotation: Float.random(in: 0...(2 * .pi))))
    }

    static func defaultScatter() -> [ScatterItem] {
        var items: [ScatterItem] = []
        for index in 0..<26 {
            let angle = Float(index) * 0.68 + 0.35
            let distance = 11 + Float(index % 7) * 2.3
            guard distance < IslandTerrain.radius * 0.94 else { continue }

            let x = cos(angle) * distance
            let z = sin(angle) * distance
            guard TerrainPaths.distance(to: SIMD2(x, z)) > 2.6 else { continue }

            let kind = index % 5 == 0 ? "rock" : "tree"
            items.append(ScatterItem(kind: kind,
                                     x: x,
                                     z: z,
                                     size: 0.85 + Float(index % 4) * 0.16,
                                     rotation: Float(index) * 0.8))
        }
        return items
    }
}

// MARK: - Reading the ground

enum TerrainSampler {
    /// The ground height a level is standing on, sculpted or still the
    /// gentle island it started as.
    static func height(_ level: GameLevel, at x: Float, _ z: Float) -> Float {
        let distance = (x * x + z * z).squareRoot()
        if distance > IslandTerrain.shoreRadius { return IslandTerrain.seaFloor }

        guard let terrain = level.terrain, terrain.isValid else {
            return IslandTerrain.height(at: x, z)
        }
        return terrain.height(at: x, z)
    }

    static func worldPoint(for point: BoardPoint, in level: GameLevel) -> SIMD3<Float> {
        let x = (Float(point.x) - 0.5) * 2 * IslandTerrain.radius
        let z = (Float(point.y) - 0.5) * 2 * IslandTerrain.radius
        return SIMD3(x, height(level, at: x, z), z)
    }
}
