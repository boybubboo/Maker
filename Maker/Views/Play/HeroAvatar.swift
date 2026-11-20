//
//  HeroAvatar.swift
//  Maker
//
//  A small rigged hero, built from jointed body parts, with a walk/run
//  cycle and a jump pose blended smoothly rather than switched.
//

import Foundation
import SceneKit
import UIKit

final class HeroAvatar {
    let root = SCNNode()

    private let hips = SCNNode()
    private let armL = SCNNode()
    private let armR = SCNNode()
    private let legL = SCNNode()
    private let legR = SCNNode()

    private var phase: Float = 0
    private var strideBlend: Float = 0
    private var jumpBlend: Float = 0
    private var swimBlend: Float = 0
    private var clock: Float = 0
    private var actionTimer: Float = 0
    private var actionKind: Int = 0

    init(jacket: UIColor, skin: UIColor, trousers: UIColor, boots: UIColor) {
        root.scale = SCNVector3(0.92, 0.92, 0.92)

        hips.position = SCNVector3(0, 0.94, 0)
        root.addChildNode(hips)

        let torsoGeometry = SCNBox(width: 0.46, height: 0.6, length: 0.28, chamferRadius: 0.07)
        torsoGeometry.firstMaterial = MakerMaterials.solid(jacket)
        let torso = SCNNode(geometry: torsoGeometry)
        torso.position = SCNVector3(0, 0.3, 0)
        hips.addChildNode(torso)

        let headGeometry = SCNSphere(radius: 0.2)
        headGeometry.segmentCount = 20
        headGeometry.firstMaterial = MakerMaterials.solid(skin)
        let head = SCNNode(geometry: headGeometry)
        head.position = SCNVector3(0, 0.84, 0)
        hips.addChildNode(head)

        let hatGeometry = SCNCone(topRadius: 0, bottomRadius: 0.21, height: 0.26)
        hatGeometry.radialSegmentCount = 20
        hatGeometry.firstMaterial = MakerMaterials.solid(jacket.mixed(with: .black, amount: 0.22))
        let hat = SCNNode(geometry: hatGeometry)
        hat.position = SCNVector3(0, 1.05, 0)
        hips.addChildNode(hat)

        for (joint, x) in [(legL, Float(-0.13)), (legR, Float(0.13))] {
            joint.position = SCNVector3(x, 0.02, 0)

            let legGeometry = SCNBox(width: 0.17, height: 0.86, length: 0.19, chamferRadius: 0.05)
            legGeometry.firstMaterial = MakerMaterials.solid(trousers)
            let leg = SCNNode(geometry: legGeometry)
            leg.position = SCNVector3(0, -0.43, 0)
            joint.addChildNode(leg)

            let footGeometry = SCNBox(width: 0.19, height: 0.1, length: 0.28, chamferRadius: 0.04)
            footGeometry.firstMaterial = MakerMaterials.solid(boots)
            let foot = SCNNode(geometry: footGeometry)
            foot.position = SCNVector3(0, -0.9, 0.05)
            joint.addChildNode(foot)

            hips.addChildNode(joint)
        }

        for (joint, x) in [(armL, Float(-0.3)), (armR, Float(0.3))] {
            joint.position = SCNVector3(x, 0.52, 0)

            let armGeometry = SCNBox(width: 0.13, height: 0.52, length: 0.14, chamferRadius: 0.05)
            armGeometry.firstMaterial = MakerMaterials.solid(jacket)
            let arm = SCNNode(geometry: armGeometry)
            arm.position = SCNVector3(0, -0.26, 0)
            joint.addChildNode(arm)

            let handGeometry = SCNSphere(radius: 0.075)
            handGeometry.segmentCount = 14
            handGeometry.firstMaterial = MakerMaterials.solid(skin)
            let hand = SCNNode(geometry: handGeometry)
            hand.position = SCNVector3(0, -0.54, 0)
            joint.addChildNode(hand)

            hips.addChildNode(joint)
        }
    }

    /// Plays a short arm gesture: 1 is a swing, 2 is a reach.
    func play(kind: Int) {
        actionKind = kind
        actionTimer = 0.34
    }

    func update(delta: Float, speed: Float, grounded: Bool, swimming: Bool = false) {
        clock += delta
        if actionTimer > 0 {
            actionTimer = max(0, actionTimer - delta)
        }

        let targetStride = min(1, speed / 4.8)
        strideBlend += (targetStride - strideBlend) * min(1, delta * 6)

        let targetJump: Float = (grounded || swimming) ? 0 : 1
        jumpBlend += (targetJump - jumpBlend) * min(1, delta * 9)

        let targetSwim: Float = swimming ? 1 : 0
        swimBlend += (targetSwim - swimBlend) * min(1, delta * 5)

        phase += delta * (3.4 + strideBlend * 7.5 + swimBlend * 2.6)

        let swing = sin(phase) * (0.62 * strideBlend)
        let gesture = gesturePose()
        let paddle = sin(phase * 1.7)
        let flutter = sin(phase * 2.6) * 0.55 * swimBlend

        legL.eulerAngles = SCNVector3(swing - jumpBlend * 0.5 + swimBlend * 0.34 + flutter, 0, 0)
        legR.eulerAngles = SCNVector3(-swing - jumpBlend * 0.28 + swimBlend * 0.34 - flutter, 0, 0)
        armL.eulerAngles = SCNVector3(-swing * 0.9 - jumpBlend * 1.6 + gesture.left
                                      + swimBlend * (-1.22 + paddle * 0.55), 0, 0)
        armR.eulerAngles = SCNVector3(swing * 0.9 - jumpBlend * 1.6 + gesture.right
                                      + swimBlend * (-1.22 - paddle * 0.55), 0, 0)

        let bob = abs(sin(phase)) * 0.03 * strideBlend
        let breathing = sin(clock * 2.2) * 0.006 * (1 - strideBlend)
        hips.position = SCNVector3(0, 0.94 + bob + jumpBlend * 0.05 + breathing - swimBlend * 0.09, 0)
        hips.eulerAngles = SCNVector3(swimBlend * 0.62,
                                      sin(phase) * 0.07 * strideBlend * (1 - swimBlend),
                                      0)
    }

    // MARK: Pose helpers

    private func gesturePose() -> (left: Float, right: Float) {
        guard actionTimer > 0 else { return (0, 0) }
        let progress = 1 - actionTimer / 0.34
        let amount = sin(progress * .pi) * 1.9
        if actionKind == 1 {
            return (-amount * 0.3, -amount)
        }
        return (-amount * 0.9, -amount * 0.6)
    }
}
