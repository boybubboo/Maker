//
//  WorldViewportControls.swift
//  Maker
//
//  The touch layer over the 3D view: orbit, zoom, pick, the move, turn
//  and resize tools, and the brushes that shape the ground.
//

import SwiftUI
import simd

struct WorldViewportView: View {
    @EnvironmentObject private var store: MakerStore
    let level: GameLevel
    @Binding var camera: ViewportCamera
    @Binding var tool: ViewportTool
    let brush: TerrainBrush
    let brushRadius: Float
    @Binding var stickerKind: StickerKind
    @Binding var pattern: SurfacePattern

    @State private var dragOrigin: ViewportCamera?
    @State private var manipulating: UUID?
    @State private var startRotation: Double = 0
    @State private var startScale: Double = 1
    @State private var groundOffset = SIMD2<Float>(0, 0)
    @State private var pinchStart: Float?
    @State private var painting = false
    @State private var lastPaintPoint: SIMD2<Float>?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                WorldSceneView(level: level, camera: camera, selectedID: store.selectedEntityID)
                    .allowsHitTesting(false)

                Color.clear
                    .contentShape(Rectangle())

                if let platform = level.entity(with: store.selectedEntityID),
                   platform.kind == .platform,
                   let endPoint = platform.platformEnd {
                    platformEndOverlay(platform, endPoint: endPoint, in: geo.size)
                }

