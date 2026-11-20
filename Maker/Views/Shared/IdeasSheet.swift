//
//  IdeasSheet.swift
//  Maker
//
//  The coach: it reads the open game and offers one useful next step at
//  a time. Every suggestion is a single tap and one undo away.
//

import SwiftUI

struct IdeasSheet: View {
    @EnvironmentObject private var store: MakerStore
    @Environment(\.dismiss) private var dismiss

    private struct Suggestion: Identifiable {
        let id: String
        let title: String
        let detail: String
        let symbol: String
        let tint: Color
        let actionTitle: String
        let perform: () -> Void
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if suggestions.isEmpty {
                        EmptyHint(
                            symbol: "checkmark.seal.fill",
                            title: "This game looks good",
                            message: "Everything Maker would suggest is already done. Add another level and there will be more to do."
                        )
                        .makerCard()
                    } else {
                        ForEach(suggestions) { suggestion in
                            card(suggestion)
                        }
                    }
                }
                .padding(20)
            }
            .background(Palette.background)
            .navigationTitle("Ideas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Palette.amber)
                .frame(width: 44, height: 44)
                .background(Palette.amber.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("One step at a time")
                    .font(.headline)
                Text("Maker looks at \(store.currentProject?.name ?? "your game") and suggests what to try next.")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private func card(_ suggestion: Suggestion) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconBadge(symbol: suggestion.symbol, tint: suggestion.tint, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.subheadline.bold())
                Text(suggestion.detail)
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
                Button {
                    suggestion.perform()
                    dismiss()
                } label: {
                    Text(suggestion.actionTitle)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(suggestion.tint.opacity(0.16), in: Capsule())
                        .foregroundStyle(suggestion.tint)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Palette.hairline.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: What to suggest

    private var suggestions: [Suggestion] {
        guard let project = store.currentProject, let level = store.currentLevel else { return [] }
        var list: [Suggestion] = []

        for issue in store.issues(for: project).prefix(2) {
            list.append(
                Suggestion(
                    id: "issue-\(issue.id)",
                    title: issue.title,
                    detail: issue.detail,
                    symbol: issue.symbol,
                    tint: issue.isBlocking ? Palette.coral : Palette.amber,
                    actionTitle: "Take me there",
                    perform: { store.selectedTab = issue.tab }
                )
            )
        }

        if level.entities.filter({ $0.kind == .baddie }).isEmpty {
            list.append(
                Suggestion(
                    id: "add-baddie",
                    title: "Add someone to beat",
                    detail: "Baddies give a level something to do. Drop one in and give it a rule.",
                    symbol: "bolt.fill",
                    tint: Palette.coral,
                    actionTitle: "Add a baddie",
                    perform: { store.addEntity(.baddie) }
                )
            )
        }

        if level.entities.filter({ $0.kind == .treasure }).isEmpty {
            list.append(
                Suggestion(
                    id: "add-treasure",
                    title: "Hide some treasure",
                    detail: "A chest with coins gives the player a reason to explore.",
                    symbol: "gift.fill",
                    tint: Palette.gold,
                    actionTitle: "Add a chest",
                    perform: { store.addEntity(.treasure) }
                )
            )
        }

        if level.entities.filter({ $0.kind == .npc }).isEmpty {
            list.append(
                Suggestion(
                    id: "add-npc",
                    title: "Put a friend in the level",
                    detail: "An NPC can say hello, give a hint or hand over a key.",
                    symbol: "bubble.left.fill",
                    tint: Palette.sky,
                    actionTitle: "Add an NPC",
                    perform: { store.addEntity(.npc) }
                )
            )
        }

        if (project.levels.first?.entities.count ?? 0) > 0,
           level.entities.allSatisfy({ $0.cards.isEmpty }) {
            list.append(
                Suggestion(
                    id: "add-rule",
                    title: "Give something a rule",
                    detail: "Rules are how things move, talk and open. Try “Treasure chest”.",
                    symbol: "arrow.triangle.branch",
                    tint: Palette.plum,
                    actionTitle: "Open Logic",
                    perform: { store.selectedTab = .logic }
                )
            )
        }

        if !project.hud.widgets.contains(where: { $0.kind == .minimap }) {
            list.append(
                Suggestion(
                    id: "add-map",
                    title: "Add a minimap",
                    detail: "A little map helps players find their way around a big level.",
                    symbol: "map.fill",
                    tint: Palette.accent,
                    actionTitle: "Add a minimap",
                    perform: { store.addWidget(.minimap) }
                )
            )
        }

        if project.levels.count < 2 {
            list.append(
                Suggestion(
                    id: "add-level",
                    title: "Make a second level",
                    detail: "A game gets going when one portal leads somewhere new.",
                    symbol: "sparkles",
                    tint: Palette.mint,
                    actionTitle: "Add a level",
                    perform: { store.addLevel() }
                )
            )
        }

        return Array(list.prefix(4))
    }
}

#Preview {
    IdeasSheet()
        .environmentObject(MakerStore())
}
