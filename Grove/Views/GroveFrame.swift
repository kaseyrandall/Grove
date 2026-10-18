import SwiftUI
import SwiftData
import UIKit

/// Grove Frame: the iPhone Duo half-folded on a desk becomes a little living
/// photo frame. Your favorite friends (then your rarest and newest) drift by
/// one at a time as big framed photos; the base shows a soft clock and
/// today's challenge, over the friend's zone colors. Tap anywhere to go back.
/// Shown by `RootView` after a quiet spell while half-folded.
struct GroveFrameView: View {
    let onDismiss: () -> Void

    @Query private var catches: [Catch]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index = 0
    @State private var zoomed = false

    /// Seconds each friend stays up.
    static let interval: TimeInterval = 9

    /// Who to show: favorites first, then the rarest, then the newest; only
    /// friends with photos, at most a dozen.
    private var friends: [Catch] {
        let withPhotos = catches.filter { $0.photoData != nil }
        let favorites = Favorites.of(withPhotos)
        let rest = withPhotos
            .filter { $0.favoritedAt == nil }
            .sorted {
                $0.species.rarity != $1.species.rarity
                    ? $0.species.rarity > $1.species.rarity
                    : $0.caughtAt > $1.caughtAt
            }
        return Array((favorites + rest).prefix(12))
    }

    var body: some View {
        let list = friends
        let current = list.isEmpty ? nil : list[index % list.count]
        GeometryReader { geo in
            let upright = geo.size.height > geo.size.width
            let layout = upright ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
            ZStack {
                (current?.effectiveZone.gradient ?? Theme.background)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.6), value: current?.persistentModelID)

                layout {
                    // The "screen" half: the friend.
                    photoPane(current)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(28)
                    // The "base" half: the time and today's goal.
                    basePane(current, count: list.count)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(24)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .task(id: list.count) {
            guard list.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.interval))
                if Task.isCancelled { return }
                withAnimation(.easeInOut(duration: 1.4)) { index += 1 }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double-tap to go back to Grove")
    }

    @ViewBuilder
    private func photoPane(_ friend: Catch?) -> some View {
        if let friend, let data = friend.photoData, let image = UIImage(data: data) {
            ZStack(alignment: .bottomLeading) {
                FriendPhoto(image: image, framing: friend.framing)
                    .scaleEffect(reduceMotion ? 1 : (zoomed ? 1.08 : 1.0))
                    .animation(reduceMotion ? nil : .linear(duration: Self.interval), value: zoomed)
                    .onAppear { zoomed.toggle() }
                    .onChange(of: friend.persistentModelID) { _, _ in zoomed.toggle() }

                LinearGradient(colors: [.clear, .black.opacity(0.5)], startPoint: .center, endPoint: .bottom)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(friend.displayName)
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                        if friend.favoritedAt != nil {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Theme.blush)
                        }
                    }
                    Text(caption(for: friend))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .opacity(0.9)
                        .lineLimit(2)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.3), radius: 6)
                .padding(22)
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white, lineWidth: 8))
            .shadow(color: Theme.ink.opacity(0.22), radius: 22, y: 10)
            .id(friend.persistentModelID)
            .transition(.opacity)
        } else {
            // No photos yet: a little scene of who might visit.
            VStack(spacing: 14) {
                Text("🌳").font(.system(size: 110))
                Text("Your Grove is waiting for its first friend")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// "🦆 Duck · Met at Hayes Valley · Sep 25, 2026" (the place left out
    /// when there isn't one).
    private func caption(for friend: Catch) -> String {
        var parts = ["\(friend.species.emoji) \(friend.species.name)"]
        if let place = friend.placeName, !place.isEmpty { parts.append("Met at \(place)") }
        parts.append(friend.caughtAt.formatted(.dateTime.month(.abbreviated).day().year()))
        return parts.joined(separator: " · ")
    }

    private func basePane(_ friend: Catch?, count: Int) -> some View {
        let challenge = DailyChallenge.today()
        let todays = catches.filter { Calendar.current.isDateInToday($0.caughtAt) }
        let complete = challenge.isComplete(todays, PlayerStats(catches: catches))
        return VStack(spacing: 14) {
            TimelineView(.everyMinute) { context in
                VStack(spacing: 2) {
                    Text(context.date.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 76, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(context.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .opacity(0.6)
                }
                .foregroundStyle(Theme.ink)
            }

            HStack(spacing: 10) {
                Image(systemName: complete ? "checkmark.circle.fill" : "target")
                    .foregroundStyle(Theme.accent)
                Text(complete ? "Today's challenge: done!" : "\(challenge.emoji) \(challenge.title)")
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.system(.headline, design: .rounded, weight: .bold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Capsule().fill(.white.opacity(0.75)))

            if count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<count, id: \.self) { i in
                        Circle()
                            .fill(Theme.ink.opacity(i == index % count ? 0.6 : 0.18))
                            .frame(width: 6, height: 6)
                    }
                }
                .accessibilityHidden(true)
            }

            Text("Tap to return to your Grove")
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.ink.opacity(0.4))
        }
    }
}

// MARK: - Idle tracking

/// When the player last touched the screen, so Grove Frame can wait for a
/// quiet spell. Fed by a touch recorder on the window that never interferes
/// with the touches themselves.
@MainActor
final class IdleClock: ObservableObject {
    static let shared = IdleClock()
    @Published private(set) var lastActivity = Date.now
    func touched() { lastActivity = .now }
}

extension View {
    /// Record every touch in this view's window (see `IdleClock`).
    func recordsTouches() -> some View {
        background(TouchRecorderHost().allowsHitTesting(false))
    }
}

private struct TouchRecorderHost: UIViewRepresentable {
    func makeUIView(context: Context) -> HostView { HostView() }
    func updateUIView(_ uiView: HostView, context: Context) {}

    final class HostView: UIView {
        private let recorder = TouchRecorder()
        override func didMoveToWindow() {
            super.didMoveToWindow()
            recorder.view?.removeGestureRecognizer(recorder)
            window?.addGestureRecognizer(recorder)
        }
    }
}

/// Sees each touch begin, records it, and steps aside at once.
private final class TouchRecorder: UIGestureRecognizer {
    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }
    convenience init() { self.init(target: nil, action: nil) }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        MainActor.assumeIsolated { IdleClock.shared.touched() }
        state = .failed
    }
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}

/// Keeps the screen awake while Grove Frame is up, but only on the charger,
/// so a frame left running never drains the battery.
@MainActor
enum FrameKeepAwake {
    static func update(showing: Bool) {
        UIDevice.current.isBatteryMonitoringEnabled = showing
        let charging = [.charging, .full].contains(UIDevice.current.batteryState)
        UIApplication.shared.isIdleTimerDisabled = showing && charging
    }
}
