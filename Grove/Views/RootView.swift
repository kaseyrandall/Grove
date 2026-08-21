import SwiftUI
import SwiftData

/// The app's five destinations. Catch is reached via the floating center button.
enum RootTab: Hashable {
    case grove, map, catchTab, journal, profile
}

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @AppStorage("hasSeenCatchCoachMark") private var hasSeenCoachMark = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: RootTab = .grove
    @State private var tabBarVisible = true
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
            case .catchTab: CatchView(onFinished: {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { selection = .grove }
            })
            case .journal:  JournalView()
            case .profile:  ProfileView()
            }
        }
        // Cross-fade between tabs instead of an instant swap.
        .id(selection)
        .transition(.opacity)
        // A pushed child screen can tuck the bar away via `.groveTabBarHidden()`.
        .onPreferenceChange(TabBarVisibilityKey.self) { visible in
            withAnimation(.easeInOut(duration: 0.25)) { tabBarVisible = visible }
        }
        // The bar floats over content; each scrollable page adds
        // `Theme.tabBarClearance` bottom padding so its content clears it.
        .overlay(alignment: .bottom) {
            GroveTabBar(
                selection: $selection,
                showCoachMark: showCoachMark,
                onCatch: { withAnimation(.easeInOut(duration: 0.22)) { selection = .catchTab } }
            )
            .offset(y: tabBarVisible ? 0 : 160)
            .opacity(tabBarVisible ? 1 : 0)
            .allowsHitTesting(tabBarVisible)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showCoachMark)
        .onChange(of: selection) { _, newValue in
            if newValue == .catchTab { hasSeenCoachMark = true }
        }
        // Retention reminders: reschedule on launch, when a catch lands, and
        // whenever we come back to the foreground.
        .task { refreshReminders() }
        .onChange(of: catches.count) { _, _ in refreshReminders() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshReminders() }
        }
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView { hasOnboarded = true }
        }
    }

    private func refreshReminders() {
        NotificationManager.refresh(catches: catches, enabled: notificationsEnabled)
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
        .modelContainer(for: Catch.self, inMemory: true)
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
