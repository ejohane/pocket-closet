import CloudKit
@preconcurrency import CoreData
import SwiftUI
import UIKit

let cloudKitContainerIdentifier = "iCloud.com.erikjohansson.PocketCloset"

@MainActor
final class ClosetSession: ObservableObject {
    @Published var selectedClosetID: UUID?

    func select(_ closet: Closet) {
        selectedClosetID = closet.id
    }

    func ensureSelection(in closets: [Closet]) {
        guard selectedClosetID == nil || !closets.contains(where: { $0.id == selectedClosetID }) else { return }
        selectedClosetID = closets.sorted { $0.createdAt < $1.createdAt }.first?.id
    }
}

@MainActor
final class ShareAcceptanceCoordinator: ObservableObject {
    enum State: Equatable {
        case idle
        case accepting
        case accepted(UUID)
        case failed(String)
    }

    static let shared = ShareAcceptanceCoordinator()

    @Published private(set) var state: State = .idle
    private var acceptanceTask: Task<Void, Never>?

    func accept(_ metadata: CKShare.Metadata) {
        acceptanceTask?.cancel()
        state = .accepting
        acceptanceTask = Task {
            do {
                let closetID = try await PersistenceController.shared.accept(metadata)
                try Task.checkCancellation()
                state = .accepted(closetID)
            } catch is CancellationError {
                return
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func reset() {
        state = .idle
    }
}

final class PersistenceController: @unchecked Sendable {
    struct ShareRecoveryResult {
        let replacementClosetID: NSManagedObjectID
        let share: CKShare
        let cleanupWarning: Error?
    }

    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer
    private(set) var privateStore: NSPersistentStore!
    private(set) var sharedStore: NSPersistentStore!

    init(inMemory: Bool = false, cloudSyncEnabled: Bool = true) {
        container = NSPersistentCloudKitContainer(
            name: "PocketCloset",
            managedObjectModel: Self.makeManagedObjectModel()
        )

        let baseURL = NSPersistentContainer.defaultDirectoryURL()
        let privateDescription = NSPersistentStoreDescription(
            url: inMemory ? URL(fileURLWithPath: "/dev/null") : baseURL.appendingPathComponent("PocketCloset-private.sqlite")
        )
        privateDescription.shouldAddStoreAsynchronously = false
        privateDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        privateDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        let sharedDescription = NSPersistentStoreDescription(
            url: inMemory ? URL(fileURLWithPath: "/dev/null-shared") : baseURL.appendingPathComponent("PocketCloset-shared.sqlite")
        )
        sharedDescription.shouldAddStoreAsynchronously = false
        sharedDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        sharedDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        if inMemory {
            privateDescription.type = NSInMemoryStoreType
            sharedDescription.type = NSInMemoryStoreType
        } else if cloudSyncEnabled {
            let privateOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerIdentifier)
            privateOptions.databaseScope = .private
            privateDescription.cloudKitContainerOptions = privateOptions

            let sharedOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainerIdentifier)
            sharedOptions.databaseScope = .shared
            sharedDescription.cloudKitContainerOptions = sharedOptions
        }

        container.persistentStoreDescriptions = [privateDescription, sharedDescription]
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            fatalError("Could not create Pocket Closet stores: \(loadError)")
        }

        privateStore = container.persistentStoreCoordinator.persistentStore(for: privateDescription.url!)
        sharedStore = container.persistentStoreCoordinator.persistentStore(for: sharedDescription.url!)

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.transactionAuthor = "PocketClosetApp"
    }