                if let sticker = selectedSticker {
                    stickerMarker(sticker, in: geo.size)
                }
            }
            .gesture(dragGesture(size: geo.size))
            .simultaneousGesture(magnify)
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { value in
                        switch tool {
                        case .sticker:
                            tapSticker(at: value.location, in: geo.size)
                        case .texture:
                            tapTexture(at: value.location, in: geo.size)
                        default:
                            select(at: value.location, in: geo.size)
                        }
                    }
            )
        }
    }

    // MARK: Gestures

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                switch tool {
                case .terrain:
                    paintStroke(at: value.location, in: size)
                    return
                case .sticker:
                    placeStickerDrag(at: value.location, in: size)
                    return
                case .texture:
                    textureDrag(at: value.location, in: size)
                    return
                case .add, .move, .rotate, .scale:
                    break
                }

                if dragOrigin == nil {
                    beginDrag(at: value.startLocation, in: size)
                }
                guard let origin = dragOrigin else { return }

                if let id = manipulating {
                    switch tool {
                    case .move:
                        if let hit = GroundPicker.point(for: value.location, camera: camera, in: size, level: level) {
                            let target = SIMD3<Float>(hit.x + groundOffset.x, 0, hit.z + groundOffset.y)
                            store.moveEntity(id, to: IslandTerrain.boardPoint(for: target))
                        }
                    case .rotate:
                        let raw = startRotation + Double(value.translation.width) * 0.45
                        let snapped = (raw / 15).rounded() * 15
                        store.updateEntity(id) { $0.rotation = snapped.truncatingRemainder(dividingBy: 360) }
                    case .scale:
                        let factor = 1 - Double(value.translation.height) / 260
                        let raw = min(3, max(0.5, startScale * factor))
                        let snapped = (raw / 0.25).rounded() * 0.25
                        store.updateEntity(id) { $0.scale = snapped }
                    case .add, .terrain, .sticker, .texture:
                        break
                    }
                } else {
                    var updated = origin
                    updated.yaw = origin.yaw - Float(value.translation.width) * 0.008
                    updated.pitch = min(1.35, max(0.08, origin.pitch + Float(value.translation.height) * 0.005))
                    camera = updated
                }
            }
            .onEnded { _ in
                dragOrigin = nil
                manipulating = nil
                painting = false
                lastPaintPoint = nil
            }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if pinchStart == nil { pinchStart = camera.distance }
                guard let start = pinchStart else { return }
                var updated = camera
                updated.distance = min(150, max(12, start / Float(max(value.magnification, 0.05))))
                camera = updated
            }
            .onEnded { _ in
                pinchStart = nil
            }
    }

    // MARK: Platform end point

    @ViewBuilder
    private func platformEndOverlay(_ platform: LevelEntity, endPoint: BoardPoint, in size: CGSize) -> some View {
        let hover = PlatformMotion.hover(for: platform.platformPreset)
        let startWorld = TerrainSampler.worldPoint(for: platform.position, in: level)
        let endWorld = TerrainSampler.worldPoint(for: endPoint, in: level)
        let start = SIMD3<Float>(startWorld.x, startWorld.y + hover, startWorld.z)
        let end = SIMD3<Float>(endWorld.x, endWorld.y + hover, endWorld.z)

        if let from = camera.project(start, in: size),
           let to = camera.project(end, in: size) {
            ZStack {
                Path { path in
                    path.move(to: from)
                    path.addLine(to: to)
                }
                .stroke(Palette.gold.opacity(0.95), style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                .allowsHitTesting(false)

                if !PlatformMotion.isSpin(platform.platformMotion) {
                    ZStack {
                        Circle()
                            .fill(Palette.gold.opacity(0.22))
                            .frame(width: 46, height: 46)
                        Circle()
                            .strokeBorder(Palette.gold, lineWidth: 2.5)
                            .frame(width: 46, height: 46)
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "#8A6A00"))
                    }
                    .position(to)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard let hit = GroundPicker.point(for: value.location,
                                                                   camera: camera,
                                                                   in: size,
                                                                   level: level) else { return }
                                store.updateEntity(platform.id) { current in
                                    current.platformEnd = IslandTerrain.boardPoint(for: hit)
                                }
                            }
                    )
                }
            }
        }
    }

    // MARK: Terrain

    private func paintStroke(at location: CGPoint, in size: CGSize) {
        guard let hit = GroundPicker.point(for: location, camera: camera, in: size, level: level) else { return }

        if !painting {
            painting = true
            store.beginTerrainStroke()
        }

        let point = SIMD2<Float>(hit.x, hit.z)
        store.paintTerrain(brush, from: lastPaintPoint, to: point, radius: brushRadius)
        lastPaintPoint = point
    }

    // MARK: Stickers and textures

    private var selectedSticker: Sticker? {
        guard let id = store.selectedStickerID else { return nil }
        return (level.stickers ?? []).first { $0.id == id }
    }

    @ViewBuilder
    private func stickerMarker(_ sticker: Sticker, in size: CGSize) -> some View {
        if let spot = StickerNodes.worldPoint(for: sticker, in: level),
           let screen = camera.project(spot.position, in: size) {
            ZStack {
                Circle()
                    .strokeBorder(Palette.accent, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .frame(width: 58, height: 58)
                Image(systemName: sticker.stickerKind.symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.accent)
            }
            .position(screen)
            .allowsHitTesting(false)
        }
    }

    private func tapSticker(at point: CGPoint, in size: CGSize) {
        if let id = stickerUnder(point, in: size) {
            store.selectedStickerID = id
            store.selectedEntityID = nil
            return
        }

        store.selectedStickerID = nil

        if let id = propUnder(point, in: size) {
            store.addSticker(stickerKind, on: id)
            return
        }
        guard let hit = GroundPicker.point(for: point, camera: camera, in: size, level: level) else { return }
        store.addSticker(stickerKind, at: IslandTerrain.boardPoint(for: hit))
    }

    private func placeStickerDrag(at location: CGPoint, in size: CGSize) {
        guard let hit = GroundPicker.point(for: location, camera: camera, in: size, level: level) else { return }

        let point = SIMD2<Float>(hit.x, hit.z)
        if let last = lastPaintPoint {
            let dx = point.x - last.x
            let dz = point.y - last.y
            // A drag leaves a scattering of stickers, not a solid heap.
            if (dx * dx + dz * dz).squareRoot() < 1.8 { return }
        }

        if let id = propUnder(location, in: size) {
            store.addSticker(stickerKind, on: id)
        } else {
            store.addSticker(stickerKind, at: IslandTerrain.boardPoint(for: hit))
        }
        lastPaintPoint = point
    }

    private func tapTexture(at point: CGPoint, in size: CGSize) {
        if let id = propUnder(point, in: size) {
            store.setSurfacePattern(pattern, for: id)
            return
        }
        guard let hit = GroundPicker.point(for: point, camera: camera, in: size, level: level) else { return }
        store.beginTextureStroke()
        store.paintPattern(pattern, from: nil, to: SIMD2(hit.x, hit.z), radius: brushRadius)
    }

    private func textureDrag(at location: CGPoint, in size: CGSize) {
        if !painting {
            painting = true
            store.beginTextureStroke()
        }

        if let id = propUnder(location, in: size) {
            store.setSurfacePattern(pattern, for: id)
            return
        }

        guard let hit = GroundPicker.point(for: location, camera: camera, in: size, level: level) else { return }
        store.paintPattern(pattern, from: lastPaintPoint, to: SIMD2(hit.x, hit.z), radius: brushRadius)
        lastPaintPoint = SIMD2(hit.x, hit.z)
    }

    /// The prop under the finger, if any, so a sticker or a texture can be
    /// put on it instead of the ground behind it.
    private func propUnder(_ point: CGPoint, in size: CGSize) -> UUID? {
        var best: (id: UUID, distance: CGFloat)?
        for entity in level.entities {
            guard let screen = camera.project(entityPoint(entity), in: size) else { continue }
            let distance = hypot(screen.x - point.x, screen.y - point.y)
            if distance < 46, best == nil || distance < best!.distance {
                best = (entity.id, distance)
            }
        }
        return best?.id
    }

    private func stickerUnder(_ point: CGPoint, in size: CGSize) -> UUID? {
        var best: (id: UUID, distance: CGFloat)?
        for sticker in level.stickers ?? [] {
            guard let spot = StickerNodes.worldPoint(for: sticker, in: level),
                  let screen = camera.project(spot.position, in: size) else { continue }
            let distance = hypot(screen.x - point.x, screen.y - point.y)
            if distance < 62, best == nil || distance < best!.distance {
                best = (sticker.id, distance)
            }
        }
        return best?.id
    }

    // MARK: Picking

    private func beginDrag(at point: CGPoint, in size: CGSize) {
        dragOrigin = camera
        manipulating = nil
        guard tool != .add,
              tool != .terrain,
              let id = store.selectedEntityID,
              let entity = level.entity(with: id) else { return }

        let world = entityPoint(entity)
        guard let screen = camera.project(world, in: size) else { return }
        guard hypot(screen.x - point.x, screen.y - point.y) < 110 else { return }

        manipulating = id
        startRotation = entity.rotation
        startScale = entity.scale
        switch tool {
        case .move:
            store.recordUndo("move \(entity.name)")
            if let hit = GroundPicker.point(for: point, camera: camera, in: size, level: level) {
                groundOffset = SIMD2<Float>(world.x - hit.x, world.z - hit.z)
            } else {
                groundOffset = SIMD2<Float>(0, 0)
            }
        case .rotate: store.recordUndo("turn \(entity.name)")
        case .scale: store.recordUndo("resize \(entity.name)")
        case .add, .terrain, .sticker, .texture: break
        }
    }

    private func select(at point: CGPoint, in size: CGSize) {
        var best: (id: UUID, distance: CGFloat)?
        for entity in level.entities {
            guard let screen = camera.project(entityPoint(entity), in: size) else { continue }
            let distance = hypot(screen.x - point.x, screen.y - point.y)
            if distance < 80, best == nil || distance < best!.distance {
                best = (entity.id, distance)
            }
        }
        store.selectedEntityID = best?.id
    }

    private func entityPoint(_ entity: LevelEntity) -> SIMD3<Float> {
        let base = TerrainSampler.worldPoint(for: entity.position, in: level)
        return SIMD3<Float>(base.x, base.y + 0.55, base.z)
    }
}

