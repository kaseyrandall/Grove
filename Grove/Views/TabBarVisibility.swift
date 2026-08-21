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

extension View {
    /// Hide Grove's floating tab bar while this screen is on top.
    func groveTabBarHidden(_ hidden: Bool = true) -> some View {
        preference(key: TabBarVisibilityKey.self, value: !hidden)
    }
}
