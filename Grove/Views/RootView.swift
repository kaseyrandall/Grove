import SwiftUI
import SwiftData
import StoreKit

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
    #if DEBUG
    @Environment(\.modelContext) private var context
    #endif
    @ObservedObject private var quickActions = QuickActionRouter.shared
    @ObservedObject private var router = AppRouter.shared
    /// Grove Frame (the half-folded Duo as a photo frame), and what it waits on.
    @Environment(\.groveFold) private var fold
    @ObservedObject private var idle = IdleClock.shared
    @State private var showsFrame = false
    /// "Made for iPhone Duo", shown once the first time Grove runs on a Duo.
    @AppStorage("hasSeenDuoIntro") private var hasSeenDuoIntro = false
    @State private var showsDuoIntro = false
    /// Quiet seconds, half-folded, before the frame appears.
    private static let frameDelay: TimeInterval = 30
    @ObservedObject private var updates = AppUpdates.shared
    @ObservedObject private var reviewPrompt = ReviewPrompt.shared
    /// Apple's own "Enjoying Grove?" rating prompt.
    @Environment(\.requestReview) private var requestReview
    @State private var selection: RootTab = .grove
    @State private var tabBarVisible = true
    /// The keyboard is up (e.g. renaming yourself on Profile): the bar steps
    /// aside instead of riding up on top of it.
    @State private var keyboardUp = false
    /// The floating bar's measured size. Its height (or width, when it stands on
    /// the side) is handed to the pages as extra safe area, so content clears
    /// the bar on any display size instead of each page padding a hardcoded guess.
    @State private var tabBarSize: CGSize = .zero
    /// The whole window, safe areas included — decides spread mode and the fold.
    @State private var windowSize: CGSize = .zero
    /// The system's safe-area insets (on a spread, the side strip the status bar lives in).
    @State private var systemInsets = EdgeInsets()

    /// The open Duo in landscape: pages lay out as two-page spreads.
    private var isSpread: Bool { DuoSpread.isSpread(windowSize: windowSize) }
    /// Room the bar takes from the pages, along whichever edge it sits on. On a
    /// spread it mostly lives in the system's side strip, which the pages already
    /// avoid, so only the part poking out of that strip counts.
    private var tabBarInset: CGFloat {
        isSpread ? max(0, tabBarSize.width - systemInsets.trailing) : tabBarSize.height
    }
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
        ZStack(alignment: isSpread ? .trailing : .bottom) {
            Group {
                switch selection {
                case .grove:    GroveView(onSnap: {
                    withAnimation(.easeInOut(duration: 0.22)) { selection = .catchTab }
                })
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
            // Each tab's root page reserves this much bottom safe area (see
            // `clearsGroveTabBar()`) so its content clears the bar; backgrounds
            // and the map still run underneath. Zero while a pushed page hides it.
            .environment(\.groveTabBarInset, tabBarVisible ? tabBarInset : 0)
            .environment(\.groveIsSpread, isSpread)
            .environment(\.groveFoldX, windowSize.width / 2)

            // The bar floats over content, which clears it via the inset above.
            GroveTabBar(
                selection: $selection,
                vertical: isSpread,
                onCatch: { withAnimation(.easeInOut(duration: 0.22)) { selection = .catchTab } }
            )
            .onGeometryChange(for: CGSize.self) { $0.size } action: { tabBarSize = $0 }
            // On a spread the bar shares the system's side column with the
            // status bar (Apple's layout for the open Duo): it runs into that
            // strip, below the status bar, rather than standing beside it.
            .padding(.top, isSpread ? DuoSpread.statusBarClearance : 0)
            .ignoresSafeArea(.container, edges: isSpread ? .trailing : [])
            .offset(x: tabBarVisible || !isSpread ? 0 : 160,
                    y: tabBarVisible || isSpread ? 0 : 160)
            .opacity(tabBarVisible && !keyboardUp ? 1 : 0)
            .allowsHitTesting(tabBarVisible && !keyboardUp)
            .animation(.easeInOut(duration: 0.2), value: keyboardUp)
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            let insets = proxy.safeAreaInsets
            return CGSize(width: proxy.size.width + insets.leading + insets.trailing,
                          height: proxy.size.height + insets.top + insets.bottom)
        } action: { windowSize = $0 }
        .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { systemInsets = $0 }
        // The active coach mark, pointed at whatever target tagged itself. Only
        // the bubble is opaque, so the rest of the UI stays fully interactive.
        .overlayPreferenceValue(CoachAnchorKey.self) { anchors in
            GeometryReader { proxy in
                // Only while the Grove root is front-most (the tab bar is up, so
                // no detail page is pushed over it) and the target is actually
                // in view — otherwise the bubble drifts over the header/chrome
                // or lingers on top of a pushed page.
                if tabBarVisible, let step = currentCoachStep, let anchor = anchors[step] {
                    let rect = proxy[anchor]
                    if coachTargetVisible(step, rect, in: proxy.size) {
                        CoachOverlay(
                            step: step,
                            targetRect: rect,
                            container: proxy.size,
                            onDismiss: { dismissCoach(step) }
                        )
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            keyboardUp = Self.keyboardCoversScreen(note)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardUp = false
        }
        .onChange(of: selection) { _, newValue in
            if newValue == .catchTab { hasSeenSnapCoach = true }
        }
        // Retention reminders: reschedule on launch, when a catch lands, and
        // whenever we come back to the foreground.
        .task {
            refreshReminders()
            noteAppActive()
        }
        .onChange(of: catches.count) { _, _ in refreshReminders() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                refreshReminders()
                noteAppActive()
                handleQuickAction() // a warm-launch shortcut may be waiting
            case .background:
                AppUpdates.scheduleBackgroundRefresh()
                WidgetSnapshotWriter.refresh(catches: catches) // favorites may have changed
            default:
                break
            }
        }
        // Apple's "Enjoying Grove?" waits until the player is back on the Grove
        // with nothing else on screen, then shows after a beat. (Apple decides
        // whether it actually appears; it limits how often apps can ask.)
        .task(id: reviewGate) {
            guard canShowReviewPrompt, reviewPrompt.isDue else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            reviewPrompt.markShown()
            requestReview()
        }
        .sheet(item: whatsNewBinding, onDismiss: { updates.dismissWhatsNew() }) { notes in
            WhatsNewView(notes: notes) { updates.dismissWhatsNew() }
        }
        .onChange(of: quickActions.pending) { _, _ in handleQuickAction() }
        // A notification asked to open somewhere: switch to its tab; the
        // tab's page opens the screen itself (Field Guide, Settings).
        .onChange(of: router.pending) { _, place in
            guard let place, hasOnboarded else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                selection = place == .fieldGuide ? .journal : .profile
            }
        }
        .onAppear { handleQuickAction() } // catch a cold-launch shortcut
        #if DEBUG
        .onAppear { applyDebugLaunchArguments() }
        #endif
        .recordsTouches()
        // The Duo intro waits for the intro, What's New and the camera to be out of the way.
        .task(id: "\(fold != .none)|\(hasOnboarded)|\(updates.whatsNew == nil)|\(selection)|\(showsFrame)") {
            guard fold != .none, hasOnboarded, updates.whatsNew == nil,
                  selection != .catchTab, !showsFrame, !fold.isHalfFolded,
                  !hasSeenDuoIntro else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            showsDuoIntro = true
        }
        .groveSheet(isPresented: $showsDuoIntro) {
            DuoIntroSheet()
                .onAppear { hasSeenDuoIntro = true }
        }
        // Grove Frame: half-folded and left alone (and not mid-catch), the
        // Duo becomes a photo frame. Any touch or unfolding ends it.
        .task(id: frameGate) {
            guard fold.isHalfFolded, hasOnboarded, selection != .catchTab else { return }
            let wait = Self.frameDelay - Date.now.timeIntervalSince(idle.lastActivity)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled, fold.isHalfFolded else { return }
            withAnimation(.easeInOut(duration: 0.8)) { showsFrame = true }
        }
        .onChange(of: fold) { _, newFold in
            if !newFold.isHalfFolded { withAnimation { showsFrame = false } }
        }
        .onChange(of: showsFrame) { _, showing in FrameKeepAwake.update(showing: showing) }
        .overlay {
            if showsFrame {
                GroveFrameView { withAnimation(.easeInOut(duration: 0.4)) { showsFrame = false } }
                    .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView { hasOnboarded = true }
                // Presented from here, outside the tab content, so hand the
                // spread layout down explicitly.
                .environment(\.groveIsSpread, isSpread)
                .environment(\.groveFoldX, windowSize.width / 2)
        }
    }

    /// Consume a pending Home Screen quick action. "Snap a friend" jumps to the
    /// camera — but only once the player is past onboarding; otherwise we clear
    /// it so it can't fire behind the intro.
    #if DEBUG
    /// Test hooks so screens can be checked without tapping (e.g. from the
    /// command line): `-GroveSeedSample` fills in the sample Grove, and
    /// `-GroveTab map|catch|journal|profile` opens that tab.
    private func applyDebugLaunchArguments() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-GroveSeedSample"), !SeedData.isPresent(in: catches) {
            SeedData.fill(context: context)
        }
        // `-GroveShowOnboarding` replays the intro (iCloud otherwise restores
        // "already onboarded" on launch).
        // `-GroveShowDuoIntro` shows the Duo intro again.
        if args.contains("-GroveShowDuoIntro") { hasSeenDuoIntro = false }
        // `-GroveShowFrame` opens Grove Frame right away.
        if args.contains("-GroveShowFrame") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showsFrame = true }
        }
        if args.contains("-GroveShowOnboarding") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { hasOnboarded = false }
        }
        if let i = args.firstIndex(of: "-GroveTab"), i + 1 < args.count {
            switch args[i + 1] {
            case "map":     selection = .map
            case "catch":   selection = .catchTab
            case "journal": selection = .journal
            case "profile": selection = .profile
            default:        break
            }
        }
    }
    #endif

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

    private func noteAppActive() {
        updates.appBecameActive()
        reviewPrompt.appBecameActive()
    }

    /// Nothing else is asking for the player's attention: they're on the
    /// Grove's root page, with no coach mark, intro or What's New up.
    private var canShowReviewPrompt: Bool {
        hasOnboarded && selection == .grove && tabBarVisible
            && currentCoachStep == nil && updates.whatsNew == nil
    }

    /// Re-arms the frame's wait whenever the fold, the tab, or the last touch changes.
    private var frameGate: String {
        "\(fold.isHalfFolded)|\(selection)|\(idle.lastActivity.timeIntervalSince1970)|\(showsFrame)"
    }

    private var reviewGate: String {
        "\(reviewPrompt.isDue)|\(canShowReviewPrompt)"
    }

    /// What's New only after the intro; a brand-new player has nothing to compare.
    private var whatsNewBinding: Binding<ReleaseNotes?> {
        Binding(
            get: { hasOnboarded ? updates.whatsNew : nil },
            set: { if $0 == nil { updates.dismissWhatsNew() } }
        )
    }

    private func refreshReminders() {
        NotificationManager.refresh(catches: catches, enabled: notificationsEnabled)
        WidgetSnapshotWriter.refresh(catches: catches)
    }

    /// Whether a step's target is on-screen enough to point at. `.snap` is
    /// pinned to the fixed tab bar, so it's always fair game; the scrolling
    /// Grove targets must sit in the band between the header and the floating
    /// tab bar, so a bubble never drifts over the chrome or off-screen.
    private func coachTargetVisible(_ step: CoachStep, _ rect: CGRect, in size: CGSize) -> Bool {
        guard step != .snap else { return true }
        guard rect.height > 0 else { return false }
        let top: CGFloat = 90
        let bottom = size.height - (isSpread ? 0 : tabBarSize.height)
        return rect.midY > top && rect.midY < bottom
    }

    /// Whether a keyboard notification means a real keyboard on screen. Folding
    /// or rotating the Duo posts "will show" with no keyboard and no matching
    /// "will hide", which used to leave the bar hidden; only a keyboard that
    /// actually covers part of the screen counts.
    private static func keyboardCoversScreen(_ note: Notification) -> Bool {
        guard let end = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return false }
        let covered = (note.object as? UIScreen).map { $0.bounds.intersection(end).height } ?? end.height
        return covered > 100
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

    /// Presents onboarding whenever it hasn't been completed.
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
