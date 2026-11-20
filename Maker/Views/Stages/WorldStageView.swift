//
//  WorldStageView.swift
//  Maker
//
//  The World tab: a real 3D view of the level with the game tree and the
//  level settings floating over it, and a map for when you want the flat
//  overview back.
//

import SwiftUI

struct WorldStageView: View {
    @EnvironmentObject private var store: MakerStore
    @Environment(\.horizontalSizeClass) private var horizontalSize

    @State private var camera = ViewportCamera()
    @State private var tool: ViewportTool = .move
    @State private var brush: TerrainBrush = .raiseGround
    @State private var brushRadius: Float = 5
    @State private var stickerKind: StickerKind = .moss
    @State private var pattern: SurfacePattern = .planks
    @State private var showsMap = false
    @State private var showsPalette = false
    @State private var showingDetails = false
    @State private var showingMap = false

    var body: some View {
        Group {
            if horizontalSize == .compact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .sheet(isPresented: $showingDetails) {
            LevelDetailsSheet()
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showingMap) {
            LevelMapView()
                .environmentObject(store)
        }
        .onAppear {
            playLevelMusic()
        }
        .onDisappear {
            AudioEngine.shared.stopMusic(owner: "editor")
        }
        .onChange(of: store.isPlaying) { _, playing in
            if playing {
                AudioEngine.shared.stopMusic(owner: "editor")
            } else {
                playLevelMusic()
            }
        }
        .onChange(of: store.currentLevel?.audio?.mood ?? MusicMood.none) { _, _ in
            playLevelMusic()
        }
    }

    private func playLevelMusic() {
        guard !store.isPlaying else { return }
        let mood = store.currentLevel?.audio?.mood ?? MusicMood.none
        AudioEngine.shared.playMusic(mood, owner: "editor")
    }

    // MARK: Regular layout

    private var regularLayout: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                viewport

                HStack(alignment: .top, spacing: 12) {
                    floatingPanel(width: 300, maxHeight: geo.size.height - 30) {
                        WorldSidebar(onShowMap: { showingMap = true })
                    }

                    Spacer(minLength: 30)

                    VStack(alignment: .trailing, spacing: 10) {
                        floatingPanel(width: 252, maxHeight: geo.size.height - 140) {
                            WorldInspector(onDetails: { showingDetails = true })
                        }
                        Spacer(minLength: 0)
                        if !showsMap {
                            ViewportToolColumn(tool: $tool, showsPalette: $showsPalette)
                        }
                    }
                    .frame(width: 252)
                }
                .padding(14)
            }
            .overlay(alignment: .bottom) {
                bottomBar
            }
        }
    }

    // MARK: Compact layout

    private var compactLayout: some View {
        VStack(spacing: 0) {
            viewport
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 12)
                .padding(.top, 10)

            HStack(spacing: 10) {
                if !showsMap {
                    ViewportToolColumn(tool: $tool, showsPalette: $showsPalette)
                        .scaleEffect(0.85, anchor: .leading)
                }
                Spacer(minLength: 0)
                mapToggle
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)

            if !showsMap {
                toolShelf
                    .padding(.top, 6)
                if let sticker = store.currentSticker {
                    StickerEditorBar(sticker: sticker)
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                }
            }

            ScrollView {
                VStack(spacing: 12) {
                    cardPanel { WorldSidebar(onShowMap: { showingMap = true }) }
                    cardPanel { WorldInspector(onDetails: { showingDetails = true }) }
                }
                .padding(14)
            }
        }
        .background(Palette.background)
    }

    // MARK: Pieces

    @ViewBuilder
    private var viewport: some View {
        if let level = store.currentLevel {
            if showsMap {
                ZStack {
                    Palette.background
                    LevelBoardView(level: level, selectedEntityID: store.selectedEntityID) { id in
                        store.selectedEntityID = id
                        store.selectedSection = level.entity(with: id)?.kind.section ?? .cast
                    }
                    .padding(26)
                    .frame(maxWidth: 940)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                WorldViewportView(level: level,
                                  camera: $camera,
                                  tool: $tool,
                                  brush: brush,
                                  brushRadius: brushRadius,
                                  stickerKind: $stickerKind,
                                  pattern: $pattern)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(level.biome.ground)
            }
        } else {
            ZStack {
                Palette.background
                EmptyHint(
                    symbol: "map.fill",
                    title: "No level yet",
                    message: "A game is made of levels. Add the first one and a start and portal come with it.",
                    actionTitle: "Add a level"
                ) {
                    store.addLevel()
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if !showsMap {
                toolShelf
                if let sticker = store.currentSticker {
                    StickerEditorBar(sticker: sticker)
                        .frame(maxWidth: 620)
                }
            }
            HStack(spacing: 10) {
                mapToggle
                if !showsMap {
                    ViewportOrbitHint(text: hintText)
                }
            }
        }
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var toolShelf: some View {
        switch tool {
        case .terrain:
            TerrainBrushShelf(brush: $brush, radius: $brushRadius, biome: store.currentLevel?.biome ?? .meadow)
        case .sticker:
            StickerShelf(kind: $stickerKind)
        case .texture:
            TextureShelf(pattern: $pattern, radius: $brushRadius)
        case .add:
            if showsPalette {
                ViewportPaletteShelf(onPick: addProp)
            }
        case .move, .rotate, .scale:
            EmptyView()
        }
    }

    private var hintText: String {
        switch tool {
        case .terrain: return "Drag on the ground to shape it"
        case .sticker: return "Tap or drag to stick it down · tap one to change it"
        case .texture: return "Drag to paint the ground · tap a prop to texture it"
        case .add, .move, .rotate, .scale: return "Drag to orbit · pinch to zoom"
        }
    }

    private var mapToggle: some View {
        HStack(spacing: 2) {
            segment(title: "3D", symbol: "cube.fill", active: !showsMap) {
                withAnimation(.snappy(duration: 0.2)) { showsMap = false }
            }
            segment(title: "Map", symbol: "map.fill", active: showsMap) {
                withAnimation(.snappy(duration: 0.2)) { showsMap = true }
            }
        }
        .padding(3)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
    }

    private func segment(title: String, symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(active ? Color.white : Palette.inkSoft)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(active ? Palette.accent : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func addProp(_ kind: EntityKind) {
        let angle = Float.random(in: 0..<(2 * .pi))
        let world = SIMD3<Float>(camera.target.x + cos(angle) * 6, 0, camera.target.z + sin(angle) * 6)
        let limit = IslandTerrain.radius * 0.8
        let clamped = SIMD3<Float>(min(limit, max(-limit, world.x)), 0, min(limit, max(-limit, world.z)))
        store.addEntity(kind, at: IslandTerrain.boardPoint(for: clamped))
        withAnimation(.snappy) { showsPalette = false }
    }

    private func floatingPanel<Content: View>(
        width: CGFloat,
        maxHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
                .padding(16)
        }
        .frame(width: width)
        .frame(maxHeight: maxHeight, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 14, y: 5)
    }

    private func cardPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
                .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Palette.hairline.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Level tree

private struct WorldSidebar: View {
    @EnvironmentObject private var store: MakerStore
    var onShowMap: () -> Void = { }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Levels")
                    .font(.headline)
                Spacer()
                Button {
                    onShowMap()
                } label: {
                    Image(systemName: "map.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.mint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Level map")

                Button {
                    store.addLevel()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add a level")
            }

            if let project = store.currentProject {
                Text(project.name)
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
                    .padding(.bottom, 2)

                ForEach(Array(project.levels.enumerated()), id: \.element.id) { index, level in
                    levelRow(level, index: index)
                    if level.id == store.selectedLevelID {
                        breakdown(level)
                    }
                }

                Button {
                    store.addLevel()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                        Text("Add a level")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Palette.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Palette.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    private func levelRow(_ level: GameLevel, index: Int) -> some View {
        let selected = level.id == store.selectedLevelID
        return Button {
            store.selectedLevelID = level.id
            store.selectedEntityID = level.entities.first?.id
        } label: {
            HStack(spacing: 10) {
                Text("\(index + 1)")
                    .font(.caption.bold().monospacedDigit())
                    .frame(width: 24, height: 24)
                    .background(selected ? Color.white.opacity(0.25) : Palette.surfaceAlt, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(level.playSummary)
                        .font(.caption2)
                        .opacity(0.75)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if level.hasPortal {
                    Image(systemName: "sparkles")
                        .font(.caption2.weight(.bold))
                        .opacity(0.8)
                }
            }
            .padding(10)
            .foregroundStyle(selected ? Color.white : Palette.ink)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? Palette.accent : Palette.surfaceAlt)
            )
        }
        .buttonStyle(.plain)
    }

    private func breakdown(_ level: GameLevel) -> some View {
        VStack(spacing: 2) {
            treeRow(symbol: "flag.fill", title: "Start", value: level.hasStart ? "ready" : "missing",
                    tint: Palette.mint, action: nil)
            treeRow(symbol: "figure.stand", title: "Hero", value: store.currentProject?.heroName ?? "Hero",
                    tint: Palette.accent, action: { store.selectedTab = .cast })

            ForEach([EntitySection.cast, .things, .hazards, .puzzles, .scenery]) { section in
                treeRow(symbol: section.symbol, title: section.title,
                        value: "\(level.entities(in: section).count)",
                        tint: Palette.inkSoft,
                        action: {
                            store.selectedSection = section
                            store.selectedEntityID = level.entities(in: section).first?.id
                            store.selectedTab = .cast
                        })
            }

            treeRow(symbol: "list.bullet", title: "Objectives", value: "\(level.objectives.count)",
                    tint: Palette.amber, action: nil)
            treeRow(symbol: "sparkles", title: "Portal", value: level.hasPortal ? "ready" : "missing",
                    tint: Palette.accent,
                    action: {
                        store.selectedSection = .markers
                        store.selectedTab = .cast
                    })
        }
        .padding(.leading, 6)
        .padding(.vertical, 4)
    }

    private func treeRow(symbol: String, title: String, value: String, tint: Color, action: (() -> Void)?) -> some View {
        Group {
            if let action {
                Button(action: action) {
                    rowContent(symbol: symbol, title: title, value: value, tint: tint, chevron: true)
                }
                .buttonStyle(.plain)
            } else {
                rowContent(symbol: symbol, title: title, value: value, tint: tint, chevron: false)
            }
        }
    }

    private func rowContent(symbol: String, title: String, value: String, tint: Color, chevron: Bool) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.ink)
            Spacer(minLength: 4)
            Text(value)
                .font(.caption2)
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1)
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(Palette.inkFaint)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Settings

private struct WorldInspector: View {
    @EnvironmentObject private var store: MakerStore
    var onDetails: () -> Void = { }
    @State private var showingDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let project = store.currentProject, let level = store.currentLevel {
                Text("Level settings")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    CountTile(value: "\(level.entities(in: .cast).count)", label: "Cast", tint: Palette.sky)
                    CountTile(value: "\(level.entities(in: .things).count)", label: "Things", tint: Palette.gold)
                    CountTile(value: "\(level.entities(in: .hazards).count)", label: "Hazards", tint: Palette.coral)
                    CountTile(value: "\(level.entities(in: .puzzles).count)", label: "Puzzles", tint: Palette.plum)
                }

                Button {
                    onDetails()
                } label: {
                    HStack(spacing: 9) {
                        IconBadge(symbol: "slider.horizontal.3", tint: Palette.accent, size: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Name, goals and portal")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Palette.ink)
                            Text(level.name)
                                .font(.caption2)
                                .foregroundStyle(Palette.inkSoft)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(Palette.inkFaint)
                    }
                    .padding(9)
                    .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Divider()

                MenuChip(title: level.sky.title, symbol: level.sky.symbol, tint: level.sky.tint) {
                    ForEach(SkyPreset.allCases) { sky in
                        Button {
                            store.updateLevel(level.id, undoLabel: "change the sky") { $0.sky = sky }
                        } label: {
                            Label(sky.title, systemImage: sky.symbol)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Sun angle")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("\(Int(level.sunAngle))°")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Slider(value: store.levelBinding(\.sunAngle, fallback: 45), in: 0...360)
                        .tint(Palette.amber)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Fog")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text("\(Int(level.fog * 100))%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Slider(value: store.levelBinding(\.fog, fallback: 0.15), in: 0...1)
                        .tint(Palette.sky)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "Needs doing")
                    let issues = Array(store.issues(for: project).prefix(3))
                    if issues.isEmpty {
                        HStack(spacing: 7) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Palette.mint)
                            Text("This level is ready to play.")
                                .font(.caption)
                        }
                    } else {
                        ForEach(issues) { issue in
                            Button {
                                store.selectedTab = issue.tab
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: issue.symbol)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(issue.isBlocking ? Palette.coral : Palette.amber)
                                        .frame(width: 18)
                                    Text(issue.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Palette.ink)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .black))
                                        .foregroundStyle(Palette.inkFaint)
                                }
                                .padding(8)
                                .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()

                Button(role: .destructive) {
                    showingDelete = true
                } label: {
                    Label("Delete this level", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                }
                .disabled(project.levels.count < 2)
                .confirmationDialog("Delete \(level.name)?", isPresented: $showingDelete, titleVisibility: .visible) {
                    Button("Delete the level", role: .destructive) { store.deleteLevel(level.id) }
                    Button("Keep it", role: .cancel) { }
                }
            }
        }
    }
}

// MARK: - The selected sticker

private struct StickerEditorBar: View {
    @EnvironmentObject private var store: MakerStore
    let sticker: Sticker

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 9) {
                Image(uiImage: sticker.stickerKind.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(sticker.stickerKind.title)
                        .font(.subheadline.weight(.bold))
                    Text(sticker.isOnProp ? "Stuck on a prop" : "Lying on the ground")
                        .font(.caption2)
                        .foregroundStyle(Palette.inkSoft)
                }

                Spacer(minLength: 6)

                Button {
                    store.deleteSticker(sticker.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Palette.coral)
                        .frame(width: 32, height: 32)
                        .background(Palette.coral.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove the sticker")

                Button {
                    store.selectedStickerID = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Palette.inkSoft)
                        .frame(width: 32, height: 32)
                        .background(Palette.surfaceAlt, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done with this sticker")
            }

            slider("Size",
                   value: binding(\.size),
                   range: 0.4...6,
                   text: String(format: "%.1f m", sticker.size),
                   tint: Palette.accent)
            slider("Turn",
                   value: binding(\.rotation),
                   range: 0...360,
                   text: "\(Int(sticker.rotation.rounded()))°",
                   tint: Palette.sky)
            slider("Fade",
                   value: binding(\.fade),
                   range: 0...1,
                   text: "\(Int((sticker.fade * 100).rounded()))%",
                   tint: Palette.plum)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
    }

    private func binding(_ keyPath: WritableKeyPath<Sticker, Double>) -> Binding<Double> {
        Binding(
            get: { store.currentSticker?[keyPath: keyPath] ?? sticker[keyPath: keyPath] },
            set: { newValue in
                store.updateSticker(sticker.id) { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    private func slider(_ title: String,
                        value: Binding<Double>,
                        range: ClosedRange<Double>,
                        text: String,
                        tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(width: 34, alignment: .leading)
            Slider(value: value, in: range)
                .tint(tint)
            Text(text)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Palette.inkSoft)
                .frame(width: 48, alignment: .trailing)
        }
    }
}

// MARK: - Details sheet

private struct LevelDetailsSheet: View {
    @EnvironmentObject private var store: MakerStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let project = store.currentProject, let level = store.currentLevel {
                        LevelHeaderCard(level: level)
                        FlowCard(level: level, project: project)
                        WeatherWaterCard(level: level)
                        LevelAudioCard(level: level)
                        LevelNotesCard(level: level)
                    }
                }
                .padding(20)
            }
            .background(Palette.background)
            .navigationTitle("Level details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Level cards used by the details sheet

private struct LevelHeaderCard: View {
    @EnvironmentObject private var store: MakerStore
    let level: GameLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IconBadge(symbol: level.biome.symbol, tint: level.biome.detail, size: 48)

                VStack(alignment: .leading, spacing: 3) {
                    TextField("Level name", text: store.levelBinding(\.name, fallback: level.name))
                        .font(.title2.bold())
                        .textFieldStyle(.plain)
                    Text(level.playSummary)
                        .font(.caption)
                        .foregroundStyle(Palette.inkSoft)
                }

                Spacer(minLength: 6)

                MenuChip(title: level.biome.title, symbol: level.biome.symbol, tint: level.biome.detail) {
                    ForEach(Biome.allCases) { biome in
                        Button {
                            store.updateLevel(level.id, undoLabel: "change the biome") { $0.biome = biome }
                        } label: {
                            Label(biome.title, systemImage: biome.symbol)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(LevelStyle.allCases) { style in
                    Button {
                        store.updateLevel(level.id, undoLabel: "change how the level is built") { $0.style = style }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Label(style.title, systemImage: style.symbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                            Text(style.blurb)
                                .font(.caption2)
                                .foregroundStyle(Palette.inkSoft)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(11)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(level.style == style ? Palette.accent.opacity(0.12) : Palette.surfaceAlt)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(level.style == style ? Palette.accent : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .makerCard()
    }
}

private struct FlowCard: View {
    @EnvironmentObject private var store: MakerStore
    let level: GameLevel
    let project: GameProject

    private var nextName: String {
        guard let nextID = level.nextLevelID,
              let next = project.levels.first(where: { $0.id == nextID }) else {
            return "End of the game"
        }
        return next.name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How the level works")
                .font(.headline)

            SwitchRow(title: "Start here",
                      subtitle: "Where the player begins.",
                      symbol: "flag.fill",
                      tint: Palette.mint,
                      isOn: store.levelBinding(\.hasStart, fallback: true))

            SwitchRow(title: "Portal at the end",
                      subtitle: "Finishes the level and moves on.",
                      symbol: "sparkles",
                      tint: Palette.accent,
                      isOn: store.levelBinding(\.hasPortal, fallback: true))

            HStack {
                FieldLabel(text: "Finish by")
                Spacer()
                MenuChip(title: level.completeCondition.title,
                         symbol: level.completeCondition.symbol,
                         tint: Palette.plum) {
                    ForEach(CompleteCondition.allCases) { condition in
                        Button {
                            store.updateLevel(level.id, undoLabel: "change how the level ends") {
                                $0.completeCondition = condition
                            }
                        } label: {
                            Label(condition.title, systemImage: condition.symbol)
                        }
                    }
                }
            }

            HStack {
                FieldLabel(text: "Portal goes to")
                Spacer()
                MenuChip(title: nextName, symbol: "arrow.right", tint: Palette.sky) {
                    Button {
                        store.updateLevel(level.id, undoLabel: "change the next level") { $0.nextLevelID = nil }
                    } label: {
                        Label("End of the game", systemImage: "flag.checkered")
                    }
                    ForEach(project.levels) { other in
                        if other.id != level.id {
                            Button {
                                store.updateLevel(level.id, undoLabel: "change the next level") {
                                    $0.nextLevelID = other.id
                                }
                            } label: {
                                Label(other.name, systemImage: "map")
                            }
                        }
                    }
                }
            }

            Divider()

            objectives
        }
        .makerCard()
    }

    private var objectives: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                FieldLabel(text: "Goals for the player")
                Spacer()
                Button {
                    store.addObjective(text: "New goal")
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.caption2.weight(.black))
                        Text("Add").font(.caption.weight(.bold))
                    }
                    .foregroundStyle(Palette.amber)
                }
                .buttonStyle(.plain)
            }

            if level.objectives.isEmpty {
                Text("No goals yet. Add one so the player knows what to do.")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }

            ForEach(level.objectives) { objective in
                HStack(spacing: 9) {
                    Image(systemName: objective.isOptional ? "circle.dashed" : "circle")
                        .font(.caption)
                        .foregroundStyle(objective.isOptional ? Palette.inkFaint : Palette.amber)

                    TextField("Goal", text: textBinding(for: objective.id))
                        .font(.subheadline)
                        .textFieldStyle(.plain)

                    Button {
                        store.toggleObjectiveOptional(objective.id)
                    } label: {
                        Text(objective.isOptional ? "extra" : "main")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Palette.inkSoft)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Palette.surfaceAlt, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.deleteObjective(objective.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Palette.inkFaint)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func textBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { store.currentLevel?.objectives.first(where: { $0.id == id })?.text ?? "" },
            set: { newValue in
                store.updateLevel(level.id) { current in
                    if let index = current.objectives.firstIndex(where: { $0.id == id }) {
                        current.objectives[index].text = newValue
                    }
                }
            }
        )
    }
}

private struct WeatherWaterCard: View {
    @EnvironmentObject private var store: MakerStore
    let level: GameLevel

    private var swimBinding: Binding<Bool> {
        Binding(
            get: { level.canSwim },
            set: { value in
                store.updateLevel(level.id, undoLabel: "change swimming") { $0.swimming = value }
            }
        )
    }

    private var windBinding: Binding<Double> {
        Binding(
            get: { level.windStrength },
            set: { value in
                store.updateLevel(level.id, undoLabel: "change the wind") { $0.wind = value }
            }
        )
    }

    private var windLabel: String {
        let value = level.windStrength
        if value < 0.12 { return "Still" }
        if value < 0.45 { return "Breezy" }
        if value < 0.78 { return "Windy" }
        return "Gale"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "cloud.rain.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.sky)
                Text("Weather and water")
                    .font(.headline)
            }

            HStack(spacing: 8) {
                ForEach(WeatherKind.allCases) { kind in
                    Button {
                        store.updateLevel(level.id, undoLabel: "change the weather") { $0.weather = kind.rawValue }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: kind.symbol)
                                .font(.subheadline.weight(.bold))
                            Text(kind.title)
                                .font(.caption2.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(level.weatherKind == kind ? Palette.sky.opacity(0.14) : Palette.surfaceAlt)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(level.weatherKind == kind ? Palette.sky : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(level.weatherKind == kind ? Palette.sky : Palette.inkSoft)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Wind")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(windLabel)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Palette.inkSoft)
                }
                Slider(value: windBinding, in: 0...1)
                    .tint(Palette.sky)
            }

            SwitchRow(title: "Swimming",
                      subtitle: "Paddle in deep water instead of walking.",
                      symbol: "drop.fill",
                      tint: Palette.sky,
                      isOn: swimBinding)

            Text("The sea around the island is the water. The hero swims in it and climbs out at the shore.")
                .font(.caption2)
                .foregroundStyle(Palette.inkSoft)
        }
        .makerCard()
    }
}

private struct LevelAudioCard: View {
    @EnvironmentObject private var store: MakerStore
    let level: GameLevel

    private var audio: LevelAudio { level.audio ?? LevelAudio() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.plum)
                Text("Music and sound")
                    .font(.headline)
                Spacer()
                Button {
                    AudioEngine.shared.play(audio.coin)
                } label: {
                    Text("Hear it")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.plum)
                }
                .buttonStyle(.plain)
            }

            HStack {
                FieldLabel(text: "Music")
                Spacer()
                MenuChip(title: audio.mood.title, symbol: audio.mood.symbol, tint: Palette.plum) {
                    ForEach(MusicMood.allCases) { mood in
                        Button {
                            store.updateLevelAudio(undoLabel: "change the music") { $0.mood = mood }
                            AudioEngine.shared.playMusic(mood, owner: "editor")
                        } label: {
                            Label(mood.title, systemImage: mood.symbol)
                        }
                    }
                }
            }

            soundRow("Coins", \.coin)
            soundRow("Hits", \.hit)
            soundRow("Doors", \.door)
            soundRow("Portal", \.portal)
            soundRow("Jump", \.jump)
            soundRow("Footsteps", \.step)

            Text("Every sound is made inside Maker, so there are no files to find.")
                .font(.caption2)
                .foregroundStyle(Palette.inkSoft)
        }
        .makerCard()
    }

    private func soundRow(_ title: String, _ keyPath: WritableKeyPath<LevelAudio, SoundEffect>) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .frame(width: 82, alignment: .leading)

            MenuChip(title: audio[keyPath: keyPath].title,
                     symbol: audio[keyPath: keyPath].symbol,
                     tint: Palette.inkSoft) {
                ForEach(SoundEffect.allCases) { effect in
                    Button {
                        store.updateLevelAudio { $0[keyPath: keyPath] = effect }
                        if effect != .none { AudioEngine.shared.play(effect) }
                    } label: {
                        Label(effect.title, systemImage: effect.symbol)
                    }
                }
            }

            Spacer(minLength: 0)

            Button {
                AudioEngine.shared.play(audio[keyPath: keyPath])
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Palette.accent)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct LevelNotesCard: View {
    @EnvironmentObject private var store: MakerStore
    let level: GameLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.inkSoft)
                FieldLabel(text: "Notes to yourself")
            }
            TextField("What happens in this level?", text: store.levelBinding(\.notes, fallback: ""), axis: .vertical)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
        }
        .makerCard()
    }
}
