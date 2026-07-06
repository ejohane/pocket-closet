import SwiftData
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case closet = "Closet"
    case add = "Add"
    case manage = "Manage"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .closet: "square.grid.2x2"
        case .add: "camera"
        case .manage: "tray.full"
        }
    }
}

struct AppShell: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: AppTab = .closet

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ClosetView(selectedTab: $selectedTab)
            }
            .tabItem { Label(AppTab.closet.rawValue, systemImage: AppTab.closet.iconName) }
            .tag(AppTab.closet)

            NavigationStack {
                AddItemView()
            }
            .tabItem { Label(AppTab.add.rawValue, systemImage: AppTab.add.iconName) }
            .tag(AppTab.add)

            NavigationStack {
                ManageView()
            }
            .tabItem { Label(AppTab.manage.rawValue, systemImage: AppTab.manage.iconName) }
            .tag(AppTab.manage)
        }
        .tint(PCColor.primary)
        .task {
            DefaultDataSeeder.seedDefaultsIfNeeded(in: modelContext)
            if ProcessInfo.processInfo.arguments.contains("UITEST_SEED_DATA") {
                DefaultDataSeeder.seedUITestDataIfNeeded(in: modelContext)
            }
        }
    }
}

@MainActor
enum DefaultDataSeeder {
    static func seedDefaultsIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<StorageLocation>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }

        let defaults: [(String, LocationKind, String)] = [
            ("Closet", .closet, "green"),
            ("Dresser", .dresser, "blue"),
            ("Storage Bin", .storageBin, "aqua"),
            ("Garage", .garage, "purple"),
            ("Donate Bag", .donateBag, "red"),
            ("Laundry/Unknown", .laundryUnknown, "yellow")
        ]

        for location in defaults {
            context.insert(StorageLocation(name: location.0, kind: location.1, colorToken: location.2))
        }

        try? context.save()
    }

    static func seedUITestDataIfNeeded(in context: ModelContext) {
        var itemDescriptor = FetchDescriptor<ClothingItem>()
        itemDescriptor.predicate = #Predicate { item in
            item.brand == "UITestSeed"
        }
        guard ((try? context.fetchCount(itemDescriptor)) ?? 0) == 0 else { return }

        let emma = Person(name: "Emma", colorToken: "pink")
        let theo = Person(name: "Theo", colorToken: "blue")
        let me = Person(name: "Me", colorToken: "green")
        [emma, theo, me].forEach(context.insert)

        let locations = (try? context.fetch(FetchDescriptor<StorageLocation>())) ?? []
        let storage = locations.first { $0.kind == .storageBin } ?? StorageLocation(name: "Storage Bin", kind: .storageBin)
        let closet = locations.first { $0.kind == .closet } ?? StorageLocation(name: "Closet", kind: .closet)
        if storage.modelContext == nil { context.insert(storage) }
        if closet.modelContext == nil { context.insert(closet) }

        let seed: [(Person, ClothingType, SizeOption, StorageLocation, ItemStatus, UIColor)] = [
            (emma, .top, SizeCatalog.toddler[2], storage, .inStorage, UIColor(red: 0.76, green: 0.86, blue: 0.76, alpha: 1)),
            (theo, .outerwear, SizeCatalog.kidsNumeric[3], closet, .inCloset, UIColor(red: 0.44, green: 0.50, blue: 0.33, alpha: 1)),
            (me, .top, SizeCatalog.adultAlpha[2], closet, .needsReview, UIColor(red: 0.42, green: 0.58, blue: 0.78, alpha: 1)),
            (emma, .bottom, SizeCatalog.kidsNumeric[4], storage, .donate, UIColor(red: 0.70, green: 0.58, blue: 0.41, alpha: 1))
        ]

        for entry in seed {
            let image = ImageStore.makePlaceholderImage(color: entry.5, symbolName: entry.1.iconName)
            if let paths = try? ImageStore.save(image: image) {
                context.insert(ClothingItem(
                    photoPath: paths.photoPath,
                    thumbnailPath: paths.thumbnailPath,
                    owner: entry.0,
                    type: entry.1,
                    size: entry.2,
                    location: entry.3,
                    status: entry.4,
                    brand: "UITestSeed"
                ))
            }
        }

        try? context.save()
    }
}
