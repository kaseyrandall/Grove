#if DEBUG
import Foundation

/// Developer launch switches (`-GroveOpenFieldGuide` and friends). Each one
/// fires once per launch: screens appear again whenever you come back to
/// them, and a switch that fired every time would trap you on the screen it
/// opens.
@MainActor
enum LaunchFlag {
    private static var used = Set<String>()

    /// True the first time it's asked about a switch the app was launched with.
    static func once(_ flag: String) -> Bool {
        guard ProcessInfo.processInfo.arguments.contains(flag) else { return false }
        return first(flag)
    }

    /// True only the first time it's called with `key` in this launch.
    static func first(_ key: String) -> Bool {
        used.insert(key).inserted
    }
}
#endif
