//
//  SceneKitProps.swift
//  Maker
//
//  Everything in a level is built from a handful of shapes. SceneKit gives
//  an explicit camera and scene, so the picture is exactly what the maths
//  says it should be.
//

import UIKit
import SceneKit

enum MakerMaterials {
    static func solid(_ color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.lightingModel = .lambert
        return material
    }

    static func glowing(_ color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color
        material.lightingModel = .constant
        return material
    }
}

enum PropNodeFactory {
    // MARK: Primitives

    static func box(_ size: SIMD3<Float>, _ color: UIColor) -> SCNNode {
        let geometry = SCNBox(width: CGFloat(size.x),
                              height: CGFloat(size.y),
                              length: CGFloat(size.z),
                              chamferRadius: 0.02)
        geometry.firstMaterial = MakerMaterials.solid(color)
        return SCNNode(geometry: geometry)
    }

    static func cylinder(radius: Float, height: Float, color: UIColor) -> SCNNode {
        let geometry = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))
        geometry.radialSegmentCount = 22
        geometry.firstMaterial = MakerMaterials.solid(color)
        return SCNNode(geometry: geometry)
    }

    static func cone(radius: Float, height: Float, color: UIColor) -> SCNNode {
        let geometry = SCNCone(topRadius: 0, bottomRadius: CGFloat(radius), height: CGFloat(height))
        geometry.radialSegmentCount = 22
        geometry.firstMaterial = MakerMaterials.solid(color)
        return SCNNode(geometry: geometry)
    }

    static func sphere(radius: Float, color: UIColor) -> SCNNode {
        let geometry = SCNSphere(radius: CGFloat(radius))
        geometry.segmentCount = 20
        geometry.firstMaterial = MakerMaterials.solid(color)
        return SCNNode(geometry: geometry)
    }

    static func disc(radius: Float, height: Float, color: UIColor) -> SCNNode {
        let geometry = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))
        geometry.radialSegmentCount = 56
        geometry.firstMaterial = MakerMaterials.solid(color)
        return SCNNode(geometry: geometry)
    }

    @discardableResult
    static func placed(_ node: SCNNode, y: Float) -> SCNNode {
        node.position = SCNVector3(0, y, 0)
        return node
    }

    // MARK: Whole props

    static func make(for entity: LevelEntity) -> SCNNode {
        let root = SCNNode()
        switch entity.kind {
        case .scenery: root.addChildNode(tree())
        case .prop: root.addChildNode(barrel())
        case .light: root.addChildNode(torch())
        case .treasure: root.addChildNode(chest())
        case .key: root.addChildNode(keyShape())
        case .pickup: root.addChildNode(placed(box(SIMD3(0.34, 0.34, 0.34), UIColor(red: 0.30, green: 0.78, blue: 0.55, alpha: 1)), y: 0.17))
        case .door: root.addChildNode(door())
        case .trap: root.addChildNode(trap())
        case .spawner: root.addChildNode(pad(color: UIColor(red: 0.92, green: 0.36, blue: 0.36, alpha: 1)))
        case .puzzle: root.addChildNode(pad(color: UIColor(red: 0.60, green: 0.36, blue: 0.92, alpha: 1)))
        case .platform: root.addChildNode(platform(preset: entity.platformPreset))
        case .sign: root.addChildNode(sign())
        case .portal: root.addChildNode(portal())
        case .checkpoint: root.addChildNode(flag(color: UIColor(red: 0.30, green: 0.74, blue: 0.55, alpha: 1)))
        case .npc: root.addChildNode(figure(color: UIColor(red: 0.25, green: 0.60, blue: 0.90, alpha: 1)))
        case .baddie: root.addChildNode(figure(color: UIColor(red: 0.85, green: 0.30, blue: 0.33, alpha: 1)))
        case .hero: root.addChildNode(figure(color: UIColor(red: 0.42, green: 0.30, blue: 0.95, alpha: 1)))
        }
        if let pattern = entity.surfacePattern {
            apply(pattern, to: root)
        }
        return root
    }

    /// Swaps the look of every part of a prop for a pattern, so a plain box
    /// can pass for brick or thatch. Glowing parts such as flames keep
    /// their own colour.
    static func apply(_ pattern: SurfacePattern, to node: SCNNode) {
        guard let image = pattern.image else { return }
        node.enumerateChildNodes { child, _ in
            guard let geometry = child.geometry else { return }
            geometry.materials = geometry.materials.map { original in
                guard original.lightingModel != .constant else { return original }
                let material = SCNMaterial()
                material.diffuse.contents = image
                material.diffuse.wrapS = .repeat
                material.diffuse.wrapT = .repeat
                material.diffuse.mipFilter = .linear
                material.lightingModel = .lambert
                material.isDoubleSided = original.isDoubleSided
                return material
            }
        }
    }

    static func tree() -> SCNNode {
        let root = SCNNode()
        root.addChildNode(placed(cylinder(radius: 0.12, height: 1.05,
                                          color: UIColor(red: 0.42, green: 0.29, blue: 0.19, alpha: 1)), y: 0.52))
        root.addChildNode(placed(cone(radius: 0.74, height: 1.05,
                                      color: UIColor(red: 0.22, green: 0.52, blue: 0.27, alpha: 1)), y: 1.28))
        root.addChildNode(placed(cone(radius: 0.58, height: 0.92,
                                      color: UIColor(red: 0.27, green: 0.60, blue: 0.31, alpha: 1)), y: 1.80))
        root.addChildNode(placed(cone(radius: 0.40, height: 0.76,
                                      color: UIColor(red: 0.32, green: 0.68, blue: 0.35, alpha: 1)), y: 2.28))
        return root
    }

    static func rock() -> SCNNode {
        let stone = sphere(radius: 0.5, color: UIColor(red: 0.55, green: 0.57, blue: 0.60, alpha: 1))
        stone.scale = SCNVector3(1.2, 0.7, 1.0)
        stone.position = SCNVector3(0, 0.22, 0)
        stone.eulerAngles.y = 0.4
        let root = SCNNode()
        root.addChildNode(stone)
        return root
    }

    static func bush() -> SCNNode {
        let root = SCNNode()
        let dark = UIColor(red: 0.22, green: 0.50, blue: 0.26, alpha: 1)
        let light = UIColor(red: 0.29, green: 0.60, blue: 0.31, alpha: 1)
        root.addChildNode(placed(sphere(radius: 0.44, color: dark), y: 0.30))
        let side = sphere(radius: 0.32, color: light)
        side.position = SCNVector3(0.34, 0.26, 0)
        root.addChildNode(side)
        let other = sphere(radius: 0.28, color: light)
        other.position = SCNVector3(-0.30, 0.24, 0)
        root.addChildNode(other)
        return root
    }

    static func barrel() -> SCNNode {
        let root = SCNNode()
        let wood = UIColor(red: 0.62, green: 0.42, blue: 0.24, alpha: 1)
        let band = UIColor(red: 0.40, green: 0.28, blue: 0.18, alpha: 1)
        root.addChildNode(placed(cylinder(radius: 0.26, height: 0.7, color: wood), y: 0.35))
        root.addChildNode(placed(cylinder(radius: 0.28, height: 0.07, color: band), y: 0.16))
        root.addChildNode(placed(cylinder(radius: 0.28, height: 0.07, color: band), y: 0.54))
        return root
    }

    static func chest() -> SCNNode {
        let root = SCNNode()
        let wood = UIColor(red: 0.58, green: 0.36, blue: 0.20, alpha: 1)
        let gold = UIColor(red: 0.92, green: 0.74, blue: 0.28, alpha: 1)
        root.addChildNode(placed(box(SIMD3(0.66, 0.40, 0.46), wood), y: 0.20))
        root.addChildNode(placed(box(SIMD3(0.70, 0.14, 0.50), gold), y: 0.46))
        root.addChildNode(placed(box(SIMD3(0.10, 0.22, 0.06), gold), y: 0.22))
        return root
    }

    static func keyShape() -> SCNNode {
        let root = SCNNode()
        let gold = UIColor(red: 0.95, green: 0.78, blue: 0.26, alpha: 1)
        let ring = cylinder(radius: 0.16, height: 0.06, color: gold)
        ring.eulerAngles.x = .pi / 2
        ring.position = SCNVector3(0, 0.3, 0)
        root.addChildNode(ring)
        let shaft = box(SIMD3(0.42, 0.07, 0.07), gold)
        shaft.position = SCNVector3(0.3, 0.3, 0)
        root.addChildNode(shaft)
        return root
    }

    static func torch() -> SCNNode {
        let root = SCNNode()
        root.addChildNode(placed(cylinder(radius: 0.06, height: 1.1,
                                          color: UIColor(red: 0.40, green: 0.28, blue: 0.18, alpha: 1)), y: 0.55))
        let flame = sphere(radius: 0.17, color: UIColor(red: 1, green: 0.72, blue: 0.22, alpha: 1))
        flame.geometry?.firstMaterial = MakerMaterials.glowing(UIColor(red: 1, green: 0.72, blue: 0.22, alpha: 1))
        flame.position = SCNVector3(0, 1.22, 0)
        root.addChildNode(flame)
        return root
    }

    static func door() -> SCNNode {
        let root = SCNNode()
        root.addChildNode(placed(box(SIMD3(1.1, 1.7, 0.16),
                                     UIColor(red: 0.53, green: 0.34, blue: 0.20, alpha: 1)), y: 0.85))
        let knob = sphere(radius: 0.07, color: UIColor(red: 0.92, green: 0.76, blue: 0.30, alpha: 1))
        knob.position = SCNVector3(0, 0.85, 0.1)
        root.addChildNode(knob)
        return root
    }

    static func trap() -> SCNNode {
        let root = SCNNode()
        root.addChildNode(placed(cylinder(radius: 0.55, height: 0.08,
                                          color: UIColor(red: 0.32, green: 0.29, blue: 0.33, alpha: 1)), y: 0.04))
        let spikeColor = UIColor(red: 0.80, green: 0.82, blue: 0.86, alpha: 1)
        for index in 0..<4 {
            let angle = Float(index) * .pi / 2 + 0.4
            let spike = cone(radius: 0.12, height: 0.42, color: spikeColor)
            spike.position = SCNVector3(cos(angle) * 0.26, 0.24, sin(angle) * 0.26)
            root.addChildNode(spike)
        }
        return root
    }

    static func pad(color: UIColor) -> SCNNode {
        let root = SCNNode()
        root.addChildNode(placed(disc(radius: 0.48, height: 0.1, color: color), y: 0.05))
        root.addChildNode(placed(disc(radius: 0.30, height: 0.12, color: color.mixed(with: .white, amount: 0.35)), y: 0.08))
        return root
    }

    static func sign() -> SCNNode {
        let root = SCNNode()
        root.addChildNode(placed(cylinder(radius: 0.06, height: 0.9,
                                          color: UIColor(red: 0.45, green: 0.32, blue: 0.2, alpha: 1)), y: 0.45))
        root.addChildNode(placed(box(SIMD3(0.7, 0.42, 0.08),
                                     UIColor(red: 0.76, green: 0.58, blue: 0.33, alpha: 1)), y: 0.95))
        return root
    }

    static func portal() -> SCNNode {
        let root = SCNNode()
        let stone = UIColor(red: 0.55, green: 0.56, blue: 0.63, alpha: 1)
        let left = box(SIMD3(0.28, 1.7, 0.5), stone)
        left.position = SCNVector3(-0.78, 0.85, 0)
        root.addChildNode(left)
        let right = box(SIMD3(0.28, 1.7, 0.5), stone)
        right.position = SCNVector3(0.78, 0.85, 0)
        root.addChildNode(right)
        root.addChildNode(placed(box(SIMD3(1.85, 0.30, 0.55), stone), y: 1.80))

        let discGeometry = SCNCylinder(radius: 0.72, height: 0.06)
        discGeometry.radialSegmentCount = 40
        discGeometry.firstMaterial = MakerMaterials.glowing(UIColor(red: 0.55, green: 0.38, blue: 0.99, alpha: 1))
        let disc = SCNNode(geometry: discGeometry)
        disc.eulerAngles.x = .pi / 2
        disc.position = SCNVector3(0, 0.88, 0)
        root.addChildNode(disc)
        return root
    }

    static func flag(color: UIColor) -> SCNNode {
        let root = SCNNode()
        root.addChildNode(placed(cylinder(radius: 0.055, height: 1.5,
                                          color: UIColor(white: 0.92, alpha: 1)), y: 0.75))
        let cloth = box(SIMD3(0.7, 0.42, 0.05), color)
        cloth.position = SCNVector3(0.36, 1.28, 0)
        root.addChildNode(cloth)
        return root
    }

    static func figure(color: UIColor) -> SCNNode {
        let root = SCNNode()
        let skin = UIColor(red: 0.95, green: 0.82, blue: 0.70, alpha: 1)
        root.addChildNode(placed(cylinder(radius: 0.20, height: 0.66, color: color), y: 0.33))
        root.addChildNode(placed(sphere(radius: 0.17, color: skin), y: 0.82))
        root.addChildNode(placed(cone(radius: 0.20, height: 0.22,
                                      color: color.mixed(with: .black, amount: 0.15)), y: 1.02))
        return root
    }

    static func platform(preset: String) -> SCNNode {
        let root = SCNNode()
        let stone = UIColor(red: 0.58, green: 0.60, blue: 0.66, alpha: 1)
        let dark = UIColor(red: 0.42, green: 0.44, blue: 0.50, alpha: 1)
        let wood = UIColor(red: 0.62, green: 0.43, blue: 0.24, alpha: 1)

        switch preset {
        case "swingingBridge":
            for index in 0..<5 {
                let plank = box(SIMD3(0.34, 0.14, 1.7), wood)
                plank.position = SCNVector3(Float(index) * 0.42 - 0.84, -0.07, 0)
                plank.eulerAngles.y = 0.02 * Float(index)
                root.addChildNode(plank)
            }
            let rope = UIColor(red: 0.76, green: 0.68, blue: 0.50, alpha: 1)
            for side in [-1, 1] {
                let rail = cylinder(radius: 0.03, height: 2.1, color: rope)
                rail.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
                rail.position = SCNVector3(0, -0.02, Float(side) * 0.8)
                root.addChildNode(rail)
            }
        case "spinningDisc":
            let disc = cylinder(radius: 1.05, height: 0.26, color: stone)
            disc.position = SCNVector3(0, -0.13, 0)
            root.addChildNode(disc)
            let rim = cylinder(radius: 1.08, height: 0.12, color: UIColor(red: 0.60, green: 0.45, blue: 0.95, alpha: 1))
            rim.geometry?.firstMaterial = MakerMaterials.glowing(UIColor(red: 0.60, green: 0.45, blue: 0.95, alpha: 1))
            rim.position = SCNVector3(0, -0.26, 0)
            root.addChildNode(rim)
        default:
            let slab = box(SIMD3(1.9, 0.3, 1.9), stone)
            slab.position = SCNVector3(0, -0.15, 0)
            root.addChildNode(slab)
            let base = box(SIMD3(1.6, 0.18, 1.6), dark)
            base.position = SCNVector3(0, -0.39, 0)
            root.addChildNode(base)
        }
        return root
    }

    static func flower() -> SCNNode {        let root = SCNNode()
        root.addChildNode(placed(cylinder(radius: 0.02, height: 0.36,
                                          color: UIColor(red: 0.28, green: 0.55, blue: 0.27, alpha: 1)), y: 0.18))
        let petal = sphere(radius: 0.12, color: UIColor(red: 0.95, green: 0.55, blue: 0.72, alpha: 1))
        petal.position = SCNVector3(0, 0.38, 0)
        petal.scale = SCNVector3(1, 0.65, 1)
        root.addChildNode(petal)
        return root
    }
}
