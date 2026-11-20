//
//  GameTitleView.swift
//  Maker
//
//  The front door of a game: its cover, its name, Play, and the levels to
//  start from. Then a card for the level, then the game.
//

import SwiftUI

struct GameSessionView: View {
    @EnvironmentObject private var store: MakerStore
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case title, card, playing }

    @State private var phase: Phase = .title

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let project = store.currentProject {
                switch phase {
                case .title:
                    GameTitleView(
                        project: project,
                        onClose: { dismiss() },
                        onStart: { level in begin(level) }
                    )
                    .transition(.opacity)

                case .card:
                    if let level = store.currentLevel {
                        LevelIntroCard(
                            level: level,
                            number: levelNumber(level, in: project),
                            onContinue: { startPlaying() }
                        )
                        .transition(.opacity)
                    }

                case .playing:
                    PlayPreviewView(
                        onExit: {
                            withAnimation(.snappy) { phase = .title }
                        },
                        onNextLevel: { next in
                            begin(next)
                        },
                        onQuit: {
                            dismiss()
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
        .animation(.snappy(duration: 0.25), value: phaseKey)
    }

    private var phaseKey: Int {
        switch phase {
        case .title: return 0
        case .card: return 1
        case .playing: return 2
        }
    }

    private func levelNumber(_ level: GameLevel, in project: GameProject) -> Int {
        (project.levels.firstIndex { $0.id == level.id } ?? 0) + 1
    }

    private func begin(_ level: GameLevel) {
        store.selectedLevelID = level.id
        withAnimation(.snappy) { phase = .card }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            startPlaying()
        }
    }

    private func startPlaying() {
        guard phase == .card else { return }
        withAnimation(.snappy) { phase = .playing }
    }
}

// MARK: - The title screen

struct GameTitleView: View {
    @EnvironmentObject private var store: MakerStore
    let project: GameProject
    let onClose: () -> Void
    let onStart: (GameLevel) -> Void

    private var levels: [GameLevel] { project.levels }

    private var coverLevel: GameLevel? {
        store.currentLevel ?? project.levels.first
    }

    private var subtitle: String {
        let text = project.coverTagline.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "A new adventure." : text
    }

    private let coverCamera = ViewportCamera(yaw: 0.62, pitch: 0.40, distance: 36, target: SIMD3<Float>(0, 2.0, 0))

    var body: some View {
        ZStack(alignment: .bottom) {
            cover
            sheet

            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 46, height: 46)
                            .background(Palette.surface.opacity(0.92), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")

                    Spacer()

                    Menu {
                        Button {
                            onClose()
                        } label: {
                            Label("Back to the maker", systemImage: "hammer.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 46, height: 46)
                            .background(Palette.surface.opacity(0.92), in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            AudioEngine.shared.playMusic(coverLevel?.audio?.mood ?? MusicMood.none, owner: "title")
        }
        .onDisappear {
            AudioEngine.shared.stopMusic(owner: "title")
        }
    }

    private var cover: some View {
        ZStack {
            Color(hex: "#8FD3FF")
            if let level = coverLevel {
                WorldSceneView(level: level, camera: coverCamera, selectedID: nil)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    private var sheet: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Palette.inkFaint.opacity(0.35))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Text(project.name)
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
                .padding(.horizontal, 20)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 26)

            Button {
                if let level = coverLevel {
                    onStart(level)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 19, weight: .bold))
                    Text("Play")
                        .font(.title3.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Color(hex: "#159957"), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(coverLevel == nil)
            .padding(.horizontal, 20)
            .padding(.top, 2)

            levelRow
                .padding(.top, 4)
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 32,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 32,
                style: .continuous
            )
            .fill(Palette.surface)
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var levelRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                    Button {
                        onStart(level)
                    } label: {
                        VStack(spacing: 7) {
                            LevelThumbnail(
                                level: level,
                                number: index + 1,
                                highlighted: level.id == store.currentLevel?.id
                            )
                            Text(shortName(level.name))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                        }
                        .frame(width: 96)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 4)
        }
    }

    private func shortName(_ name: String) -> String {
        if name.lowercased().hasPrefix("the ") {
            return String(name.dropFirst(4))
        }
        return name
    }
}

// MARK: - Level thumbnail

private struct LevelThumbnail: View {
    let level: GameLevel
    let number: Int
    let highlighted: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            LevelBoardView(level: level, interactive: false, showsPins: false)
                .frame(width: 150, height: 84)
                .scaleEffect(1.55)
                .frame(width: 88, height: 88)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(
                        highlighted ? Palette.accent : Palette.hairline.opacity(0.6),
                        lineWidth: highlighted ? 3 : 1.5
                    )
                )

            Text("\(number)")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Palette.accent, in: Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .offset(x: -3, y: -3)
        }
        .frame(width: 88, height: 88)
    }
}

// MARK: - Level card

struct LevelIntroCard: View {
    let level: GameLevel
    let number: Int
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.35), Color.black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Text("LEVEL \(number)")
                    .font(.system(size: 11, weight: .black))
                    .kerning(1.8)
                    .foregroundStyle(Palette.inkSoft)

                Text(level.name)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if level.objectives.isEmpty {
                    Text("Go and explore.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSoft)
                } else {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(level.objectives) { objective in
                            HStack(spacing: 8) {
                                Image(systemName: "circle")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Palette.amber)
                                Text(objective.text)
                                    .font(.subheadline)
                                    .foregroundStyle(Palette.ink)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("Tap to start")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.inkFaint)
                    .padding(.top, 4)
            }
            .padding(26)
            .frame(maxWidth: 380)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 24, y: 10)
            .padding(24)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onContinue()
        }
        .task {
            try? await Task.sleep(for: .seconds(2.2))
            onContinue()
        }
    }
}
