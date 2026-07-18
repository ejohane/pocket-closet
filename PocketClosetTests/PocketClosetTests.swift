import CoreData
import SQLite3
import XCTest
@testable import PocketCloset

@MainActor
final class PocketClosetTests: XCTestCase {
    private lazy var persistenceController = PersistenceController(inMemory: true, cloudSyncEnabled: false)
    private lazy var context = persistenceController.container.viewContext

    func testToddlerSizesKeepExpectedOrder() {
        XCTAssertEqual(SizeCatalog.toddler.map(\.label), ["2T", "3T", "4T", "5T"])
        XCTAssertLessThan(SizeCatalog.toddler[0].sortOrder, SizeCatalog.toddler[1].sortOrder)
    }

    func testSizeCatalogHasStableUniqueIDs() {
        let ids = SizeCatalog.allOptions.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
        XCTAssertTrue(ids.contains("Toddler-4T"))
        XCTAssertTrue(ids.contains("Shoes-8"))
    }

    func testRequiredFieldValidation() {
        let owner = Person(context: context, name: "Emma")
        let location = StorageLocation(context: context, name: "Bin 2", kind: .storageBin)
        let size = SizeCatalog.toddler[2]

        XCTAssertTrue(ItemValidation.canSave(hasPhoto: true, owner: owner, size: size, location: location))
        XCTAssertFalse(ItemValidation.canSave(hasPhoto: false, owner: owner, size: size, location: location))
        XCTAssertFalse(ItemValidation.canSave(hasPhoto: true, owner: nil, size: size, location: location))
        XCTAssertFalse(ItemValidation.canSave(hasPhoto: true, owner: owner, size: nil, location: location))
        XCTAssertFalse(ItemValidation.canSave(hasPhoto: true, owner: owner, size: size, location: nil))
    }

    func testInventoryFilterMatchesMetadata() {
        let owner = Person(context: context, name: "Emma")
        let location = StorageLocation(context: context, name: "Bin 2", kind: .storageBin)
        let item = ClothingItem(
            context: context,
            photoPath: "PocketClosetImages/full.jpg",
            thumbnailPath: "PocketClosetImages/thumb.jpg",
            owner: owner,
            type: .top,
            size: SizeCatalog.toddler[2],
            location: location,
            status: .inStorage,
            brand: "Primary",
            colorName: "Green",
            notes: "Favorite sweatshirt"
        )

        XCTAssertTrue(InventoryFilter(query: "sweat").matches(item))
        XCTAssertTrue(InventoryFilter(ownerID: owner.id, type: .top, sizeLabel: "4T", status: .inStorage, locationID: location.id).matches(item))
        XCTAssertFalse(InventoryFilter(ownerID: UUID()).matches(item))
        XCTAssertFalse(InventoryFilter(sizeLabel: "5T").matches(item))
    }

    func testDateAddedFilterExcludesOlderItems() {
        let oldItem = ClothingItem(
            context: context,
            photoPath: "a",
            thumbnailPath: "a",
            owner: Person(context: context, name: "Emma"),
            type: .top,
            size: SizeCatalog.toddler[0],
            location: StorageLocation(context: context, name: "Closet", kind: .closet),
            createdAt: Calendar.current.date(byAdding: .day, value: -40, to: Date())!
        )

        XCTAssertFalse(InventoryFilter(dateAdded: .pastMonth).matches(oldItem))
        XCTAssertTrue(InventoryFilter(dateAdded: .pastThreeMonths).matches(oldItem))
    }

    func testSizeValidityTracksClothingType() {
        XCTAssertTrue(SizeCatalog.isValid(SizeCatalog.toddler[0], for: .top))
        XCTAssertFalse(SizeCatalog.isValid(SizeCatalog.toddler[0], for: .shoes))
        XCTAssertTrue(SizeCatalog.isValid(SizeCatalog.toddlerShoes[0], for: .shoes))
        XCTAssertFalse(SizeCatalog.isValid(SizeCatalog.toddlerShoes[0], for: .bottom))
    }

    func testArchivedItemsAreHiddenByDefault() {
        let item = ClothingItem(
            context: context,
            photoPath: "PocketClosetImages/full.jpg",
            thumbnailPath: "PocketClosetImages/thumb.jpg",
            owner: Person(context: context, name: "Theo"),
            type: .outerwear,
            size: SizeCatalog.kidsNumeric[2],
            location: StorageLocation(context: context, name: "Closet", kind: .closet),
            status: .archived,
            archivedAt: Date()
        )

        XCTAssertFalse(InventoryFilter().matches(item))
        XCTAssertTrue(InventoryFilter(includeArchived: true).matches(item))
    }

