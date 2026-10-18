import CoreData
import CloudKit
import SwiftData

/// Watches the Grove's iCloud sync and says what it's doing. Every line it
/// logs starts with "☁️ Grove iCloud:" so it's easy to find in Xcode's
/// console. It also remembers the last sync error, so the app can tell the
/// player when syncing has stopped (say, their iCloud storage is full).
final class CloudSyncMonitor: ObservableObject {
    static let shared = CloudSyncMonitor()
    static let containerID = "iCloud.com.kaseyrandall.grove"

    /// The player's "iCloud backup" setting (on unless they turn it off).
    /// Read once at launch: the store opens with or without iCloud then, so a
    /// change applies the next time Grove opens.
    static let syncEnabledKey = "iCloudSyncEnabled"
    static var syncEnabledSetting: Bool {
        UserDefaults.standard.object(forKey: syncEnabledKey) as? Bool ?? true
    }
    /// Whether this launch opened the store with iCloud.
    static let syncEnabledAtLaunch = syncEnabledSetting

    /// Where the Grove's iCloud backup stands, for the Settings card.
    enum Status: Equatable {
        case checking
        case backedUp
        case notSignedIn
        case storageFull
        case paused(String)
        /// The player turned iCloud backup off.
        case off
    }

    @Published private(set) var status: Status = .checking
    /// The most recent sync failure, if the last attempt failed.
    private(set) var lastError: Error?
    private var started = false
    /// True once iCloud sync has reported in at all. Creating a CKContainer
    /// in a build without the iCloud entitlement traps the app, so the
    /// account is only looked up after sync has proven it's set up.
    private var syncIsConfigured = false

    func start() {
        guard !started else { return }
        started = true
        guard Self.syncEnabledAtLaunch else {
            status = .off
            return
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(syncEvent(_:)),
            name: NSPersistentCloudKitContainer.eventChangedNotification, object: nil)
        // The account is checked once sync reports in (see syncEvent), never
        // here: without the iCloud entitlement, CKContainer would crash.
        // Signing in or out of iCloud while Grove is open.
        NotificationCenter.default.addObserver(
            self, selector: #selector(accountChanged),
            name: .CKAccountChanged, object: nil)
    }

    @objc private func accountChanged() { refreshAccountStatus() }

    private func refreshAccountStatus() {
        guard syncIsConfigured else { return }
        CKContainer(identifier: Self.containerID).accountStatus { status, error in
            Self.log("account is \(Self.describe(status))" + (error.map { " (\($0.localizedDescription))" } ?? ""))
            DispatchQueue.main.async {
                switch status {
                case .available:
                    if self.status == .checking || self.status == .notSignedIn { self.status = .backedUp }
                case .noAccount, .restricted:
                    self.status = .notSignedIn
                default:
                    break
                }
            }
        }
    }

    @objc private func syncEvent(_ note: Notification) {
        guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
        if !syncIsConfigured {
            // Sync is set up, so the iCloud entitlement is there: safe to ask
            // about the account now.
            syncIsConfigured = true
            refreshAccountStatus()
        }
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
            let ns = error as NSError
            let noAccount = ns.domain == NSCocoaErrorDomain && ns.code == 134400
            let newStatus: Status = Self.contains(error, code: .quotaExceeded) ? .storageFull
                : noAccount || Self.contains(error, code: .notAuthenticated) ? .notSignedIn
                : Self.contains(error, code: .networkUnavailable) || Self.contains(error, code: .networkFailure)
                    ? status // offline: it'll catch up, no need to alarm anyone
                : .paused(Self.describe(error))
            DispatchQueue.main.async { self.status = newStatus }
        } else {
            lastError = nil
            Self.log("\(kind) finished")
            DispatchQueue.main.async { self.status = .backedUp }
        }
    }

    /// Whether `error`, or anything it wraps, is a CloudKit error with `code`.
    private static func contains(_ error: Error, code: CKError.Code) -> Bool {
        if let ck = error as? CKError {
            if ck.code == code { return true }
            if let partial = ck.partialErrorsByItemID?.values,
               partial.contains(where: { contains($0, code: code) }) { return true }
        }
        let ns = error as NSError
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error, contains(underlying, code: code) { return true }
        if let partial = ns.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error],
           partial.values.contains(where: { contains($0, code: code) }) { return true }
        return false
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