    func createShare(for objectID: NSManagedObjectID, title: String) async throws -> CKShare {
        let persistedShare: CKShare = try await withCheckedThrowingContinuation { continuation in
            container.viewContext.perform {
                do {
                    guard let closet = try self.container.viewContext.existingObject(with: objectID) as? Closet else {
                        throw CocoaError(.validationMissingMandatoryProperty)
                    }
                    guard let store = closet.objectID.persistentStore else {
                        throw CocoaError(.persistentStoreOperation)
                    }
                    self.container.share([closet], to: nil) { _, share, _, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else if let share {
                            share[CKShare.SystemFieldKey.title] = title as CKRecordValue
                            self.container.persistUpdatedShare(share, in: store) { persistedShare, persistError in
                                if let persistError {
                                    continuation.resume(throwing: persistError)
                                } else if let persistedShare {
                                    continuation.resume(returning: persistedShare)
                                } else {
                                    continuation.resume(throwing: CocoaError(.persistentStoreOperation))
                                }
                            }
                        } else {
                            continuation.resume(throwing: CocoaError(.persistentStoreOperation))
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        return try await fetchVerifiedServerShare(persistedShare)
    }

    func fetchShare(for closet: Closet, completion: @escaping (CKShare?) -> Void) {
        Task {
            let shares = try? container.fetchShares(matching: [closet.objectID])
            completion(shares?[closet.objectID])
        }
    }

    func fetchServerShare(_ share: CKShare, databaseScope: CKDatabase.Scope) async throws -> CKShare {
        let cloudContainer = CKContainer(identifier: cloudKitContainerIdentifier)
        let database: CKDatabase = databaseScope == .shared
            ? cloudContainer.sharedCloudDatabase
            : cloudContainer.privateCloudDatabase
        let record = try await database.record(for: share.recordID)
        guard let serverShare = record as? CKShare else {
            throw CocoaError(.coderInvalidValue)
        }
        return serverShare
    }

    func recoverMissingShare(for objectID: NSManagedObjectID, staleShare: CKShare, title: String) async throws -> ShareRecoveryResult {
        let exportEvents = privateExportEvents(startingAfter: Date())
        let replacementClosetID = try await duplicateClosetGraph(for: objectID)

        do {
            try await waitForSuccessfulExport(in: exportEvents)
            let verifiedShare = try await createShare(for: replacementClosetID, title: title)
            let cleanupWarning: Error?
            do {
                try await purgeZone(staleShare.recordID.zoneID)
                cleanupWarning = nil
            } catch {
                // The replacement is already safe and usable. Keep both closets if cleaning up
                // the orphaned zone fails rather than risking the newly shared copy.
                cleanupWarning = error
            }
            return ShareRecoveryResult(
                replacementClosetID: replacementClosetID,
                share: verifiedShare,
                cleanupWarning: cleanupWarning
            )
        } catch {
            await discardReplacement(with: replacementClosetID)
            throw error
        }
    }

    private func privateExportEvents(
        startingAfter startDate: Date
    ) -> AsyncStream<NSPersistentCloudKitContainer.Event> {
        let privateStoreIdentifier = privateStore.identifier
        return AsyncStream { continuation in
            let token = NotificationCenter.default.addObserver(
                forName: NSPersistentCloudKitContainer.eventChangedNotification,
                object: container,
                queue: nil
            ) { notification in
                guard
                    let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                        as? NSPersistentCloudKitContainer.Event,
                    event.type == .export,
                    event.storeIdentifier == privateStoreIdentifier,
                    event.startDate >= startDate,
                    event.endDate != nil
                else { return }
                continuation.yield(event)
            }
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(token)
            }
        }
    }

    private func waitForSuccessfulExport(
        in events: AsyncStream<NSPersistentCloudKitContainer.Event>
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for await event in events {
                    if event.succeeded {
                        return
                    }
                    throw event.error ?? CocoaError(.persistentStoreOperation)
                }
                throw CancellationError()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 45_000_000_000)
                throw NSError(
                    domain: "PocketClosetSharing",
                    code: 3,
                    userInfo: [
                        NSLocalizedDescriptionKey: "iCloud did not finish syncing the replacement closet in time. Please check your connection and try again."
                    ]
                )
            }

            defer { group.cancelAll() }
            _ = try await group.next()
        }
    }

    func duplicateClosetGraph(for objectID: NSManagedObjectID) async throws -> NSManagedObjectID {
        try await withCheckedThrowingContinuation { continuation in
            container.viewContext.perform {
                do {
                    let context = self.container.viewContext
                    guard let original = try context.existingObject(with: objectID) as? Closet,
                          let privateStore = self.privateStore else {
                        throw CocoaError(.validationMissingMandatoryProperty)
                    }

                    let copy = Closet(
                        context: context,
                        name: original.name,
                        createdAt: original.createdAt,
                        updatedAt: original.updatedAt
                    )
                    context.assign(copy, to: privateStore)

                    var peopleByObjectID: [NSManagedObjectID: Person] = [:]
                    for person in original.people ?? [] {
                        let personCopy = Person(
                            context: context,
                            closet: copy,
                            name: person.name,
                            colorToken: person.colorToken,
                            avatarImagePath: person.avatarImagePath,
                            createdAt: person.createdAt,
                            updatedAt: person.updatedAt
                        )
                        peopleByObjectID[person.objectID] = personCopy
                    }

                    var locationsByObjectID: [NSManagedObjectID: StorageLocation] = [:]
                    for location in original.locations ?? [] {
                        let locationCopy = StorageLocation(
                            context: context,
                            closet: copy,
                            name: location.name,
                            kind: location.kind,
                            iconName: location.iconName,
                            colorToken: location.colorToken,
                            createdAt: location.createdAt,
                            updatedAt: location.updatedAt
                        )
                        locationCopy.kindRaw = location.kindRaw
                        locationsByObjectID[location.objectID] = locationCopy
                    }

                    for item in original.items ?? [] {
                        let itemCopy = ClothingItem(
                            context: context,
                            closet: copy,
                            photoPath: item.photoPath,
                            thumbnailPath: item.thumbnailPath,
                            photoData: item.photoData,
                            thumbnailData: item.thumbnailData,
                            owner: item.owner.flatMap { peopleByObjectID[$0.objectID] },
                            type: item.type,
                            size: item.sizeOption,
                            location: item.location.flatMap { locationsByObjectID[$0.objectID] },
                            status: item.status,
                            season: item.season,
                            brand: item.brand,
                            colorName: item.colorName,
                            notes: item.notes,
                            createdAt: item.createdAt,
                            updatedAt: item.updatedAt,
                            archivedAt: item.archivedAt
                        )
                        itemCopy.typeRaw = item.typeRaw
                        itemCopy.sizeSystemRaw = item.sizeSystemRaw
                        itemCopy.sizeLabel = item.sizeLabel
                        itemCopy.sizeSortOrder = item.sizeSortOrder
                        itemCopy.statusRaw = item.statusRaw
                        itemCopy.seasonRaw = item.seasonRaw
                    }

                    try context.save()
                    continuation.resume(returning: copy.objectID)
                } catch {
                    self.container.viewContext.rollback()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchVerifiedServerShare(_ share: CKShare) async throws -> CKShare {
        var lastError: Error?
        for attempt in 0..<6 {
            do {
                let serverShare = try await fetchServerShare(share, databaseScope: .private)
                guard serverShare.url != nil else {
                    throw NSError(
                        domain: "PocketClosetSharing",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "CloudKit did not create an invitation link for the replacement closet."]
                    )
                }
                return serverShare
            } catch {
                lastError = error
                if attempt < 5 {
                    try await Task.sleep(nanoseconds: UInt64(500_000_000 * (attempt + 1)))
                }
            }
        }
        throw lastError ?? CocoaError(.persistentStoreOperation)
    }

    private func purgeZone(_ zoneID: CKRecordZone.ID) async throws {
        guard let privateStore else {
            throw CocoaError(.persistentStoreOperation)
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.purgeObjectsAndRecordsInZone(with: zoneID, in: privateStore) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func discardReplacement(with objectID: NSManagedObjectID) async {
        if let shares = try? container.fetchShares(matching: [objectID]),
           let share = shares[objectID] {
            try? await purgeZone(share.recordID.zoneID)
            return
        }

        await container.viewContext.perform {
            guard let object = try? self.container.viewContext.existingObject(with: objectID) else { return }
            self.container.viewContext.delete(object)
            try? self.container.viewContext.save()
        }
    }

    func accept(_ metadata: CKShare.Metadata) async throws -> UUID {
        guard let sharedStore else {
            throw CocoaError(.persistentStoreOperation)
        }

        if metadata.participantStatus == .pending {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                container.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        }

        return try await waitForAcceptedCloset(matching: metadata.share.recordID)
    }

    private func waitForAcceptedCloset(matching shareRecordID: CKRecord.ID) async throws -> UUID {
        let deadline = Date().addingTimeInterval(30)
        var lastError: Error?

        while Date() < deadline {
            try Task.checkCancellation()
            do {
                let closets: [Closet] = try await container.viewContext.perform {
                    let request = Closet.fetchRequest()
                    request.affectedStores = [self.sharedStore]
                    return try self.container.viewContext.fetch(request)
                }
                let shares = try container.fetchShares(matching: closets.map(\.objectID))
                if let closet = closets.first(where: {
                    shares[$0.objectID]?.recordID == shareRecordID
                }) {
                    return closet.id
                }
            } catch {
                lastError = error
            }
            try await Task.sleep(for: .milliseconds(500))
        }

        throw lastError ?? NSError(
            domain: "PocketClosetSharing",
            code: 4,
            userInfo: [
                NSLocalizedDescriptionKey: "The invitation was accepted, but iCloud did not finish downloading the shared closet. Please reopen Pocket Closet in a moment."
            ]
        )
    }

    func store(for closet: Closet) -> NSPersistentStore? {
        closet.objectID.persistentStore
    }

    func deleteOwnedCloset(_ objectID: NSManagedObjectID) async throws {
        let snapshot: (share: CKShare?, imagePaths: [(String, String)]) = try await container.viewContext.perform {
            guard
                let closet = try self.container.viewContext.existingObject(with: objectID) as? Closet,
                closet.objectID.persistentStore == self.privateStore
            else {
                throw NSError(
                    domain: "PocketClosetSharing",
                    code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "Only closets you own can be deleted."]
                )
            }

            let share = try self.container.fetchShares(matching: [closet.objectID])[closet.objectID]
            let imagePaths = (closet.items ?? []).map { ($0.photoPath, $0.thumbnailPath) }
            return (share, imagePaths)
        }

        if let share = snapshot.share {
            try await purgeZone(share.recordID.zoneID)
            await container.viewContext.perform {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: [objectID]],
                    into: [self.container.viewContext]
                )
                self.container.viewContext.processPendingChanges()
            }
        } else {
            try await container.viewContext.perform {
                let closet = try self.container.viewContext.existingObject(with: objectID)
                self.container.viewContext.delete(closet)
                try self.container.viewContext.save()
            }
        }

        for paths in snapshot.imagePaths {
            ImageStore.delete(relativePath: paths.0)
            ImageStore.delete(relativePath: paths.1)
        }
    }

    #if DEBUG
    func initializeDevelopmentCloudKitSchema() throws {
        try container.initializeCloudKitSchema(options: [])
        print("Pocket Closet CloudKit schema initialization succeeded")
    }
    #endif

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        let closet = entity("Closet", Closet.self)
        let person = entity("Person", Person.self)
        let location = entity("StorageLocation", StorageLocation.self)
        let item = entity("ClothingItem", ClothingItem.self)

        closet.properties = [
            attribute("id", .UUIDAttributeType, defaultValue: UUID()),
            attribute("name", .stringAttributeType, defaultValue: "Closet"),
            attribute("createdAt", .dateAttributeType, defaultValue: Date()),
            attribute("updatedAt", .dateAttributeType, defaultValue: Date())
        ]
        person.properties = [
            attribute("id", .UUIDAttributeType, defaultValue: UUID()),
            attribute("name", .stringAttributeType, defaultValue: "Person"),
            attribute("colorToken", .stringAttributeType, defaultValue: "green"),
            attribute("avatarImagePath", .stringAttributeType, optional: true),
            attribute("createdAt", .dateAttributeType, defaultValue: Date()),
            attribute("updatedAt", .dateAttributeType, defaultValue: Date())
        ]
        location.properties = [
            attribute("id", .UUIDAttributeType, defaultValue: UUID()),
            attribute("name", .stringAttributeType, defaultValue: "Location"),
            attribute("kindRaw", .stringAttributeType, defaultValue: LocationKind.custom.rawValue),
            attribute("iconName", .stringAttributeType, defaultValue: LocationKind.custom.iconName),
            attribute("colorToken", .stringAttributeType, defaultValue: "green"),
            attribute("createdAt", .dateAttributeType, defaultValue: Date()),
            attribute("updatedAt", .dateAttributeType, defaultValue: Date())
        ]
        item.properties = [
            attribute("id", .UUIDAttributeType, defaultValue: UUID()),
            attribute("photoPath", .stringAttributeType, defaultValue: ""),
            attribute("thumbnailPath", .stringAttributeType, defaultValue: ""),
            binaryAttribute("photoData"),
            binaryAttribute("thumbnailData"),
            attribute("typeRaw", .stringAttributeType, defaultValue: ClothingType.other.rawValue),
            attribute("sizeSystemRaw", .stringAttributeType, defaultValue: SizeSystem.adultAlpha.rawValue),
            attribute("sizeLabel", .stringAttributeType, defaultValue: ""),
            attribute("sizeSortOrder", .integer64AttributeType, defaultValue: 0),
            attribute("statusRaw", .stringAttributeType, defaultValue: ItemStatus.needsReview.rawValue),
            attribute("seasonRaw", .stringAttributeType, optional: true),
            attribute("brand", .stringAttributeType, optional: true),
            attribute("colorName", .stringAttributeType, optional: true),
            attribute("notes", .stringAttributeType, optional: true),
            attribute("createdAt", .dateAttributeType, defaultValue: Date()),
            attribute("updatedAt", .dateAttributeType, defaultValue: Date()),
            attribute("archivedAt", .dateAttributeType, optional: true)
        ]

        relate(closet, "people", to: person, "closet", toMany: true, deleteRule: .cascadeDeleteRule)
        relate(closet, "locations", to: location, "closet", toMany: true, deleteRule: .cascadeDeleteRule)
        relate(closet, "items", to: item, "closet", toMany: true, deleteRule: .cascadeDeleteRule)
        relate(person, "items", to: item, "owner", toMany: true)
        relate(location, "items", to: item, "location", toMany: true)

        model.entities = [closet, person, location, item]
        return model
    }

    private static func entity(_ name: String, _ type: NSManagedObject.Type) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = NSStringFromClass(type)
        return entity
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        return attribute
    }

    private static func binaryAttribute(_ name: String) -> NSAttributeDescription {
        let attribute = attribute(name, .binaryDataAttributeType, optional: true)
        attribute.allowsExternalBinaryDataStorage = true
        return attribute
    }

    private static func relate(
        _ source: NSEntityDescription,
        _ sourceName: String,
        to destination: NSEntityDescription,
        _ destinationName: String,
        toMany: Bool,
        deleteRule: NSDeleteRule = .nullifyDeleteRule
    ) {
        let forward = NSRelationshipDescription()
        forward.name = sourceName
        forward.destinationEntity = destination
        forward.minCount = 0
        forward.maxCount = toMany ? 0 : 1
        forward.isOptional = true
        forward.deleteRule = deleteRule

        let inverse = NSRelationshipDescription()
        inverse.name = destinationName
        inverse.destinationEntity = source
        inverse.minCount = 0
        inverse.maxCount = 1
        inverse.isOptional = true
        inverse.deleteRule = .nullifyDeleteRule

        forward.inverseRelationship = inverse
        inverse.inverseRelationship = forward
        source.properties.append(forward)
        destination.properties.append(inverse)
    }
}

final class PocketClosetSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            ShareAcceptanceCoordinator.shared.accept(metadata)
        }
    }

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        ShareAcceptanceCoordinator.shared.accept(metadata)
    }
}

final class PocketClosetAppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = PocketClosetSceneDelegate.self
        return configuration
    }
}

@main
struct PocketClosetApp: App {
    @UIApplicationDelegateAdaptor(PocketClosetAppDelegate.self) private var appDelegate
    @StateObject private var closetSession = ClosetSession()
    @StateObject private var shareAcceptance = ShareAcceptanceCoordinator.shared
    private let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            AppShell()
                .environmentObject(closetSession)
                .environmentObject(shareAcceptance)
                .environment(\.persistenceController, persistenceController)
        }
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
    }
}

private struct PersistenceControllerKey: EnvironmentKey {
    static let defaultValue = PersistenceController.shared
}

extension EnvironmentValues {
    var persistenceController: PersistenceController {
        get { self[PersistenceControllerKey.self] }
        set { self[PersistenceControllerKey.self] = newValue }
    }
}
