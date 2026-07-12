import CoreData
import Foundation
import SQLite3

struct LegacyMigrationSummary: Equatable {
    let people: Int
    let locations: Int
    let items: Int
}

enum LegacyStoreMigrator {
    private static let completionKey = "legacySwiftDataMigrationCompleted"

    @MainActor
    static func migrateIfNeeded(
        from legacyURL: URL = NSPersistentContainer.defaultDirectoryURL().appendingPathComponent("default.store"),
        into context: NSManagedObjectContext,
        privateStore: NSPersistentStore
    ) throws -> LegacyMigrationSummary? {
        guard FileManager.default.fileExists(atPath: legacyURL.path) else { return nil }

        let closetRequest = Closet.fetchRequest()
        closetRequest.affectedStores = [privateStore]
        guard try context.count(for: closetRequest) == 0 else { return nil }

        let database = try LegacyDatabase(url: legacyURL)
        let peopleRows = try database.people()
        let locationRows = try database.locations()
        let itemRows = try database.items()

        guard !peopleRows.isEmpty || !locationRows.isEmpty || !itemRows.isEmpty else {
            UserDefaults.standard.set(true, forKey: completionKey)
            return LegacyMigrationSummary(people: 0, locations: 0, items: 0)
        }

        let closet = Closet(context: context, name: "Our Closet")
        context.assign(closet, to: privateStore)

        do {
            var peopleByLegacyID: [Int64: Person] = [:]
            for row in peopleRows {
                let person = Person(
                    context: context,
                    closet: closet,
                    id: row.id,
                    name: row.name,
                    colorToken: row.colorToken,
                    avatarImagePath: row.avatarImagePath,
                    createdAt: row.createdAt,
                    updatedAt: row.updatedAt
                )
                peopleByLegacyID[row.primaryKey] = person
            }

            var locationsByLegacyID: [Int64: StorageLocation] = [:]
            for row in locationRows {
                let location = StorageLocation(
                    context: context,
                    closet: closet,
                    id: row.id,
                    name: row.name,
                    kind: LocationKind(rawValue: row.kindRaw) ?? .custom,
                    iconName: row.iconName,
                    colorToken: row.colorToken,
                    createdAt: row.createdAt,
                    updatedAt: row.updatedAt
                )
                locationsByLegacyID[row.primaryKey] = location
            }

            for row in itemRows {
                _ = ClothingItem(
                    context: context,
                    closet: closet,
                    id: row.id,
                    photoPath: row.photoPath,
                    thumbnailPath: row.thumbnailPath,
                    photoData: ImageStore.loadData(relativePath: row.photoPath),
                    thumbnailData: ImageStore.loadData(relativePath: row.thumbnailPath),
                    owner: row.ownerPrimaryKey.flatMap { peopleByLegacyID[$0] },
                    type: ClothingType(rawValue: row.typeRaw) ?? .other,
                    size: SizeCatalog.defaultOption(
                        systemRaw: row.sizeSystemRaw,
                        label: row.sizeLabel,
                        sortOrder: row.sizeSortOrder
                    ),
                    location: row.locationPrimaryKey.flatMap { locationsByLegacyID[$0] },
                    status: ItemStatus(rawValue: row.statusRaw) ?? .needsReview,
                    season: row.seasonRaw.flatMap(ClothingSeason.init(rawValue:)),
                    brand: row.brand,
                    colorName: row.colorName,
                    notes: row.notes,
                    createdAt: row.createdAt,
                    updatedAt: row.updatedAt,
                    archivedAt: row.archivedAt
                )
            }

            try context.save()
            UserDefaults.standard.set(true, forKey: completionKey)
            return LegacyMigrationSummary(
                people: peopleRows.count,
                locations: locationRows.count,
                items: itemRows.count
            )
        } catch {
            context.rollback()
            throw error
        }
    }
}

private struct LegacyPersonRow {
    let primaryKey: Int64
    let id: UUID
    let name: String
    let colorToken: String
    let avatarImagePath: String?
    let createdAt: Date
    let updatedAt: Date
}

private struct LegacyLocationRow {
    let primaryKey: Int64
    let id: UUID
    let name: String
    let kindRaw: String
    let iconName: String
    let colorToken: String
    let createdAt: Date
    let updatedAt: Date
}

private struct LegacyItemRow {
    let id: UUID
    let ownerPrimaryKey: Int64?
    let locationPrimaryKey: Int64?
    let photoPath: String
    let thumbnailPath: String
    let typeRaw: String
    let sizeSystemRaw: String
    let sizeLabel: String
    let sizeSortOrder: Int
    let statusRaw: String
    let seasonRaw: String?
    let brand: String?
    let colorName: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let archivedAt: Date?
}

private final class LegacyDatabase {
    private var handle: OpaquePointer?

