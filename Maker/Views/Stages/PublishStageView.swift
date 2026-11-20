//
//  PublishStageView.swift
//  Maker
//
//  The Publish tab: a cover, a checklist, and an honest look at what is
//  ready and what is not.
//

import SwiftUI

struct PublishStageView: View {
    var body: some View {
        StageScaffold {
            PublishSidebar()
        } content: {
            PublishContent()
        } inspector: {
            PublishInspector()
        }
    }
}

// MARK: - Content

private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct PublishContent: View {
    @EnvironmentObject private var store: MakerStore
    @AppStorage("maker.nickname") private var nickname = ""
    @State private var shareItem: ShareItem?
    @State private var shareProblem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let project = store.currentProject {
                coverCard(project)
                detailsCard(project)
                shareCard(project)
            }
        }
        .sheet(item: $shareItem) { item in
            ActivityView(items: [item.url])
        }
    }

    private func coverCard(_ project: GameProject) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Cover")
                    .font(.headline)
                Spacer()
                Pill(text: "Made with Maker", symbol: "cube.fill", tint: Palette.accent)
            }

            ZStack(alignment: .bottomLeading) {
                if let level = store.currentLevel ?? project.levels.first {
                    LevelBoardView(level: level, interactive: false, showsPins: false)
                } else {
                    Rectangle()
                        .fill(project.tint.opacity(0.5))
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                }

                Rectangle()
                    .fill(Color.black.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(project.name)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(project.coverTagline.isEmpty ? "A new adventure." : project.coverTagline)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .makerCard()
    }

    private func detailsCard(_ project: GameProject) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("About the game")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(text: "Name")
                TextField("Game name", text: store.projectBinding(\.name, fallback: ""))
                    .font(.title3.weight(.semibold))
                    .textFieldStyle(.plain)
                    .padding(11)
                    .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(text: "One line about it")
                TextField("A short line that makes someone want to play.",
                          text: store.projectBinding(\.coverTagline, fallback: ""),
                          axis: .vertical)
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .padding(11)
                    .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack {
                FieldLabel(text: "Difficulty")
                Spacer()
                MenuChip(title: project.difficulty, symbol: "speedometer", tint: Palette.amber) {
                    ForEach(["Gentle", "Easy", "Tricky", "Hard"], id: \.self) { level in
                        Button(level) {
                            store.updateProject(undoLabel: "change the difficulty") { $0.difficulty = level }
                        }
                    }
                }
            }

            SwitchRow(title: "Mark as ready",
                      subtitle: "Ticks a box for you. Nothing is uploaded.",
                      symbol: "checkmark.seal.fill",
                      tint: Palette.mint,
                      isOn: store.projectBinding(\.published, fallback: false))
        }
        .makerCard()
    }

    private func shareCard(_ project: GameProject) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.accent)
                Text("Share the game")
                    .font(.headline)
            }

            Text("Packs every level, the ground you sculpted, your characters and the sounds into one file. Send it by Messages, Mail or AirDrop, and whoever opens it in Maker gets the whole game to play and build on.")
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text("Your name")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.inkSoft)
                TextField(GameSharing.deviceName, text: $nickname)
                    .font(.subheadline)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Button {
                shareProblem = nil
                let name = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                let sender = name.isEmpty ? GameSharing.deviceName : name
                if let url = store.shareFileURL(for: project, sharedBy: sender) {
                    shareItem = ShareItem(url: url)
                } else {
                    shareProblem = "The game couldn't be packed. Try again in a moment."
                }
            } label: {
                Label("Share the game", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Palette.accent, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            if let shareProblem {
                Text(shareProblem)
                    .font(.caption2)
                    .foregroundStyle(Palette.coral)
            }

            Text("A friend without Maker still sees the game's name, its one-line subtitle and what is inside it — the file opens as readable text rather than a broken blob.")
                .font(.caption2)
                .foregroundStyle(Palette.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .makerCard()
    }
}

// MARK: - Sidebar

private struct PublishSidebar: View {
    @EnvironmentObject private var store: MakerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Checklist")
                .font(.headline)

            if let project = store.currentProject {
                let issues = store.issues(for: project)
                if issues.isEmpty {
                    HStack(spacing: 9) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title3)
                            .foregroundStyle(Palette.mint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("All clear")
                                .font(.subheadline.bold())
                            Text("Nothing is missing.")
                                .font(.caption2)
                                .foregroundStyle(Palette.inkSoft)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Palette.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    ForEach(issues) { issue in
                        Button {
                            store.selectedTab = issue.tab
                        } label: {
                            HStack(alignment: .top, spacing: 9) {
                                Image(systemName: issue.symbol)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(issue.isBlocking ? Palette.coral : Palette.amber)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(issue.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Palette.ink)
                                        .multilineTextAlignment(.leading)
                                    Text(issue.detail)
                                        .font(.caption2)
                                        .foregroundStyle(Palette.inkSoft)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(9)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                Text("Levels")
                    .font(.subheadline.bold())

                ForEach(Array(project.levels.enumerated()), id: \.element.id) { index, level in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption2.bold().monospacedDigit())
                            .frame(width: 20, height: 20)
                            .background(Palette.surfaceAlt, in: Circle())
                        Text(level.name)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if level.hasPortal {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundStyle(Palette.accent)
                        } else {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(Palette.coral)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

// MARK: - Inspector

private struct PublishInspector: View {
    @EnvironmentObject private var store: MakerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let project = store.currentProject {
                Text("The numbers")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    CountTile(value: "\(project.levels.count)", label: "Levels", tint: Palette.mint)
                    CountTile(value: "\(project.entityCount)", label: "Things", tint: Palette.sky)
                    CountTile(value: "\(project.enabledActions.count)", label: "Moves", tint: Palette.amber)
                    CountTile(value: "\(project.hud.widgets.count)", label: "HUD parts", tint: Palette.accent)
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Made by")
                    Text("You")
                        .font(.subheadline.weight(.semibold))
                    Text("Everything here stays on this iPad.")
                        .font(.caption2)
                        .foregroundStyle(Palette.inkSoft)
                }
            }
        }
    }
}
