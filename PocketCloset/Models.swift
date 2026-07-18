import CoreData
import Foundation

@objc(Closet)
final class Closet: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var people: Set<Person>?
    @NSManaged var locations: Set<StorageLocation>?
    @NSManaged var items: Set<ClothingItem>?
    @NSManaged var lists: Set<ClothingList>?

    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init(context: context)
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@objc(Person)
final class Person: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var colorToken: String
    @NSManaged var avatarImagePath: String?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var closet: Closet?
    @NSManaged var items: Set<ClothingItem>?

    convenience init(
        context: NSManagedObjectContext,
        closet: Closet? = nil,
        id: UUID = UUID(),
        name: String,
        colorToken: String = "green",
        avatarImagePath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init(context: context)
        self.id = id
        self.name = name
        self.colorToken = colorToken
        self.avatarImagePath = avatarImagePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.closet = closet
        if let store = closet?.objectID.persistentStore {
            context.assign(self, to: store)
        }
    }
}

@objc(StorageLocation)
final class StorageLocation: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var kindRaw: String
    @NSManaged var iconName: String
    @NSManaged var colorToken: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var closet: Closet?
    @NSManaged var items: Set<ClothingItem>?

    var kind: LocationKind {
        get { LocationKind(rawValue: kindRaw) ?? .custom }
        set {
            kindRaw = newValue.rawValue
            iconName = newValue.iconName
        }
    }

    convenience init(
        context: NSManagedObjectContext,
        closet: Closet? = nil,
        id: UUID = UUID(),
        name: String,
        kind: LocationKind = .custom,
        iconName: String? = nil,
        colorToken: String = "green",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init(context: context)
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.iconName = iconName ?? kind.iconName
        self.colorToken = colorToken
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.closet = closet
        if let store = closet?.objectID.persistentStore {
            context.assign(self, to: store)
        }
    }
}

@objc(ClothingItem)
final class ClothingItem: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var photoPath: String
    @NSManaged var thumbnailPath: String
    @NSManaged var photoData: Data?
    @NSManaged var thumbnailData: Data?
    @NSManaged var typeRaw: String
    @NSManaged var sizeSystemRaw: String
    @NSManaged var sizeLabel: String
    @NSManaged var sizeSortOrder: Int64
    @NSManaged var statusRaw: String
    @NSManaged var seasonRaw: String?
    @NSManaged var brand: String?
    @NSManaged var colorName: String?
    @NSManaged var notes: String?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var archivedAt: Date?
    @NSManaged var closet: Closet?
    @NSManaged var owner: Person?
    @NSManaged var location: StorageLocation?
    @NSManaged var listEntries: Set<ClothingListEntry>?

    var type: ClothingType {
        get { ClothingType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var sizeSystem: SizeSystem {
        get { SizeSystem(rawValue: sizeSystemRaw) ?? .adultAlpha }
        set { sizeSystemRaw = newValue.rawValue }
    }

    var sizeOption: SizeOption {
        get { SizeCatalog.defaultOption(systemRaw: sizeSystemRaw, label: sizeLabel, sortOrder: Int(sizeSortOrder)) }
        set {
            sizeSystemRaw = newValue.system.rawValue
            sizeLabel = newValue.label
            sizeSortOrder = Int64(newValue.sortOrder)
        }
    }

    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .needsReview }
        set {
            statusRaw = newValue.rawValue
            archivedAt = newValue == .archived ? (archivedAt ?? Date()) : nil
        }
    }

    var season: ClothingSeason? {
        get { seasonRaw.flatMap(ClothingSeason.init(rawValue:)) }
        set { seasonRaw = newValue?.rawValue }
    }

    convenience init(
        context: NSManagedObjectContext,
        closet: Closet? = nil,
        id: UUID = UUID(),
        photoPath: String,
        thumbnailPath: String,
        photoData: Data? = nil,
        thumbnailData: Data? = nil,
        owner: Person?,
        type: ClothingType,
        size: SizeOption,
        location: StorageLocation?,
        status: ItemStatus = .inStorage,
        season: ClothingSeason? = nil,
        brand: String? = nil,
        colorName: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        archivedAt: Date? = nil
    ) {
        self.init(context: context)
        self.id = id
        self.photoPath = photoPath
        self.thumbnailPath = thumbnailPath
        self.photoData = photoData
        self.thumbnailData = thumbnailData
        self.owner = owner
        self.typeRaw = type.rawValue
        self.sizeSystemRaw = size.system.rawValue
        self.sizeLabel = size.label
        self.sizeSortOrder = Int64(size.sortOrder)
        self.location = location
        self.statusRaw = status.rawValue
        self.seasonRaw = season?.rawValue
        self.brand = brand
        self.colorName = colorName
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
        self.closet = closet
        if let store = closet?.objectID.persistentStore {
            context.assign(self, to: store)
        }
    }

    func markUpdated() {
        updatedAt = Date()
    }
}

@objc(ClothingList)
final class ClothingList: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var notes: String?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var archivedAt: Date?
    @NSManaged var closet: Closet?
    @NSManaged var entries: Set<ClothingListEntry>?

    convenience init(
        context: NSManagedObjectContext,
        closet: Closet? = nil,
        id: UUID = UUID(),
        name: String,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        archivedAt: Date? = nil
    ) {
        self.init(context: context)
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
        self.closet = closet
        if let store = closet?.objectID.persistentStore {
            context.assign(self, to: store)
        }
    }

    func markUpdated() {
        updatedAt = Date()
    }
}

@objc(ClothingListEntry)
final class ClothingListEntry: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var isCompleted: Bool
    @NSManaged var completedAt: Date?
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var list: ClothingList?
    @NSManaged var item: ClothingItem?

    convenience init(
        context: NSManagedObjectContext,
        list: ClothingList,
        item: ClothingItem,
        id: UUID = UUID(),
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init(context: context)
        self.id = id
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.list = list
        self.item = item
        if let store = list.objectID.persistentStore {
            context.assign(self, to: store)
        }
    }

    func setCompleted(_ completed: Bool) {
        isCompleted = completed
        completedAt = completed ? Date() : nil
        updatedAt = Date()
        list?.markUpdated()
    }
}

extension Closet {
    static func fetchRequest() -> NSFetchRequest<Closet> {
        NSFetchRequest(entityName: "Closet")
    }

    static func find(id: UUID?, in context: NSManagedObjectContext) -> Closet? {
        guard let id else { return nil }
        let request = fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? context.fetch(request).first
    }
}

extension Person {
    static func fetchRequest() -> NSFetchRequest<Person> {
        NSFetchRequest(entityName: "Person")
    }
}

extension StorageLocation {
    static func fetchRequest() -> NSFetchRequest<StorageLocation> {
        NSFetchRequest(entityName: "StorageLocation")
    }
}

extension ClothingItem {
    static func fetchRequest() -> NSFetchRequest<ClothingItem> {
        NSFetchRequest(entityName: "ClothingItem")
    }
}

extension ClothingList {
    static func fetchRequest() -> NSFetchRequest<ClothingList> {
        NSFetchRequest(entityName: "ClothingList")
    }
}

extension ClothingListEntry {
    static func fetchRequest() -> NSFetchRequest<ClothingListEntry> {
        NSFetchRequest(entityName: "ClothingListEntry")
    }
}
