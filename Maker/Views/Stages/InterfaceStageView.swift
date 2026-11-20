//
//  InterfaceStageView.swift
//  Maker
//
//  The Interface tab: drag health bars, an inventory and a minimap onto
//  the screen and see them over a real level.
//

import SwiftUI

struct InterfaceStageView: View {
    var body: some View {
        StageScaffold {
            InterfaceSidebar()
        } content: {
            InterfaceContent()
        } inspector: {
            InterfaceInspector()
        }
    }
}

// MARK: - Content

private struct InterfaceContent: View {
    @EnvironmentObject private var store: MakerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let project = store.currentProject, let level = store.currentLevel {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("The screen")
                            .font(.title3.bold())
                        Text("Drag anything to move it. Tap it to change it.")
                            .font(.caption)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Spacer(minLength: 0)
                    MenuChip(title: project.hud.themeName, symbol: "paintpalette.fill", tint: Palette.accent) {
                        ForEach(PresetLibrary.themes, id: \.self) { theme in
                            Button(theme) {
                                store.updateProject(undoLabel: "change the theme") { $0.hud.themeName = theme }
                            }
                        }
                    }
                }

                HUDCanvas(level: level, profile: project.hud)

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                    Text("Everything you see here is what the player sees while playing.")
                        .font(.caption2)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Palette.inkSoft)
            } else {
                EmptyHint(symbol: "rectangle.3.group", title: "No level yet",
                          message: "Add a level first, then design the screen it plays on.")
                    .makerCard()
            }
        }
    }
}

private struct HUDCanvas: View {
    @EnvironmentObject private var store: MakerStore
    let level: GameLevel
    let profile: HUDProfile

    @State private var origins: [UUID: CGPoint] = [:]

    var body: some View {
        ZStack {
            LevelBoardView(level: level, interactive: false, showsPins: false)
                .overlay(Color.black.opacity(0.22))

            GeometryReader { geo in
                ForEach(profile.widgets) { widget in
                    HUDWidgetView(widget: widget, isSelected: widget.id == store.selectedWidgetID)
                        .frame(width: widget.width, height: widget.height)
                        .position(point(for: widget, in: geo.size))
                        .onTapGesture {
                            store.selectedWidgetID = widget.id
                        }
                        .gesture(drag(widget))
                }
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private func point(for widget: HUDWidget, in size: CGSize) -> CGPoint {
        let pad: CGFloat = 18
        let x = widget.width / 2 + pad
        let y = widget.height / 2 + pad
        let base: CGPoint
        switch widget.anchor {
        case .topLeading: base = CGPoint(x: x, y: y)
        case .top: base = CGPoint(x: size.width / 2, y: y)
        case .topTrailing: base = CGPoint(x: size.width - x, y: y)
        case .bottomLeading: base = CGPoint(x: x, y: size.height - y)
        case .bottom: base = CGPoint(x: size.width / 2, y: size.height - y)
        case .bottomTrailing: base = CGPoint(x: size.width - x, y: size.height - y)
        case .center: base = CGPoint(x: size.width / 2, y: size.height / 2)
        }
        return CGPoint(x: base.x + widget.offsetX, y: base.y + widget.offsetY)
    }

    private func drag(_ widget: HUDWidget) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if origins[widget.id] == nil {
                    origins[widget.id] = CGPoint(x: widget.offsetX, y: widget.offsetY)
                }
                let origin = origins[widget.id] ?? .zero
                store.updateWidget(widget.id) { current in
                    current.offsetX = origin.x + value.translation.width
                    current.offsetY = origin.y + value.translation.height
                }
            }
            .onEnded { _ in
                origins[widget.id] = nil
            }
    }
}

// MARK: - Sidebar

private struct InterfaceSidebar: View {
    @EnvironmentObject private var store: MakerStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("On the screen")
                    .font(.headline)
                Spacer()
                Text("\(store.currentProject?.hud.widgets.count ?? 0)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.inkSoft)
            }

            if let widgets = store.currentProject?.hud.widgets, !widgets.isEmpty {
                ForEach(widgets) { widget in
                    row(widget)
                }
            } else {
                Text("Nothing on the screen yet. Add a health bar to begin.")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }

            Divider()

