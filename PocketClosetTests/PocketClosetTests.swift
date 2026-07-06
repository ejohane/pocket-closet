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
