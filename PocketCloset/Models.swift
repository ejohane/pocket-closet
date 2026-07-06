import Foundation
import SwiftData

@Model
final class Person {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorToken: String
    var avatarImagePath: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorToken: String = "green",
        avatarImagePath: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorToken = colorToken
        self.avatarImagePath = avatarImagePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class StorageLocation {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var iconName: String
    var colorToken: String
    var createdAt: Date
    var updatedAt: Date

    var kind: LocationKind {
        get { LocationKind(rawValue: kindRaw) ?? .custom }
        set {
            kindRaw = newValue.rawValue
            iconName = newValue.iconName
        }
    }

    init(
        id: UUID = UUID(),
        name: String,
        kind: LocationKind = .custom,
        iconName: String? = nil,
        colorToken: String = "green",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.iconName = iconName ?? kind.iconName
        self.colorToken = colorToken
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class ClothingItem {
    @Attribute(.unique) var id: UUID
    var photoPath: String
    var thumbnailPath: String
    var typeRaw: String
    var sizeSystemRaw: String
    var sizeLabel: String
    var sizeSortOrder: Int
    var statusRaw: String
    var seasonRaw: String?
    var brand: String?
    var colorName: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?
    var owner: Person?
    var location: StorageLocation?

    var type: ClothingType {
        get { ClothingType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var sizeSystem: SizeSystem {
        get { SizeSystem(rawValue: sizeSystemRaw) ?? .adultAlpha }
        set { sizeSystemRaw = newValue.rawValue }
    }

    var sizeOption: SizeOption {
        get { SizeCatalog.defaultOption(systemRaw: sizeSystemRaw, label: sizeLabel, sortOrder: sizeSortOrder) }
        set {
            sizeSystemRaw = newValue.system.rawValue
            sizeLabel = newValue.label
            sizeSortOrder = newValue.sortOrder
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

    init(
        id: UUID = UUID(),
        photoPath: String,
        thumbnailPath: String,
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
        self.id = id
        self.photoPath = photoPath
        self.thumbnailPath = thumbnailPath
        self.owner = owner
        self.typeRaw = type.rawValue
        self.sizeSystemRaw = size.system.rawValue
        self.sizeLabel = size.label
        self.sizeSortOrder = size.sortOrder
        self.location = location
        self.statusRaw = status.rawValue
        self.seasonRaw = season?.rawValue
        self.brand = brand
        self.colorName = colorName
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
    }

    func markUpdated() {
        updatedAt = Date()
    }
}
