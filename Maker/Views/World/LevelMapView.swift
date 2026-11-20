//
//  LevelMapView.swift
//  Maker
//
//  The whole game at a glance: every level on one trail, joined by the
//  portals that lead from one to the next.
//

import SwiftUI

struct LevelMapView: View {
    @EnvironmentObject private var store: MakerStore
    @Environment(\.dismiss) private var dismiss

    private var project: GameProject? { store.currentProject }
    private var levels: [GameLevel] { project?.levels ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            ZStack {
                MapBackdrop()
                ScrollView {
                    VStack(spacing: 0) {
                        startMarker

                        ForEach(Array(levels.enumerated()), id: \.element.id) { index, level in
                            connector(offset: index)
                            levelCard(level, index: index)
                            if portalGoesNowhere(level, index: index) {
                                warningChip
                            }
                        }

                        connector(offset: levels.count)
                        endMarker
                        addLevelButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 40)
                }
            }
        }
        .background(Palette.background)
    }

    // MARK: Chrome

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 42, height: 42)
                    .background(Palette.surfaceAlt, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            VStack(alignment: .leading, spacing: 1) {
                Text(project?.name ?? "Your game")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            Button {
                open(store.currentLevel ?? levels.first)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil").font(.system(size: 13, weight: .bold))
                    Text("Edit").font(.subheadline.weight(.bold))
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Palette.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.hairline.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                play(store.currentLevel ?? levels.first)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.system(size: 12, weight: .bold))
                    Text("Play").font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "#159957"), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Palette.surface)
    }

    private var tabBar: some View {
        StageTabBar(selection: Binding(
            get: { store.selectedTab },
            set: { tab in
                store.selectedTab = tab
                dismiss()
            }
        ))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(Palette.surface)
    }

    private var subtitle: String {
        let count = levels.count
        let minutes = max(5, count * 5)
        return "\(count) level\(count == 1 ? "" : "s") · about \(minutes) minutes to play"
    }

    // MARK: Trail

    private var startMarker: some View {
        VStack(spacing: 3) {
            Image(systemName: "flag.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Color(hex: "#22B573"), in: Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            Text("START")
                .font(.system(size: 10, weight: .black))
                .kerning(1.2)
                .foregroundStyle(Palette.ink)
        }
        .padding(.top, 14)
    }

    private var endMarker: some View {
        VStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Palette.accent, in: Circle())
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
            Text("THE END")
                .font(.system(size: 10, weight: .black))
                .kerning(1.2)
                .foregroundStyle(Palette.ink)
        }
    }

    private func connector(offset: Int) -> some View {
        ZStack {
            MapTrailShape(shift: offset % 2 == 0 ? -1 : 1)
                .stroke(Color(hex: "#D9C08A"), style: StrokeStyle(lineWidth: 22, lineCap: .round))
                .frame(width: 210, height: 84)
            Image(systemName: "arrow.down")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color(hex: "#A9853F"))
        }
        .frame(height: 84)
    }

    private func levelCard(_ level: GameLevel, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("\(index + 1)")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Palette.accent, in: Circle())

                Text(level.name)
                    .font(.title3.bold())
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                statPill("\(level.baddies.count) baddie\(level.baddies.count == 1 ? "" : "s")",
                         symbol: "flame.fill", tint: Palette.coral)
                statPill("\(treasureCount(level)) treasure\(treasureCount(level) == 1 ? "" : "s")",
                         symbol: "gift.fill", tint: Palette.gold)
                statPill("\(level.objectives.count) goal\(level.objectives.count == 1 ? "" : "s")",
                         symbol: "flag.fill", tint: Palette.plum)
            }

            Button {
                play(level)
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "play.fill").font(.system(size: 11, weight: .bold))
                    Text("Play from here").font(.subheadline.weight(.bold))
                }
                .foregroundStyle(Palette.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Palette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: 430)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            open(level)
        }
    }

    private var warningChip: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.triangle.branch").font(.system(size: 10, weight: .bold))
            Text("Portal goes nowhere yet").font(.caption2.weight(.bold))
        }
        .foregroundStyle(Color(hex: "#A85A00"))
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Palette.amber.opacity(0.20), in: Capsule())
        .padding(.top, 8)
    }

    private var addLevelButton: some View {
        Button {
            store.addLevel()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: 18, weight: .bold))
                Text("Add another level").font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: 430)
            .padding(.vertical, 16)
            .background(Palette.accent, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 26)
    }

    private func statPill(_ text: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.system(size: 9, weight: .bold))
            Text(text).font(.caption2.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.13), in: Capsule())
    }

    // MARK: Behaviour

    private func treasureCount(_ level: GameLevel) -> Int {
        level.entities.filter { $0.kind == .treasure }.count
    }

    private func portalGoesNowhere(_ level: GameLevel, index: Int) -> Bool {
        index < levels.count - 1 && level.nextLevelID == nil
    }

    private func open(_ level: GameLevel?) {
        guard let level else { return }
        store.selectedLevelID = level.id
        store.selectedTab = .world
        dismiss()
    }

    private func play(_ level: GameLevel?) {
        guard let level else { return }
        store.selectedLevelID = level.id
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            store.isPlaying = true
        }
    }
}

// MARK: - Trail shape

private struct MapTrailShape: Shape {
    var shift: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.midX + shift * rect.width * 0.42, y: rect.minY + rect.height * 0.32),
            control2: CGPoint(x: rect.midX + shift * rect.width * 0.42, y: rect.minY + rect.height * 0.68)
        )
        return path
    }
}

// MARK: - Backdrop

private struct MapBackdrop: View {
    var body: some View {
        ZStack {
            Color(hex: "#A8D672")

            GeometryReader { geo in
                Circle()
                    .fill(Color(hex: "#93C95F"))
                    .frame(width: geo.size.width * 0.85)
                    .offset(x: -geo.size.width * 0.28, y: geo.size.height * 0.08)

                Circle()
                    .fill(Color(hex: "#9CD06A"))
                    .frame(width: geo.size.width * 0.75)
                    .offset(x: geo.size.width * 0.34, y: geo.size.height * 0.42)

                Circle()
                    .fill(Color(hex: "#8FC65C"))
                    .frame(width: geo.size.width * 0.9)
                    .offset(x: -geo.size.width * 0.2, y: geo.size.height * 0.78)

                Rectangle()
                    .fill(Color(hex: "#7CC6F2"))
                    .frame(height: geo.size.height * 0.10)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .ignoresSafeArea()

            Color.white.opacity(0.06)
        }
        .ignoresSafeArea()
    }
}
