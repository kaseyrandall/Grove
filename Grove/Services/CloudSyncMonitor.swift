import CoreData
import CloudKit
import SwiftData

/// Watches the Grove's iCloud sync and says what it's doing. Every line it
/// logs starts with "☁️ Grove iCloud:" so it's easy to find in Xcode's
/// console. It also remembers the last sync error, so the app can tell the
/// player when syncing has stopped (say, their iCloud storage is full).
final class CloudSyncMonitor {
    static let shared = CloudSyncMonitor()
    static let containerID = "iCloud.com.kaseyrandall.grove"

    /// The most recent sync failure, if the last attempt failed.
    private(set) var lastError: Error?
    private var started = false

    func start() {
        guard !started else { return }
        started = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(syncEvent(_:)),
            name: NSPersistentCloudKitContainer.eventChangedNotification, object: nil)
        CKContainer(identifier: Self.containerID).accountStatus { status, error in
            Self.log("account is \(Self.describe(status))" + (error.map { " (\($0.localizedDescription))" } ?? ""))
        }
    }

    @objc private func syncEvent(_ note: Notification) {
        guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
        let kind: String
        switch event.type {
        case .setup: kind = "setup"
        case .import: kind = "download"
        case .export: kind = "upload"
        @unknown default: kind = "sync"
        }
        guard event.endDate != nil else {
            Self.log("\(kind) started")
            return
        }
        if let error = event.error {
            lastError = error
            Self.log("\(kind) FAILED: \(Self.describe(error))")
        } else {
            lastError = nil
            Self.log("\(kind) finished")
        }
    }

    static func log(_ message: String) {
        print("☁️ Grove iCloud: \(message)")
    }

    private static func describe(_ status: CKAccountStatus) -> String {
        switch status {
        case .available: return "available"
        case .noAccount: return "NOT SIGNED IN to iCloud"
        case .restricted: return "restricted (Screen Time or a profile blocks iCloud)"
        case .couldNotDetermine: return "unknown"
        case .temporarilyUnavailable: return "temporarily unavailable (check Settings → your name)"
        @unknown default: return "unknown (\(status.rawValue))"
        }
    }

    private static func describe(_ error: Error) -> String {
        let ns = error as NSError
        if let ck = error as? CKError {
            switch ck.code {
            case .quotaExceeded: return "iCloud storage is full"
            case .notAuthenticated: return "not signed in to iCloud"
            case .permissionFailure: return "no permission for this iCloud container"
            case .networkUnavailable, .networkFailure: return "no network"
            default: break
            }
        }
        if ns.domain == NSCocoaErrorDomain, ns.code == 134400 {
            return "no iCloud account available on this device"
        }
        var text = "\(ns.domain) \(ns.code): \(ns.localizedDescription)"
        // Core Data wraps the real cause; show it.
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
            text += " ← " + describe(underlying)
        }
        if let partial = ns.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error],
           let first = partial.values.first {
            text += " ← " + describe(first)
        }
        return text
    }

    #if DEBUG
    /// DEBUG only (`-GroveInitCloudKitSchema`): creates the Grove's record
    /// types in iCloud's Development environment straight away, and logs
    /// exactly why if it can't. Must run before the ModelContainer opens.
    static func initializeSchemaIfAsked(configuration: ModelConfiguration) {
        guard ProcessInfo.processInfo.arguments.contains("-GroveInitCloudKitSchema") else { return }
        log("creating record types in Development…")
        do {
            try autoreleasepool {
                let description = NSPersistentStoreDescription(url: configuration.url)
                description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: containerID)
                description.shouldAddStoreAsynchronously = false
                guard let model = NSManagedObjectModel.makeManagedObjectModel(for: [Catch.self]) else {
                    log("couldn't build the data model")
                    return
                }
                let container = NSPersistentCloudKitContainer(name: "Grove", managedObjectModel: model)
                container.persistentStoreDescriptions = [description]
                var loadError: Error?
                container.loadPersistentStores { _, error in loadError = error }
                if let loadError { throw loadError }
                try container.initializeCloudKitSchema()
                if let store = container.persistentStoreCoordinator.persistentStores.first {
                    try container.persistentStoreCoordinator.remove(store)
                }
            }
            log("record types created. Look for CD_Catch under Schema → Record Types.")
        } catch {
            log("couldn't create record types: \(describe(error))")
        }
    }
    #endif
}
