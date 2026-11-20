//
//  Stickers.swift
//  Maker
//
//  The stickers a kid sticks onto a level and the textures a prop or the
//  ground can wear. Every picture is drawn in code, so there is nothing to
//  download and nothing to find.
//

import Foundation
import SceneKit
import UIKit

// MARK: - Stickers

enum StickerKind: String, CaseIterable, Identifiable, Codable {
    case moss, cracks, runes, arrows, flowers, pawPrints, stars

    var id: String { rawValue }

    var title: String {
        switch self {
        case .moss: return "Moss"
        case .cracks: return "Cracks"
        case .runes: return "Runes"
        case .arrows: return "Arrows"
        case .flowers: return "Daisies"
        case .pawPrints: return "Paws"
        case .stars: return "Stars"
        }
    }

    var symbol: String {
        switch self {
        case .moss: return "leaf.fill"
        case .cracks: return "bolt.fill"
        case .runes: return "circle.hexagongrid.fill"
        case .arrows: return "arrow.up.right"
        case .flowers: return "camera.macro"
        case .pawPrints: return "pawprint.fill"
        case .stars: return "sparkles"
        }
    }

    var blurb: String {
        switch self {
        case .moss: return "Soft green patches for old stones."
        case .cracks: return "Split ground and broken walls."
        case .runes: return "Glowing marks for a magic door."
        case .arrows: return "Point the way to the portal."
        case .flowers: return "Scatter daisies over a meadow."
        case .pawPrints: return "Something came through here."
        case .stars: return "Twinkly spots of light."
        }
    }

    var image: UIImage { StickerArt.image(for: self) }
}

struct Sticker: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: String = StickerKind.moss.rawValue
    var position = BoardPoint(x: 0.5, y: 0.5)
    var rotation: Double = 0
    var size: Double = 2.0
    var fade: Double = 0.85

    /// When a sticker is stuck on a prop it rides along with it, in the
    /// prop's own little space.
    var entityID: UUID? = nil
    var localX: Double = 0
    var localY: Double = 0.55
    var localZ: Double = 0.45

    var stickerKind: StickerKind { StickerKind(rawValue: kind) ?? .moss }

    var isOnProp: Bool { entityID != nil }

    var name: String { stickerKind.title }
}

// MARK: - Textures

enum SurfacePattern: String, CaseIterable, Identifiable, Codable {
    case bare, planks, brick, thatch, stone, sand, grass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bare: return "Bare"
        case .planks: return "Planks"
        case .brick: return "Brick"
        case .thatch: return "Thatch"
        case .stone: return "Stone"
        case .sand: return "Sand"
        case .grass: return "Grass"
        }
    }

    var symbol: String {
        switch self {
        case .bare: return "eraser.fill"
        case .planks, .brick, .thatch, .stone, .sand, .grass: return "square.grid.3x3.fill"
        }
    }

    var blurb: String {
        switch self {
        case .bare: return "Back to the level's own ground."
        case .planks: return "Wooden boards."
        case .brick: return "A wall of red bricks."
        case .thatch: return "Dry straw and reeds."
        case .stone: return "Grey cobbles."
        case .sand: return "Fine warm sand."
        case .grass: return "Short green grass."
        }
    }

    /// The pattern's place in the heightmap, 0 being bare ground.
    var index: Int { SurfacePattern.allCases.firstIndex(of: self) ?? 0 }

    static func from(index: Int) -> SurfacePattern {
        allCases.indices.contains(index) ? allCases[index] : .bare
    }

    var image: UIImage? { PatternArt.image(for: self) }

    var swatch: UIColor {
        switch self {
        case .bare: return UIColor(white: 0.72, alpha: 1)
        case .planks: return UIColor(red: 0.63, green: 0.44, blue: 0.26, alpha: 1)
        case .brick: return UIColor(red: 0.72, green: 0.36, blue: 0.28, alpha: 1)
        case .thatch: return UIColor(red: 0.82, green: 0.68, blue: 0.36, alpha: 1)
        case .stone: return UIColor(red: 0.60, green: 0.62, blue: 0.65, alpha: 1)
        case .sand: return UIColor(red: 0.88, green: 0.78, blue: 0.55, alpha: 1)
        case .grass: return UIColor(red: 0.40, green: 0.65, blue: 0.32, alpha: 1)
        }
    }
}

// MARK: - Putting stickers in the scene

enum StickerNodes {
    /// Every sticker in a level, as flat pictures lying on the ground or
    /// stuck to the front of a prop.
    static func nodes(for level: GameLevel) -> [SCNNode] {
        (level.stickers ?? []).compactMap { node(for: $0, in: level) }
    }

