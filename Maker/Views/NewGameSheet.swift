//
//  NewGameSheet.swift
//  Maker
//

import SwiftUI

struct NewGameSheet: View {
    @EnvironmentObject private var store: MakerStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedTemplate: GameTemplate = TemplateLibrary.all[0]

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 220), spacing: 12)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    nameSection
                    templateSection
                }
                .padding(20)
            }
            .background(Palette.background)
            .navigationTitle("New game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.createProject(name: title.isEmpty ? selectedTemplate.name : title,
                                            template: selectedTemplate)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .tint(Palette.accent)
                }
            }
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            FieldLabel(text: "What is it called?")
            TextField("Castle Adventure", text: $name)
                .font(.title3.weight(.semibold))
                .textFieldStyle(.plain)
                .padding(14)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .autocorrectionDisabled()
        }
    }

    private var templateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FieldLabel(text: "Start with")
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(TemplateLibrary.all) { template in
                    Button {
                        withAnimation(.snappy(duration: 0.15)) { selectedTemplate = template }
                    } label: {
                        HStack(spacing: 10) {
                            IconBadge(symbol: template.symbol, tint: Color(hex: template.colorHex), size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Palette.ink)
                                Text(template.blurb)
                                    .font(.caption2)
                                    .foregroundStyle(Palette.inkSoft)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            if template.id == selectedTemplate.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(hex: template.colorHex))
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    template.id == selectedTemplate.id ? Color(hex: template.colorHex) : Palette.hairline.opacity(0.4),
                                    lineWidth: template.id == selectedTemplate.id ? 2 : 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    NewGameSheet()
        .environmentObject(MakerStore())
}
