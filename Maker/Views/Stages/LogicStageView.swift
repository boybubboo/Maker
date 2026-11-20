//
//  LogicStageView.swift
//  Maker
//
//  The Logic tab: when something happens, if it is allowed, then do
//  these things. Read back as a sentence so nobody has to read code.
//

import SwiftUI

struct LogicStageView: View {
    var body: some View {
        StageScaffold {
            LogicSidebar()
        } content: {
            LogicContent()
        } inspector: {
            LogicInspector()
        }
    }
}

// MARK: - Sidebar

private struct LogicSidebar: View {
    @EnvironmentObject private var store: MakerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rules in this level")
                .font(.headline)

            if let level = store.currentLevel {
                if level.entities.isEmpty {
                    Text("Add something in the Cast tab and it will show up here.")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                } else {
                    ForEach(level.entities) { entity in
                        let selected = entity.id == store.selectedEntityID
                        Button {
                            store.selectedEntityID = entity.id
                        } label: {
                            HStack(spacing: 10) {
                                IconBadge(symbol: entity.kind.symbol, tint: entity.kind.tint, size: 32)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(entity.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Palette.ink)
                                        .lineLimit(1)
                                    Text("\(entity.cards.count) rule\(entity.cards.count == 1 ? "" : "s")")
                                        .font(.caption2)
                                        .foregroundStyle(Palette.inkSoft)
                                }
                                Spacer(minLength: 0)
                                if entity.cards.isEmpty {
                                    Image(systemName: "circle.dashed")
                                        .font(.caption2)
                                        .foregroundStyle(Palette.inkFaint)
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
                }

                Divider()

                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(Palette.amber)
                    Text("A rule is always: when, if, then.")
                        .font(.caption2)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
        }
    }
}

// MARK: - Content

private struct LogicContent: View {
    @EnvironmentObject private var store: MakerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let entity = store.currentEntity {
                header(entity)
                recipeShelf(entity)
                if entity.cards.isEmpty {
                    EmptyHint(
                        symbol: "arrow.triangle.branch",
                        title: "\(entity.name) does nothing yet",
                        message: "Pick a recipe above, or write a rule from scratch.",
                        actionTitle: "Write a rule"
                    ) {
                        store.addEmptyCard(to: entity.id)
                    }
                    .makerCard()
                } else {
                    ForEach(Array(entity.cards.enumerated()), id: \.element.id) { index, card in
                        RuleCardEditor(entity: entity, card: card, number: index + 1)
                    }
                }

                Button {
                    store.addEmptyCard(to: entity.id)
                } label: {
                    Label("Add another rule", systemImage: "plus")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Palette.plum.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(Palette.plum)
                }
                .buttonStyle(.plain)
            } else {
                EmptyHint(
                    symbol: "arrow.triangle.branch",
                    title: "Pick something to give a rule",
                    message: "Choose anything in the list on the left: a baddie, a door, a chest, a trap."
                )
                .makerCard()
            }
        }
    }

