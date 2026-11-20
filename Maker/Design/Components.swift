//
//  Components.swift
//  Maker
//
//  Shared building blocks: the three-panel stage layout, the chunky tab
//  bar, chips, steppers, and the widgets that draw a game's interface.
//

import SwiftUI

// MARK: - Stage layout

/// How much room a stage needs before the three columns are worth it. One
/// place, because the World stage has to make exactly the same decision as
/// everything else and must never disagree with the scaffold.
enum StageLayout {
    static let wideWidth: CGFloat = 880
    /// A window this short is better off as one scrolling page whatever its
    /// width, so nothing gets squeezed into an unusable strip.
    static let wideHeight: CGFloat = 520

    /// Side columns scale with the screen: an iPad Pro gets roomier ones, and
    /// the working column always keeps the space in the middle.
    static func columnWidth(for width: CGFloat) -> CGFloat {
        min(340, max(240, width * 0.23))
    }
}

/// The one page every stage sits in. Wide and tall enough gets the three
/// columns, each scrolling on its own; anything else becomes a single page
/// that scrolls from top to bottom, so a stage can never be cropped.
struct StageScaffold<Sidebar: View, Content: View, Inspector: View>: View {
    var showsInspector: Bool = true
    @ViewBuilder var sidebar: Sidebar
    @ViewBuilder var content: Content
    @ViewBuilder var inspector: Inspector

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= StageLayout.wideWidth, geo.size.height >= StageLayout.wideHeight {
                columns(width: geo.size.width)
            } else {
                stacked
            }
        }
    }

    private var stacked: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
                sidebar
                if showsInspector { inspector }
            }
            .padding(16)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background)
    }

    private func columns(width: CGFloat) -> some View {
        let column = StageLayout.columnWidth(for: width)
        return HStack(spacing: 0) {
            ScrollView {
                sidebar.padding(16)
            }
            .frame(width: column)
            .background(Palette.sidebar)

            Divider()

            ScrollView {
                content.padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background)

            if showsInspector {
                Divider()
                ScrollView {
                    inspector.padding(16)
                }
                .frame(width: column)
                .background(Palette.sidebar)
            }
        }
    }
}

// MARK: - Panels

/// Lets its content keep hugging what is inside it, and scrolls instead once
/// the content is taller than the room it has, so a panel can never hide the
/// rest of itself on a small screen.
struct BoundedScroll<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder var content: Content

    @State private var contentHeight: CGFloat = 0

    private var needsScrolling: Bool { contentHeight > maxHeight + 1 }

    var body: some View {
        Group {
            if needsScrolling {
                ScrollView(showsIndicators: false) {
                    content.background(measure)
                }
                .frame(height: max(maxHeight, 0))
            } else {
                content.background(measure)
            }
        }
    }

    private var measure: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { contentHeight = geo.size.height }
                .onChange(of: geo.size.height) { _, height in contentHeight = height }
        }
    }
}

// MARK: - Tabs

struct StageTabBar: View {
    @Binding var selection: StageTab