    func testStatusCountsAggregateActiveItems() {
        let owner = Person(context: context, name: "Emma")
        let location = StorageLocation(context: context, name: "Closet", kind: .closet)
        let items = [
            ClothingItem(context: context, photoPath: "a", thumbnailPath: "a", owner: owner, type: .top, size: SizeCatalog.toddler[0], location: location, status: .inCloset),
            ClothingItem(context: context, photoPath: "b", thumbnailPath: "b", owner: owner, type: .bottom, size: SizeCatalog.toddler[0], location: location, status: .inCloset),
            ClothingItem(context: context, photoPath: "c", thumbnailPath: "c", owner: owner, type: .shoes, size: SizeCatalog.infantShoes[1], location: location, status: .donate)
        ]

        let counts = InventoryMetrics.statusCounts(items: items)
        XCTAssertEqual(counts[.inCloset], 2)
        XCTAssertEqual(counts[.donate], 1)
        XCTAssertNil(counts[.sell])
    }

    func testCompoundSortUsesCriteriaInPriorityOrder() {
        let emma = Person(context: context, name: "Emma")
        let theo = Person(context: context, name: "Theo")
        let location = StorageLocation(context: context, name: "Closet", kind: .closet)
        let items = [
            ClothingItem(context: context, photoPath: "a", thumbnailPath: "a", owner: theo, type: .top, size: SizeCatalog.toddler[2], location: location),
            ClothingItem(context: context, photoPath: "b", thumbnailPath: "b", owner: emma, type: .bottom, size: SizeCatalog.toddler[2], location: location),
            ClothingItem(context: context, photoPath: "c", thumbnailPath: "c", owner: theo, type: .top, size: SizeCatalog.toddler[0], location: location)
        ]

        let sorted = InventorySorter.sort(items, using: [
            InventorySortCriterion(field: .size, direction: .ascending),
            InventorySortCriterion(field: .owner, direction: .ascending)
        ])

        XCTAssertEqual(sorted.map(\.thumbnailPath), ["c", "b", "a"])
    }

    func testShoesRemainAfterClothingForBothSizeDirections() {
        let owner = Person(context: context, name: "Emma")
        let location = StorageLocation(context: context, name: "Closet", kind: .closet)
        let clothing = ClothingItem(
            context: context,
            photoPath: "clothing",
            thumbnailPath: "clothing",
            owner: owner,
            type: .top,
            size: SizeCatalog.baby[0],
            location: location
        )
        let shoes = ClothingItem(
            context: context,
            photoPath: "shoes",
            thumbnailPath: "shoes",
            owner: owner,
            type: .shoes,
            size: SizeCatalog.adultShoes.last!,
            location: location
        )

        for direction in InventorySortDirection.allCases {
            let sorted = InventorySorter.sort(
                [shoes, clothing],
                using: [InventorySortCriterion(field: .size, direction: direction)]
            )
            XCTAssertEqual(sorted.map(\.thumbnailPath), ["clothing", "shoes"])
        }
    }

    func testSortConfigurationPersistsOrderAndRemovesDuplicateFields() {
        let criteria = [
            InventorySortCriterion(field: .size, direction: .descending),
            InventorySortCriterion(field: .type, direction: .ascending)
        ]
        let encoded = InventorySortConfiguration.encode(criteria)

        XCTAssertEqual(InventorySortConfiguration.decode(encoded), criteria)

        let duplicateData = try! JSONEncoder().encode(criteria + [criteria[0]])
        let duplicateString = String(decoding: duplicateData, as: UTF8.self)
        XCTAssertEqual(InventorySortConfiguration.decode(duplicateString), criteria)
        XCTAssertEqual(InventorySortConfiguration.decode("not json"), InventorySortConfiguration.defaultCriteria)
    }

    func testImageStoreSaveAndDelete() throws {
        let image = ImageStore.makePlaceholderImage(color: .systemGreen)
        let paths = try ImageStore.save(image: image)

        XCTAssertNotNil(ImageStore.load(relativePath: paths.photoPath))
        XCTAssertNotNil(ImageStore.load(relativePath: paths.thumbnailPath))

        ImageStore.delete(paths: paths)

        XCTAssertNil(ImageStore.load(relativePath: paths.photoPath))
        XCTAssertNil(ImageStore.load(relativePath: paths.thumbnailPath))
    }

