import SwiftUI

/// Grove's custom bottom bar: four flat tabs split two-and-two around a raised,
/// floating Catch button in the center. On the open Duo's spread it stands up
/// along the trailing edge instead. The coach mark (when shown) sits just above
/// that button.
struct GroveTabBar: View {
    @Binding var selection: RootTab
    /// Stand the bar up along the trailing edge (the open Duo's spread layout).
    var vertical = false
    var onCatch: () -> Void

    var body: some View {
        if vertical { verticalBar } else { horizontalBar }
    }

    private var horizontalBar: some View {
        ZStack {
            // The bar itself
            HStack(spacing: 0) {
                TabBarItem(selection: $selection, tab: .grove, icon: "leaf.fill", label: "Grove")
                TabBarItem(selection: $selection, tab: .map, icon: "map.fill", label: "Map")
                Spacer().frame(width: 72) // room for the floating button
                TabBarItem(selection: $selection, tab: .journal, icon: "book.closed.fill", label: "Journal")
                TabBarItem(selection: $selection, tab: .profile, icon: "person.crop.circle.fill", label: "Profile")
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(barBackground)
            .padding(.horizontal, 16)

            catchButton
                .offset(y: -18)
        }
        // Extra top room so the raised Catch button is inside the bar's reserved
        // safe-area height — scroll content then clears it instead of hiding behind.
        .padding(.top, 28)
    }

    /// The same bar stood on its end: a full-height capsule on the trailing
    /// edge, with the Catch button raised out of it toward the content.
    private var verticalBar: some View {
        ZStack {
            VStack(spacing: 18) {
                Spacer(minLength: 0)
                TabBarItem(selection: $selection, tab: .grove, icon: "leaf.fill", label: "Grove")
                TabBarItem(selection: $selection, tab: .map, icon: "map.fill", label: "Map")
                Spacer().frame(height: 72) // room for the floating button
                TabBarItem(selection: $selection, tab: .journal, icon: "book.closed.fill", label: "Journal")
                TabBarItem(selection: $selection, tab: .profile, icon: "person.crop.circle.fill", label: "Profile")
                Spacer(minLength: 0)
            }
            .frame(width: 66)
            .frame(maxHeight: .infinity)
            .background(barBackground)
            .padding(.vertical, 10)

            catchButton
                .offset(x: -18)
        }
        // Extra leading room so the raised Catch button is inside the bar's
        // reserved width — content then clears it instead of hiding behind.
        .padding(.leading, 28)
        .padding(.trailing, 8)
    }

    private var barBackground: some View {
        Capsule(style: .continuous)
            .fill(.white)
            .shadow(color: Theme.ink.opacity(0.14), radius: 12, y: 4)
    }

    // Floating Catch button
    private var catchButton: some View {
        Button(action: onCatch) {
            Image(systemName: "camera.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(Circle().fill(Theme.accent))
                .overlay(Circle().strokeBorder(.white, lineWidth: 5))
                .shadow(color: Theme.accent.opacity(0.45), radius: 10, y: 5)
        }
        .buttonStyle(BouncyButtonStyle())
        .accessibilityLabel("Catch a friend")
        .coachTarget(.snap)
    }
}

private struct TabBarItem: View {
    @Binding var selection: RootTab
    let tab: RootTab
    let icon: String
    let label: String

    private var isSelected: Bool { selection == tab }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { selection = tab }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isSelected ? Theme.accent : Theme.ink.opacity(0.35))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
