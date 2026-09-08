import SwiftUI
import UIKit

/// Home Screen quick actions — the shortcuts that appear when you long-press
/// Grove's app icon. Right now there's one: jump straight to the camera.
///
/// Routing quick actions in a SwiftUI-lifecycle app takes a small UIKit bridge:
/// a cold launch (app not running) is delivered to the app delegate's
/// `configurationForConnecting`, while a warm launch (app already in the
/// background) is delivered to the *scene* delegate's `performActionFor`. Both
/// paths funnel into `QuickActionRouter`, which the UI observes.
enum QuickAction: String {
    /// Open the Catch camera.
    case snap = "com.grove.action.snap"

    /// The long-press menu entry for this action.
    var shortcutItem: UIApplicationShortcutItem {
        switch self {
        case .snap:
            return UIApplicationShortcutItem(
                type: rawValue,
                localizedTitle: "Snap a Friend",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "camera.fill"),
                userInfo: nil
            )
        }
    }

    init?(_ item: UIApplicationShortcutItem) {
        self.init(rawValue: item.type)
    }
}

/// Carries the most recently tapped quick action to the UI, which consumes it
/// (and resets it to nil) once handled.
final class QuickActionRouter: ObservableObject {
    static let shared = QuickActionRouter()
    @Published var pending: QuickAction?
    private init() {}

    /// Record an action from any UIKit callback thread (they fire on main, but
    /// hop explicitly so `@Published` always mutates on the main actor).
    func stash(_ item: UIApplicationShortcutItem) {
        guard let action = QuickAction(item) else { return }
        DispatchQueue.main.async { self.pending = action }
    }
}

/// Minimal app delegate: registers the long-press menu and installs our scene
/// delegate so warm-launch quick actions have somewhere to land.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Registered dynamically so we don't need a hand-maintained Info.plist.
        application.shortcutItems = [QuickAction.snap.shortcutItem]
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Cold launch: the shortcut that opened the app arrives here.
        if let item = options.shortcutItem {
            QuickActionRouter.shared.stash(item)
        }
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

/// Scene delegate whose only job is catching *warm* quick actions. It never
/// touches the window — SwiftUI still owns and renders that.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        QuickActionRouter.shared.stash(shortcutItem)
        completionHandler(true)
    }
}