    init(url: URL) throws {
        let result = sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil)
        guard result == SQLITE_OK, handle != nil else {
            defer { if handle != nil { sqlite3_close(handle) } }
            throw LegacyMigrationError.couldNotOpenDatabase(message: String(cString: sqlite3_errmsg(handle)))
        }
    }

    deinit {
        sqlite3_close(handle)
    }

    func people() throws -> [LegacyPersonRow] {
        try rows(
            "SELECT Z_PK, ZID, ZNAME, ZCOLORTOKEN, ZAVATARIMAGEPATH, ZCREATEDAT, ZUPDATEDAT FROM ZPERSON"
        ) { statement in
            LegacyPersonRow(
                primaryKey: statement.int64(0),
                id: statement.uuid(1),
                name: statement.string(2) ?? "Person",
                colorToken: statement.string(3) ?? "green",
                avatarImagePath: statement.string(4),
                createdAt: statement.date(5) ?? Date(),
                updatedAt: statement.date(6) ?? Date()
            )
        }
    }

    func locations() throws -> [LegacyLocationRow] {
        try rows(
            "SELECT Z_PK, ZID, ZNAME, ZKINDRAW, ZICONNAME, ZCOLORTOKEN, ZCREATEDAT, ZUPDATEDAT FROM ZSTORAGELOCATION"
        ) { statement in
            LegacyLocationRow(
                primaryKey: statement.int64(0),
                id: statement.uuid(1),
                name: statement.string(2) ?? "Location",
                kindRaw: statement.string(3) ?? LocationKind.custom.rawValue,
                iconName: statement.string(4) ?? LocationKind.custom.iconName,
                colorToken: statement.string(5) ?? "green",
                createdAt: statement.date(6) ?? Date(),
                updatedAt: statement.date(7) ?? Date()
            )
        }
    }

    func items() throws -> [LegacyItemRow] {
        try rows(
            """
            SELECT ZID, ZOWNER, ZLOCATION, ZPHOTOPATH, ZTHUMBNAILPATH, ZTYPERAW,
                   ZSIZESYSTEMRAW, ZSIZELABEL, ZSIZESORTORDER, ZSTATUSRAW, ZSEASONRAW,
                   ZBRAND, ZCOLORNAME, ZNOTES, ZCREATEDAT, ZUPDATEDAT, ZARCHIVEDAT
            FROM ZCLOTHINGITEM
            """
        ) { statement in
            LegacyItemRow(
                id: statement.uuid(0),
                ownerPrimaryKey: statement.optionalInt64(1),
                locationPrimaryKey: statement.optionalInt64(2),
                photoPath: statement.string(3) ?? "",
                thumbnailPath: statement.string(4) ?? "",
                typeRaw: statement.string(5) ?? ClothingType.other.rawValue,
                sizeSystemRaw: statement.string(6) ?? SizeSystem.adultAlpha.rawValue,
                sizeLabel: statement.string(7) ?? "",
                sizeSortOrder: Int(statement.int64(8)),
                statusRaw: statement.string(9) ?? ItemStatus.needsReview.rawValue,
                seasonRaw: statement.string(10),
                brand: statement.string(11),
                colorName: statement.string(12),
                notes: statement.string(13),
                createdAt: statement.date(14) ?? Date(),
                updatedAt: statement.date(15) ?? Date(),
                archivedAt: statement.date(16)
            )
        }
    }

    private func rows<T>(_ sql: String, transform: (LegacyStatement) -> T) throws -> [T] {
        var rawStatement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &rawStatement, nil) == SQLITE_OK, let rawStatement else {
            throw LegacyMigrationError.invalidLegacyStore(message: String(cString: sqlite3_errmsg(handle)))
        }
        let statement = LegacyStatement(raw: rawStatement)
        defer { sqlite3_finalize(rawStatement) }

        var results: [T] = []
        while true {
            switch sqlite3_step(rawStatement) {
            case SQLITE_ROW:
                results.append(transform(statement))
            case SQLITE_DONE:
                return results
            default:
                throw LegacyMigrationError.invalidLegacyStore(message: String(cString: sqlite3_errmsg(handle)))
            }
        }
    }
}

private struct LegacyStatement {
    let raw: OpaquePointer

    func string(_ index: Int32) -> String? {
        guard sqlite3_column_type(raw, index) != SQLITE_NULL, let text = sqlite3_column_text(raw, index) else { return nil }
        return String(cString: text)
    }

    func int64(_ index: Int32) -> Int64 {
        sqlite3_column_int64(raw, index)
    }

    func optionalInt64(_ index: Int32) -> Int64? {
        sqlite3_column_type(raw, index) == SQLITE_NULL ? nil : int64(index)
    }

    func date(_ index: Int32) -> Date? {
        guard sqlite3_column_type(raw, index) != SQLITE_NULL else { return nil }
        return Date(timeIntervalSinceReferenceDate: sqlite3_column_double(raw, index))
    }

    func uuid(_ index: Int32) -> UUID {
        guard
            sqlite3_column_type(raw, index) == SQLITE_BLOB,
            sqlite3_column_bytes(raw, index) == 16,
            let blob = sqlite3_column_blob(raw, index)
        else { return UUID() }

        let bytes = blob.assumingMemoryBound(to: UInt8.self)
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

enum LegacyMigrationError: LocalizedError {
    case couldNotOpenDatabase(message: String)
    case invalidLegacyStore(message: String)

    var errorDescription: String? {
        switch self {
        case .couldNotOpenDatabase(let message):
            "Pocket Closet couldn't open the existing inventory: \(message)"
        case .invalidLegacyStore(let message):
            "Pocket Closet couldn't read the existing inventory: \(message)"
        }
    }
}
