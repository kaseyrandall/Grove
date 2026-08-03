import SwiftUI

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @State private var showOnboarding = false

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
        .onAppear {
            if !hasOnboarded { showOnboarding = true }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView {
                hasOnboarded = true
                showOnboarding = false
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Catch.self, inMemory: true)
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