    static func node(for sticker: Sticker, in level: GameLevel) -> SCNNode? {
        guard sticker.fade > 0.02, sticker.size > 0.05 else { return nil }
        guard let spot = worldPoint(for: sticker, in: level) else { return nil }

        let side = CGFloat(max(0.2, min(12, sticker.size)))
        let plane = SCNPlane(width: side, height: side)
        let material = SCNMaterial()
        material.diffuse.contents = sticker.stickerKind.image
        material.diffuse.wrapS = .clamp
        material.diffuse.wrapT = .clamp
        material.lightingModel = .lambert
        material.isDoubleSided = true
        material.writesToDepthBuffer = false
        material.transparency = CGFloat(max(0, min(1, sticker.fade)))
        plane.firstMaterial = material

        let picture = SCNNode(geometry: plane)
        picture.castsShadow = false
        if spot.flat {
            // Lying face up on the ground, turned the way it was spun.
            picture.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        }

        let holder = SCNNode()
        holder.name = "sticker"
        holder.position = SCNVector3(spot.position.x, spot.position.y, spot.position.z)
        holder.eulerAngles = SCNVector3(0, spot.yaw, 0)
        holder.addChildNode(picture)
        return holder
    }

    /// Where a sticker sits in the world, how it is turned, and whether it
    /// lies flat on the ground or stands on the face of a prop.
    static func worldPoint(for sticker: Sticker,
                           in level: GameLevel) -> (position: SIMD3<Float>, yaw: Float, flat: Bool)? {
        let turn = Float(sticker.rotation * .pi / 180)

        if let id = sticker.entityID, let entity = level.entity(with: id) {
            let world = TerrainSampler.worldPoint(for: entity.position, in: level)
            let yaw = Float(entity.rotation * .pi / 180)
            let scale = Float(max(0.3, min(4, entity.scale)))
            let local = SIMD3<Float>(Float(sticker.localX) * scale,
                                     Float(sticker.localY) * scale,
                                     Float(sticker.localZ) * scale)
            let turned = SIMD3<Float>(cos(yaw) * local.x + sin(yaw) * local.z,
                                      local.y,
                                      -sin(yaw) * local.x + cos(yaw) * local.z)
            let position = SIMD3<Float>(world.x + turned.x, world.y + turned.y, world.z + turned.z)
            return (position, yaw + turn, false)
        }

        let world = TerrainSampler.worldPoint(for: sticker.position, in: level)
        return (SIMD3<Float>(world.x, world.y + 0.03, world.z), turn, true)
    }
}

// MARK: - Drawn art

/// A tiny repeatable random so a sticker looks the same every time it is
/// drawn.
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        if state == 0 { state = 88_172_645_463_293 }
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func unit() -> CGFloat {
        CGFloat(next() % 10_000) / 10_000
    }

    mutating func range(_ low: CGFloat, _ high: CGFloat) -> CGFloat {
        low + unit() * (high - low)
    }
}

private enum StickerArt {
    private static var cache: [String: UIImage] = [:]
    private static let side: CGFloat = 256

    static func image(for kind: StickerKind) -> UIImage {
        if let cached = cache[kind.rawValue] { return cached }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { _ in
            switch kind {
            case .moss: drawMoss()
            case .cracks: drawCracks()
            case .runes: drawRunes()
            case .arrows: drawArrows()
            case .flowers: drawFlowers()
            case .pawPrints: drawPawPrints()
            case .stars: drawStars()
            }
        }
        cache[kind.rawValue] = image
        return image
    }

    // MARK: Moss

    private static func drawMoss() {
        var random = SeededRandom(seed: 7)
        let greens = [
            UIColor(red: 0.34, green: 0.60, blue: 0.29, alpha: 1),
            UIColor(red: 0.26, green: 0.49, blue: 0.23, alpha: 1),
            UIColor(red: 0.47, green: 0.72, blue: 0.36, alpha: 1)
        ]

        for index in 0..<44 {
            let angle = Double(random.range(0, 2 * .pi))
            let distance = random.range(0, 82)
            let centre = CGPoint(x: 128 + CGFloat(cos(angle)) * distance,
                                 y: 128 + CGFloat(sin(angle)) * distance)
            let radius = random.range(11, 32)
            greens[index % greens.count].withAlphaComponent(random.range(0.4, 0.9)).setFill()
            UIBezierPath(ovalIn: CGRect(x: centre.x - radius,
                                        y: centre.y - radius * 0.78,
                                        width: radius * 2,
                                        height: radius * 1.56)).fill()
        }

        for _ in 0..<30 {
            let centre = CGPoint(x: random.range(30, 226), y: random.range(30, 226))
            greens[2].withAlphaComponent(random.range(0.35, 0.8)).setFill()
            UIBezierPath(ovalIn: CGRect(x: centre.x - 3, y: centre.y - 3, width: 6, height: 6)).fill()
        }
    }

