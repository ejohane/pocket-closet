import SwiftData
import XCTest
@testable import PocketCloset

final class PocketClosetTests: XCTestCase {
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
        let owner = Person(name: "Emma")
        let location = StorageLocation(name: "Bin 2", kind: .storageBin)
        let size = SizeCatalog.toddler[2]

        XCTAssertTrue(ItemValidation.canSave(hasPhoto: true, owner: owner, size: size, location: location))
        XCTAssertFalse(ItemValidation.canSave(hasPhoto: false, owner: owner, size: size, location: location))
        XCTAssertFalse(ItemValidation.canSave(hasPhoto: true, owner: nil, size: size, location: location))
        XCTAssertFalse(ItemValidation.canSave(hasPhoto: true, owner: owner, size: nil, location: location))
        XCTAssertFalse(ItemValidation.canSave(hasPhoto: true, owner: owner, size: size, location: nil))
    }

    func testInventoryFilterMatchesMetadata() {
        let owner = Person(name: "Emma")
        let location = StorageLocation(name: "Bin 2", kind: .storageBin)
        let item = ClothingItem(
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
            photoPath: "a",
            thumbnailPath: "a",
            owner: Person(name: "Emma"),
            type: .top,
            size: SizeCatalog.toddler[0],
            location: StorageLocation(name: "Closet", kind: .closet),
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
            photoPath: "PocketClosetImages/full.jpg",
            thumbnailPath: "PocketClosetImages/thumb.jpg",
            owner: Person(name: "Theo"),
            type: .outerwear,
            size: SizeCatalog.kidsNumeric[2],
            location: StorageLocation(name: "Closet", kind: .closet),
            status: .archived,
            archivedAt: Date()
        )

        XCTAssertFalse(InventoryFilter().matches(item))
        XCTAssertTrue(InventoryFilter(includeArchived: true).matches(item))
    }

    func testStatusCountsAggregateActiveItems() {
        let owner = Person(name: "Emma")
        let location = StorageLocation(name: "Closet", kind: .closet)
        let items = [
            ClothingItem(photoPath: "a", thumbnailPath: "a", owner: owner, type: .top, size: SizeCatalog.toddler[0], location: location, status: .inCloset),
            ClothingItem(photoPath: "b", thumbnailPath: "b", owner: owner, type: .bottom, size: SizeCatalog.toddler[0], location: location, status: .inCloset),
            ClothingItem(photoPath: "c", thumbnailPath: "c", owner: owner, type: .shoes, size: SizeCatalog.infantShoes[1], location: location, status: .donate)
        ]

        let counts = InventoryMetrics.statusCounts(items: items)
        XCTAssertEqual(counts[.inCloset], 2)
        XCTAssertEqual(counts[.donate], 1)
        XCTAssertNil(counts[.sell])
    }

    func testCompoundSortUsesCriteriaInPriorityOrder() {
        let emma = Person(name: "Emma")
        let theo = Person(name: "Theo")
        let location = StorageLocation(name: "Closet", kind: .closet)
        let items = [
            ClothingItem(photoPath: "a", thumbnailPath: "a", owner: theo, type: .top, size: SizeCatalog.toddler[2], location: location),
            ClothingItem(photoPath: "b", thumbnailPath: "b", owner: emma, type: .bottom, size: SizeCatalog.toddler[2], location: location),
            ClothingItem(photoPath: "c", thumbnailPath: "c", owner: theo, type: .top, size: SizeCatalog.toddler[0], location: location)
        ]

        let sorted = InventorySorter.sort(items, using: [
            InventorySortCriterion(field: .size, direction: .ascending),
            InventorySortCriterion(field: .owner, direction: .ascending)
        ])

        XCTAssertEqual(sorted.map(\.thumbnailPath), ["c", "b", "a"])
    }

    func testShoesRemainAfterClothingForBothSizeDirections() {
        let owner = Person(name: "Emma")
        let location = StorageLocation(name: "Closet", kind: .closet)
        let clothing = ClothingItem(
            photoPath: "clothing",
            thumbnailPath: "clothing",
            owner: owner,
            type: .top,
            size: SizeCatalog.baby[0],
            location: location
        )
        let shoes = ClothingItem(
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
}
