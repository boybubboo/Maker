//
//  Theme.swift
//  Maker
//
//  Colour, surfaces and type used across the maker.
//

import SwiftUI

extension Color {
    init(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if text.hasPrefix("#") { text.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: text).scanHexInt64(&value)
        let r: Double
        let g: Double
        let b: Double
        let a: Double
        if text.count == 8 {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

enum Palette {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let surfaceAlt = Color(uiColor: .tertiarySystemGroupedBackground)
    static let sidebar = Color(uiColor: .secondarySystemGroupedBackground)
    static let ink = Color(uiColor: .label)
    static let inkSoft = Color(uiColor: .secondaryLabel)
    static let inkFaint = Color(uiColor: .tertiaryLabel)
    static let hairline = Color(uiColor: .separator)

    static let accent = Color(hex: "#6C4CF1")
    static let plum = Color(hex: "#9B5DE5")
    static let amber = Color(hex: "#FF9F1C")
    static let mint = Color(hex: "#22B573")
    static let coral = Color(hex: "#F2545B")
    static let sky = Color(hex: "#3AA0FF")
    static let gold = Color(hex: "#F2C230")
}

// MARK: - Surfaces

struct MakerCardStyle: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Palette.hairline.opacity(0.5), lineWidth: 1)
            )
    }
}

extension View {
    func makerCard(padding: CGFloat = 18) -> some View {
        modifier(MakerCardStyle(padding: padding))
    }
}

// MARK: - Small pieces

struct FieldLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.heavy))
            .kerning(0.8)
            .foregroundStyle(Palette.inkFaint)
    }
}

struct IconBadge: View {
    let symbol: String
    var tint: Color = Palette.accent
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.44, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }
}

struct Pill: View {
    let text: String
    var symbol: String? = nil
    var tint: Color = Palette.inkSoft

    var body: some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol).font(.caption2.weight(.bold))
            }
            Text(text).font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

struct SectionTitle: View {
    let text: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text).font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