    // MARK: Cracks

    private static func drawCracks() {
        var random = SeededRandom(seed: 19)
        let ink = UIColor(red: 0.18, green: 0.16, blue: 0.15, alpha: 1)

        for _ in 0..<3 {
            var point = CGPoint(x: random.range(40, 216), y: random.range(20, 80))
            let path = UIBezierPath()
            path.move(to: point)
            for _ in 0..<7 {
                point = CGPoint(x: point.x + random.range(-34, 34), y: point.y + random.range(14, 30))
                path.addLine(to: point)
            }
            ink.withAlphaComponent(0.75).setStroke()
            path.lineWidth = random.range(3, 6)
            path.lineCapStyle = .round
            path.stroke()

            if random.unit() > 0.4 {
                let branch = UIBezierPath()
                branch.move(to: point)
                branch.addLine(to: CGPoint(x: point.x + random.range(-46, 46), y: point.y + random.range(6, 34)))
                branch.lineWidth = 2.5
                branch.lineCapStyle = .round
                ink.withAlphaComponent(0.55).setStroke()
                branch.stroke()
            }
        }
    }

    // MARK: Runes

    private static func drawRunes() {
        let glow = UIColor(red: 0.55, green: 0.86, blue: 0.98, alpha: 1)

        let ring = UIBezierPath(ovalIn: CGRect(x: 44, y: 44, width: 168, height: 168))
        ring.lineWidth = 5
        ring.stroke()

        let inner = UIBezierPath(ovalIn: CGRect(x: 82, y: 82, width: 92, height: 92))
        inner.lineWidth = 3
        glow.withAlphaComponent(0.7).setStroke()
        inner.stroke()

        for index in 0..<8 {
            let angle = Double(index) * .pi / 4 + 0.2
            let cx = 128 + CGFloat(cos(angle)) * 106
            let cy = 128 + CGFloat(sin(angle)) * 106
            let rune = UIBezierPath()
            rune.move(to: CGPoint(x: cx - 10, y: cy - 12))
            rune.addLine(to: CGPoint(x: cx + 8, y: cy - 2))
            rune.addLine(to: CGPoint(x: cx - 8, y: cy + 12))
            rune.lineWidth = 4
            rune.lineCapStyle = .round
            rune.lineJoinStyle = .round
            glow.setStroke()
            rune.stroke()
        }

        let core = UIBezierPath(ovalIn: CGRect(x: 118, y: 118, width: 20, height: 20))
        glow.withAlphaComponent(0.85).setFill()
        core.fill()
    }

    // MARK: Arrows

    private static func drawArrows() {
        let ink = UIColor(red: 0.96, green: 0.94, blue: 0.86, alpha: 1)

        for row in 0..<3 {
            let y = 84 + CGFloat(row) * 50
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 92, y: y))
            path.addLine(to: CGPoint(x: 146, y: y))
            path.addLine(to: CGPoint(x: 146, y: y - 22))
            path.addLine(to: CGPoint(x: 194, y: y + 10))
            path.addLine(to: CGPoint(x: 146, y: y + 42))
            path.addLine(to: CGPoint(x: 146, y: y + 20))
            path.addLine(to: CGPoint(x: 92, y: y + 20))
            path.close()

            path.lineWidth = 7
            path.lineJoinStyle = .round
            UIColor(red: 0.16, green: 0.14, blue: 0.12, alpha: 0.55).setStroke()
            path.stroke()

