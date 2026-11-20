//
//  RootView.swift
//  Maker
//

import SwiftUI

struct RootView: View {
    @StateObject private var store = MakerStore()

    var body: some View {
        ZStack {
            if store.openProjectID == nil {
                ProjectBrowserView()
            } else {
                EditorShellView()
            }
        }
        .environmentObject(store)
        .onOpenURL { url in
            _ = store.importSharedGame(from: url)
        }
        .animation(.snappy(duration: 0.25), value: store.openProjectID)
        .sheet(isPresented: $store.showingNewGame) {
            NewGameSheet()
                .environmentObject(store)
        }
        .task(id: store.toast) {
            guard store.toast != nil else { return }
            try? await Task.sleep(for: .seconds(2.4))
            withAnimation(.snappy) { store.toast = nil }
        }
        .overlay(alignment: .bottom) {
            if let message = store.toast {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Palette.hairline.opacity(0.5), lineWidth: 1))
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

#Preview {
    RootView()
}
