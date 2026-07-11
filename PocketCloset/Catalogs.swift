import Foundation
import SwiftUI

enum ClothingType: String, CaseIterable, Identifiable, Codable {
    case top = "Top"
    case bottom = "Bottom"
    case dress = "Dress"
    case pajamas = "Pajamas"
    case set = "Set"
    case outerwear = "Outerwear"
    case shoes = "Shoes"
    case accessory = "Accessory"
    case swim = "Swim"
    case costume = "Costume"
    case uniformSports = "Uniform/Sports"
    case other = "Other"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .top: "tshirt"
        case .bottom: "rectangle.split.2x1"
        case .dress: "figure.dress.line.vertical.figure"
        case .pajamas: "moon"
        case .set: "square.grid.2x2"
        case .outerwear: "cloud.rain"
        case .shoes: "shoeprints.fill"
        case .accessory: "sunglasses"
        case .swim: "water.waves"
        case .costume: "theatermasks"
        case .uniformSports: "sportscourt"
        case .other: "tag"
        }
    }
}

enum ItemStatus: String, CaseIterable, Identifiable, Codable {
    case inCloset = "In Closet"
    case inStorage = "In Storage"
    case needsReview = "Needs Review"
    case tooSmall = "Too Small"
    case donate = "Donate"
    case sell = "Sell"
    case archived = "Archived"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .inCloset: "hanger"
        case .inStorage: "archivebox"
        case .needsReview: "checklist"
        case .tooSmall: "arrow.down.forward.and.arrow.up.backward"
        case .donate: "heart"
        case .sell: "dollarsign.circle"
        case .archived: "tray"
        }
    }

    var accent: Color {
        switch self {
        case .inCloset: PCColor.primary
        case .inStorage: PCColor.blue
        case .needsReview: PCColor.yellow
        case .tooSmall: PCColor.purple
        case .donate: PCColor.red
        case .sell: PCColor.aqua
        case .archived: .secondary
        }
    }
}

enum ClothingSeason: String, CaseIterable, Identifiable, Codable {
    case allSeason = "All Season"
    case warmWeather = "Warm Weather"
    case coldWeather = "Cold Weather"
    case rainSnow = "Rain/Snow"
    case specialOccasion = "Special Occasion"

    var id: String { rawValue }
}

enum LocationKind: String, CaseIterable, Identifiable, Codable {
    case closet = "Closet"
    case dresser = "Dresser"
    case storageBin = "Storage Bin"
    case garage = "Garage"
    case donateBag = "Donate Bag"
    case laundryUnknown = "Laundry/Unknown"
    case custom = "Custom"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .closet: "hanger"
        case .dresser: "rectangle.stack"
        case .storageBin: "archivebox"
        case .garage: "house"
        case .donateBag: "heart"
        case .laundryUnknown: "washer"
        case .custom: "mappin.and.ellipse"
        }
    }
}

enum SizeSystem: String, CaseIterable, Identifiable, Codable {
    case baby = "Baby"
    case toddler = "Toddler"
    case kidsNumeric = "Kids Numeric"
    case adultAlpha = "Adult Alpha"
    case adultNumeric = "Adult Numeric"
    case shoes = "Shoes"
    case pants = "Pants"

    var id: String { rawValue }
}

struct SizeOption: Identifiable, Hashable, Codable {
    let system: SizeSystem
    let label: String
    let sortOrder: Int

    var id: String { "\(system.rawValue)-\(label)" }
}

struct SizeGroup: Identifiable {
    let title: String
    let options: [SizeOption]

    var id: String { title }
}

enum DateAddedFilter: String, CaseIterable, Identifiable {
    case pastWeek = "Last 7 Days"
    case pastMonth = "Last 30 Days"
    case pastThreeMonths = "Last 90 Days"

    var id: String { rawValue }

    var dayCount: Int {
        switch self {
        case .pastWeek: 7
        case .pastMonth: 30
        case .pastThreeMonths: 90
        }
    }
}

enum SizeCatalog {
    static let baby = makeOptions(
        system: .baby,
        start: 0,
        labels: ["Preemie", "NB", "0-3M", "3-6M", "6-9M", "9-12M", "12M", "18M", "24M"]
    )

    static let toddler = makeOptions(
        system: .toddler,
        start: 100,
        labels: ["2T", "3T", "4T", "5T"]
    )

    static let kidsNumeric = makeOptions(
        system: .kidsNumeric,
        start: 200,
        labels: ["4", "5", "6", "6X", "7", "8", "10", "12", "14", "16", "18", "20"]
    )

    static let adultAlpha = makeOptions(
        system: .adultAlpha,
        start: 300,
        labels: ["XS", "S", "M", "L", "XL", "XXL"]
    )

    static let adultNumeric = makeOptions(
        system: .adultNumeric,
        start: 400,
        labels: ["0", "2", "4", "6", "8", "10", "12", "14", "16", "18", "20", "22"]
    )

    static let infantShoes = makeOptions(
        system: .shoes,
        start: 500,
        labels: ["0C", "1C", "2C", "3C", "4C"]
    )

    static let toddlerShoes = makeOptions(
        system: .shoes,
        start: 520,
        labels: ["5C", "6C", "7C", "8C", "9C", "10C"]
    )

