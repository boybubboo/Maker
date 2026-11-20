//
//  CastStageView.swift
//  Maker
//
//  The Cast tab: everything that lives in the level, and how it fights,
//  talks, opens or hides.
//

import SwiftUI

struct CastStageView: View {
    var body: some View {
        StageScaffold {
            CastSidebar()
        } content: {
            CastContent()
        } inspector: {
            CastInspector()
        }
    }
}

// MARK: - Sidebar

private struct CastSidebar: View {
    @EnvironmentObject private var store: MakerStore
    @State private var showingAdd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("What is here")
                    .font(.headline)
                Spacer()
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add something")
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(EntitySection.allCases) { section in
                    Button {
                        store.selectedSection = section
                        store.selectedEntityID = store.currentLevel?.entities(in: section).first?.id
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: section.symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(store.selectedSection == section ? Palette.accent : Palette.inkSoft)
                            Text(section.title)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            Text("\(store.currentLevel?.entities(in: section).count ?? 0)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Palette.inkSoft)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(store.selectedSection == section ? Palette.accent.opacity(0.14) : Palette.surfaceAlt)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(store.selectedSection == section ? Palette.accent : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            Text(store.selectedSection.title)
                .font(.subheadline.bold())

            if let level = store.currentLevel {
                let entities = level.entities(in: store.selectedSection)
                if entities.isEmpty {
                    Text("Nothing here yet.")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                } else {
                    ForEach(entities) { entity in
                        entityRow(entity)
                    }
                }
            }

            Button {
                showingAdd = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "plus").font(.caption.weight(.bold))
                    Text("Add something").font(.caption.weight(.bold))
                }
                .foregroundStyle(Palette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Palette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingAdd) {
            AddEntitySheet()
                .environmentObject(store)
        }
    }

    private func entityRow(_ entity: LevelEntity) -> some View {
        let selected = entity.id == store.selectedEntityID
        return Button {
            store.selectedEntityID = entity.id
        } label: {
            HStack(spacing: 10) {
                IconBadge(symbol: entity.kind.symbol, tint: entity.kind.tint, size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entity.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text(subtitle(for: entity))
                        .font(.caption2)
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if !entity.cards.isEmpty {
                    Text("\(entity.cards.count)")
                        .font(.caption2.bold())
                        .foregroundStyle(Palette.plum)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Palette.plum.opacity(0.14), in: Capsule())
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Palette.accent.opacity(0.12) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Palette.accent.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func subtitle(for entity: LevelEntity) -> String {
        switch entity.kind {
        case .baddie:
            return entity.isBoss ? "Boss · \(entity.health) health" : "\(entity.brain) · \(entity.health) health"
        case .npc:
            return "Lives here · \(entity.cards.count) rules"
        case .treasure:
            return "Gives \(entity.loot.lowercased())"
        case .puzzle:
            return entity.puzzleType
        case .trap:
            return "Hurts on touch"
        default:
            return entity.kind.title
        }
    }
}

// MARK: - Content

private struct CastContent: View {
    @EnvironmentObject private var store: MakerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if store.selectedSection == .cast {
                HeroCard()
            }

            if let entity = store.currentEntity, entity.kind.section == store.selectedSection {
                EntityEditor(entity: entity)
            } else {
                SectionPickerGrid()
            }
        }
    }
}

private struct HeroCard: View {
    @EnvironmentObject private var store: MakerStore
    @State private var showingImport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IconBadge(symbol: "figure.stand", tint: Palette.accent, size: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text("The hero")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.inkSoft)
                    TextField("Hero name", text: store.projectBinding(\.heroName, fallback: "Pip"))
                        .font(.title3.bold())
                        .textFieldStyle(.plain)
                }
                Spacer(minLength: 0)
                MenuChip(title: store.currentProject?.heroBody ?? "Adventurer",
                         symbol: "person.fill",
                         tint: Palette.accent) {
                    ForEach(PresetLibrary.heroBodies, id: \.self) { body in
                        Button {
                            store.chooseHeroBody(body)
                        } label: {
                            Label(body, systemImage: store.currentProject?.heroCharacterID == nil && store.currentProject?.heroBody == body ? "checkmark" : "person.fill")
                        }
                    }
                    if let characters = store.currentProject?.importedCharacters, !characters.isEmpty {
                        Divider()
                        ForEach(characters) { character in
                            Button {
                                store.chooseHeroCharacter(character.id)
                            } label: {
                                Label(character.name, systemImage: store.currentProject?.heroCharacterID == character.id ? "checkmark" : "cube.fill")
                            }
                        }
                    }
                    Divider()
                    Button {
                        showingImport = true
                    } label: {
                        Label("Bring in a character…", systemImage: "square.and.arrow.down")
                    }
                }
            }

            Text("Only one hero in a game. Their moves live in the Actions tab.")
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)

