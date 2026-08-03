import SwiftUI
import SwiftData

/// The app's five destinations. Catch is reached via the floating center button.
enum RootTab: Hashable {
    case grove, map, catchTab, journal, profile
}

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @AppStorage("hasSeenCatchCoachMark") private var hasSeenCoachMark = false
    @State private var selection: RootTab = .grove
    @Query private var catches: [Catch]

    /// Point new players at the Catch button until they've used it — but only
    /// once onboarding is done and the Grove is still empty.
    private var showCoachMark: Bool {
        hasOnboarded && !hasSeenCoachMark && catches.isEmpty && selection != .catchTab
    }

    var body: some View {
        Group {
            switch selection {
            case .grove:    GroveView()
            case .map:      DiscoveryMapView()
            case .catchTab: CatchView()
            case .journal:  JournalView()
            case .profile:  ProfileView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GroveTabBar(
                selection: $selection,
                showCoachMark: showCoachMark,
                onCatch: { selection = .catchTab }
            )
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showCoachMark)
        .onChange(of: selection) { _, newValue in
            if newValue == .catchTab { hasSeenCoachMark = true }
        }
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView { hasOnboarded = true }
        }
    }

    /// Presents onboarding whenever it hasn't been completed — so "Replay the
    /// intro" in Settings (which clears the flag) brings it right back.
    private var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !hasOnboarded },
            set: { presenting in if !presenting { hasOnboarded = true } }
        )
    }
}

#Preview {
    RootView()
        .modelContainer(for: [Catch.self, FriendProfile.self], inMemory: true)
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
