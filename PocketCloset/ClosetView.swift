import CoreData
import SwiftUI

private enum ClosetSheet: Identifiable {
    case size
    case sort

    var id: String {
        switch self {
        case .size: "size"
        case .sort: "sort"
        }
    }
}

struct ClosetView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var closetSession: ClosetSession
    @Binding var selectedTab: AppTab
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \ClothingItem.createdAt, ascending: false)]) private var allItems: FetchedResults<ClothingItem>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Person.name, ascending: true)]) private var allPeople: FetchedResults<Person>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \StorageLocation.name, ascending: true)]) private var allLocations: FetchedResults<StorageLocation>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Closet.createdAt, ascending: true)]) private var closets: FetchedResults<Closet>

    @AppStorage("closetSortCriteria") private var encodedSortCriteria = ""
    @State private var filter = InventoryFilter()
    @State private var activeSheet: ClosetSheet?
    @State private var showingClosetSettings = false
    @State private var showingClosetManager = false

    private var items: [ClothingItem] { allItems.filter { $0.closet?.id == closetSession.selectedClosetID } }
    private var people: [Person] { allPeople.filter { $0.closet?.id == closetSession.selectedClosetID } }
    private var locations: [StorageLocation] { allLocations.filter { $0.closet?.id == closetSession.selectedClosetID } }
    private var selectedCloset: Closet? { closets.first { $0.id == closetSession.selectedClosetID } }

    private var columns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 14), count: count)
    }

    private var visibleItems: [ClothingItem] {
        InventorySorter.sort(
            items.filter { filter.matches($0) },
            using: sortCriteria
        )
    }

    private var sortCriteria: [InventorySortCriterion] {
        InventorySortConfiguration.decode(encodedSortCriteria)
    }

    private var sortCriteriaBinding: Binding<[InventorySortCriterion]> {
        Binding(
            get: { InventorySortConfiguration.decode(encodedSortCriteria) },
            set: { encodedSortCriteria = InventorySortConfiguration.encode($0) }
        )
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
        .navigationTitle(selectedCloset?.name ?? "Pocket Closet")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    ForEach(closets) { closet in
                        Button {
                            closetSession.select(closet)
                            filter = InventoryFilter()
                        } label: {
                            if closet.id == closetSession.selectedClosetID {
                                Label(closet.name, systemImage: "checkmark")
                            } else {
                                Text(closet.name)
                            }
                        }
                    }

                    Divider()

                    Button {
                        showingClosetManager = true
                    } label: {
                        Label("Manage Closets", systemImage: "slider.horizontal.3")
                    }
                } label: {
                    Label("Choose Closet", systemImage: "chevron.down")
                }
                .accessibilityLabel("Choose closet")
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingClosetSettings = true
                } label: {
                    Image(systemName: "person.2")
                }
                .accessibilityLabel("Closet sharing")
                .disabled(selectedCloset == nil)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeSheet = .sort
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort items")
                .accessibilityValue(sortCriteria.map { "\($0.field.title), \($0.directionTitle)" }.joined(separator: ", then "))
                .accessibilityIdentifier("sortItemsButton")
            }

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
            case .sort:
                ClosetSortView(criteria: sortCriteriaBinding)
            }
        }
        .sheet(isPresented: $showingClosetSettings) {
            if let selectedCloset {
                ClosetSettingsView(closet: selectedCloset)
            }
        }
        .sheet(isPresented: $showingClosetManager) {
            ClosetManagerView()
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

struct ClosetSortView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var criteria: [InventorySortCriterion]
    @State private var editMode: EditMode = .active
    @State private var isShowingFieldPicker = false

    private var availableFields: [InventorySortField] {
        let selectedFields = Set(criteria.map(\.field))
        return InventorySortField.allCases.filter { !selectedFields.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(criteria.enumerated()), id: \.element.id) { index, criterion in
                        sortRow(index: index, criterion: criterion)
                    }
                    .onMove { source, destination in
                        criteria.move(fromOffsets: source, toOffset: destination)
                    }
                } header: {
                    Text("Sort Priority")
                } footer: {
                    Text("Drag the handles to change priority. Items are sorted by the first option, then by each option below it when values match. Filters are applied before sorting.")
                }

                Section {
                    Button {
                        isShowingFieldPicker = true
                    } label: {
                        HStack {
                            Label("Add Sort", systemImage: "plus")
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    .disabled(availableFields.isEmpty)

                    Button("Reset to Default", role: .destructive) {
                        criteria = InventorySortConfiguration.defaultCriteria
                    }
                    .disabled(criteria == InventorySortConfiguration.defaultCriteria)
                }
            }
            .environment(\.editMode, $editMode)
            .navigationDestination(isPresented: $isShowingFieldPicker) {
                ClosetSortFieldPickerView(criteria: $criteria)
            }
            .navigationTitle("Sort Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func sortRow(index: Int, criterion: InventorySortCriterion) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(Color(.tertiarySystemFill), in: Circle())

            Text(criterion.field.title)

            Spacer()

            Menu {
                ForEach(InventorySortDirection.allCases) { direction in
                    Button {
                        updateDirection(direction, at: index)
                    } label: {
                        if direction == criterion.direction {
                            Label(directionTitle(for: criterion.field, direction: direction), systemImage: "checkmark")
                        } else {
                            Text(directionTitle(for: criterion.field, direction: direction))
                        }
                    }
                }
            } label: {
                Text(criterion.directionTitle)
                .font(.callout)
                .foregroundStyle(PCColor.primary)
            }
            .accessibilityLabel("\(criterion.field.title) direction")
            .accessibilityValue(criterion.directionTitle)

        }
        .accessibilityElement(children: .contain)
        .swipeActions(edge: .trailing, allowsFullSwipe: criteria.count > 1) {
            if criteria.count > 1 {
                Button("Delete", role: .destructive) {
                    removeCriterion(criterion.id)
                }
                .accessibilityLabel("Remove \(criterion.field.title) sort")
            }
        }
    }

    private func directionTitle(
        for field: InventorySortField,
        direction: InventorySortDirection
    ) -> String {
        InventorySortCriterion(field: field, direction: direction).directionTitle
    }

    private func updateDirection(_ direction: InventorySortDirection, at index: Int) {
        criteria[index].direction = direction
    }

    private func removeCriterion(_ id: InventorySortField) {
        guard criteria.count > 1 else { return }
        criteria.removeAll { $0.id == id }
    }
}

private struct ClosetSortFieldPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var criteria: [InventorySortCriterion]

    private var availableFields: [InventorySortField] {
        let selectedFields = Set(criteria.map(\.field))
        return InventorySortField.allCases.filter { !selectedFields.contains($0) }
    }

    var body: some View {
        List(availableFields) { field in
            Button(field.title) {
                criteria.append(InventorySortCriterion(field: field))
                dismiss()
            }
            .foregroundStyle(.primary)
            .accessibilityIdentifier("addSortField-\(field.rawValue)")
        }
        .navigationTitle("Add Sort")
        .navigationBarTitleDisplayMode(.inline)
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