// MARK: - Floating chrome for the viewport

/// The tool column laid on its side, for a phone: one swipeable row above the
/// viewport so every tool stays in reach.
struct ViewportToolStrip: View {
    @Binding var tool: ViewportTool
    @Binding var showsPalette: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ViewportTool.allCases) { item in
                    Button {
                        withAnimation(.snappy(duration: 0.15)) {
                            tool = item
                            showsPalette = (item == .add)
                        }
                    } label: {
                        Image(systemName: item.symbol)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(tool == item ? .white : Palette.inkSoft)
                            .frame(width: 40, height: 40)
                            .background(background(for: item), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                }
            }
            .padding(6)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }

    private func background(for item: ViewportTool) -> Color {
        if tool == item { return Palette.accent }
        return item == .add ? Palette.mint : Palette.surface
    }
}

struct ViewportToolColumn: View {
    @Binding var tool: ViewportTool
    @Binding var showsPalette: Bool

    var body: some View {
        VStack(spacing: 8) {
            ForEach(ViewportTool.allCases) { item in
                Button {
                    withAnimation(.snappy(duration: 0.15)) {
                        tool = item
                        showsPalette = (item == .add)
                    }
                } label: {
                    Image(systemName: item.symbol)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(foreground(for: item))
                        .frame(width: 46, height: 46)
                        .background(background(for: item), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
            }
        }
        .padding(7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 27, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }

    private func foreground(for item: ViewportTool) -> Color {
        tool == item ? .white : Palette.inkSoft
    }

    private func background(for item: ViewportTool) -> Color {
        if tool == item { return Palette.accent }
        return item == .add ? Palette.mint : Palette.surface
    }
}

struct ViewportPaletteShelf: View {
    let onPick: (EntityKind) -> Void

    private let kinds: [EntityKind] = [.scenery, .prop, .light, .treasure, .sign, .platform, .trap, .door]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(kinds) { kind in
                Button {
                    onPick(kind)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: kind.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(kind.tint)
                        Text(shortName(kind))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                    }
                    .frame(width: 62, height: 52)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }

    private func shortName(_ kind: EntityKind) -> String {
        switch kind {
        case .scenery: return "Tree"
        case .prop: return "Barrel"
        case .light: return "Torch"
        case .treasure: return "Chest"
        case .sign: return "Sign"
        case .platform: return "Platform"
        case .trap: return "Trap"
        default: return kind.defaultName
        }
    }
}

struct TerrainBrushShelf: View {
    @Binding var brush: TerrainBrush
    @Binding var radius: Float
    let biome: Biome

    var body: some View {
        VStack(spacing: 7) {
            row([.raiseGround, .lowerGround, .smoothGround, .flattenGround])
            row([.paintGrass, .paintSand, .paintRock, .paintSnow])
            row([.scatterTree, .scatterRock, .scatterFlower])
            HStack(spacing: 8) {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
                Slider(value: $radius, in: 2...14)
                    .tint(Palette.accent)
                    .frame(maxWidth: 190)
                Text("\(Int(radius)) m")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Palette.inkSoft)
            }
            .padding(.top, 1)
        }
        .padding(9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }

    private func row(_ items: [TerrainBrush]) -> some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                button(item)
            }
        }
    }