    static let kidsShoes = makeOptions(
        system: .shoes,
        start: 540,
        labels: ["10.5C", "11C", "11.5C", "12C", "12.5C", "13C", "13.5C", "1Y", "1.5Y", "2Y", "2.5Y", "3Y", "3.5Y", "4Y", "4.5Y", "5Y", "5.5Y", "6Y", "6.5Y", "7Y"]
    )

    static let adultShoes = makeOptions(
        system: .shoes,
        start: 600,
        labels: ["5", "5.5", "6", "6.5", "7", "7.5", "8", "8.5", "9", "9.5", "10", "10.5", "11", "11.5", "12", "13", "14"]
    )

    static let pants: [SizeOption] = {
        let waists = [24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 36, 38, 40]
        let inseams = [28, 30, 32, 34, 36]
        return waists.flatMap { waist in
            inseams.map { inseam in "\(waist)x\(inseam)" }
        }
        .enumerated()
        .map { index, label in SizeOption(system: .pants, label: label, sortOrder: 700 + index) }
    }()

    static let clothingGroups: [SizeGroup] = [
        SizeGroup(title: "Baby", options: baby),
        SizeGroup(title: "Toddler", options: toddler),
        SizeGroup(title: "Kids Numeric", options: kidsNumeric),
        SizeGroup(title: "Adult Alpha", options: adultAlpha),
        SizeGroup(title: "Adult Numeric", options: adultNumeric),
        SizeGroup(title: "Pants", options: pants)
    ]

    static let shoeGroups: [SizeGroup] = [
        SizeGroup(title: "Infant Shoes", options: infantShoes),
        SizeGroup(title: "Toddler Shoes", options: toddlerShoes),
        SizeGroup(title: "Kids Shoes", options: kidsShoes),
        SizeGroup(title: "Adult Shoes", options: adultShoes)
    ]

    static let allGroups: [SizeGroup] = clothingGroups + shoeGroups
    static let allOptions: [SizeOption] = allGroups.flatMap(\.options).sorted { $0.sortOrder < $1.sortOrder }

    static func groups(for type: ClothingType) -> [SizeGroup] {
        type == .shoes ? shoeGroups : clothingGroups
    }

    static func options(for type: ClothingType) -> [SizeOption] {
        groups(for: type).flatMap(\.options)
    }

    static func isValid(_ size: SizeOption, for type: ClothingType) -> Bool {
        options(for: type).contains(size)
    }

    static func option(system: SizeSystem, label: String) -> SizeOption? {
        allOptions.first { $0.system == system && $0.label == label }
    }

    static func defaultOption(systemRaw: String, label: String, sortOrder: Int) -> SizeOption {
        let system = SizeSystem(rawValue: systemRaw) ?? .adultAlpha
        return option(system: system, label: label) ?? SizeOption(system: system, label: label, sortOrder: sortOrder)
    }

    private static func makeOptions(system: SizeSystem, start: Int, labels: [String]) -> [SizeOption] {
        labels.enumerated().map { index, label in
            SizeOption(system: system, label: label, sortOrder: start + index)
        }
    }
}

struct InventoryFilter: Equatable {
    var query = ""
    var ownerID: UUID?
    var type: ClothingType?
    var sizeLabel: String?
    var status: ItemStatus?
    var locationID: UUID?
    var season: ClothingSeason?
    var dateAdded: DateAddedFilter?
    var includeArchived = false

    var hasActiveFilters: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        ownerID != nil ||
        type != nil ||
        sizeLabel != nil ||
        status != nil ||
        locationID != nil ||
        season != nil ||
        dateAdded != nil ||
        includeArchived
    }

    func matches(_ item: ClothingItem) -> Bool {
        if !includeArchived, item.archivedAt != nil { return false }
        if let ownerID, item.owner?.id != ownerID { return false }
        if let type, item.type != type { return false }
        if let sizeLabel, item.sizeLabel != sizeLabel { return false }
        if let status, item.status != status { return false }
        if let locationID, item.location?.id != locationID { return false }
        if let season, item.season != season { return false }
        if let dateAdded {
            let cutoff = Calendar.current.date(byAdding: .day, value: -dateAdded.dayCount, to: Date()) ?? .distantPast
            if item.createdAt < cutoff { return false }
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return true }

        let haystack = [
            item.type.rawValue,
            item.sizeLabel,
            item.status.rawValue,
            item.owner?.name,
            item.location?.name,
            item.brand,
            item.colorName,
            item.notes
        ]
        .compactMap(\.self)
        .joined(separator: " ")

        return haystack.localizedCaseInsensitiveContains(trimmedQuery)
    }
}

enum InventoryMetrics {
    static func statusCounts(items: [ClothingItem]) -> [ItemStatus: Int] {
        items.reduce(into: [:]) { counts, item in
            counts[item.status, default: 0] += 1
        }
    }
}

enum ItemValidation {
    static func canSave(hasPhoto: Bool, owner: Person?, size: SizeOption?, location: StorageLocation?) -> Bool {
        hasPhoto && owner != nil && size != nil && location != nil
    }
}