    func testDefaultClosetScopesSeededLocations() throws {
        let closet = DefaultDataSeeder.seedDefaultsIfNeeded(
            in: context,
            privateStore: persistenceController.privateStore
        )
        XCTAssertEqual(closet?.name, "Our Closet")

        let locations = try context.fetch(StorageLocation.fetchRequest())
        XCTAssertEqual(locations.count, 6)
        XCTAssertTrue(locations.allSatisfy { $0.closet == closet })
    }

    func testSavedImagesIncludeCloudKitBackedData() throws {
        let paths = try ImageStore.save(image: ImageStore.makePlaceholderImage(color: .systemBlue))
        defer { ImageStore.delete(paths: paths) }

        XCTAssertFalse(paths.photoData.isEmpty)
        XCTAssertFalse(paths.thumbnailData.isEmpty)
        XCTAssertNotNil(ImageStore.load(data: paths.photoData))
        XCTAssertNotNil(ImageStore.load(data: paths.thumbnailData))
    }

    func testClothingListTracksSharedProgressWithoutChangingInventory() throws {
        let closet = Closet(context: context, name: "Family")
        context.assign(closet, to: persistenceController.privateStore)
        let owner = Person(context: context, closet: closet, name: "Emma")
        let location = StorageLocation(context: context, closet: closet, name: "Dresser", kind: .dresser)
        let item = ClothingItem(
            context: context,
            closet: closet,
            photoPath: "full.jpg",
            thumbnailPath: "thumb.jpg",
            owner: owner,
            type: .top,
            size: SizeCatalog.toddler[0],
            location: location,
            status: .inCloset
        )
        let clothingList = ClothingList(context: context, closet: closet, name: "Weekend Bag")
        let entry = ClothingListEntry(context: context, list: clothingList, item: item)
        try context.save()

        entry.setCompleted(true)
        try context.save()

        XCTAssertEqual(closet.lists, Set([clothingList]))
        XCTAssertEqual(clothingList.entries, Set([entry]))
        XCTAssertEqual(item.listEntries, Set([entry]))
        XCTAssertTrue(entry.isCompleted)
        XCTAssertNotNil(entry.completedAt)
        XCTAssertEqual(item.status, .inCloset)
        XCTAssertEqual(item.location, location)

        entry.setCompleted(false)
        XCTAssertFalse(entry.isCompleted)
        XCTAssertNil(entry.completedAt)
    }

    func testDeletingClothingItemRemovesItsListEntriesButKeepsTheList() throws {
        let closet = Closet(context: context, name: "Family")
        context.assign(closet, to: persistenceController.privateStore)
        let item = ClothingItem(
            context: context,
            closet: closet,
            photoPath: "full.jpg",
            thumbnailPath: "thumb.jpg",
            owner: Person(context: context, closet: closet, name: "Theo"),
            type: .bottom,
            size: SizeCatalog.toddler[0],
            location: StorageLocation(context: context, closet: closet, name: "Closet", kind: .closet)
        )
        let clothingList = ClothingList(context: context, closet: closet, name: "Next Week")
        _ = ClothingListEntry(context: context, list: clothingList, item: item)
        try context.save()

        context.delete(item)
        try context.save()

        XCTAssertEqual(try context.count(for: ClothingList.fetchRequest()), 1)
        XCTAssertEqual(try context.count(for: ClothingListEntry.fetchRequest()), 0)
    }

