import SwiftUI
import SwiftData

@main
struct GroveApp: App {
    /// UIKit bridge for Home Screen quick actions (long-press the app icon).
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Shared SwiftData container. Everything the player collects lives here,
    /// on-device. When we add a social/backend layer later, this is where
    /// sync would hook in.
    let container: ModelContainer
    /// Shown on every cold launch, handing off from the system launch screen.
    @State private var showsSplash = true

    init() {
        let schema = Schema(versionedSchema: GroveCurrentSchema.self)
        CloudSyncMonitor.shared.start()
        #if DEBUG
        CloudSyncMonitor.initializeSchemaIfAsked(
            configuration: ModelConfiguration(schema: schema, cloudKitDatabase: .automatic))
        #endif
        container = Self.makeContainer(schema: schema)
        ProfileSync.shared.start()
    }

    /// The Grove's store. With the iCloud capability on, `.automatic` keeps it
    /// in the player's private iCloud so it survives a reinstall or a new
    /// phone; without it, it's an ordinary on-device store.
    ///
    /// If iCloud can't be used (say the store's format and iCloud disagree),
    /// fall back to the same file on-device only, so nothing the player does is
    /// lost. Only if even that fails do we open a temporary in-memory Grove,
    /// rather than crash on launch.
    private static func makeContainer(schema: Schema) -> ModelContainer {
        do {
            let synced = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            let container = try ModelContainer(for: schema, migrationPlan: GroveMigrationPlan.self,
                                               configurations: synced)
            CloudSyncMonitor.log("store opened with iCloud sync (\(synced.cloudKitContainerIdentifier ?? "no container"))")
            return container
        } catch {
            CloudSyncMonitor.log("store couldn't use iCloud, using this device only: \(error)")
            assertionFailure("iCloud-backed ModelContainer failed: \(error)")
        }
        do {
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, migrationPlan: GroveMigrationPlan.self,
                                      configurations: local)
        } catch {
            assertionFailure("On-device ModelContainer failed: \(error)")
        }
        do {
            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: memory)
        } catch {
            fatalError("Could not create even an in-memory ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .tint(Theme.accent)
                    .fontDesign(.rounded) // soft, friendly type everywhere
                    .preferredColorScheme(.light) // Grove's palette is a fixed light aesthetic — keep it consistent on every device
                if showsSplash {
                    SplashView { showsSplash = false }
                        .zIndex(1)
                }
            }
        }
        .modelContainer(container)
    }
}
