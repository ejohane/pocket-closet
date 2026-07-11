import SwiftData
import SwiftUI

private enum ClosetSheet: Identifiable {
    case size

    var id: String { "size" }
}

struct ClosetView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selectedTab: AppTab
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var items: [ClothingItem]
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]

    @State private var filter = InventoryFilter()
    @State private var activeSheet: ClosetSheet?

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 14), count: count)
    }

    private var visibleItems: [ClothingItem] {
        items.filter { filter.matches($0) }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    filters

                    if items.filter({ $0.archivedAt == nil }).isEmpty {
                        EmptyStateView(
                            iconName: "tshirt",
                            title: "Start your closet",
                            message: "Add the first item with a photo, owner, size, location, and status.",
                            buttonTitle: "Add Item",
                            action: { selectedTab = .add }
                        )
                        .padding(.top, 56)
                    } else if visibleItems.isEmpty {
                        EmptyStateView(
                            iconName: "line.3.horizontal.decrease.circle",
                            title: "No matches",
                            message: "Clear a filter or adjust your search to see more clothes.",
                            buttonTitle: "Clear Filters",
                            action: { filter = InventoryFilter() }
                        )
                        .padding(.top, 56)
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(visibleItems) { item in
                                NavigationLink {
                                    ItemDetailView(item: item)
                                } label: {
                                    ItemCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .accessibilityIdentifier("closetGrid")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            .background(Color(.systemGroupedBackground))

            if !dynamicTypeSize.isAccessibilitySize {
                Button {
                    selectedTab = .add
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 62, height: 62)
                        .background(PCColor.primary, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 22)
                .padding(.bottom, 22)
                .accessibilityLabel("Add item")
            }
        }
        .navigationTitle("Pocket Closet")
        .toolbar {
            if dynamicTypeSize.isAccessibilitySize {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        selectedTab = .add
                    } label: {
                        Image(systemName: "camera.fill")
                    }
                    .accessibilityLabel("Add item")
                }
            }
        }
        .searchable(
            text: $filter.query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search clothes"
        )
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .size:
                SizeFilterPickerView(selectedSizeLabel: Binding(
                    get: { filter.sizeLabel },
                    set: { filter.sizeLabel = $0 }
                ))
            }
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(title: "All", isActive: !filter.hasActiveFilters) {
                    filter = InventoryFilter()
                }

                ForEach(people) { person in
                    FilterChip(
                        title: person.name,
                        iconName: "person",
                        isActive: filter.ownerID == person.id
                    ) {
                        filter.ownerID = filter.ownerID == person.id ? nil : person.id
                    }
                }

                Button {
                    activeSheet = .size
                } label: {
                    chipLabel(
                        title: filter.sizeLabel ?? "Size",
                        iconName: "ruler",
                        isActive: filter.sizeLabel != nil
                    )
                }
                .buttonStyle(.plain)

                Menu {
                    Button("Any Type") { filter.type = nil }
                    ForEach(ClothingType.allCases) { type in
                        Button(type.rawValue) { filter.type = type }
                    }
                } label: {
                    chipLabel(
                        title: filter.type?.rawValue ?? "Type",
                        iconName: filter.type?.iconName ?? "tshirt",
                        isActive: filter.type != nil
                    )
                }
                .menuIndicator(.hidden)
                .accessibilityLabel("Type filter")

                Menu {
                    Button("Any Status") { filter.status = nil }
                    ForEach(ItemStatus.allCases.filter { $0 != .archived }) { status in
                        Button(status.rawValue) { filter.status = status }
                    }
                } label: {
                    chipLabel(
                        title: filter.status?.rawValue ?? "Status",
                        iconName: filter.status?.iconName ?? "tray.full",
                        isActive: filter.status != nil
                    )
                }
                .menuIndicator(.hidden)
                .accessibilityLabel("Status filter")

                Menu {
                    Button("Any Location") { filter.locationID = nil }
                    ForEach(locations) { location in
                        Button(location.name) { filter.locationID = location.id }
                    }
                } label: {
                    chipLabel(
                        title: locations.first { $0.id == filter.locationID }?.name ?? "Location",
                        iconName: "archivebox",
                        isActive: filter.locationID != nil
                    )
                }
                .menuIndicator(.hidden)
                .accessibilityLabel("Location filter")

                Menu {
                    Button("Any Season") { filter.season = nil }
                    ForEach(ClothingSeason.allCases) { season in
                        Button(season.rawValue) { filter.season = season }
                    }
                } label: {
                    chipLabel(
                        title: filter.season?.rawValue ?? "Season",
                        iconName: "sun.max",
                        isActive: filter.season != nil
                    )
                }
                .menuIndicator(.hidden)
                .accessibilityLabel("Season filter")

                Menu {
                    Button("Any Date") { filter.dateAdded = nil }
                    ForEach(DateAddedFilter.allCases) { dateFilter in
                        Button(dateFilter.rawValue) { filter.dateAdded = dateFilter }
                    }
                } label: {
                    chipLabel(
                        title: filter.dateAdded?.rawValue ?? "Date Added",
                        iconName: "calendar",
                        isActive: filter.dateAdded != nil
                    )
                }
                .menuIndicator(.hidden)
                .accessibilityLabel("Date added filter")
            }
            .padding(.vertical, 2)
        }
    }

    private func chipLabel(title: String, iconName: String, isActive: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: iconName)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.callout.weight(isActive ? .semibold : .regular))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .opacity(0.65)
                .accessibilityHidden(true)
        }
        .foregroundStyle(isActive ? .white : .primary)
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(isActive ? PCColor.primary : Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(isActive ? Color.clear : Color(.separator).opacity(0.45), lineWidth: 1)
        }
    }
}

struct SizeFilterPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSizeLabel: String?

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedSizeLabel = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("Any Size")
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedSizeLabel == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(PCColor.primary)
                        }
                    }
                }

                ForEach(SizeCatalog.allGroups) { group in
                    Section(group.title) {
                        ForEach(group.options) { size in
                            Button {
                                selectedSizeLabel = size.label
                                dismiss()
                            } label: {
                                HStack {
                                    Text(size.label)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedSizeLabel == size.label {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(PCColor.primary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Size")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