    var body: some View {
        // All six tabs share the width whenever there is room for them, so a
        // big screen shows the whole set at once; a narrow window scrolls the
        // strip instead of hiding a tab behind the edge.
        ViewThatFits(in: .horizontal) {
            strip(expanding: true)
            ScrollView(.horizontal, showsIndicators: false) {
                strip(expanding: false)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
    }

    private func strip(expanding: Bool) -> some View {
        HStack(spacing: 2) {
            ForEach(StageTab.allCases) { tab in
                tabButton(tab)
                    .frame(maxWidth: expanding ? .infinity : nil)
            }
        }
        .padding(4)
        .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .fixedSize(horizontal: !expanding, vertical: false)
    }

    private func tabButton(_ tab: StageTab) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { selection = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 10, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(minWidth: 46)
            .padding(.vertical, 6)
            .padding(.horizontal, 5)
            .foregroundStyle(selection == tab ? Color.white : Palette.inkSoft)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(selection == tab ? deepTint(tab) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func deepTint(_ tab: StageTab) -> Color {
        switch tab {
        case .world: return Color(hex: "#1F8A5B")
        case .cast: return Color(hex: "#1D6FC4")
        case .logic: return Color(hex: "#7B3FD4")
        case .actions: return Color(hex: "#C26A00")
        case .interface: return Color(hex: "#5B3AE0")
        case .publish: return Color(hex: "#C43B44")
        }
    }
}

// MARK: - Chips and controls

struct MenuChip<Content: View>: View {
    let title: String
    var symbol: String? = nil
    var tint: Color = Palette.inkSoft
    @ViewBuilder var content: Content

    var body: some View {
        Menu {
            content
        } label: {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol).font(.caption.weight(.bold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .black))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(tint.opacity(0.12), in: Capsule())
        }
    }
}

struct StepperControl: View {
    let title: String
    let symbol: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...20
    var tint: Color = Palette.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.inkSoft)
            }
            HStack(spacing: 8) {
                stepButton(symbol: "minus", enabled: value > range.lowerBound) {
                    if value > range.lowerBound { value -= 1 }
                }
                Text("\(value)")
                    .font(.headline.monospacedDigit())
                    .frame(minWidth: 34)
                stepButton(symbol: "plus", enabled: value < range.upperBound) {
                    if value < range.upperBound { value += 1 }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stepButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(enabled ? tint : Palette.inkFaint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(enabled ? 0.14 : 0.06), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

struct SwitchRow: View {
    let title: String
    var subtitle: String? = nil
    var symbol: String? = nil
    var tint: Color = Palette.accent
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                if let symbol {
                    IconBadge(symbol: symbol, tint: tint, size: 34)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(Palette.inkSoft)
                    }
                }
            }
        }
        .tint(tint)
    }
}

struct EmptyHint: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Palette.inkFaint)
            Text(title).font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
            if let actionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accent)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 16)
    }
}

struct CountTile: View {
    let value: String
    let label: String
    var tint: Color = Palette.accent

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - HUD widgets

/// What the interface is showing right now. In the designer this holds
/// believable sample values; in play it holds the real ones.
struct HUDState: Equatable {
    var health: Int = 6
    var maxHealth: Int = 6
    var stamina: Float = 1
    var magic: Float = 1
    var coins: Int = 0
    var keys: Int = 0
    var timeText: String = "0:00"
    var objectives: [String] = []
    var heroPoint = CGPoint(x: 0.5, y: 0.5)
    var portalPoint = CGPoint(x: 0.78, y: 0.26)
    var baddiePoints: [CGPoint] = []
    var bossHealth: Float? = nil
    var flashHealth = false

    static let preview = HUDState(
        health: 4,
        maxHealth: 6,
        stamina: 0.72,
        magic: 1,
        coins: 12,
        keys: 1,
        timeText: "0:42",
        objectives: ["Find the gold key", "Open the big door"],
        heroPoint: CGPoint(x: 0.34, y: 0.66),
        portalPoint: CGPoint(x: 0.78, y: 0.26),
        baddiePoints: [CGPoint(x: 0.48, y: 0.44), CGPoint(x: 0.66, y: 0.58)],
        bossHealth: 0.6,
        flashHealth: false
    )
}

struct HUDWidgetView: View {
    let widget: HUDWidget
    var isSelected: Bool = false
    var state: HUDState = .preview

    private var stat: BindableStat? { StatLibrary.stat(widget.binding) }

    private var fraction: CGFloat {
        if widget.kind == .bossBar {
            return CGFloat(min(1, max(0, state.bossHealth ?? 0)))
        }
        switch widget.binding {
        case "health":
            return state.maxHealth > 0 ? CGFloat(state.health) / CGFloat(state.maxHealth) : 0
        case "stamina":
            return CGFloat(min(1, max(0, state.stamina)))
        case "magic":
            return CGFloat(min(1, max(0, state.magic)))
        default:
            return 1
        }
    }

    private var counterValue: Int {
        switch widget.binding {
        case "coins": return state.coins
        case "keys": return state.keys
        default: return 0
        }
    }