            HStack(spacing: 8) {
                Button {
                    store.selectedTab = .actions
                } label: {
                    Label("Change their moves", systemImage: "figure.run")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Palette.amber.opacity(0.16), in: Capsule())
                        .foregroundStyle(Color(hex: "#A85A00"))
                }
                .buttonStyle(.plain)

                Button {
                    showingImport = true
                } label: {
                    Label("Bring in a character", systemImage: "square.and.arrow.down")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Palette.accent.opacity(0.14), in: Capsule())
                        .foregroundStyle(Palette.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .makerCard()
        .sheet(isPresented: $showingImport) {
            CharacterImportSheet()
                .environmentObject(store)
        }
    }
}

private struct SectionPickerGrid: View {
    @EnvironmentObject private var store: MakerStore
    @State private var showingAdd = false

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: 12)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(store.selectedSection.title)
                    .font(.title3.bold())
                Spacer()
                Button {
                    showingAdd = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Palette.accent.opacity(0.13), in: Capsule())
                        .foregroundStyle(Palette.accent)
                }
                .buttonStyle(.plain)
            }

            Text(store.selectedSection.blurb)
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)

            if let level = store.currentLevel, !level.entities(in: store.selectedSection).isEmpty {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(level.entities(in: store.selectedSection)) { entity in
                        Button {
                            store.selectedEntityID = entity.id
                        } label: {
                            EntityTile(entity: entity)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                EmptyHint(
                    symbol: store.selectedSection.symbol,
                    title: "Nothing in \(store.selectedSection.title.lowercased()) yet",
                    message: store.selectedSection.blurb,
                    actionTitle: "Add something"
                ) {
                    showingAdd = true
                }
                .makerCard()
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddEntitySheet()
                .environmentObject(store)
        }
    }
}

private struct EntityTile: View {
    let entity: LevelEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                IconBadge(symbol: entity.kind.symbol, tint: entity.kind.tint, size: 38)
                Spacer()
                if !entity.cards.isEmpty {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Palette.plum)
                }
            }
            Text(entity.name)
                .font(.subheadline.bold())
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Text(entity.kind.title)
                .font(.caption2)
                .foregroundStyle(Palette.inkSoft)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Palette.hairline.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Editor

