//
//  MakerStore.swift
//  Maker
//
//  Holds the projects on this device, the selection, undo history and
//  autosave. Everything a screen changes goes through here.
//

import Foundation
import SwiftUI

struct UndoStep {
    var projects: [GameProject]
    var label: String
}

struct ReadinessIssue: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let isBlocking: Bool
    let tab: StageTab
}

final class MakerStore: ObservableObject {
    @Published private(set) var projects: [GameProject] = []
    @Published var openProjectID: UUID?

    @Published var selectedTab: StageTab = .world
    @Published var selectedLevelID: UUID?
    @Published var selectedSection: EntitySection = .cast
    @Published var selectedEntityID: UUID?
    @Published var selectedWidgetID: UUID?
    @Published var selectedStickerID: UUID?

    @Published var isPlaying = false
    @Published var showingNewGame = false
    @Published var showingIdeas = false
    @Published var toast: String?

    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    @Published private(set) var undoTitle: String?

    private var undoStack: [UndoStep] = []
    private var redoStack: [UndoStep] = []
    private var saveWork: DispatchWorkItem?

    // MARK: Load & save

    private var fileURL: URL {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return folder.appendingPathComponent("maker-projects.json")
    }

    init() {
        load()
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([GameProject].self, from: data),
           !saved.isEmpty {
            projects = saved
        } else {
            projects = TemplateLibrary.starterProjects()
            saveNow()
        }
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    func saveNow() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: Reading

    func project(_ id: UUID) -> GameProject? {
        projects.first { $0.id == id }
    }

    var currentProject: GameProject? {
        guard let openProjectID else { return nil }
        return projects.first { $0.id == openProjectID }
    }

    var currentLevel: GameLevel? {
        currentProject?.level(with: selectedLevelID)
    }

    var currentEntity: LevelEntity? {
        currentLevel?.entity(with: selectedEntityID)
    }

    var currentWidget: HUDWidget? {
        currentProject?.hud.widget(with: selectedWidgetID)
    }

    var currentSticker: Sticker? {
        guard let selectedStickerID else { return nil }
        return currentLevel?.stickers?.first { $0.id == selectedStickerID }
    }

    var levelIndex: Int {
        currentProject?.levelIndex(of: selectedLevelID) ?? 0
    }

    // MARK: Opening

    func open(_ id: UUID) {
        guard let project = project(id) else { return }
        openProjectID = id
        selectedTab = .world
        selectedLevelID = project.levels.first?.id
        selectedSection = .cast
        selectedEntityID = project.levels.first?.entities.first?.id
        selectedWidgetID = project.hud.widgets.first?.id
        undoStack.removeAll()
        redoStack.removeAll()
        refreshUndoFlags()
    }

    func closeProject() {
        saveNow()
        openProjectID = nil
    }

    // MARK: Projects

    func createProject(name: String, template: GameTemplate) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = TemplateLibrary.project(for: template, name: trimmed.isEmpty ? template.name : trimmed)
        projects.insert(project, at: 0)
        open(project.id)
        saveNow()
    }

    func deleteProject(_ id: UUID) {
        projects.removeAll { $0.id == id }
        if openProjectID == id { openProjectID = nil }
        saveNow()
    }

    func duplicateProject(_ id: UUID) {
        guard var copy = project(id) else { return }
        let newLevels = copy.levels.map { level -> GameLevel in
            var fresh = level
            fresh.id = UUID()
            fresh.entities = level.entities.map { entity in
                var copyEntity = entity
                copyEntity.id = UUID()
                return copyEntity
            }
            return fresh
        }
        copy.id = UUID()
        copy.name = copy.name + " copy"
        copy.levels = newLevels
        copy.createdAt = Date()
        copy.updatedAt = Date()
        projects.insert(copy, at: 0)
        saveNow()
        toast = "Made a copy of \(copy.name)"
    }

    func renameProject(_ name: String) {
        updateProject(undoLabel: "rename the game") { $0.name = name }
    }

    // MARK: Undo

    private func pushUndo(_ label: String) {
        undoStack.append(UndoStep(projects: projects, label: label))
        if undoStack.count > 60 { undoStack.removeFirst() }
        redoStack.removeAll()
        refreshUndoFlags()
    }

