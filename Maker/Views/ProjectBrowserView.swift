//
//  ProjectBrowserView.swift
//  Maker
//
//  The front door: the games on this device and a shelf of templates.
//

import SwiftUI
import UniformTypeIdentifiers

struct ProjectBrowserView: View {
    @EnvironmentObject private var store: MakerStore
    @Environment(\.horizontalSizeClass) private var horizontalSize

    @State private var importing = false
    @State private var importProblem: String?

    private var sharedType: UTType {
        UTType(filenameExtension: GameSharing.fileExtension) ?? .data
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 250, maximum: 420), spacing: 16)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                if let importProblem {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(Palette.amber)
                        Text(importProblem)
                            .font(.caption)
                        Spacer(minLength: 8)
                        Button("Dismiss") { self.importProblem = nil }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.accent)
                    }
                    .padding(11)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                gamesSection
                templatesSection
                footer
            }
            .padding(.horizontal, horizontalSize == .compact ? 18 : 30)
            .padding(.vertical, 22)
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.background)
        .fileImporter(isPresented: $importing,
                      allowedContentTypes: [sharedType],
                      allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if !store.importSharedGame(from: url) {
                    importProblem = "That file isn't a Maker game. Look for a file ending in .makergame."
                }
            case .failure:
                importProblem = "That file couldn't be opened."
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "cube.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(Palette.accent, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("Maker")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .lineLimit(1)
                Text("Build a 3D adventure. No code needed.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 6)

            Button {
                importing = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "square.and.arrow.down").font(.system(size: 14, weight: .bold))
                    Text("Open").font(.subheadline.weight(.bold))
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Palette.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(Palette.hairline.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                store.showingNewGame = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                    Text("New game").font(.subheadline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Palette.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Games

    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your games").font(.title3.bold())
                Spacer()
                Text("\(store.projects.count) saved on this device")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }

            if store.projects.isEmpty {
                EmptyHint(
                    symbol: "cube.fill",
                    title: "No games yet",
                    message: "Pick a template and make it yours. Everything saves as you go.",
                    actionTitle: "Start a game"
                ) {
                    store.showingNewGame = true
                }
                .makerCard()
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(store.projects) { project in
                        Button {
                            store.open(project.id)
                        } label: {
                            ProjectCard(project: project)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                store.open(project.id)
                            } label: {
                                Label("Open", systemImage: "arrow.up.right")
                            }
                            Button {
                                store.duplicateProject(project.id)
                            } label: {
                                Label("Make a copy", systemImage: "plus.square.on.square")
                            }
                            Divider()
                            Button(role: .destructive) {
                                store.deleteProject(project.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Templates

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Start from a template").font(.title3.bold())
                Spacer()
                Text("Tap to make it yours")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(TemplateLibrary.all) { template in
                        Button {
                            store.createProject(name: template.name, template: template)
                        } label: {
                            TemplateCard(template: template)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "internaldrive.fill")
                .font(.caption)
            Text("Your games are saved on this device. Nothing leaves it.")
                .font(.caption)
        }
        .foregroundStyle(Palette.inkFaint)
        .padding(.top, 4)
    }
}

// MARK: - Cards

private struct ProjectCard: View {
    let project: GameProject

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                IconBadge(symbol: project.symbol, tint: project.tint, size: 52)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.inkFaint)
            }

            Spacer(minLength: 6)

            Text(project.name)
                .font(.title3.bold())
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                Pill(text: "\(project.levelCount) level\(project.levelCount == 1 ? "" : "s")",
                     symbol: "map.fill",
                     tint: project.tint)
                if let sharedBy = project.sharedBy {
                    Pill(text: "From \(sharedBy)", symbol: "shippingbox.fill", tint: Palette.plum)
                } else {
                    Pill(text: project.updatedText, symbol: "clock", tint: Palette.inkSoft)
                }
            }
        }
        .padding(18)
        .frame(height: 200, alignment: .topLeading)
        .frame(maxWidth: .infinity)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Palette.hairline.opacity(0.45), lineWidth: 1)
        )
    }
}

private struct TemplateCard: View {
    let template: GameTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            IconBadge(symbol: template.symbol, tint: Color(hex: template.colorHex), size: 44)
            Text(template.name)
                .font(.subheadline.bold())
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
            Text(template.blurb)
                .font(.caption)
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill").font(.caption2)
                Text("Use").font(.caption.weight(.bold))
            }
            .foregroundStyle(Color(hex: template.colorHex))
        }
        .padding(14)
        .frame(width: 192, height: 168, alignment: .topLeading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Palette.hairline.opacity(0.45), lineWidth: 1)
        )
    }
}

#Preview {
    ProjectBrowserView()
        .environmentObject(MakerStore())
}