            ink.setFill()
            path.fill()
        }
    }

    // MARK: Daisies

    private static func drawFlowers() {
        var random = SeededRandom(seed: 41)
        let petal = UIColor(white: 1, alpha: 1)
        let heart = UIColor(red: 0.98, green: 0.78, blue: 0.28, alpha: 1)

        for _ in 0..<7 {
            let centre = CGPoint(x: random.range(44, 212), y: random.range(44, 212))
            let radius = random.range(11, 17)

            petal.withAlphaComponent(0.95).setFill()
            for petalIndex in 0..<6 {
                let angle = Double(petalIndex) * .pi / 3 + 0.3
                let px = centre.x + CGFloat(cos(angle)) * radius
                let py = centre.y + CGFloat(sin(angle)) * radius
                UIBezierPath(ovalIn: CGRect(x: px - radius * 0.62,
                                            y: py - radius * 0.5,
                                            width: radius * 1.24,
                                            height: radius)).fill()
            }

            heart.setFill()
            UIBezierPath(ovalIn: CGRect(x: centre.x - radius * 0.42,
                                        y: centre.y - radius * 0.42,
                                        width: radius * 0.84,
                                        height: radius * 0.84)).fill()
        }
    }

    // MARK: Paws

    private static func drawPawPrints() {
        var random = SeededRandom(seed: 53)
        let mud = UIColor(red: 0.31, green: 0.24, blue: 0.20, alpha: 1)

        for _ in 0..<3 {
            let centre = CGPoint(x: random.range(56, 200), y: random.range(56, 200))
            let turn = random.range(-0.6, 0.6)
            let scale = random.range(0.75, 1.1)

            mud.withAlphaComponent(0.72).setFill()

            let pad = CGRect(x: -17, y: -6, width: 34, height: 30)
            let padPath = UIBezierPath(ovalIn: pad)
            let toes: [(CGFloat, CGFloat)] = [(-19, -26), (-6, -34), (8, -32), (19, -22)]
            let all = UIBezierPath()
            all.append(padPath)
            for (dx, dy) in toes {
                all.append(UIBezierPath(ovalIn: CGRect(x: dx - 7, y: dy - 8, width: 14, height: 16)))
            }

            var transform = CGAffineTransform(translationX: centre.x, y: centre.y)
            transform = transform.rotated(by: turn)
            transform = transform.scaledBy(x: scale, y: scale)
            all.apply(transform)
            all.fill()
        }
    }

    // MARK: Stars

    private static func drawStars() {
        var random = SeededRandom(seed: 67)
        let colours = [
            UIColor(red: 1, green: 0.94, blue: 0.62, alpha: 1),
            UIColor(red: 0.98, green: 0.99, blue: 1, alpha: 1),
            UIColor(red: 0.86, green: 0.82, blue: 1, alpha: 1)
        ]

        for index in 0..<9 {
            let centre = CGPoint(x: random.range(40, 216), y: random.range(40, 216))
            let radius = random.range(12, 26)
            let path = starPath(centre: centre, radius: radius)
            colours[index % colours.count].withAlphaComponent(random.range(0.7, 1)).setFill()
            path.fill()
        }
    }

    private static func starPath(centre: CGPoint, radius: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let inner = radius * 0.44
        for index in 0..<10 {
            let angle = -Double.pi / 2 + Double(index) * .pi / 5
            let length = index.isMultiple(of: 2) ? radius : inner
            let point = CGPoint(x: centre.x + CGFloat(cos(angle)) * length,
                                y: centre.y + CGFloat(sin(angle)) * length)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.close()
        return path
    }
}

/// The patterns a prop or the ground can be painted with. Each one is a
/// small tile that repeats, so it never runs out.
private enum PatternArt {
    private static var cache: [String: UIImage] = [:]
    private static let side: CGFloat = 128

    static func image(for pattern: SurfacePattern) -> UIImage? {
        guard pattern != .bare else { return nil }
        if let cached = cache[pattern.rawValue] { return cached }
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let image = renderer.image { _ in
            switch pattern {
            case .planks: drawPlanks()
            case .brick: drawBrick()
            case .thatch: drawThatch()
            case .stone: drawStone()
            case .sand: drawSand()
            case .grass: drawGrass()
            case .bare: UIColor.white.setFill()
                UIRectFill(CGRect(x: 0, y: 0, width: side, height: side))
            }
        }
        cache[pattern.rawValue] = image
        return image
    }

    private static func drawPlanks() {
        var random = SeededRandom(seed: 21)
        let base = UIColor(red: 0.63, green: 0.45, blue: 0.27, alpha: 1)
        let board: CGFloat = 32

        for row in 0..<4 {
            let y = CGFloat(row) * board
            base.mixed(with: .black, amount: random.range(0, 0.16)).setFill()
            UIRectFill(CGRect(x: 0, y: y, width: 128, height: board))

            UIColor(white: 0.15, alpha: 0.34).setFill()
            UIRectFill(CGRect(x: 0, y: y, width: 128, height: 1.5))

            UIColor(white: 0.2, alpha: 0.14).setStroke()
            for _ in 0..<3 {
                let grain = UIBezierPath()
                let gy = y + random.range(6, board - 4)
                grain.move(to: CGPoint(x: 0, y: gy))
                grain.addLine(to: CGPoint(x: 128, y: gy + random.range(-2, 2)))
                grain.lineWidth = 1
                grain.stroke()
            }

            UIColor(white: 0.12, alpha: 0.3).setFill()
            UIRectFill(CGRect(x: random.range(8, 120), y: y + 3, width: 1.5, height: board - 6))
        }
    }

