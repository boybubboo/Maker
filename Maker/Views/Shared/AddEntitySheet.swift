//
//  AddEntitySheet.swift
//  Maker
//

import SwiftUI

struct AddEntitySheet: View {
    @EnvironmentObject private var store: MakerStore
    @Environment(\.dismiss) private var dismiss

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 110, maximum: 160), spacing: 10)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(EntitySection.allCases) { section in
                        let kinds = section.memberKinds.filter { $0.isAddable }
                        if !kinds.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: section.symbol)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Palette.inkSoft)
                                    Text(section.title)
                                        .font(.subheadline.bold())
                                }
                                Text(section.blurb)
                                    .font(.caption2)
                                    .foregroundStyle(Palette.inkSoft)

                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach(kinds) { kind in
                                        Button {
                                            store.addEntity(kind)
                                            dismiss()
                                        } label: {
                                            KindTile(kind: kind)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Palette.background)
            .navigationTitle("Add something")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct KindTile: View {
    let kind: EntityKind

    var body: some View {
        VStack(spacing: 7) {
            IconBadge(symbol: kind.symbol, tint: kind.tint, size: 42)
            Text(kind.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Palette.hairline.opacity(0.4), lineWidth: 1)
        )
    }
}

#Preview {
    AddEntitySheet()
        .environmentObject(MakerStore())
}