    private func refreshUndoFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        undoTitle = undoStack.last?.label
    }

    func undo() {
        guard let step = undoStack.popLast() else { return }
        redoStack.append(UndoStep(projects: projects, label: step.label))
        projects = step.projects
        sanitizeSelection()
        toast = "Undid “\(step.label)”"
        refreshUndoFlags()
        saveNow()
    }

    func redo() {
        guard let step = redoStack.popLast() else { return }
        undoStack.append(UndoStep(projects: projects, label: step.label))
        projects = step.projects
        sanitizeSelection()
        toast = "Redid “\(step.label)”"
        refreshUndoFlags()
        saveNow()
    }

    private func sanitizeSelection() {
        guard let project = currentProject else { return }
        if project.levels.first(where: { $0.id == selectedLevelID }) == nil {
            selectedLevelID = project.levels.first?.id
        }
        if let level = currentLevel {
            if level.entities.first(where: { $0.id == selectedEntityID }) == nil {
                selectedEntityID = level.entities.first?.id
            }
        } else {
            selectedEntityID = nil
        }
        if project.hud.widgets.first(where: { $0.id == selectedWidgetID }) == nil {
            selectedWidgetID = project.hud.widgets.first?.id
        }
        if let stickerID = selectedStickerID,
           currentLevel?.stickers?.contains(where: { $0.id == stickerID }) != true {
            selectedStickerID = nil
        }
    }

    // MARK: Mutating the open project

    func updateProject(undoLabel: String? = nil, _ changes: (inout GameProject) -> Void) {
        guard let index = projects.firstIndex(where: { $0.id == openProjectID }) else { return }
        if let undoLabel { pushUndo(undoLabel) }
        var project = projects[index]
        changes(&project)
        project.updatedAt = Date()
        projects[index] = project
        scheduleSave()
    }

    func updateLevel(_ id: UUID, undoLabel: String? = nil, _ changes: (inout GameLevel) -> Void) {
        updateProject(undoLabel: undoLabel) { project in
            guard let index = project.levels.firstIndex(where: { $0.id == id }) else { return }
            changes(&project.levels[index])
        }
    }

    func updateEntity(_ id: UUID, undoLabel: String? = nil, _ changes: (inout LevelEntity) -> Void) {
        updateProject(undoLabel: undoLabel) { project in
            for levelIndex in project.levels.indices {
                if let entityIndex = project.levels[levelIndex].entities.firstIndex(where: { $0.id == id }) {
                    changes(&project.levels[levelIndex].entities[entityIndex])
                    return
                }
            }
        }
    }

    func updateWidget(_ id: UUID, undoLabel: String? = nil, _ changes: (inout HUDWidget) -> Void) {
        updateProject(undoLabel: undoLabel) { project in
            guard let index = project.hud.widgets.firstIndex(where: { $0.id == id }) else { return }
            changes(&project.hud.widgets[index])
        }
    }

    func updateCard(entityID: UUID, cardID: UUID, undoLabel: String? = nil, _ changes: (inout BehaviorCard) -> Void) {
        updateEntity(entityID, undoLabel: undoLabel) { entity in
            guard let index = entity.cards.firstIndex(where: { $0.id == cardID }) else { return }
            changes(&entity.cards[index])
        }
    }

    // MARK: Levels

    func addLevel() {
        guard let index = projects.firstIndex(where: { $0.id == openProjectID }) else { return }
        pushUndo("add a level")
        var project = projects[index]
        var level = GameLevel(name: "Level \(project.levels.count + 1)")
        level.biome = project.levels.last?.biome ?? .meadow
        level.objectives = [LevelObjective(text: "Reach the portal")]
        level.audio = LevelAudio(mood: project.levels.last?.audio?.mood ?? .adventure)
        project.levels.append(level)
        project.updatedAt = Date()
        projects[index] = project
        selectedLevelID = level.id
        selectedEntityID = nil
        scheduleSave()
    }

    func updateLevelAudio(undoLabel: String? = nil, _ changes: (inout LevelAudio) -> Void) {
        guard let id = currentLevel?.id else { return }
        updateLevel(id, undoLabel: undoLabel) { level in
            var audio = level.audio ?? LevelAudio()
            changes(&audio)
            level.audio = audio
        }
    }

    func duplicateLevel(_ id: UUID) {
        guard let index = projects.firstIndex(where: { $0.id == openProjectID }) else { return }
        guard let source = projects[index].levels.first(where: { $0.id == id }) else { return }
        pushUndo("duplicate the level")
        var copy = source
        copy.id = UUID()
        copy.name = source.name + " copy"
        var renamed: [UUID: UUID] = [:]
        copy.entities = source.entities.map { entity in
            var fresh = entity
            let newID = UUID()
            renamed[entity.id] = newID
            fresh.id = newID
            return fresh
        }
        copy.stickers = (source.stickers ?? []).map { sticker in
            var fresh = sticker
            fresh.id = UUID()
            if let old = sticker.entityID {
                fresh.entityID = renamed[old]
            }
            return fresh
        }
        copy.objectives = source.objectives.map { objective in
            var fresh = objective
            fresh.id = UUID()
            return fresh
        }
        copy.nextLevelID = nil
        let position = (projects[index].levels.firstIndex(where: { $0.id == id }) ?? 0) + 1
        projects[index].levels.insert(copy, at: position)
        projects[index].updatedAt = Date()
        selectedLevelID = copy.id
        selectedEntityID = copy.entities.first?.id
        scheduleSave()
    }

    func deleteLevel(_ id: UUID) {
        guard let project = currentProject, project.levels.count > 1 else { return }
        updateProject(undoLabel: "delete the level") { project in
            project.levels.removeAll { $0.id == id }
            for index in project.levels.indices {
                if project.levels[index].nextLevelID == id {
                    project.levels[index].nextLevelID = nil
                }
            }
        }
        sanitizeSelection()
    }

    // MARK: Entities

    func addEntity(_ kind: EntityKind) {
        addEntity(kind, at: BoardPoint(x: CGFloat.random(in: 0.22...0.78),
                                       y: CGFloat.random(in: 0.24...0.76)))
    }

    func addEntity(_ kind: EntityKind, at point: BoardPoint) {
        guard let level = currentLevel else { return }
        var created: UUID?
        updateLevel(level.id, undoLabel: "add \(kind.title.lowercased())") { level in
            var entity = LevelEntity(kind: kind, name: kind.defaultName)
            entity.position = BoardPoint(x: min(0.92, max(0.08, point.x)),
                                         y: min(0.92, max(0.08, point.y)))
            if kind == .platform {
                entity.platformEnd = BoardPoint(x: entity.position.x,
                                                y: max(0.08, entity.position.y - 0.14))
            }
            level.entities.append(entity)
            created = entity.id
        }
        selectedEntityID = created
        selectedSection = kind.section
    }

    /// Records an undo step on its own, for a gesture that is about to make
    /// many small changes (dragging, turning or resizing in 3D).
    func recordUndo(_ label: String) {
        pushUndo(label)
    }

    // MARK: Terrain

    /// One undo step per brush stroke, and the level gets its own heightmap
    /// the first time it is touched.
    func beginTerrainStroke() {
        guard let level = currentLevel else { return }
        recordUndo("shape the ground")
        if level.terrain == nil {
            updateLevel(level.id) { $0.terrain = TerrainData() }
        }
    }

    func paintTerrain(_ brush: TerrainBrush, from origin: SIMD2<Float>?, to point: SIMD2<Float>, radius: Float) {
        guard let id = currentLevel?.id else { return }
        updateLevel(id) { level in
            if level.terrain == nil { level.terrain = TerrainData() }

            guard let origin, !brush.isScatter else {
                level.terrain?.apply(brush, x: point.x, z: point.y, radius: radius)
                return
            }

            // Fill in the gaps between one touch and the next so a quick
            // stroke leaves an unbroken line.
            let dx = point.x - origin.x
            let dz = point.y - origin.y
            let distance = (dx * dx + dz * dz).squareRoot()
            let spacing = max(0.6, radius * 0.35)
            let steps = max(1, min(14, Int(distance / spacing)))
            for step in 1...steps {
                let t = Float(step) / Float(steps)
                level.terrain?.apply(brush, x: origin.x + dx * t, z: origin.y + dz * t, radius: radius)
            }
        }
    }

    // MARK: Stickers and textures

    func addSticker(_ kind: StickerKind, at point: BoardPoint) {
        guard let level = currentLevel else { return }
        var created: UUID?
        updateLevel(level.id, undoLabel: "add a sticker") { level in
            var sticker = Sticker()
            sticker.kind = kind.rawValue
            sticker.position = BoardPoint(x: min(0.96, max(0.04, point.x)),
                                          y: min(0.96, max(0.04, point.y)))
            sticker.rotation = Double.random(in: 0..<360).rounded()
            level.stickers = (level.stickers ?? []) + [sticker]
            created = sticker.id
        }
        selectedStickerID = created
    }

    func addSticker(_ kind: StickerKind, on entityID: UUID) {
        guard let level = currentLevel, let entity = level.entity(with: entityID) else { return }
        var created: UUID?
        updateLevel(level.id, undoLabel: "stick something on \(entity.name)") { level in
            var sticker = Sticker()
            sticker.kind = kind.rawValue
            sticker.size = 1.1
            sticker.entityID = entityID
            sticker.localY = 0.62
            sticker.localZ = 0.42
            sticker.rotation = Double.random(in: 0..<360).rounded()
            level.stickers = (level.stickers ?? []) + [sticker]
            created = sticker.id
        }
        selectedStickerID = created
    }

    func updateSticker(_ id: UUID, undoLabel: String? = nil, _ changes: (inout Sticker) -> Void) {
        guard let level = currentLevel else { return }
        updateLevel(level.id, undoLabel: undoLabel) { level in
            var list = level.stickers ?? []
            guard let index = list.firstIndex(where: { $0.id == id }) else { return }
            changes(&list[index])
            level.stickers = list
        }
    }

    func deleteSticker(_ id: UUID) {
        guard let level = currentLevel else { return }
        updateLevel(level.id, undoLabel: "remove a sticker") { level in
            level.stickers?.removeAll { $0.id == id }
        }
        if selectedStickerID == id {
            selectedStickerID = nil
        }
    }

    /// One undo step per texture stroke, and the level gets a heightmap to
    /// keep the paint in.
    func beginTextureStroke() {
        guard let level = currentLevel else { return }
        recordUndo("paint a texture")
        if level.terrain == nil {
            updateLevel(level.id) { $0.terrain = TerrainData() }
        }
    }

    func paintPattern(_ pattern: SurfacePattern, from origin: SIMD2<Float>?, to point: SIMD2<Float>, radius: Float) {
        guard let id = currentLevel?.id else { return }
        updateLevel(id) { level in
            if level.terrain == nil { level.terrain = TerrainData() }

            guard let origin else {
                level.terrain?.paintPattern(pattern.index, x: point.x, z: point.y, radius: radius)
                return
            }

            let dx = point.x - origin.x
            let dz = point.y - origin.y
            let distance = (dx * dx + dz * dz).squareRoot()
            let spacing = max(0.6, radius * 0.35)
            let steps = max(1, min(14, Int(distance / spacing)))
            for step in 1...steps {
                let t = Float(step) / Float(steps)
                level.terrain?.paintPattern(pattern.index,
                                             x: origin.x + dx * t,
                                             z: origin.y + dz * t,
                                             radius: radius)
            }
        }
    }

    /// Puts a texture on a single prop, so a barrel can look like planks
    /// without any modelling.
    func setSurfacePattern(_ pattern: SurfacePattern, for entityID: UUID) {
        guard let entity = currentLevel?.entity(with: entityID) else { return }
        guard (entity.surfacePattern ?? .bare) != pattern else { return }
        updateEntity(entityID, undoLabel: pattern == .bare ? "clean \(entity.name)" : "texture \(entity.name)") { entity in
            entity.texture = pattern == .bare ? nil : pattern.rawValue
        }
    }

    func deleteEntity(_ id: UUID) {
        guard let level = currentLevel else { return }
        let name = level.entity(with: id)?.name ?? "it"
        updateLevel(level.id, undoLabel: "delete \(name)") { level in
            level.entities.removeAll { $0.id == id }
            level.stickers?.removeAll { $0.entityID == id }
        }
        if selectedEntityID == id {
            selectedEntityID = currentLevel?.entities.first?.id
        }
    }

    func duplicateEntity(_ id: UUID) {
        guard let level = currentLevel, let source = level.entity(with: id) else { return }
        var created: UUID?
        updateLevel(level.id, undoLabel: "duplicate \(source.name)") { level in
            var copy = source
            copy.id = UUID()
            copy.name = source.name + " copy"
            copy.position = BoardPoint(x: min(0.94, source.position.x + 0.06),
                                       y: min(0.94, source.position.y + 0.06))
            level.entities.append(copy)
            created = copy.id
        }
        selectedEntityID = created
    }

    func moveEntity(_ id: UUID, to point: BoardPoint) {
        updateEntity(id) { entity in
            entity.position = BoardPoint(x: min(0.96, max(0.04, point.x)),
                                         y: min(0.94, max(0.08, point.y)))
        }
    }

    // MARK: Objectives

    func addObjective(text: String) {
        guard let level = currentLevel else { return }
        let trimmed = text.isEmpty ? "Reach the portal" : text
        updateLevel(level.id, undoLabel: "add a goal") { level in
            level.objectives.append(LevelObjective(text: trimmed))
        }
    }

    func deleteObjective(_ id: UUID) {
        guard let level = currentLevel else { return }
        updateLevel(level.id, undoLabel: "delete a goal") { level in
            level.objectives.removeAll { $0.id == id }
        }
    }

    func toggleObjectiveOptional(_ id: UUID) {
        guard let level = currentLevel else { return }
        updateLevel(level.id) { level in
            guard let index = level.objectives.firstIndex(where: { $0.id == id }) else { return }
            level.objectives[index].isOptional.toggle()
        }
    }

    // MARK: Rules

    func addCard(to entityID: UUID, whenKey: String, conditionKeys: [String], actionKeys: [String]) {
        updateEntity(entityID, undoLabel: "add a rule") { entity in
            let actions = actionKeys.map { key -> CardClause in
                var detail = ""
                if key == "say" { detail = "Hello there!" }
                if key == "showMessage" { detail = "Something happened!" }
                return CardClause(key: key, detail: detail)
            }
            let conditions = conditionKeys.map { CardClause(key: $0) }
            entity.cards.append(BehaviorCard(when: CardClause(key: whenKey),
                                             conditions: conditions,
                                             actions: actions))
        }
    }

    func addEmptyCard(to entityID: UUID) {
        updateEntity(entityID, undoLabel: "add a rule") { entity in
            entity.cards.append(BehaviorCard(when: CardClause(key: "levelStarts"),
                                             actions: [CardClause(key: "playSound", detail: "chime")]))
        }
    }

    func deleteCard(entityID: UUID, cardID: UUID) {
        updateEntity(entityID, undoLabel: "delete a rule") { entity in
            entity.cards.removeAll { $0.id == cardID }
        }
    }

    func apply(_ recipe: RuleRecipe) {
        guard let level = currentLevel else { return }
        var target = level.entities.first { recipe.kinds.contains($0.kind) }
        if let current = currentEntity, recipe.kinds.contains(current.kind) {
            target = current
        }
        guard let target else { return }
        addCard(to: target.id, whenKey: recipe.whenKey,
                conditionKeys: recipe.conditionKeys, actionKeys: recipe.actionKeys)
        selectedEntityID = target.id
        selectedTab = .logic
        toast = "Added “\(recipe.title)” to \(target.name)"
    }

    // MARK: Characters

    func addImportedCharacter(_ character: ImportedCharacter) {
        updateProject(undoLabel: "bring in a character") { project in
            var list = project.importedCharacters ?? []
            list.append(character)
            project.importedCharacters = list
            project.heroCharacterID = character.id
            project.heroBody = character.name
        }
    }

    func chooseHeroBody(_ body: String) {
        updateProject(undoLabel: "change the hero") { project in
            project.heroBody = body
            project.heroCharacterID = nil
        }
    }

    func chooseHeroCharacter(_ id: UUID) {
        updateProject(undoLabel: "change the hero") { project in
            project.heroCharacterID = id
            if let name = project.importedCharacters?.first(where: { $0.id == id })?.name {
                project.heroBody = name
            }
        }
    }

    // MARK: Actions

    func toggleAction(_ id: String) {
        updateProject(undoLabel: "change actions") { project in
            if project.enabledActions.contains(id) {
                project.enabledActions.remove(id)
            } else {
                project.enabledActions.insert(id)
            }
        }
    }

    func setAllActions(_ enabled: Bool) {
        updateProject(undoLabel: enabled ? "turn on every action" : "turn off every action") { project in
            project.enabledActions = enabled ? Set(ActionRegistry.all.map { $0.id }) : []
        }
    }

    func resetActions() {
        updateProject(undoLabel: "reset actions") { project in
            project.enabledActions = ActionRegistry.starter
        }
    }

    // MARK: Interface

    func addWidget(_ kind: WidgetKind) {
        var created: UUID?
        updateProject(undoLabel: "add a \(kind.title.lowercased())") { project in
            let sameKind = project.hud.widgets.filter { $0.kind == kind }.count
            let widget = HUDWidget.make(
                kind,
                anchor: .center,
                binding: kind.usesBinding ? "health" : "coins",
                fillHex: kind == .bar ? "#F2545B" : "#6C4CF1",
                label: kind.title,
                offsetY: CGFloat(sameKind) * 12
            )
            project.hud.widgets.append(widget)
            created = widget.id
        }
        selectedWidgetID = created
    }

    func deleteWidget(_ id: UUID) {
        updateProject(undoLabel: "delete a bar") { project in
            project.hud.widgets.removeAll { $0.id == id }
        }
        if selectedWidgetID == id {
            selectedWidgetID = currentProject?.hud.widgets.first?.id
        }
    }

    // MARK: Sharing

    func shareFileURL(for project: GameProject, sharedBy: String) -> URL? {
        GameSharing.temporaryFile(for: project, sharedBy: sharedBy)
    }

    @discardableResult
    func importSharedGame(from url: URL) -> Bool {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let shared = GameSharing.decode(text) else { return false }

        var project = shared.project
        project.id = UUID()
        project.createdAt = Date()
        project.updatedAt = Date()
        project.sharedBy = shared.sharedBy
        project.name = uniqueName(project.name)

        if var characters = project.importedCharacters {
            for index in characters.indices {
                let fileName = characters[index].fileName
                guard let file = shared.characters.first(where: { $0.fileName == fileName }) else { continue }
                let extensionName = (fileName as NSString).pathExtension
                let destination = CharacterStorage.destination(for: extensionName.isEmpty ? "usdz" : extensionName)
                do {
                    try file.data.write(to: destination, options: .atomic)
                    characters[index].fileName = destination.lastPathComponent
                } catch {
                    continue
                }
            }
            project.importedCharacters = characters
        }

        projects.insert(project, at: 0)
        saveNow()
        toast = "Added \(project.name), shared by \(shared.sharedBy)."
        return true
    }

    private func uniqueName(_ name: String) -> String {
        let existing = Set(projects.map { $0.name })
        guard existing.contains(name) else { return name }
        var index = 2
        while existing.contains("\(name) \(index)") { index += 1 }
        return "\(name) \(index)"
    }

    // MARK: Readiness

    func issues(for project: GameProject) -> [ReadinessIssue] {
        var found: [ReadinessIssue] = []

        if project.levels.isEmpty {
            found.append(ReadinessIssue(id: "nolevels", title: "No levels yet",
                                        detail: "A game needs at least one level.",
                                        symbol: "map.fill", isBlocking: true, tab: .world))
            return found
        }

        if project.levels.contains(where: { !$0.hasStart }) {
            found.append(ReadinessIssue(id: "nostart", title: "A level has no start",
                                        detail: "Every level needs a place to begin.",
                                        symbol: "flag.fill", isBlocking: true, tab: .world))
        }
        if project.levels.contains(where: { !$0.hasPortal }) {
            found.append(ReadinessIssue(id: "noportal", title: "A level has no portal",
                                        detail: "Without a portal the player cannot finish the level.",
                                        symbol: "sparkles", isBlocking: true, tab: .world))
        }
        if project.levels.contains(where: { !$0.canSwim }) {
            found.append(ReadinessIssue(id: "noswim", title: "Water you can't swim in",
                                        detail: "A level has swimming turned off, so the hero stops at the shore instead of paddling.",
                                        symbol: "drop.fill", isBlocking: false, tab: .world))
        }
        if project.levels.contains(where: { $0.objectives.isEmpty }) {
            found.append(ReadinessIssue(id: "nogoals", title: "A level has no goals",
                                        detail: "Add one thing to do so the player knows where to go.",
                                        symbol: "list.bullet", isBlocking: false, tab: .world))
        }
        if !project.enabledActions.contains("walk") || !project.enabledActions.contains("jump") {
            found.append(ReadinessIssue(id: "noactions", title: "The hero cannot get around",
                                        detail: "Turn on walking and jumping in Actions.",
                                        symbol: "figure.walk", isBlocking: true, tab: .actions))
        }
        if project.enabledActions.count < 4 {
            found.append(ReadinessIssue(id: "fewactions", title: "Only \(project.enabledActions.count) actions",
                                        detail: "A hero with more moves is more fun to play.",
                                        symbol: "figure.run", isBlocking: false, tab: .actions))
        }
        if !project.hud.widgets.contains(where: { $0.kind == .bar && $0.binding == "health" }) {
            found.append(ReadinessIssue(id: "nohealth", title: "No health bar",
                                        detail: "Add a health bar so the player knows how they are doing.",
                                        symbol: "heart.fill", isBlocking: false, tab: .interface))
        }
        if project.levels.contains(where: { ($0.audio?.mood ?? MusicMood.none) == MusicMood.none }) {
            found.append(ReadinessIssue(id: "nomusic", title: "A level has no music",
                                        detail: "Pick a mood so it doesn't play in silence.",
                                        symbol: "music.note", isBlocking: false, tab: .world))
        }

        let startPoint = BoardPoint(x: 0.12, y: 0.82)
        func distanceFromStart(_ point: BoardPoint) -> CGFloat {
            let dx = point.x - startPoint.x
            let dy = point.y - startPoint.y
            return (dx * dx + dy * dy).squareRoot()
        }
        for level in project.levels {
            let checkpoints = level.entities.filter { $0.kind == .checkpoint }
            let bosses = level.entities.filter { $0.kind == .baddie && $0.isBoss }
            guard !checkpoints.isEmpty, !bosses.isEmpty else { continue }

            let bossDistance = bosses.map { distanceFromStart($0.position) }.min() ?? 0
            let allPastTheBoss = checkpoints.allSatisfy { distanceFromStart($0.position) > bossDistance + 0.05 }
            if allPastTheBoss {
                found.append(ReadinessIssue(id: "checkpointpastboss",
                                            title: "The checkpoints are past the boss",
                                            detail: "Put one before the boss in \(level.name) so losing to it isn't a long walk back.",
                                            symbol: "flag.fill", isBlocking: false, tab: .cast))
                break
            }
        }
        let rules = project.levels.reduce(0) { total, level in
            total + level.entities.reduce(0) { $0 + $1.cards.count }
        }
        if rules == 0 {
            found.append(ReadinessIssue(id: "norules", title: "Nothing has a rule yet",
                                        detail: "Rules make things move, talk and open.",
                                        symbol: "arrow.triangle.branch", isBlocking: false, tab: .logic))
        }
        if project.levels.enumerated().contains(where: { index, level in
            index < project.levels.count - 1 && level.nextLevelID == nil
        }) {
            found.append(ReadinessIssue(id: "nolink", title: "A level has no next level",
                                        detail: "Link the portal to the level that follows.",
                                        symbol: "arrow.right", isBlocking: false, tab: .world))
        }
        return found
    }

    func issuesForCurrentLevel() -> [ReadinessIssue] {
        guard let project = currentProject else { return [] }
        return issues(for: project)
    }
}

