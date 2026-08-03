import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            GroveView()
                .tabItem { Label("Grove", systemImage: "leaf.fill") }

            DiscoveryMapView()
                .tabItem { Label("Map", systemImage: "map.fill") }

            CatchView()
                .tabItem { Label("Catch", systemImage: "camera.fill") }

            ProfileView()
                .tabItem { Label("Journal", systemImage: "book.closed.fill") }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Catch.self, inMemory: true)
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
