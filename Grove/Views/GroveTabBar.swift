import SwiftUI

/// Grove's custom bottom bar: four flat tabs split two-and-two around a raised,
/// floating Catch button in the center. The coach mark (when shown) sits just
/// above that button.
struct GroveTabBar: View {
    @Binding var selection: RootTab
    var showCoachMark: Bool
    var onCatch: () -> Void

    var body: some View {
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
            .background(
                Capsule(style: .continuous)
                    .fill(.white)
                    .shadow(color: Theme.ink.opacity(0.14), radius: 12, y: 4)
            )
            .padding(.horizontal, 16)

            // Floating Catch button
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
            .offset(y: -18)
            .overlay(alignment: .top) {
                if showCoachMark {
                    CatchCoachMark(onTap: onCatch)
                        .fixedSize()
                        .offset(y: -62)
                        .transition(.opacity)
                }
            }
        }
        // Extra top room so the raised Catch button is inside the bar's reserved
        // safe-area height — scroll content then clears it instead of hiding behind.
        .padding(.top, 28)
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
            selection = tab
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
        }
        .buttonStyle(.plain)
    }
}