    private func button(_ item: TerrainBrush) -> some View {
        let selected = item == brush
        return Button {
            brush = item
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(selected ? Palette.accent : Palette.surface)
                        .frame(width: 36, height: 36)

                    if let layer = item.layer {
                        Circle()
                            .fill(Color(layer.color(biome: biome)))
                            .frame(width: 22, height: 22)
                            .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1))
                    } else if item.isScatter {
                        Image(systemName: item.symbol)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(selected ? .white : Color(item.scatteredColor))
                    } else {
                        Image(systemName: item.symbol)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(selected ? .white : Palette.inkSoft)
                    }
                }
                Text(item.title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(selected ? Palette.ink : Palette.inkSoft)
                    .lineLimit(1)
            }
            .frame(width: 54)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
    }
}

struct StickerShelf: View {
    @Binding var kind: StickerKind

    var body: some View {
        HStack(spacing: 6) {
            ForEach(StickerKind.allCases) { item in
                Button {
                    kind = item
                } label: {
                    VStack(spacing: 3) {
                        Image(uiImage: item.image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
                            .padding(3)
                            .background(Circle().fill(kind == item ? Palette.accent : Palette.surface))
                        Text(item.title)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(kind == item ? Palette.ink : Palette.inkSoft)
                            .lineLimit(1)
                    }
                    .frame(width: 56)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
            }
        }
        .padding(9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }
}

struct TextureShelf: View {
    @Binding var pattern: SurfacePattern
    @Binding var radius: Float

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                ForEach([SurfacePattern.bare, .planks, .brick, .thatch]) { item in
                    button(item)
                }
            }
            HStack(spacing: 6) {
                ForEach([SurfacePattern.stone, .sand, .grass]) { item in
                    button(item)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "circle.dashed")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.inkSoft)
                Slider(value: $radius, in: 2...14)
                    .tint(Palette.accent)
                    .frame(maxWidth: 190)
                Text("\(Int(radius)) m")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Palette.inkSoft)
            }
            .padding(.top, 1)
        }
        .padding(9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }

    private func button(_ item: SurfacePattern) -> some View {
        let selected = item == pattern
        return Button {
            pattern = item
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(selected ? Palette.accent : Palette.surface)
                        .frame(width: 36, height: 36)

                    if let image = item.image {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 22, height: 22)
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 1))
                    } else {
                        Image(systemName: item.symbol)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(selected ? .white : Palette.inkSoft)
                    }
                }
                Text(item.title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(selected ? Palette.ink : Palette.inkSoft)
                    .lineLimit(1)
            }
            .frame(width: 54)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
    }
}

struct ViewportOrbitHint: View {
    var text: String = "Drag to orbit · pinch to zoom"

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "hand.draw.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(Palette.inkSoft)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
    }
}
