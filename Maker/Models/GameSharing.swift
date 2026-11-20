//
//  GameSharing.swift
//  Maker
//
//  One game in one file: the levels, the sculpted ground, the imported
//  characters and the sounds, wrapped in a header anyone can read.
//

import Foundation
import UIKit

struct SharedGameFile: Codable {
    var format = "maker.game"
    var version = 1
    var sharedBy: String
    var sharedAt: Date
    var summary: String
    var project: GameProject
    var characters: [SharedCharacterFile]
}

struct SharedCharacterFile: Codable {
    var fileName: String
    var data: Data
}

enum GameSharing {
    static let marker = "---MAKER GAME DATA---"
    static let fileExtension = "makergame"

    static var deviceName: String {
        let name = UIDevice.current.name
        return name.isEmpty ? "a friend" : name
    }

    static func summary(for project: GameProject) -> String {
        let levels = project.levels.count
        let baddies = project.levels.reduce(0) { $0 + $1.baddies.count }
        let treasures = project.levels.reduce(0) { total, level in
            total + level.entities.filter { $0.kind == .treasure }.count
        }

        var parts = ["\(levels) level\(levels == 1 ? "" : "s")"]
        if baddies > 0 { parts.append("\(baddies) baddie\(baddies == 1 ? "" : "s")") }
        if treasures > 0 { parts.append("\(treasures) treasure\(treasures == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }

    static func documentText(for project: GameProject, sharedBy: String) -> String? {
        var shared = SharedGameFile(
            sharedBy: sharedBy,
            sharedAt: Date(),
            summary: summary(for: project),
            project: project,
            characters: []
        )

        for character in project.importedCharacters ?? [] {
            guard let data = try? Data(contentsOf: character.url) else { continue }
            shared.characters.append(SharedCharacterFile(fileName: character.fileName, data: data))
        }

        guard let json = try? JSONEncoder().encode(shared),
              let payload = String(data: json, encoding: .utf8) else { return nil }

        let line = project.coverTagline.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        MAKER GAME
        \(project.name)
        \(line.isEmpty ? "A new adventure." : line)
        \(summary(for: project))
        Shared by \(sharedBy).

        This is one game made with Maker. Open it in Maker to play it and build on it.
        Nothing in this file runs on its own, so it is safe to keep or forward.

        \(marker)
        \(payload)
        """
    }

    static func decode(_ text: String) -> SharedGameFile? {
        guard let range = text.range(of: marker) else { return nil }
        let payload = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = payload.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SharedGameFile.self, from: data)
    }

    static func fileName(for project: GameProject) -> String {
        let trimmed = project.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "My Game" : trimmed
        return "\(base).\(fileExtension)"
    }

    static func temporaryFile(for project: GameProject, sharedBy: String) -> URL? {
        guard let text = documentText(for: project, sharedBy: sharedBy) else { return nil }

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("MakerShare", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(fileName(for: project))

        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
