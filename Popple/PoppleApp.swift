import SwiftUI
import SwiftData

@main
struct PoppleApp: App {
    /// Shared SwiftData container. Everything the player collects lives here,
    /// on-device. When we add a social/backend layer later, this is where
    /// sync would hook in.
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Catch.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
                .fontDesign(.rounded) // soft, friendly type everywhere
        }
        .modelContainer(container)
    }
}