    private func header(_ entity: LevelEntity) -> some View {
        HStack(spacing: 12) {
            IconBadge(symbol: entity.kind.symbol, tint: entity.kind.tint, size: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text(entity.name)
                    .font(.title3.bold())
                Text("\(entity.kind.title) · \(entity.cards.count) rule\(entity.cards.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
            MenuChip(title: "Another thing", symbol: "arrow.triangle.branch", tint: Palette.inkSoft) {
                if let level = store.currentLevel {
                    ForEach(level.entities) { other in
                        Button {
                            store.selectedEntityID = other.id
                        } label: {
                            Label(other.name, systemImage: other.kind.symbol)
                        }
                    }
                }
            }
        }
        .makerCard()
    }

    private func recipeShelf(_ entity: LevelEntity) -> some View {
        let recipes = RecipeLibrary.recipes(for: entity.kind).isEmpty
            ? Array(RecipeLibrary.all.prefix(4))
            : RecipeLibrary.recipes(for: entity.kind)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ready-made rules")
                    .font(.headline)
                Spacer()
                Text("One tap")
                    .font(.caption2)
                    .foregroundStyle(Palette.inkSoft)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recipes) { recipe in
                        Button {
                            store.apply(recipe)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                IconBadge(symbol: recipe.symbol, tint: Palette.plum, size: 34)
                                Text(recipe.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Palette.ink)
                                    .lineLimit(1)
                                Text(recipe.blurb)
                                    .font(.caption2)
                                    .foregroundStyle(Palette.inkSoft)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(11)
                            .frame(width: 168, height: 132, alignment: .topLeading)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Palette.hairline.opacity(0.4), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - One rule

private struct RuleCardEditor: View {
    @EnvironmentObject private var store: MakerStore
    let entity: LevelEntity
    let card: BehaviorCard
    let number: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(number)")
                    .font(.caption.bold().monospacedDigit())
                    .frame(width: 22, height: 22)
                    .background(Palette.plum.opacity(0.16), in: Circle())
                    .foregroundStyle(Palette.plum)

                Text(RuleSentence.text(for: card))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Toggle("", isOn: enabledBinding)
                    .labelsHidden()
                    .tint(Palette.plum)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                label("WHEN", tint: Palette.sky)
                ClauseRow(kind: .whenCase,
                          clause: card.when,
                          onPick: { key in change { $0.when.key = key } },
                          onDetail: { text in change { $0.when.detail = text } },
                          onRemove: nil)

                HStack {
                    label("IF", tint: Palette.amber)
                    Spacer()
                    Button {
                        change { $0.conditions.append(CardClause(key: "playerClose", detail: "")) }
                    } label: {
                        Text("+ add")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Palette.amber)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(card.conditions) { clause in
                    ClauseRow(kind: .condition,
                              clause: clause,
                              onPick: { key in updateCondition(clause.id) { $0.key = key } },
                              onDetail: { text in updateCondition(clause.id) { $0.detail = text } },
                              onRemove: { change { $0.conditions.removeAll { $0.id == clause.id } } })
                }

                if card.conditions.isEmpty {
                    Text("Always.")
                        .font(.caption2)
                        .foregroundStyle(Palette.inkFaint)
                }

                HStack {
                    label("THEN", tint: Palette.mint)
                    Spacer()
                    Button {
                        change { $0.actions.append(CardClause(key: "playSound", detail: "chime")) }
                    } label: {
                        Text("+ add")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Palette.mint)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(card.actions) { clause in
                    ClauseRow(kind: .action,
                              clause: clause,
                              onPick: { key in updateAction(clause.id) { $0.key = key } },
                              onDetail: { text in updateAction(clause.id) { $0.detail = text } },
                              onRemove: { change { $0.actions.removeAll { $0.id == clause.id } } })
                }

                if card.actions.isEmpty {
                    Text("Nothing yet — this rule will not do anything.")
                        .font(.caption2)
                        .foregroundStyle(Palette.coral)
                }
            }

            Divider()

            HStack {
                Toggle(isOn: onceBinding) {
                    Text("Only the first time")
                        .font(.caption.weight(.semibold))
                }
                .tint(Palette.plum)

                Spacer()

                Button(role: .destructive) {
                    store.deleteCard(entityID: entity.id, cardID: card.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.coral)
                }
                .buttonStyle(.plain)
            }
        }
        .makerCard()
    }

    private func label(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black))
            .kerning(0.8)
            .foregroundStyle(tint)
            .frame(width: 44, alignment: .leading)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { card.isEnabled },
            set: { value in change { $0.isEnabled = value } }
        )
    }

    private var onceBinding: Binding<Bool> {
        Binding(
            get: { card.isOnce },
            set: { value in change { $0.isOnce = value } }
        )
    }

    private func change(_ mutate: @escaping (inout BehaviorCard) -> Void) {
        store.updateCard(entityID: entity.id, cardID: card.id, undoLabel: "change a rule") { current in
            mutate(&current)
        }
    }

    private func updateCondition(_ id: UUID, _ mutate: @escaping (inout CardClause) -> Void) {
        change { current in
            if let index = current.conditions.firstIndex(where: { $0.id == id }) {
                mutate(&current.conditions[index])
            }
        }
    }

    private func updateAction(_ id: UUID, _ mutate: @escaping (inout CardClause) -> Void) {
        change { current in
            if let index = current.actions.firstIndex(where: { $0.id == id }) {
                mutate(&current.actions[index])
            }
        }
    }
}

private enum ClauseKind {
    case whenCase, condition, action

    var options: [Clause] {
        switch self {
        case .whenCase: return BehaviorVocabulary.events
        case .condition: return BehaviorVocabulary.conditions
        case .action: return BehaviorVocabulary.actions
        }
    }

    var tint: Color {
        switch self {
        case .whenCase: return Palette.sky
        case .condition: return Palette.amber
        case .action: return Palette.mint
        }
    }
}

private struct ClauseRow: View {
    let kind: ClauseKind
    let clause: CardClause
    let onPick: (String) -> Void
    let onDetail: (String) -> Void
    let onRemove: (() -> Void)?

    private var selected: Clause? {
        kind.options.first { $0.key == clause.key }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: selected?.symbol ?? "circle")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(kind.tint)
                .frame(width: 18)

            Menu {
                ForEach(kind.options) { option in
                    Button {
                        onPick(option.key)
                    } label: {
                        Label(option.label, systemImage: option.symbol)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selected?.label ?? "Choose…")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.leading)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(Palette.inkFaint)
                }
            }

            Spacer(minLength: 4)

            if selected?.needsDetail == true {
                TextField(selected?.detailHint ?? "detail",
                          text: Binding(get: { clause.detail }, set: onDetail))
                    .font(.caption)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: 128)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Palette.surfaceAlt, in: Capsule())
            }

            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(Palette.inkFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Inspector

private struct LogicInspector: View {
    @EnvironmentObject private var store: MakerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How rules work")
                .font(.headline)

            step(number: "1", tint: Palette.sky, title: "When",
                 text: "Pick the thing that starts the rule, like touching the player.")
            step(number: "2", tint: Palette.amber, title: "If",
                 text: "Optional. Only do it when something is true, like having a key.")
            step(number: "3", tint: Palette.mint, title: "Then",
                 text: "What happens, in order. Up to six things.")

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(text: "In this level")
                let rules = store.currentLevel?.entities.reduce(0) { $0 + $1.cards.count } ?? 0
                Text("\(rules) rule\(rules == 1 ? "" : "s") across \(store.currentLevel?.entities.count ?? 0) things")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }

            Divider()

            HStack(spacing: 7) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(Palette.amber)
                Text("A rule that does nothing is greyed out next to its name.")
                    .font(.caption2)
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private func step(number: String, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text(number)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(tint, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