// MARK: - Bindings

extension MakerStore {
    func projectBinding<T>(_ keyPath: WritableKeyPath<GameProject, T>, fallback: T) -> Binding<T> {
        Binding(
            get: { self.currentProject.map { $0[keyPath: keyPath] } ?? fallback },
            set: { newValue in
                self.updateProject { project in
                    project[keyPath: keyPath] = newValue
                }
            }
        )
    }

    func levelBinding<T>(_ keyPath: WritableKeyPath<GameLevel, T>, fallback: T) -> Binding<T> {
        Binding(
            get: { self.currentLevel.map { $0[keyPath: keyPath] } ?? fallback },
            set: { newValue in
                guard let id = self.currentLevel?.id else { return }
                self.updateLevel(id) { level in
                    level[keyPath: keyPath] = newValue
                }
            }
        )
    }

    func entityBinding<T>(_ keyPath: WritableKeyPath<LevelEntity, T>, fallback: T) -> Binding<T> {
        Binding(
            get: { self.currentEntity.map { $0[keyPath: keyPath] } ?? fallback },
            set: { newValue in
                guard let id = self.selectedEntityID else { return }
                self.updateEntity(id) { entity in
                    entity[keyPath: keyPath] = newValue
                }
            }
        )
    }

    func widgetBinding<T>(_ keyPath: WritableKeyPath<HUDWidget, T>, fallback: T) -> Binding<T> {
        Binding(
            get: { self.currentWidget.map { $0[keyPath: keyPath] } ?? fallback },
            set: { newValue in
                guard let id = self.selectedWidgetID else { return }
                self.updateWidget(id) { widget in
                    widget[keyPath: keyPath] = newValue
                }
            }
        )
    }
}