private struct EntityEditor: View {
    @EnvironmentObject private var store: MakerStore
    let entity: LevelEntity
    @State private var showingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if entity.kind.usesStats { statsCard }
            if entity.kind == .treasure { optionCard(title: "What is inside",
                                                    symbol: "gift.fill",
                                                    tint: Palette.gold,
                                                    options: PresetLibrary.loot,
                                                    selection: entity.loot,
                                                    keyPath: \.loot) }
            if entity.kind == .puzzle { optionCard(title: "What kind of puzzle",
                                                  symbol: "square.grid.2x2.fill",
                                                  tint: Palette.plum,
                                                  options: PresetLibrary.puzzles,
                                                  selection: entity.puzzleType,
                                                  keyPath: \.puzzleType) }
            if entity.kind == .npc { npcCard }
            if entity.kind == .platform { platformCard }
            rulesCard
            notesCard
        }
        .confirmationDialog("Delete \(entity.name)?", isPresented: $showingDelete, titleVisibility: .visible) {
            Button("Delete it", role: .destructive) { store.deleteEntity(entity.id) }
            Button("Keep it", role: .cancel) { }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                IconBadge(symbol: entity.kind.symbol, tint: entity.kind.tint, size: 54)

                VStack(alignment: .leading, spacing: 3) {
                    TextField("Name", text: store.entityBinding(\.name, fallback: entity.name))
                        .font(.title3.bold())
                        .textFieldStyle(.plain)
                    HStack(spacing: 6) {
                        Pill(text: entity.kind.title, symbol: entity.kind.symbol, tint: entity.kind.tint)
                        if entity.isBoss {
                            Pill(text: "Boss", symbol: "crown.fill", tint: Palette.amber)
                        }
                    }
                }

                Spacer(minLength: 0)

                Menu {
                    Button {
                        store.duplicateEntity(entity.id)
                    } label: {
                        Label("Make a copy", systemImage: "plus.square.on.square")
                    }
                    Button {
                        store.selectedTab = .logic
                    } label: {
                        Label("Give it a rule", systemImage: "arrow.triangle.branch")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showingDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .foregroundStyle(Palette.inkSoft)
                        .frame(width: 34, height: 34)
                        .background(Palette.surfaceAlt, in: Circle())
                }
            }
        }
        .makerCard()
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("How it fights")
                    .font(.headline)
                Spacer()
                MenuChip(title: entity.brain, symbol: "bolt.fill", tint: Palette.plum) {
                    ForEach(PresetLibrary.brains, id: \.self) { brain in
                        Button(brain) {
                            store.updateEntity(entity.id, undoLabel: "change how it moves") { $0.brain = brain }
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: 14) {
                StepperControl(title: "Health",
                               symbol: "heart.fill",
                               value: store.entityBinding(\.health, fallback: 3),
                               range: 1...30,
                               tint: Palette.coral)
                StepperControl(title: "Speed",
                               symbol: "hare.fill",
                               value: store.entityBinding(\.speed, fallback: 3),
                               range: 1...10,
                               tint: Palette.mint)
                StepperControl(title: "Hit",
                               symbol: "flame.fill",
                               value: store.entityBinding(\.damage, fallback: 1),
                               range: 0...10,
                               tint: Palette.amber)
            }

            SwitchRow(title: "Boss",
                      subtitle: "Gets a big health bar across the screen.",
                      symbol: "crown.fill",
                      tint: Palette.gold,
                      isOn: store.entityBinding(\.isBoss, fallback: false))
        }
        .makerCard()
    }

    private func optionCard(
        title: String,
        symbol: String,
        tint: Color,
        options: [String],
        selection: String,
        keyPath: WritableKeyPath<LevelEntity, String>
    ) -> some View {
        HStack(spacing: 12) {
            IconBadge(symbol: symbol, tint: tint, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.inkSoft)
                Text(selection)
                    .font(.subheadline.bold())
            }
            Spacer(minLength: 0)
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        store.updateEntity(entity.id) { $0[keyPath: keyPath] = option }
                    }
                }
            } label: {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .padding(9)
                    .background(tint.opacity(0.14), in: Circle())
            }
        }
        .makerCard()
    }

    private var npcCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.sky)
                FieldLabel(text: "Talking to \(entity.name)")
            }

            TextField("Hello there, traveller!",
                      text: store.entityBinding(\.dialogue, fallback: ""),
                      axis: .vertical)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .lineLimit(2...3)

            Text("The quick line, used when they have no conversation below.")
                .font(.caption2)
                .foregroundStyle(Palette.inkFaint)

            Divider()

            questSection

            Divider()

            conversationSection
        }
        .makerCard()
    }

    @ViewBuilder
    private var questSection: some View {
        if entity.quest != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Their quest")
                        .font(.headline)
                    Spacer()
                    Button(role: .destructive) {
                        store.updateEntity(entity.id, undoLabel: "remove a quest") { $0.quest = nil }
                    } label: {
                        Text("Remove")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.coral)
                    }
                    .buttonStyle(.plain)
                }

                TextField("Quest title", text: Binding(
                    get: { entity.quest?.title ?? "" },
                    set: { value in store.updateEntity(entity.id) { $0.quest?.title = value } }
                ))
                .font(.headline)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                ForEach(entity.quest?.steps ?? []) { step in
                    HStack(spacing: 8) {
                        TextField("A step", text: Binding(
                            get: { step.text },
                            set: { value in
                                store.updateEntity(entity.id) { current in
                                    if let index = current.quest?.steps.firstIndex(where: { $0.id == step.id }) {
                                        current.quest?.steps[index].text = value
                                    }
                                }
                            }
                        ))
                        .font(.subheadline)
                        .textFieldStyle(.plain)

                        MenuChip(title: step.trigger.title, symbol: step.trigger.symbol, tint: Palette.plum) {
                            ForEach(QuestStepTrigger.allCases) { trigger in
                                Button {
                                    store.updateEntity(entity.id) { current in
                                        if let index = current.quest?.steps.firstIndex(where: { $0.id == step.id }) {
                                            current.quest?.steps[index].trigger = trigger
                                        }
                                    }
                                } label: {
                                    Label(trigger.title, systemImage: trigger.symbol)
                                }
                            }
                        }

                        Button {
                            store.updateEntity(entity.id, undoLabel: "remove a step") { current in
                                current.quest?.steps.removeAll { $0.id == step.id }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Palette.inkFaint)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    store.updateEntity(entity.id, undoLabel: "add a step") { current in
                        if current.quest == nil { current.quest = Quest() }
                        current.quest?.steps.append(QuestStep())
                    }
                } label: {
                    Label("Add a step", systemImage: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.plum)
                }
                .buttonStyle(.plain)

                Divider()

                StepperControl(title: "Coins",
                               symbol: "circle.fill",
                               value: Binding(
                                   get: { entity.quest?.rewardCoins ?? 0 },
                                   set: { value in store.updateEntity(entity.id) { $0.quest?.rewardCoins = value } }
                               ),
                               range: 0...99,
                               tint: Palette.gold)

                SwitchRow(title: "Also gives a key",
                          subtitle: "As part of the reward.",
                          symbol: "key.fill",
                          tint: Palette.amber,
                          isOn: Binding(
                              get: { entity.quest?.rewardKey ?? false },
                              set: { value in store.updateEntity(entity.id) { $0.quest?.rewardKey = value } }
                          ))
            }
            .padding(.top, 2)
        } else {
            Button {
                store.updateEntity(entity.id, undoLabel: "give a quest") { current in
                    current.quest = Quest(title: "A new quest",
                                          steps: [QuestStep(text: "Find the key", trigger: .foundKey)])
                }
            } label: {
                Label("Give them a quest", systemImage: "exclamationmark.bubble.fill")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Palette.plum.opacity(0.14), in: Capsule())
                    .foregroundStyle(Palette.plum)
            }
            .buttonStyle(.plain)
        }
    }

    private var conversationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("A conversation")
                    .font(.headline)
                Spacer()
                Text("\(entity.conversation.count) line\(entity.conversation.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(Palette.inkSoft)
            }

            ForEach(entity.conversation) { line in
                conversationLineCard(line)
            }

            Button {
                store.updateEntity(entity.id, undoLabel: "add a line") { current in
                    current.conversation.append(ConversationLine(isHero: false, words: "", replies: []))
                }
            } label: {
                Label("Add a line", systemImage: "plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.sky)
            }
            .buttonStyle(.plain)
        }
    }

    private func conversationLineCard(_ line: ConversationLine) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(line.isHero ? Palette.accent : Palette.sky)
                        .frame(width: 28, height: 28)
                    Image(systemName: line.isHero ? "figure.stand" : "bubble.left.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }

                MenuChip(title: line.isHero ? "The hero" : entity.name,
                         symbol: "person.fill",
                         tint: line.isHero ? Palette.accent : Palette.sky) {
                    Button("\(entity.name)") { updateLine(line.id) { $0.isHero = false } }
                    Button("The hero") { updateLine(line.id) { $0.isHero = true } }
                }

                Spacer(minLength: 0)

                Button {
                    store.updateEntity(entity.id, undoLabel: "remove a line") { current in
                        current.conversation.removeAll { $0.id == line.id }
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.coral)
                }
                .buttonStyle(.plain)
            }

            TextField("What they say", text: Binding(
                get: { line.words },
                set: { value in updateLine(line.id) { $0.words = value } }
            ), axis: .vertical)
            .font(.subheadline)
            .textFieldStyle(.plain)
            .lineLimit(1...3)
            .padding(9)
            .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            ForEach(Array(line.replies.enumerated()), id: \.offset) { index, reply in
                HStack(spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption2)
                        .foregroundStyle(Palette.inkFaint)

                    TextField("A reply the player can pick", text: Binding(
                        get: { reply },
                        set: { value in
                            updateLine(line.id) { current in
                                if index < current.replies.count { current.replies[index] = value }
                            }
                        }
                    ))
                    .font(.caption)
                    .textFieldStyle(.plain)

                    Button {
                        updateLine(line.id) { current in
                            if index < current.replies.count { current.replies.remove(at: index) }
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Palette.inkFaint)
                    }
                    .buttonStyle(.plain)
                }
            }

            if line.replies.count < 3 {
                Button {
                    updateLine(line.id) { $0.replies.append("") }
                } label: {
                    Label("Add a reply", systemImage: "plus")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Palette.sky)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Palette.surfaceAlt.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func updateLine(_ id: UUID, _ change: @escaping (inout ConversationLine) -> Void) {
        store.updateEntity(entity.id) { current in
            if let index = current.conversation.firstIndex(where: { $0.id == id }) {
                change(&current.conversation[index])
            }
        }
    }

    private var platformCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("How it moves")
                    .font(.headline)
                Spacer()
                MenuChip(title: PlatformMotion.title(for: entity.platformPreset),
                         symbol: "arrow.left.and.right",
                         tint: Palette.sky) {
                    ForEach(PlatformMotion.presets, id: \.id) { preset in
                        Button {
                            store.updateEntity(entity.id, undoLabel: "change the platform") { current in
                                current.platformPreset = preset.id
                                switch preset.id {
                                case "spinningDisc":
                                    current.platformMotion = "spin"
                                    current.platformSpeed = 1.0
                                    current.platformWait = 0
                                case "swingingBridge":
                                    current.platformMotion = "slide"
                                    current.platformSpeed = 0.8
                                    current.platformWait = 0.5
                                default:
                                    current.platformMotion = "slide"
                                    current.platformSpeed = 1.0
                                    current.platformWait = 1.4
                                }
                            }
                        } label: {
                            Label(preset.title,
                                  systemImage: preset.id == entity.platformPreset ? "checkmark" : "square")
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Text(PlatformMotion.isSpin(entity.platformMotion) ? "Spin" : "Speed")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.inkSoft)
                    .frame(width: 48, alignment: .leading)
                Slider(value: store.entityBinding(\.platformSpeed, fallback: 1), in: 0.3...3)
                    .tint(Palette.sky)
                Text(String(format: "%.1f", entity.platformSpeed))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.inkSoft)
            }

            if !PlatformMotion.isSpin(entity.platformMotion) {
                HStack(spacing: 8) {
                    Text("Wait")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(width: 48, alignment: .leading)
                    Slider(value: store.entityBinding(\.platformWait, fallback: 1), in: 0...3)
                        .tint(Palette.sky)
                    Text(String(format: "%.1f s", entity.platformWait))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Palette.inkSoft)
                }
            }

            SwitchRow(title: "Starts moving",
                      subtitle: "Rules can start and stop it as well.",
                      symbol: "play.fill",
                      tint: Palette.mint,
                      isOn: store.entityBinding(\.platformRunning, fallback: true))

            Text(PlatformMotion.isSpin(entity.platformMotion)
                 ? "It turns on the spot, so there is no end point to place."
                 : "Drag the gold ring in the viewport to choose where it travels to.")
                .font(.caption2)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .makerCard()
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("What it does")
                    .font(.headline)
                Spacer()
                Menu {
                    Button {
                        store.addEmptyCard(to: entity.id)
                    } label: {
                        Label("A blank rule", systemImage: "plus")
                    }
                    Divider()
                    ForEach(RecipeLibrary.recipes(for: entity.kind)) { recipe in
                        Button {
                            store.apply(recipe)
                        } label: {
                            Label(recipe.title, systemImage: recipe.symbol)
                        }
                    }
                } label: {
                    Label("Add rule", systemImage: "plus")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Palette.plum.opacity(0.14), in: Capsule())
                        .foregroundStyle(Palette.plum)
                }
            }

            if entity.cards.isEmpty {
                Text("No rules yet. A rule says when something happens, then what to do.")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            } else {
                ForEach(entity.cards) { card in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(RuleSentence.text(for: card))
                            .font(.caption)
                            .foregroundStyle(Palette.ink)
                        HStack(spacing: 6) {
                            if card.isOnce {
                                Pill(text: "only once", symbol: "1.circle.fill", tint: Palette.inkSoft)
                            }
                            Spacer()
                            Button {
                                store.selectedTab = .logic
                            } label: {
                                Text("Edit")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Palette.plum)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .makerCard()
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: "Notes")
            TextField("Anything you want to remember about this one.",
                      text: store.entityBinding(\.notes, fallback: ""),
                      axis: .vertical)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
        }
        .makerCard()
    }
}

