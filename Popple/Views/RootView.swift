import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @AppStorage("hasSeenCatchCoachMark") private var hasSeenCoachMark = false
    @State private var showOnboarding = false
    @State private var selection = Tab.grove
    @Query private var catches: [Catch]

    private enum Tab: Hashable { case grove, map, catchTab, journal }

    /// Point new players at the Catch button until they've used it — but only
    /// once onboarding is done and the Grove is still empty.
    private var showCoachMark: Bool {
        hasOnboarded && !hasSeenCoachMark && catches.isEmpty && selection != .catchTab
    }

    var body: some View {
        TabView(selection: $selection) {
            GroveView()
                .tabItem { Label("Grove", systemImage: "leaf.fill") }
                .tag(Tab.grove)

            DiscoveryMapView()
                .tabItem { Label("Map", systemImage: "map.fill") }
                .tag(Tab.map)

            CatchView()
                .tabItem { Label("Catch", systemImage: "camera.fill") }
                .tag(Tab.catchTab)

            ProfileView()
                .tabItem { Label("Journal", systemImage: "book.closed.fill") }
                .tag(Tab.journal)
        }
        .overlay(alignment: .bottom) {
            if showCoachMark {
                CatchCoachMark {
                    withAnimation { selection = .catchTab }
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showCoachMark)
        .onChange(of: selection) { _, newValue in
            if newValue == .catchTab { hasSeenCoachMark = true }
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