    private static func drawBrick() {
        var random = SeededRandom(seed: 33)
        let mortar = UIColor(white: 0.86, alpha: 1)
        let brick = UIColor(red: 0.72, green: 0.36, blue: 0.28, alpha: 1)
        mortar.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 128, height: 128))

        for row in 0..<4 {
            let y = CGFloat(row) * 32
            let offset: CGFloat = row % 2 == 0 ? 0 : 32
            for column in 0..<3 {
                let x = CGFloat(column) * 64 - offset
                for shift in [CGFloat(0), 128] {
                    brick.mixed(with: .black, amount: random.range(0, 0.2)).setFill()
                    UIBezierPath(roundedRect: CGRect(x: x + shift, y: y + 2, width: 61, height: 28),
                                 cornerRadius: 2).fill()
                }
            }
        }
    }

    private static func drawThatch() {
        var random = SeededRandom(seed: 47)
        let base = UIColor(red: 0.80, green: 0.67, blue: 0.36, alpha: 1)
        base.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 128, height: 128))

        for _ in 0..<150 {
            let x = random.range(0, 128)
            let straw = UIBezierPath()
            straw.move(to: CGPoint(x: x, y: 0))
            straw.addLine(to: CGPoint(x: x + random.range(-3, 3), y: 128))
            straw.lineWidth = random.range(1, 2.6)
            straw.lineCapStyle = .round
            UIColor(red: random.range(0.62, 0.92),
                    green: random.range(0.52, 0.78),
                    blue: random.range(0.22, 0.44),
                    alpha: random.range(0.5, 1)).setStroke()
            straw.stroke()
        }
    }

    private static func drawStone() {
        var random = SeededRandom(seed: 59)
        let mortar = UIColor(red: 0.44, green: 0.45, blue: 0.47, alpha: 1)
        mortar.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 128, height: 128))

        for row in 0..<4 {
            for column in 0..<4 {
                let inset = random.range(2.5, 6)
                let rect = CGRect(x: CGFloat(column) * 32 + inset,
                                  y: CGFloat(row) * 32 + inset,
                                  width: 32 - inset * 2,
                                  height: 32 - inset * 2)
                UIColor(red: random.range(0.56, 0.72),
                        green: random.range(0.56, 0.72),
                        blue: random.range(0.58, 0.74),
                        alpha: 1).setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: 5).fill()
            }
        }
    }

    private static func drawSand() {
        var random = SeededRandom(seed: 71)
        let base = UIColor(red: 0.88, green: 0.78, blue: 0.55, alpha: 1)
        base.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 128, height: 128))

        for _ in 0..<260 {
            let x = random.range(0, 128)
            let y = random.range(0, 128)
            let radius = random.range(0.6, 1.8)
            UIColor(white: random.range(0.4, 1), alpha: random.range(0.12, 0.35)).setFill()
            for dx in [CGFloat(0), -128, 128] {
                for dy in [CGFloat(0), -128, 128] {
                    UIBezierPath(ovalIn: CGRect(x: x + dx - radius, y: y + dy - radius,
                                                width: radius * 2, height: radius * 2)).fill()
                }
            }
        }
    }

    private static func drawGrass() {
        var random = SeededRandom(seed: 83)
        let base = UIColor(red: 0.40, green: 0.63, blue: 0.32, alpha: 1)
        base.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: 128, height: 128))

        for _ in 0..<170 {
            let x = random.range(0, 128)
            let y = random.range(0, 128)
            let blade = UIBezierPath()
            blade.move(to: CGPoint(x: x, y: y + random.range(5, 9)))
            blade.addLine(to: CGPoint(x: x + random.range(-2.5, 2.5), y: y - random.range(4, 9)))
            blade.lineWidth = random.range(1, 2)
            blade.lineCapStyle = .round
            UIColor(red: random.range(0.22, 0.48),
                    green: random.range(0.48, 0.78),
                    blue: random.range(0.18, 0.36),
                    alpha: random.range(0.6, 1)).setStroke()
            blade.stroke()
        }
    }
}
