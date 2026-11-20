//
//  EditorShellView.swift
//  Maker
//
//  The maker itself: one bar for the game and the level, one row of big
//  tabs, and whichever stage is showing below.
//

import SwiftUI

struct EditorShellView: View {
    @EnvironmentObject private var store: MakerStore
    @Environment(\.horizontalSizeClass) private var horizontalSize

    private var isCompact: Bool { horizontalSize == .compact }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .layoutPriority(1)
            Rectangle()
                .fill(Palette.hairline.opacity(0.6))
                .frame(height: 1)
            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            if !isCompact {
                Rectangle()
                    .fill(Palette.hairline.opacity(0.6))
                    .frame(height: 1)
                bottomBar
            }
        }
        .background(Palette.background)
        .fullScreenCover(isPresented: $store.isPlaying) {
            GameSessionView()
                .environmentObject(store)
        }
        .sheet(isPresented: $store.showingIdeas) {
            IdeasSheet()
                .environmentObject(store)
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        VStack(spacing: 8) {
            if isCompact {
                compactHeader
                compactTabs
            } else {
                regularHeader
            }
        }
        .padding(.horizontal, isCompact ? 12 : 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Palette.surface)
    }

    /// A big screen gets one row: the game, the level, and the buttons that act
    /// on the level. The stage tabs live in a bar of their own at the bottom,
    /// where a tablet keeps its navigation and where there is always room for
    /// all six.
    private var regularHeader: some View {
        HStack(spacing: 12) {
            backButton
            titleBlock
            Spacer(minLength: 8)
            levelMenu
            ideasButton
            undoButtons
            playButton
        }
    }

    private var bottomBar: some View {
        StageTabBar(selection: $store.selectedTab)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Palette.surface)
    }

    /// A phone gets the whole chrome in two rows: the project, the level and
    /// the buttons that matter up top, every stage tab reachable below.
    private var compactHeader: some View {
        HStack(spacing: 8) {
            backButton
            compactTitle
            Spacer(minLength: 4)
            undoButtons
            playCircle
        }
    }

    private var compactTabs: some View {
        HStack(spacing: 8) {
            StageTabBar(selection: $store.selectedTab)
            ideasButton
        }
    }

    private var backButton: some View {
        Button {
            store.closeProject()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.accent)
                .frame(width: 42, height: 42)
                .background(Palette.surfaceAlt, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("All games")
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(store.currentProject?.name ?? "Untitled")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .lineLimit(1)
            Text("Level \(store.levelIndex + 1) of \(max(store.currentProject?.levelCount ?? 0, 1))")
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)
        }
    }

    private var compactTitle: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(store.currentProject?.name ?? "Untitled")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            compactLevelMenu
        }
        .layoutPriority(1)
    }

    @ViewBuilder
    private var levelMenuContent: some View {
        if let project = store.currentProject {
            ForEach(Array(project.levels.enumerated()), id: \.element.id) { index, level in
                Button {
                    store.selectedLevelID = level.id
                    store.selectedEntityID = level.entities.first?.id
                } label: {
                    Label("\(index + 1). \(level.name)",
                          systemImage: level.id == store.selectedLevelID ? "checkmark" : "map")
                }
            }
            Divider()
        }
        Button {
            store.addLevel()
        } label: {
            Label("Add a level", systemImage: "plus")
        }
    }

    private var levelMenu: some View {
        Menu {
            levelMenuContent
        } label: {
            levelMenuLabel(compact: false)
        }
    }

    private var compactLevelMenu: some View {
        Menu {
            levelMenuContent
        } label: {
            levelMenuLabel(compact: true)
        }
    }

    private func levelMenuLabel(compact: Bool) -> some View {
        HStack(spacing: 5) {
            if !compact {
                Image(systemName: "map.fill")
                    .font(.caption)
            }
            Text(compact
                 ? "Level \(store.levelIndex + 1) · \(store.currentLevel?.name ?? "No level")"
                 : (store.currentLevel?.name ?? "No level"))
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .black))
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, compact ? 0 : 11)
        .padding(.vertical, compact ? 0 : 7)
        .background(compact ? Color.clear : Palette.surfaceAlt, in: Capsule())
    }

    private var undoButtons: some View {
        HStack(spacing: 6) {
            Button {
                store.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .foregroundStyle(store.canUndo ? Palette.inkSoft : Palette.inkFaint)
                    .background(Palette.surfaceAlt, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!store.canUndo)
            .accessibilityLabel("Undo")

            Button {
                store.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .foregroundStyle(store.canRedo ? Palette.inkSoft : Palette.inkFaint)
                    .background(Palette.surfaceAlt, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!store.canRedo)
            .accessibilityLabel("Redo")
        }
    }

    private var ideasButton: some View {
        Button {
            store.showingIdeas = true
        } label: {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.amber)
                .frame(width: 38, height: 38)
                .background(Palette.surfaceAlt, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ideas for your game")
    }

    private var playButton: some View {
        Button {
            store.isPlaying = true
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("Play")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "#159957"), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var playCircle: some View {
        Button {
            store.isPlaying = true
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color(hex: "#159957"), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play the game")
    }

    // MARK: Stages

    @ViewBuilder
    private var stage: some View {
        switch store.selectedTab {
        case .world:
            WorldStageView()
        case .cast:
            CastStageView()
        case .logic:
            LogicStageView()
        case .actions:
            ActionsStageView()
        case .interface:
            InterfaceStageView()
        case .publish:
            PublishStageView()
        }
    }
}
