import SwiftUI

/// Lets a pushed child screen ask the root to tuck the floating tab bar away,
/// so detail pages get the full screen. Root tab screens leave it at the
/// default (visible); a child simply calls `.groveTabBarHidden()`.
struct TabBarVisibilityKey: PreferenceKey {
    static let defaultValue = true // visible
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value && nextValue()
    }
}

extension EnvironmentValues {
    /// Room the floating tab bar takes while it's showing (0 when tucked away):
    /// its height along the bottom, or its width when it stands on the side.
    @Entry var groveTabBarInset: CGFloat = 0
}

extension View {
    /// Hide Grove's floating tab bar while this screen is on top.
    func groveTabBarHidden(_ hidden: Bool = true) -> some View {
        preference(key: TabBarVisibilityKey.self, value: !hidden)
    }

    /// Reserve bottom safe area for the floating tab bar on a tab's root page,
    /// so scroll content clears it on any display size. Apply *inside* the
    /// page's NavigationStack — insets added outside one don't reach its content.
    func clearsGroveTabBar() -> some View {
        modifier(TabBarClearance())
    }
}

private struct TabBarClearance: ViewModifier {
    @Environment(\.groveTabBarInset) private var inset
    @Environment(\.groveIsSpread) private var isSpread

    func body(content: Content) -> some View {
        // On a spread the bar stands along the trailing edge; otherwise it floats
        // along the bottom.
        if isSpread {
            content.safeAreaInset(edge: .trailing, spacing: 0) {
                Color.clear.frame(width: inset)
            }
        } else {
            content.safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: inset)
            }
        }
    }
}
