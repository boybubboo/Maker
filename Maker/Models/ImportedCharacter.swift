//
//  ImportedCharacter.swift
//  Maker
//
//  A character brought in from a file, and the skeleton we try to match
//  it to so it can walk like everything else.
//

import Foundation

struct ImportedCharacter: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var fileName: String
    var height: Double
    var boneMap: [String: String]
    var hasSkeleton: Bool
    var triangleCount: Int
    var addedAt = Date()

    var url: URL {
        CharacterStorage.folder.appendingPathComponent(fileName)
    }

    var isGLB: Bool {
        fileName.lowercased().hasSuffix(".glb")
    }
}

enum CharacterStorage {
    static var folder: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Characters", isDirectory: true)
    }

    static func prepareFolder() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    static func destination(for extensionName: String) -> URL {
        prepareFolder()
        return folder.appendingPathComponent("\(UUID().uuidString).\(extensionName.lowercased())")
    }
}

/// The skeleton everything in Maker is expected to be able to stand in for.
enum MakerRig {
    static let bones: [String] = [
        "Hips", "Spine", "Chest", "Neck", "Head",
        "UpperArm.L", "LowerArm.L", "Hand.L",
        "UpperArm.R", "LowerArm.R", "Hand.R",
        "UpperLeg.L", "LowerLeg.L", "Foot.L",
        "UpperLeg.R", "LowerLeg.R", "Foot.R"
    ]

    static let required: [String] = [
        "Hips", "Head", "UpperLeg.L", "UpperLeg.R", "UpperArm.L", "UpperArm.R"
    ]

    static func isLeft(_ bone: String) -> Bool { bone.hasSuffix(".L") }
    static func isRight(_ bone: String) -> Bool { bone.hasSuffix(".R") }

    static func baseName(_ bone: String) -> String {
        bone.replacingOccurrences(of: ".L", with: "").replacingOccurrences(of: ".R", with: "")
    }

    /// A best guess at which of the model's bones is which of ours.
    static func autoMap(_ names: [String]) -> [String: String] {
        var map: [String: String] = [:]
        for rigBone in bones {
            if let match = names.first(where: { matches(rigBone: rigBone, model: $0) }) {
                map[rigBone] = match
            }
        }
        return map
    }

    static func matches(rigBone: String, model: String) -> Bool {
        let candidate = model.lowercased()
        let wantedSide: String = isLeft(rigBone) ? "l" : (isRight(rigBone) ? "r" : "")
        let base = baseName(rigBone).lowercased()

        var candidateSide = ""
        if candidate.contains("left") || candidate.hasSuffix("_l") || candidate.hasSuffix(".l") || candidate.hasSuffix(":l") {
            candidateSide = "l"
        } else if candidate.contains("right") || candidate.hasSuffix("_r") || candidate.hasSuffix(".r") || candidate.hasSuffix(":r") {
            candidateSide = "r"
        }

        if !wantedSide.isEmpty && !candidateSide.isEmpty && wantedSide != candidateSide {
            return false
        }
        if !wantedSide.isEmpty && candidateSide.isEmpty && !candidate.contains("arm") && !candidate.contains("leg") && !candidate.contains("hand") && !candidate.contains("foot") {
            return false
        }

        switch base {
        case "hips": return candidate.contains("hip") || candidate.contains("pelvis")
        case "spine": return candidate.contains("spine") && !candidate.contains("top")
        case "chest": return candidate.contains("chest") || candidate.contains("torso")
        case "neck": return candidate.contains("neck")
        case "head": return candidate.contains("head")
        case "upperarm":
            return candidate.contains("upperarm") || candidate.contains("shoulder")
                || (candidate.contains("arm") && !candidate.contains("lower") && !candidate.contains("fore"))
        case "lowerarm":
            return candidate.contains("lowerarm") || candidate.contains("forearm") || candidate.contains("elbow")
        case "hand": return candidate.contains("hand") || candidate.contains("wrist")
        case "upperleg":
            return candidate.contains("upperleg") || candidate.contains("thigh")
        case "lowerleg":
            return candidate.contains("lowerleg") || candidate.contains("shin") || candidate.contains("calf")
        case "foot": return candidate.contains("foot") || candidate.contains("ankle")
        default: return false
        }
    }
}
