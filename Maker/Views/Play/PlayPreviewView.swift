//
//  PlayPreviewView.swift
//  Maker
//
//  Play: the hero on the island, seen over their shoulder, with the game's
//  own interface on top. Touch or a paired controller.
//

import SwiftUI

struct PlayPreviewView: View {
    @EnvironmentObject private var store: MakerStore
    var onExit: () -> Void = { }
    var onNextLevel: ((GameLevel) -> Void)? = nil
    var onQuit: () -> Void = { }

    @State private var input = PlayInput()
    @State private var finished = false
    @State private var elapsed: TimeInterval = 0
    @State private var paused = false
    @State private var bubble: String?
    @State private var stickOffset = CGSize.zero
    @State private var lastCameraDrag = CGSize.zero
    @State private var pinchStartDistance: Float?
    @State private var resetToken = 0
    @State private var log: [String] = []
    @State private var showsLog = true
    @State private var hearts = 6
    @State private var coins = 0
    @State private var keys = 0
    @State private var hud = HUDState()
    @State private var dead = false
    @State private var deathCause = ""
    @State private var deathHadCheckpoint = false
    @State private var respawnToken = 0
    @State private var conversation: ConversationState?

    private struct ConversationState {
        var speaker: String
        var lines: [ConversationLine]
        var index: Int = 0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let project = store.currentProject, let level = store.currentLevel {
                    HeroPlayScene(
                        level: level,
                        project: project,
                        input: input,
                        resetToken: resetToken,
                        respawnToken: respawnToken,
                        onFinish: { time in
                            elapsed = time
                            withAnimation(.snappy) { finished = true }
                        },
                        onPause: {
                            paused = true
                        },
                        onMessage: { text in
                            log.append(text)
                            if log.count > 40 {
                                log.removeFirst()
                            }
                        },
                        onStatus: { newHearts, newCoins, newKeys in
                            hearts = newHearts
                            coins = newCoins
                            keys = newKeys
                        },
                        onHUD: { newState in
                            hud = newState
                        },
                        onDeath: { reason, hasCheckpoint in
                            deathCause = reason
                            deathHadCheckpoint = hasCheckpoint
                            withAnimation(.snappy) { dead = true }
                        },
                        onConversation: { speaker, lines in
                            openConversation(speaker, lines)
                        }
                    )
                    .ignoresSafeArea()

                    cameraLayer
                    hud(project: project, in: geo.size)
                    joystick
                    actionButtons(project: project)
                    logPanel
                    topBar(level: level, project: project)

                    if finished {
                        outro(level: level)
                    }
                    if paused {
                        pauseCard
                    }
                    if dead {
                        tryAgainCard
                    }
                    if let conversation {
                        conversationCard(conversation)
                    }
                    bubbleView
                } else {
                    noLevel
                }
            }
        }
        .statusBarHidden()
        .onChange(of: paused) { _, newValue in
            input.isPaused = newValue
        }
    }

    // MARK: Camera gestures

    private var cameraLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard !finished, !paused else { return }
                        let dx = value.translation.width - lastCameraDrag.width
                        lastCameraDrag = value.translation
                        input.cameraYaw -= Float(dx) * 0.006
                    }
                    .onEnded { _ in
                        lastCameraDrag = .zero
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        guard !finished, !paused else { return }
                        if pinchStartDistance == nil {
                            pinchStartDistance = input.cameraDistance
                        }
                        let start = pinchStartDistance ?? input.cameraDistance
                        input.cameraDistance = min(11, max(2.8, start / Float(max(value.magnification, 0.05))))
                    }
                    .onEnded { _ in
                        pinchStartDistance = nil
                    }
            )
    }

    // MARK: Interface

    private func hud(project: GameProject, in size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(project.hud.widgets) { widget in
                HUDWidgetView(widget: widget, state: hud)
                    .frame(width: widget.width, height: widget.height)
                    .position(x: pointX(widget, in: size), y: pointY(widget, in: size))
            }
        }
        .allowsHitTesting(false)
        .opacity(finished ? 0.3 : 1)
    }

    private var joystick: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.22))
            Circle()
                .strokeBorder(Color.white.opacity(0.45), lineWidth: 2)
            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: 54, height: 54)
                .offset(stickOffset)
        }
        .frame(width: 132, height: 132)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !finished, !paused else { return }
                    let limit: CGFloat = 40
                    let dx = max(-limit, min(limit, value.translation.width))
                    let dy = max(-limit, min(limit, value.translation.height))
                    stickOffset = CGSize(width: dx, height: dy)
                    input.touchMove = SIMD2<Float>(Float(dx / limit), Float(-dy / limit))
                }
                .onEnded { _ in
                    stickOffset = .zero
                    input.touchMove = SIMD2<Float>(0, 0)
                }
        )
        .padding(.leading, 32)
        .padding(.bottom, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private func actionButtons(project: GameProject) -> some View {
        let canJump = project.enabledActions.contains("jump")
        let canAttack = project.enabledActions.contains("swordLight") || project.enabledActions.contains("punch")
        let canUse = project.enabledActions.contains("pickUp")
            || project.enabledActions.contains("open")
            || project.enabledActions.contains("talk")

        return VStack(alignment: .trailing, spacing: 14) {
            HStack(spacing: 12) {
                circleButton(symbol: "hand.raised.fill", locked: !canUse, tint: Palette.sky, size: 56) {
                    if canUse {
                        input.use = true
                    } else {
                        show("Use is turned off. Turn “pick up”, “open” or “talk” on in Actions.")
                    }
                }
                circleButton(symbol: "bolt.fill", locked: !canAttack, tint: Palette.coral, size: 56) {
                    if canAttack {
                        input.attack = true
                    } else {
                        show("Attacking is turned off. Turn “punch” or “swing sword” on in Actions.")
                    }
                }
            }
            circleButton(symbol: "arrow.up", locked: !canJump, tint: Palette.mint, size: 74) {
                if canJump {
                    input.jump = true
                } else {
                    show("Jump is turned off. Turn “jump” on in Actions.")
                }
            }
        }
        .padding(.trailing, 22)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
    }

    private func circleButton(symbol: String, locked: Bool, tint: Color, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(locked ? Color.black.opacity(0.28) : tint.opacity(0.88))
                Circle()
                    .strokeBorder(Color.white.opacity(locked ? 0.22 : 0.6), lineWidth: 2)
                Image(systemName: locked ? "lock.fill" : symbol)
                    .font(.system(size: size * 0.32, weight: .bold))
                    .foregroundStyle(.white.opacity(locked ? 0.65 : 1))
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }

    private func topBar(level: GameLevel, project: GameProject) -> some View {
        VStack {
            HStack(spacing: 10) {
                Button {
                    onExit()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.28), in: Circle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text(level.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(project.name)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.25), in: Capsule())

                Spacer(minLength: 8)

                Button {
                    withAnimation(.snappy) { showsLog.toggle() }
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(showsLog ? Color.white : Color.white.opacity(0.6))
                        .frame(width: 40, height: 40)
                        .background(showsLog ? Palette.accent.opacity(0.9) : Color.black.opacity(0.28), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("What's happening")

                Button {
                    paused = true
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.28), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
    }

    // MARK: Cards

    private func outro(level: GameLevel) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Palette.accent)
            Text("Level complete!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("You reached the portal in \(level.name).")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                stat(value: timeText, label: "Time")
                stat(value: "\(coins)", label: "Coins")
                stat(value: "\(level.objectives.count)", label: "Goals")
            }
            .padding(.vertical, 2)

            HStack(spacing: 10) {
                Button("Back to maker") { onExit() }
                    .buttonStyle(.bordered)
                if level.nextLevelID != nil {
                    Button("Next level") { advance(level) }
                        .buttonStyle(.borderedProminent)
                        .tint(Palette.accent)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: 400)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        .padding(24)
    }

    // MARK: Conversation

    private func openConversation(_ speaker: String, _ lines: [ConversationLine]) {
        guard !lines.isEmpty, conversation == nil else { return }
        conversation = ConversationState(speaker: speaker, lines: lines)
        input.isPaused = true
    }

    private func advanceConversation() {
        guard var current = conversation else { return }
        current.index += 1
        if current.index >= current.lines.count {
            conversation = nil
            input.isPaused = paused
        } else {
            conversation = current
        }
    }

    private func conversationCard(_ state: ConversationState) -> some View {
        let line = state.lines[state.index]

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(line.isHero ? Palette.accent : Palette.sky)
                        .frame(width: 34, height: 34)
                    Image(systemName: line.isHero ? "figure.stand" : "bubble.left.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(line.isHero ? "You" : state.speaker)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.ink)

                Spacer(minLength: 0)

                Text("\(state.index + 1) / \(state.lines.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Palette.inkFaint)
            }

            Text(line.words.isEmpty ? "…" : line.words)
                .font(.subheadline)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if line.replies.isEmpty {
                Button {
                    advanceConversation()
                } label: {
                    Text("Continue")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Palette.accent, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            } else {
                ForEach(Array(line.replies.enumerated()), id: \.offset) { _, reply in
                    Button {
                        advanceConversation()
                    } label: {
                        Text(reply.isEmpty ? "…" : reply)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(Palette.ink)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: 420)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var tryAgainCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Palette.coral)

            Text("You fell over")
                .font(.system(size: 26, weight: .bold, design: .rounded))

            Text(deathCause.isEmpty ? "Something got you." : "\(deathCause).")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)

            Button {
                dead = false
                respawnToken += 1
            } label: {
                Text(deathHadCheckpoint ? "Try again from the checkpoint" : "Try again from the start")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Palette.accent, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            Button("Back to the maker") { onQuit() }
                .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        .padding(24)
    }

    private var pauseCard: some View {
        VStack(spacing: 12) {
            Text("Paused")
                .font(.title2.bold())
            Text("Take your time.")
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)

            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.caption)
                Slider(value: Binding(get: { Double(AudioEngine.shared.volume) },
                                      set: { AudioEngine.shared.volume = Float($0) }), in: 0...1)
                    .tint(Palette.accent)
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption)
            }
            .foregroundStyle(Palette.inkSoft)
            .padding(.horizontal, 6)

            Button("Keep playing") { paused = false }
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
            Button("Start this level again") { restart() }
                .buttonStyle(.bordered)
            Button("Back to the maker") { onQuit() }
                .buttonStyle(.bordered)
            Button("Back to the title") { onExit() }
                .buttonStyle(.bordered)
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
    }

    @ViewBuilder
    private var bubbleView: some View {
        if let bubble {
            VStack {
                Spacer()
                Text(bubble)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: 320)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 200)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var logPanel: some View {
        if showsLog {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text("WHAT'S HAPPENING")
                        .font(.system(size: 9, weight: .black))
                        .kerning(0.6)
                        .foregroundStyle(.white.opacity(0.65))
                    Spacer(minLength: 0)
                    HStack(spacing: 7) {
                        statusPill("heart.fill", hearts)
                        statusPill("circle.fill", coins)
                        statusPill("key.fill", keys)
                    }
                }

                let recent = Array(log.suffix(6).reversed())
                if recent.isEmpty {
                    Text("Nothing has happened yet.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                } else {
                    ForEach(Array(recent.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(10)
            .frame(width: 236, alignment: .leading)
            .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            )
            .padding(.leading, 14)
            .padding(.bottom, 208)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .transition(.opacity)
        }
    }

    private func statusPill(_ symbol: String, _ value: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
            Text("\(value)")
                .font(.system(size: 10, weight: .bold).monospacedDigit())
        }
        .foregroundStyle(.white)
    }

    private var noLevel: some View {
        VStack(spacing: 14) {
            Text("No level to play")
                .font(.title2.bold())
                .foregroundStyle(.white)
            Button("Close") { onExit() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(Palette.inkSoft)
        }
        .frame(width: 86)
        .padding(.vertical, 8)
        .background(Palette.surfaceAlt, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Behaviour

    private var timeText: String {
        let total = Int(elapsed.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func advance(_ level: GameLevel) {
        guard let nextID = level.nextLevelID,
              let next = store.currentProject?.level(with: nextID) else { return }

        if let onNextLevel {
            onNextLevel(next)
            return
        }

        store.selectedLevelID = nextID
        finished = false
        elapsed = 0
        log.removeAll()
        resetToken += 1
    }

    private func restart() {
        resetToken += 1
        finished = false
        elapsed = 0
        log.removeAll()
        paused = false
    }

    private func show(_ message: String) {
        withAnimation(.snappy) { bubble = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            withAnimation(.snappy) { bubble = nil }
        }
    }

    private func pointX(_ widget: HUDWidget, in size: CGSize) -> CGFloat {
        let pad: CGFloat = 22
        let half = widget.width / 2 + pad
        switch widget.anchor {
        case .topLeading, .bottomLeading: return half + widget.offsetX
        case .top, .bottom, .center: return size.width / 2 + widget.offsetX
        case .topTrailing, .bottomTrailing: return size.width - half + widget.offsetX
        }
    }

    private func pointY(_ widget: HUDWidget, in size: CGSize) -> CGFloat {
        let pad: CGFloat = 22
        let half = widget.height / 2 + pad
        switch widget.anchor {
        case .topLeading, .top, .topTrailing: return half + widget.offsetY + 58
        case .bottomLeading, .bottom, .bottomTrailing: return size.height - half + widget.offsetY - 150
        case .center: return size.height / 2 + widget.offsetY
        }
    }
}
