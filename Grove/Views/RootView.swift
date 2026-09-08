import SwiftUI
import SwiftData

/// The app's five destinations. Catch is reached via the floating center button.
enum RootTab: Hashable {
    case grove, map, catchTab, journal, profile
}

struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasOnboarded = false
    @AppStorage("hasSeenCatchCoachMark") private var hasSeenSnapCoach = false
    @AppStorage("hasSeenMeetCoach") private var hasSeenMeetCoach = false
    @AppStorage("hasSeenGoalCoach") private var hasSeenGoalCoach = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var quickActions = QuickActionRouter.shared
    @State private var selection: RootTab = .grove
    @State private var tabBarVisible = true
    @Query private var catches: [Catch]

    /// The one coach mark to show right now, if any. All three live on the Grove
    /// and each fires only when the player reaches the moment it teaches.
    private var currentCoachStep: CoachStep? {
        guard hasOnboarded, selection == .grove else { return nil }
        if !hasSeenSnapCoach, catches.isEmpty { return .snap }
        if !hasSeenMeetCoach, catches.count == 1 { return .meetFriend }
        if !hasSeenGoalCoach, !catches.isEmpty, hasSeenMeetCoach || catches.count > 1 { return .dailyGoal }
        return nil
    }

    var body: some View {
        // Content and the floating bar share a ZStack so both can register coach
        // anchors that reduce to a common parent (an `.overlay`'s preferences
        // wouldn't propagate to the reader below).
        ZStack(alignment: .bottom) {
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
            GroveTabBar(
                selection: $selection,
                onCatch: { withAnimation(.easeInOut(duration: 0.22)) { selection = .catchTab } }
            )
            .offset(y: tabBarVisible ? 0 : 160)
            .opacity(tabBarVisible ? 1 : 0)
            .allowsHitTesting(tabBarVisible)
        }
        // The active coach mark, pointed at whatever target tagged itself. Only
        // the bubble is opaque, so the rest of the UI stays fully interactive.
        .overlayPreferenceValue(CoachAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if let step = currentCoachStep, let anchor = anchors[step] {
                    CoachOverlay(
                        step: step,
                        targetRect: proxy[anchor],
                        container: proxy.size,
                        onDismiss: { dismissCoach(step) }
                    )
                }
            }
        }
        .onChange(of: selection) { _, newValue in
            if newValue == .catchTab { hasSeenSnapCoach = true }
        }
        // Retention reminders: reschedule on launch, when a catch lands, and
        // whenever we come back to the foreground.
        .task { refreshReminders() }
        .onChange(of: catches.count) { _, _ in refreshReminders() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshReminders()
                handleQuickAction() // a warm-launch shortcut may be waiting
            }
        }
        .onChange(of: quickActions.pending) { _, _ in handleQuickAction() }
        .onAppear { handleQuickAction() } // catch a cold-launch shortcut
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView { hasOnboarded = true }
        }
    }

    /// Consume a pending Home Screen quick action. "Snap a friend" jumps to the
    /// camera — but only once the player is past onboarding; otherwise we clear
    /// it so it can't fire behind the intro.
    private func handleQuickAction() {
        guard let action = quickActions.pending else { return }
        quickActions.pending = nil
        guard hasOnboarded else { return }
        switch action {
        case .snap:
            withAnimation(.easeInOut(duration: 0.22)) { selection = .catchTab }
            hasSeenSnapCoach = true
        }
    }

    private func refreshReminders() {
        NotificationManager.refresh(catches: catches, enabled: notificationsEnabled)
    }

    /// Dismiss the active coach mark. Snap jumps the player to Catch (and gets
    /// marked seen by the tab change); the others just fade away.
    private func dismissCoach(_ step: CoachStep) {
        withAnimation(.easeInOut(duration: 0.25)) {
            switch step {
            case .snap:       selection = .catchTab
            case .meetFriend: hasSeenMeetCoach = true
            case .dailyGoal:  hasSeenGoalCoach = true
            }
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
        .modelContainer(for: Catch.self, inMemory: true)
        .tint(Theme.accent)
        .fontDesign(.rounded)
}