// MARK: - Inspector

private struct CastInspector: View {
    @EnvironmentObject private var store: MakerStore
    @State private var showingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let entity = store.currentEntity {
                Text("About this \(entity.kind.title.lowercased())")
                    .font(.headline)

                HStack(spacing: 8) {
                    IconBadge(symbol: entity.kind.symbol, tint: entity.kind.tint, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entity.name)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        Text(entity.kind.title)
                            .font(.caption2)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Spacer(minLength: 0)
                }

                if entity.kind.usesStats {
                    VStack(alignment: .leading, spacing: 6) {
                        FieldLabel(text: "How tough")
                        HStack(spacing: 3) {
                            ForEach(0..<10, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(index < danger ? Palette.coral : Palette.surfaceAlt)
                                    .frame(height: 9)
                            }
                        }
                        Text(dangerText)
                            .font(.caption2)
                            .foregroundStyle(Palette.inkSoft)
                    }

                    HStack(spacing: 8) {
                        Button {
                            store.updateEntity(entity.id, undoLabel: "make it gentler") { current in
                                current.health = max(1, current.health - 1)
                                current.damage = max(0, current.damage - 1)
                            }
                        } label: {
                            Text("Gentler")
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Palette.mint.opacity(0.15), in: Capsule())
                                .foregroundStyle(Color(hex: "#137B4E"))
                        }
                        .buttonStyle(.plain)

                        Button {
                            store.updateEntity(entity.id, undoLabel: "make it meaner") { current in
                                current.health = min(30, current.health + 1)
                                current.damage = min(10, current.damage + 1)
                            }
                        } label: {
                            Text("Meaner")
                                .font(.caption.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Palette.coral.opacity(0.15), in: Capsule())
                                .foregroundStyle(Palette.coral)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Rules")
                    Text("\(entity.cards.count) rule\(entity.cards.count == 1 ? "" : "s")")
                        .font(.subheadline.weight(.semibold))
                    Button {
                        store.selectedTab = .logic
                    } label: {
                        Text("Open Logic")
                            .font(.caption.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Palette.plum.opacity(0.14), in: Capsule())
                            .foregroundStyle(Palette.plum)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                Button(role: .destructive) {
                    showingDelete = true
                } label: {
                    Label("Delete this", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                }
                .confirmationDialog("Delete \(entity.name)?", isPresented: $showingDelete, titleVisibility: .visible) {
                    Button("Delete it", role: .destructive) { store.deleteEntity(entity.id) }
                    Button("Keep it", role: .cancel) { }
                }
            } else {
                Text("Nothing selected")
                    .font(.headline)
                Text("Pick something in the list to change how it looks, fights or talks.")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private var danger: Int {
        guard let entity = store.currentEntity else { return 0 }
        let raw = entity.health + entity.damage * 2 + (entity.isBoss ? 5 : 0)
        return min(10, max(1, raw))
    }

    private var dangerText: String {
        switch danger {
        case 0...2: return "Gentle — good for a first level."
        case 3...5: return "A fair fight."
        case 6...8: return "Tricky. Bring a sword."
        default: return "Boss material."
        }
    }
}
