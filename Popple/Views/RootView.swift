import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            DexView()
                .tabItem { Label("Dex", systemImage: "square.grid.2x2.fill") }

            CatchView()
                .tabItem { Label("Catch", systemImage: "camera.fill") }

            ProfileView()
                .tabItem { Label("Me", systemImage: "star.fill") }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Catch.self, inMemory: true)
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
