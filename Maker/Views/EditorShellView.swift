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

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Rectangle()
                .fill(Palette.hairline.opacity(0.6))
                .frame(height: 1)
            stage
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
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                backButton
                titleBlock
                Spacer(minLength: 8)
                levelMenu
            }
            HStack(spacing: 8) {
                StageTabBar(selection: $store.selectedTab)
                Spacer(minLength: 8)
                ideasButton
                undoButtons
                playButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Palette.surface)
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

    private var levelMenu: some View {
        Menu {
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
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "map.fill")
                    .font(.caption)
                Text(store.currentLevel?.name ?? "No level")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .black))
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Palette.surfaceAlt, in: Capsule())
        }
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