            Text("Add to the screen")
                .font(.subheadline.bold())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(WidgetKind.allCases) { kind in
                    Button {
                        store.addWidget(kind)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: kind.symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Palette.accent)
                            Text(kind.title)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func row(_ widget: HUDWidget) -> some View {
        let selected = widget.id == store.selectedWidgetID
        return HStack(spacing: 9) {
            Button {
                store.selectedWidgetID = widget.id
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: widget.kind.symbol)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(widget.fill)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(widget.kind.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        Text(StatLibrary.stat(widget.binding)?.title ?? widget.binding)
                            .font(.caption2)
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button {
                store.deleteWidget(widget.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(Palette.inkFaint)
                    .padding(6)
                    .background(Palette.surfaceAlt, in: Circle())
            }
            .buttonStyle(.plain)
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
}

// MARK: - Inspector

private struct InterfaceInspector: View {
    @EnvironmentObject private var store: MakerStore

    private let swatches = ["#F2545B", "#FF9F1C", "#F2C230", "#22B573", "#3AA0FF", "#6C4CF1", "#FFFFFF"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let widget = store.currentWidget {
                Text("This \(widget.kind.title.lowercased())")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "Label")
                    TextField("Label", text: store.widgetBinding(\.label, fallback: ""))
                        .font(.subheadline)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if widget.kind.usesBinding {
                    VStack(alignment: .leading, spacing: 8) {
                        FieldLabel(text: "Shows")
                        MenuChip(title: StatLibrary.stat(widget.binding)?.title ?? "Health",
                                 symbol: StatLibrary.stat(widget.binding)?.symbol ?? "heart.fill",
                                 tint: Palette.accent) {
                            ForEach(StatLibrary.all) { stat in
                                Button {
                                    store.updateWidget(widget.id) { $0.binding = stat.id }
                                } label: {
                                    Label(stat.title, systemImage: stat.symbol)
                                }
                            }
                        }
                        Text(bindingNote(for: widget))
                            .font(.caption2)
                            .foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(widgetNote(for: widget.kind))
                        .font(.caption2)
                        .foregroundStyle(Palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "Colour")
                    HStack(spacing: 8) {
                        ForEach(swatches, id: \.self) { hex in
                            Button {
                                store.updateWidget(widget.id) { $0.fillHex = hex }
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        Circle().strokeBorder(
                                            widget.fillHex == hex ? Palette.ink : Color.white.opacity(0.5),
                                            lineWidth: widget.fillHex == hex ? 2.5 : 1
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "Where it sits")
                    MenuChip(title: widget.anchor.title, symbol: widget.anchor.symbol, tint: Palette.inkSoft) {
                        ForEach(WidgetAnchor.allCases) { anchor in
                            Button {
                                store.updateWidget(widget.id, undoLabel: "move a widget") { current in
                                    current.anchor = anchor
                                    current.offsetX = 0
                                    current.offsetY = 0
                                }
                            } label: {
                                Label(anchor.title, systemImage: anchor.symbol)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    FieldLabel(text: "Size")
                    HStack {
                        Text("Width").font(.caption.weight(.semibold))
                        Slider(value: store.widgetBinding(\.width, fallback: 190), in: 40...380)
                            .tint(Palette.accent)
                    }
                    HStack {
                        Text("Height").font(.caption.weight(.semibold))
                        Slider(value: store.widgetBinding(\.height, fallback: 26), in: 18...160)
                            .tint(Palette.accent)
                    }
                }

                Divider()

                Button(role: .destructive) {
                    store.deleteWidget(widget.id)
                } label: {
                    Label("Take it off the screen", systemImage: "trash")
                        .font(.caption.weight(.semibold))
                }
            } else {
                Text("Nothing selected")
                    .font(.headline)
                Text("Tap a bar or map on the screen to change its colour, size and what it shows.")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private func bindingNote(for widget: HUDWidget) -> String {
        if widget.binding == "magic" {
            return "Reads the hero's real magic. Nothing spends it yet, so it stays full."
        }
        guard let stat = StatLibrary.stat(widget.binding) else {
            return "Not connected to anything yet, so it stays empty in play."
        }
        return stat.isLive
            ? "Reads the hero's real \(stat.title.lowercased()) while you play."
            : "Nothing fills this yet, so it stays empty in play."
    }

    private func widgetNote(for kind: WidgetKind) -> String {
        switch kind {
        case .minimap:
            return "Follows the hero in play, with the portal and nearby baddies marked."
        case .objectiveList:
            return "Shows the goals from the World tab."
        case .timer:
            return "Counts the time since the level started."
        case .inventoryGrid:
            return "There is no inventory in the game yet, so these slots stay empty."
        case .pauseButton:
            return "Decoration: the pause button at the top of Play is the one that works."
        default:
            return "Decoration for now: nothing in the game drives it."
        }
    }
}