    var body: some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Palette.accent : Color.clear, lineWidth: 2.5)
                    .padding(-4)
            )
    }

    @ViewBuilder
    private var content: some View {
        switch widget.kind {
        case .bar, .bossBar:
            bar
        case .counter:
            counter
        case .inventoryGrid:
            inventory
        case .minimap:
            minimap
        case .objectiveList:
            objectives
        case .dialogue:
            dialogue
        case .pauseButton:
            pauseButton
        case .timer:
            timer
        case .tutorial:
            tutorial
        }
    }

    private var bar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.45))
                Capsule()
                    .fill(widget.fill)
                    .frame(width: max(4, geo.size.width * fraction))
                if widget.binding == "health" && state.flashHealth && widget.kind != .bossBar {
                    Capsule()
                        .fill(Color.white.opacity(0.8))
                        .frame(width: max(4, geo.size.width * fraction))
                }
                HStack(spacing: 5) {
                    Image(systemName: stat?.symbol ?? "heart.fill")
                        .font(.system(size: 11, weight: .bold))
                    if !widget.label.isEmpty {
                        Text(widget.label)
                            .font(.system(size: 11, weight: .heavy))
                    }
                    Spacer(minLength: 2)
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(.system(size: 10, weight: .bold))
                }
                .padding(.horizontal, 9)
                .foregroundStyle(.white)
            }
        }
    }

    private var counter: some View {
        HStack(spacing: 6) {
            Image(systemName: stat?.symbol ?? "circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(widget.fill)
            Text("× \(counterValue)")
                .font(.system(size: 12, weight: .heavy).monospacedDigit())
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .background(Capsule().fill(Color.black.opacity(0.45)))
    }

    private var inventory: some View {
        HStack(spacing: 5) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.black.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                    )
            }
        }
    }

    private var minimap: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.42))
            Canvas { context, size in
                let radius = min(size.width, size.height) * 0.44
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                let island = CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)

                context.fill(Path(ellipseIn: island), with: .color(Color.white.opacity(0.10)))
                context.stroke(Path(ellipseIn: island), with: .color(Color.white.opacity(0.32)), lineWidth: 1.5)

                let portal = mapPoint(state.portalPoint, centre: centre, radius: radius)
                context.fill(
                    Path(ellipseIn: CGRect(x: portal.x - 4, y: portal.y - 4, width: 8, height: 8)),
                    with: .color(widget.fill)
                )

                for point in state.baddiePoints {
                    let spot = mapPoint(point, centre: centre, radius: radius)
                    context.fill(
                        Path(ellipseIn: CGRect(x: spot.x - 2.5, y: spot.y - 2.5, width: 5, height: 5)),
                        with: .color(Palette.coral)
                    )
                }

                let hero = mapPoint(state.heroPoint, centre: centre, radius: radius)
                let heroRect = CGRect(x: hero.x - 4, y: hero.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: heroRect), with: .color(.white))
                context.stroke(Path(ellipseIn: heroRect), with: .color(Color.black.opacity(0.55)), lineWidth: 1.5)
            }
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
        }
    }

    private func mapPoint(_ point: CGPoint, centre: CGPoint, radius: CGFloat) -> CGPoint {
        CGPoint(x: centre.x + (point.x - 0.5) * radius * 2,
                y: centre.y + (point.y - 0.5) * radius * 2)
    }

    private var objectives: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "list.bullet").font(.system(size: 10, weight: .bold))
                Text("TO DO").font(.system(size: 9, weight: .black)).kerning(0.6)
            }
            .foregroundStyle(widget.fill)

            let goals = Array(state.objectives.prefix(2))
            if goals.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "circle").font(.system(size: 8, weight: .bold))
                    Text("No goals yet").font(.system(size: 11, weight: .semibold))
                }
            } else {
                ForEach(Array(goals.enumerated()), id: \.offset) { _, goal in
                    HStack(spacing: 5) {
                        Image(systemName: "circle").font(.system(size: 8, weight: .bold))
                        Text(goal)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(.white)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.45)))
    }

    private var dialogue: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Mira")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(widget.fill)
            Text("A key? The guard dropped one by the well.")
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.black.opacity(0.55)))
    }

    private var pauseButton: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.45))
            Image(systemName: "pause.fill")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(.white)
        }
    }

    private var timer: some View {
        HStack(spacing: 5) {
            Image(systemName: "timer").font(.system(size: 11, weight: .bold))
            Text(state.timeText).font(.system(size: 12, weight: .heavy).monospacedDigit())
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Capsule().fill(Color.black.opacity(0.45)))
    }

    private var tutorial: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.tap.fill").font(.system(size: 12, weight: .bold))
            Text("Move with the stick").font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Capsule().fill(Color.black.opacity(0.5)))
    }
}
