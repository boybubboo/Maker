//
//  ActionsStageView.swift
//  Maker
//
//  The Actions tab: everything the hero can do, one tap on or off.
//  The buttons, animation and state machine wire themselves.
//

import SwiftUI

struct ActionsStageView: View {
    @State private var filter: ActionGroup? = nil

    var body: some View {
        StageScaffold {
            ActionsSidebar(filter: $filter)
        } content: {
            ActionsContent(filter: $filter)
        } inspector: {
            ActionsInspector()
        }
    }
}

// MARK: - Sidebar

private struct ActionsSidebar: View {
    @EnvironmentObject private var store: MakerStore
    @Binding var filter: ActionGroup?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The hero's moves")
                .font(.headline)
            Text("\(enabledCount) of \(ActionRegistry.all.count) turned on")
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)

            ForEach(ActionGroup.allCases) { group in
                Button {
                    filter = (filter == group ? nil : group)
                } label: {
                    HStack(spacing: 10) {
                        IconBadge(symbol: group.symbol, tint: group.tint, size: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(group.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Text("\(count(in: group)) of \(ActionRegistry.actions(in: group).count)")
                                .font(.caption2)
                                .foregroundStyle(Palette.inkSoft)
                        }
                        Spacer(minLength: 0)
                        if filter == group {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(group.tint)
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(filter == group ? group.tint.opacity(0.12) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }

            Divider()

            Button {
                store.setAllActions(true)
            } label: {
                Label("Turn everything on", systemImage: "checkmark.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.ink)
            }
            .buttonStyle(.plain)

            Button {
                store.resetActions()
            } label: {
                Label("Back to the starter set", systemImage: "arrow.counterclockwise")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.inkSoft)
            }
            .buttonStyle(.plain)
        }
    }

    private var enabledCount: Int {
        store.currentProject?.enabledActions.count ?? 0
    }

    private func count(in group: ActionGroup) -> Int {
        guard let enabled = store.currentProject?.enabledActions else { return 0 }
        return enabled.filter { ActionRegistry.action($0)?.group == group }.count
    }
}

// MARK: - Content

private struct ActionsContent: View {
    @EnvironmentObject private var store: MakerStore
    @Binding var filter: ActionGroup?

    private var groups: [ActionGroup] {
        if let filter { return [filter] }
        return ActionGroup.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if let filter {
                Button {
                    self.filter = nil
                } label: {
                    Label("Show every group", systemImage: "square.grid.2x2")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Palette.surfaceAlt, in: Capsule())
                        .foregroundStyle(Palette.inkSoft)
                }
                .buttonStyle(.plain)
            }

            ForEach(groups) { group in
                section(group)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            IconBadge(symbol: "figure.run", tint: Palette.amber, size: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text("What can the hero do?")
                    .font(.title3.bold())
                Text("Turn a move on and it gets a button, an animation and a sound.")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
            Pill(text: store.currentProject?.heroBody ?? "Adventurer",
                 symbol: "person.fill",
                 tint: Palette.accent)
        }
        .makerCard()
    }

    private func section(_ group: ActionGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: group.symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(group.tint)
                Text(group.title)
                    .font(.headline)
                Spacer()
                Text("\(count(in: group))/\(ActionRegistry.actions(in: group).count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.inkSoft)
            }
            Text(group.blurb)
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 10) {
                ForEach(ActionRegistry.actions(in: group)) { action in
                    ActionTile(action: action, isOn: isOn(action.id))
                }
            }
        }
    }

    private func isOn(_ id: String) -> Bool {
        store.currentProject?.enabledActions.contains(id) ?? false
    }

    private func count(in group: ActionGroup) -> Int {
        ActionRegistry.actions(in: group).filter { isOn($0.id) }.count
    }
}

private struct ActionTile: View {
    @EnvironmentObject private var store: MakerStore
    let action: CharacterAction
    let isOn: Bool

    var body: some View {
        Toggle(isOn: Binding(get: { isOn }, set: { _ in store.toggleAction(action.id) })) {
            HStack(spacing: 10) {
                IconBadge(symbol: action.symbol, tint: action.group.tint, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(Palette.ink)
                    Text(action.blurb)
                        .font(.caption2)
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
        }
        .tint(action.group.tint)
        .padding(11)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isOn ? action.group.tint.opacity(0.35) : Palette.hairline.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Inspector

private struct ActionsInspector: View {
    @EnvironmentObject private var store: MakerStore

    private struct Preset: Identifiable {
        let id: String
        let name: String
        let symbol: String
        let ids: [String]
    }

    private let presets: [Preset] = [
        Preset(id: "adventurer", name: "Adventurer", symbol: "figure.walk",
               ids: ["idle", "walk", "run", "jump", "climb", "swim", "pickUp", "open", "talk",
                     "punch", "swordLight", "block", "wave", "dance"]),
        Preset(id: "ninja", name: "Ninja", symbol: "figure.run",
               ids: ["idle", "walk", "run", "sprint", "jump", "doubleJump", "crouch", "climb",
                     "dodge", "punch", "kick", "swordLight", "throw", "block", "wave"]),
        Preset(id: "knight", name: "Knight", symbol: "shield.fill",
               ids: ["idle", "walk", "run", "jump", "block", "parry", "swordLight", "swordHeavy",
                     "takeDamage", "open", "pickUp", "wave"]),
        Preset(id: "wizard", name: "Wizard", symbol: "sparkles",
               ids: ["idle", "walk", "run", "jump", "magicBolt", "heal", "shieldSpell", "teleport",
                     "read", "talk", "wave", "dance"])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick sets")
                .font(.headline)
            Text("Start from a hero that already feels right, then change what you like.")
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)

            ForEach(presets) { preset in
                Button {
                    store.updateProject(undoLabel: "use the \(preset.name) set") { project in
                        project.enabledActions = Set(preset.ids)
                    }
                } label: {
                    HStack(spacing: 10) {
                        IconBadge(symbol: preset.symbol, tint: Palette.amber, size: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(preset.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Text("\(preset.ids.count) moves")
                                .font(.caption2)
                                .foregroundStyle(Palette.inkSoft)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Palette.amber)
                    }
                    .padding(9)
                    .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Good to know")
                    .font(.caption.weight(.bold))
                Text("Walk and jump are the two a game really needs. Without them a player cannot get anywhere.")
                    .font(.caption2)
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
