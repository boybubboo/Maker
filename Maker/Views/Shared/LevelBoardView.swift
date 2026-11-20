//
//  LevelBoardView.swift
//  Maker
//
//  A small board that shows the shape of a level: ground, water, path,
//  the start, the portal and everything living in it.
//

import SwiftUI

struct LevelBoardView: View {
    let level: GameLevel
    var selectedEntityID: UUID? = nil
    var interactive: Bool = true
    var showsPins: Bool = true
    var onSelect: ((UUID) -> Void)? = nil

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height

            ZStack {
                Rectangle().fill(level.biome.ground)

                Ellipse()
                    .fill(level.biome.water.opacity(0.92))
                    .frame(width: width * 0.56, height: height * 0.62)
                    .offset(x: -width * 0.36, y: height * 0.42)

                Ellipse()
                    .fill(level.biome.detail.opacity(0.45))
                    .frame(width: width * 0.52, height: height * 0.52)
                    .offset(x: width * 0.24, y: -height * 0.30)

                Ellipse()
                    .fill(level.biome.detail.opacity(0.32))
                    .frame(width: width * 0.38, height: height * 0.34)
                    .offset(x: -width * 0.16, y: -height * 0.32)

                Path { path in
                    path.move(to: CGPoint(x: width * 0.12, y: height * 0.82))
                    path.addCurve(
                        to: CGPoint(x: width * 0.88, y: height * 0.24),
                        control1: CGPoint(x: width * 0.34, y: height * 0.58),
                        control2: CGPoint(x: width * 0.62, y: height * 0.72)
                    )
                }
                .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 9, lineCap: .round, dash: [1, 14]))

                Canvas { context, size in
                    var grid = Path()
                    let step: CGFloat = 30
                    var x: CGFloat = 0
                    while x < size.width {
                        grid.move(to: CGPoint(x: x, y: 0))
                        grid.addLine(to: CGPoint(x: x, y: size.height))
                        x += step
                    }
                    var y: CGFloat = 0
                    while y < size.height {
                        grid.move(to: CGPoint(x: 0, y: y))
                        grid.addLine(to: CGPoint(x: size.width, y: y))
                        y += step
                    }
                    context.stroke(grid, with: .color(.white.opacity(0.12)), lineWidth: 1)
                }

                if showsPins {
                    ForEach(level.entities) { entity in
                        entityPin(entity, width: width, height: height)
                    }
                    markerPin(symbol: "flag.fill", tint: Color(hex: "#1F8A5B"), x: 0.12, y: 0.82, width: width, height: height)
                    markerPin(symbol: "sparkles", tint: Palette.accent, x: 0.88, y: 0.24, width: width, height: height)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private func entityPin(_ entity: LevelEntity, width: CGFloat, height: CGFloat) -> some View {
        let isSelected = entity.id == selectedEntityID
        return Button {
            onSelect?(entity.id)
        } label: {
            ZStack {
                Circle()
                    .fill(entity.tint)
                    .frame(width: isSelected ? 34 : 28, height: isSelected ? 34 : 28)
                Image(systemName: entity.kind.symbol)
                    .font(.system(size: isSelected ? 14 : 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2))
            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(!interactive)
        .position(x: width * entity.position.x, y: height * entity.position.y)
    }

    private func markerPin(symbol: String, tint: Color, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(tint)
                .frame(width: 30, height: 30)
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
        .shadow(color: .black.opacity(0.22), radius: 4, y: 2)
        .position(x: width * x, y: height * y)
        .allowsHitTesting(false)
    }
}
