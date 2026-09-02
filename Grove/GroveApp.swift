import SwiftUI
import SwiftData

@main
struct GroveApp: App {
    /// Shared SwiftData container. Everything the player collects lives here,
    /// on-device. When we add a social/backend layer later, this is where
    /// sync would hook in.
    let container: ModelContainer

    init() {
        let schema = Schema(versionedSchema: GroveCurrentSchema.self)
        let config = ModelConfiguration(schema: schema)
        do {
            container = try ModelContainer(for: schema,
                                           migrationPlan: GroveMigrationPlan.self,
                                           configurations: config)
        } catch {
            // Never crash a player into a broken launch. In development we want
            // to see the failure loudly; in a shipped build we fall back to a
            // temporary in-memory store so the app still opens. (The store file
            // is left untouched, so a fixed build can read it again.)
            assertionFailure("Persistent ModelContainer failed: \(error)")
            do {
                let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                container = try ModelContainer(for: schema, configurations: memory)
            } catch {
                fatalError("Could not create even an in-memory ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
                .fontDesign(.rounded) // soft, friendly type everywhere
                .preferredColorScheme(.light) // Grove's palette is a fixed light aesthetic — keep it consistent on every device
        }
        .modelContainer(container)
    }
}