    func testDuplicateClosetGraphPreservesDataAndRebuildsRelationships() async throws {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let updatedAt = Date(timeIntervalSince1970: 2_000)
        let archivedAt = Date(timeIntervalSince1970: 3_000)
        let original = Closet(context: context, name: "Kids", createdAt: createdAt, updatedAt: updatedAt)
        context.assign(original, to: persistenceController.privateStore)
        let person = Person(
            context: context,
            closet: original,
            name: "Emma",
            colorToken: "pink",
            avatarImagePath: "avatar.jpg",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        let location = StorageLocation(
            context: context,
            closet: original,
            name: "Bin 2",
            kind: .storageBin,
            iconName: "shippingbox.fill",
            colorToken: "blue",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        let item = ClothingItem(
            context: context,
            closet: original,
            photoPath: "full.jpg",
            thumbnailPath: "thumb.jpg",
            photoData: Data([1, 2, 3]),
            thumbnailData: Data([4, 5]),
            owner: person,
            type: .outerwear,
            size: SizeCatalog.kidsNumeric[1],
            location: location,
            status: .archived,
            season: .coldWeather,
            brand: "Primary",
            colorName: "Green",
            notes: "Warm",
            createdAt: createdAt,
            updatedAt: updatedAt,
            archivedAt: archivedAt
        )
        let clothingList = ClothingList(
            context: context,
            closet: original,
            name: "Cabin Weekend",
            notes: "Warm layers",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        _ = ClothingListEntry(
            context: context,
            list: clothingList,
            item: item,
            isCompleted: true,
            completedAt: archivedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        try context.save()

        let copyID = try await persistenceController.duplicateClosetGraph(for: original.objectID)
        let copy = try XCTUnwrap(try context.existingObject(with: copyID) as? Closet)
        let copiedPerson = try XCTUnwrap(copy.people?.first)
        let copiedLocation = try XCTUnwrap(copy.locations?.first)
        let copiedItem = try XCTUnwrap(copy.items?.first)
        let copiedList = try XCTUnwrap(copy.lists?.first)
        let copiedEntry = try XCTUnwrap(copiedList.entries?.first)

        XCTAssertNotEqual(copy.id, original.id)
        XCTAssertEqual(copy.name, original.name)
        XCTAssertEqual(copy.createdAt, createdAt)
        XCTAssertEqual(copy.updatedAt, updatedAt)
        XCTAssertNotEqual(copiedPerson.id, person.id)
        XCTAssertEqual(copiedPerson.name, person.name)
        XCTAssertEqual(copiedPerson.avatarImagePath, person.avatarImagePath)
        XCTAssertNotEqual(copiedLocation.id, location.id)
        XCTAssertEqual(copiedLocation.iconName, location.iconName)
        XCTAssertNotEqual(copiedItem.id, item.id)
        XCTAssertEqual(copiedItem.photoData, item.photoData)
        XCTAssertEqual(copiedItem.thumbnailData, item.thumbnailData)
        XCTAssertEqual(copiedItem.statusRaw, item.statusRaw)
        XCTAssertEqual(copiedItem.archivedAt, archivedAt)
        XCTAssertEqual(copiedItem.owner, copiedPerson)
        XCTAssertEqual(copiedItem.location, copiedLocation)
        XCTAssertEqual(copiedItem.closet, copy)
        XCTAssertEqual(copiedList.name, clothingList.name)
        XCTAssertEqual(copiedList.notes, clothingList.notes)
        XCTAssertTrue(copiedEntry.isCompleted)
        XCTAssertEqual(copiedEntry.completedAt, archivedAt)
        XCTAssertEqual(copiedEntry.item, copiedItem)
        XCTAssertEqual(original.items?.count, 1)
    }

    func testDeletingOwnedClosetDeletesItsEntireGraph() async throws {
        let closet = Closet(context: context, name: "Duplicate")
        context.assign(closet, to: persistenceController.privateStore)
        let person = Person(context: context, closet: closet, name: "Emma")
        let location = StorageLocation(context: context, closet: closet, name: "Bin", kind: .storageBin)
        _ = ClothingItem(
            context: context,
            closet: closet,
            photoPath: "missing-full.jpg",
            thumbnailPath: "missing-thumb.jpg",
            owner: person,
            type: .top,
            size: SizeCatalog.toddler[0],
            location: location
        )
        let clothingList = ClothingList(context: context, closet: closet, name: "Packing")
        if let item = closet.items?.first {
            _ = ClothingListEntry(context: context, list: clothingList, item: item)
        }
        try context.save()

        try await persistenceController.deleteOwnedCloset(closet.objectID)

        XCTAssertEqual(try context.count(for: Closet.fetchRequest()), 0)
        XCTAssertEqual(try context.count(for: Person.fetchRequest()), 0)
        XCTAssertEqual(try context.count(for: StorageLocation.fetchRequest()), 0)
        XCTAssertEqual(try context.count(for: ClothingItem.fetchRequest()), 0)
        XCTAssertEqual(try context.count(for: ClothingList.fetchRequest()), 0)
        XCTAssertEqual(try context.count(for: ClothingListEntry.fetchRequest()), 0)
    }

    func testLegacySwiftDataStoreMigratesRelationshipsAndMetadata() throws {
        let legacyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PocketClosetLegacy-\(UUID().uuidString).store")
        defer { try? FileManager.default.removeItem(at: legacyURL) }
        let imagePaths = try ImageStore.save(image: ImageStore.makePlaceholderImage(color: .systemPink))
        defer { ImageStore.delete(paths: imagePaths) }
        try createLegacyFixture(
            at: legacyURL,
            photoPath: imagePaths.photoPath,
            thumbnailPath: imagePaths.thumbnailPath
        )

        let summary = try LegacyStoreMigrator.migrateIfNeeded(
            from: legacyURL,
            into: context,
            privateStore: persistenceController.privateStore
        )

        XCTAssertEqual(summary, LegacyMigrationSummary(people: 1, locations: 1, items: 1))
        let closets = try context.fetch(Closet.fetchRequest())
        let people = try context.fetch(Person.fetchRequest())
        let locations = try context.fetch(StorageLocation.fetchRequest())
        let items = try context.fetch(ClothingItem.fetchRequest())

        XCTAssertEqual(closets.map(\.name), ["Our Closet"])
        XCTAssertEqual(people.first?.name, "Emma")
        XCTAssertEqual(people.first?.id.uuidString, "00112233-4455-6677-8899-AABBCCDDEEFF")
        XCTAssertEqual(locations.first?.name, "Bin 2")
        XCTAssertEqual(items.first?.owner, people.first)
        XCTAssertEqual(items.first?.location, locations.first)
        XCTAssertEqual(items.first?.closet, closets.first)
        XCTAssertEqual(items.first?.brand, "Fixture Brand")
        XCTAssertEqual(items.first?.sizeLabel, "4T")
        XCTAssertEqual(items.first?.status, .inStorage)
        XCTAssertEqual(items.first?.photoData, imagePaths.photoData)
        XCTAssertEqual(items.first?.thumbnailData, imagePaths.thumbnailData)

        let secondAttempt = try LegacyStoreMigrator.migrateIfNeeded(
            from: legacyURL,
            into: context,
            privateStore: persistenceController.privateStore
        )
        XCTAssertNil(secondAttempt)
        XCTAssertEqual(try context.count(for: ClothingItem.fetchRequest()), 1)
    }

    private func createLegacyFixture(at url: URL, photoPath: String, thumbnailPath: String) throws {
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
            throw LegacyMigrationError.couldNotOpenDatabase(message: "Test fixture could not open")
        }
        defer { sqlite3_close(database) }

        let sql = """
        CREATE TABLE ZPERSON (
            Z_PK INTEGER PRIMARY KEY, ZCREATEDAT TIMESTAMP, ZUPDATEDAT TIMESTAMP,
            ZAVATARIMAGEPATH VARCHAR, ZCOLORTOKEN VARCHAR, ZNAME VARCHAR, ZID BLOB
        );
        CREATE TABLE ZSTORAGELOCATION (
            Z_PK INTEGER PRIMARY KEY, ZCREATEDAT TIMESTAMP, ZUPDATEDAT TIMESTAMP,
            ZCOLORTOKEN VARCHAR, ZICONNAME VARCHAR, ZKINDRAW VARCHAR, ZNAME VARCHAR, ZID BLOB
        );
        CREATE TABLE ZCLOTHINGITEM (
            Z_PK INTEGER PRIMARY KEY, ZSIZESORTORDER INTEGER, ZLOCATION INTEGER, ZOWNER INTEGER,
            ZARCHIVEDAT TIMESTAMP, ZCREATEDAT TIMESTAMP, ZUPDATEDAT TIMESTAMP,
            ZBRAND VARCHAR, ZCOLORNAME VARCHAR, ZNOTES VARCHAR, ZPHOTOPATH VARCHAR,
            ZSEASONRAW VARCHAR, ZSIZELABEL VARCHAR, ZSIZESYSTEMRAW VARCHAR,
            ZSTATUSRAW VARCHAR, ZTHUMBNAILPATH VARCHAR, ZTYPERAW VARCHAR, ZID BLOB
        );
        INSERT INTO ZPERSON VALUES (
            1, 100, 200, NULL, 'pink', 'Emma', X'00112233445566778899AABBCCDDEEFF'
        );
        INSERT INTO ZSTORAGELOCATION VALUES (
            1, 300, 400, 'blue', 'shippingbox', 'Storage Bin', 'Bin 2',
            X'102132435465768798A9BACBDCEDFE0F'
        );
        INSERT INTO ZCLOTHINGITEM VALUES (
            1, 2, 1, 1, NULL, 500, 600, 'Fixture Brand', 'Green', 'Fixture notes',
            '\(photoPath)', 'Winter', '4T', 'Toddler', 'In Storage',
            '\(thumbnailPath)', 'Top', X'FFEEDDCCBBAA99887766554433221100'
        );
        """

        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown SQLite error"
            sqlite3_free(errorMessage)
            throw LegacyMigrationError.invalidLegacyStore(message: message)
        }
    }
}
