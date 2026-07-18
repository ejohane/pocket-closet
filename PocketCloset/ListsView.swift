import CoreData
import SwiftUI

private enum ListsSheet: Identifiable {
    case create

    var id: String { "create" }
}

struct ListsView: View {
    @EnvironmentObject private var closetSession: ClosetSession
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \ClothingList.updatedAt, ascending: false)])
    private var allLists: FetchedResults<ClothingList>

    @State private var activeSheet: ListsSheet?

    private var lists: [ClothingList] {
        allLists.filter { $0.closet?.id == closetSession.selectedClosetID }
    }

    private var activeLists: [ClothingList] {
        lists.filter { $0.archivedAt == nil }
    }

    private var archivedLists: [ClothingList] {
        lists.filter { $0.archivedAt != nil }
    }

    var body: some View {
        Group {
            if lists.isEmpty {
                ScrollView {
                    EmptyStateView(
                        iconName: "checklist",
                        title: "Create your first list",
                        message: "Select clothes for packing, moving, donating, or anything else your household is organizing.",
                        buttonTitle: "New List",
                        action: { activeSheet = .create }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 72)
                }
                .background(Color(.systemGroupedBackground))
            } else {
                List {
                    if !activeLists.isEmpty {
                        Section("Active") {
                            ForEach(activeLists) { clothingList in
                                NavigationLink {
                                    ClothingListDetailView(clothingList: clothingList)
                                } label: {
                                    ClothingListRow(clothingList: clothingList)
                                }
                            }
                        }
                    }

                    if !archivedLists.isEmpty {
                        Section("Archived") {
                            ForEach(archivedLists) { clothingList in
                                NavigationLink {
                                    ClothingListDetailView(clothingList: clothingList)
                                } label: {
                                    ClothingListRow(clothingList: clothingList)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Lists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeSheet = .create
                } label: {
                    Label("New List", systemImage: "plus")
                }
                .accessibilityIdentifier("newListButton")
            }
        }
        .sheet(item: $activeSheet) { _ in
            NewClothingListView()
        }
    }
}

private struct ClothingListRow: View {
    @ObservedObject var clothingList: ClothingList

    private var entries: [ClothingListEntry] {
        Array(clothingList.entries ?? [])
    }

    private var completedCount: Int {
        entries.count(where: \.isCompleted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(clothingList.name)
                    .font(.headline)
                Spacer(minLength: 12)
                Text("\(completedCount) of \(entries.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if let notes = clothingList.notes?.nilIfBlank {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            ProgressView(value: Double(completedCount), total: Double(max(entries.count, 1)))
                .tint(PCColor.primary)
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(clothingList.name)
        .accessibilityValue("\(completedCount) of \(entries.count) complete")
    }
}

private struct NewClothingListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var modelContext
    @EnvironmentObject private var closetSession: ClosetSession
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Closet.createdAt, ascending: true)])
    private var closets: FetchedResults<Closet>

    @State private var name = ""
    @State private var notes = ""
    @State private var saveError: String?
    @FocusState private var nameIsFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("List") {
                    TextField("List Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($nameIsFocused)
                    TextField("Note (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Text("Everyone who shares this closet can see and update the list.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: createList)
                        .disabled(trimmedName.isEmpty)
                        .accessibilityIdentifier("createListButton")
                }
            }
            .onAppear { nameIsFocused = true }
            .alert("Couldn’t create the list", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
    }

    private func createList() {
        guard let closet = closets.first(where: { $0.id == closetSession.selectedClosetID }) else {
            saveError = "Choose a closet before creating a list."
            return
        }

        _ = ClothingList(
            context: modelContext,
            closet: closet,
            name: trimmedName,
            notes: notes.nilIfBlank
        )
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }
}

private enum ClothingListGrouping: String, CaseIterable, Identifiable {
    case owner = "Owner"
    case type = "Type"
    case location = "Location"

    var id: String { rawValue }

    func title(for entry: ClothingListEntry) -> String {
        guard let item = entry.item else { return "Unavailable" }
        switch self {
        case .owner:
            return item.owner?.name ?? "No Owner"
        case .type:
            return item.type.rawValue
        case .location:
            return item.location?.name ?? "No Location"
        }
    }
}

private enum ClothingListDetailSheet: Identifiable {
    case addItems
    case edit

    var id: String {
        switch self {
        case .addItems: "addItems"
        case .edit: "edit"
        }
    }
}

private struct ClothingListSection: Identifiable {
    let id: String
    let title: String
    let entries: [ClothingListEntry]
}

struct ClothingListDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var modelContext
    @ObservedObject var clothingList: ClothingList

    @State private var grouping: ClothingListGrouping = .owner
    @State private var activeSheet: ClothingListDetailSheet?
    @State private var confirmDelete = false
    @State private var saveError: String?

    private var entries: [ClothingListEntry] {
        (clothingList.entries ?? [])
            .filter { $0.item != nil }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    private var completedCount: Int {
        entries.count(where: \.isCompleted)
    }

    private var sections: [ClothingListSection] {
        let grouped = Dictionary(grouping: entries) { grouping.title(for: $0) }
        return grouped.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }.map { title in
            ClothingListSection(id: title, title: title, entries: grouped[title] ?? [])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            summary

            if entries.isEmpty {
                ScrollView {
                    EmptyStateView(
                        iconName: "tshirt",
                        title: "No clothes yet",
                        message: "Choose clothes from this closet to build the shared list.",
                        buttonTitle: "Add Clothes",
                        action: { activeSheet = .addItems }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 56)
                }
            } else {
                Picker("Group By", selection: $grouping) {
                    ForEach(ClothingListGrouping.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 18)
                .padding(.bottom, 12)

                List {
                    ForEach(sections) { section in
                        Section(section.title) {
                            ForEach(section.entries) { entry in
                                ClothingListEntryRow(entry: entry) {
                                    toggle(entry)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(clothingList.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    activeSheet = .addItems
                } label: {
                    Label("Add Clothes", systemImage: "plus")
                }
                .accessibilityIdentifier("addClothesToListButton")

                Menu {
                    Button {
                        activeSheet = .edit
                    } label: {
                        Label("Edit List", systemImage: "pencil")
                    }

                    Button(action: duplicateList) {
                        Label("Duplicate List", systemImage: "plus.square.on.square")
                    }

                    if clothingList.archivedAt == nil {
                        Button(action: archiveList) {
                            Label("Archive List", systemImage: "archivebox")
                        }
                    } else {
                        Button(action: reopenList) {
                            Label("Reopen List", systemImage: "arrow.uturn.backward")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("Delete List", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addItems:
                ClothingListItemPicker(clothingList: clothingList)
            case .edit:
                EditClothingListView(clothingList: clothingList)
            }
        }
        .confirmationDialog("Delete this list?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete List", role: .destructive, action: deleteList)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The clothing items will remain in your closet.")
        }
        .alert("Couldn’t update the list", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Please try again.")
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(completedCount) of \(entries.count) complete")
                    .font(.headline.monospacedDigit())
                    .accessibilityIdentifier("listProgressLabel")
                Spacer()
                if clothingList.archivedAt != nil {
                    Label("Archived", systemImage: "archivebox")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: Double(completedCount), total: Double(max(entries.count, 1)))
                .tint(PCColor.primary)
            if let notes = clothingList.notes?.nilIfBlank {
                Text(notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    private func toggle(_ entry: ClothingListEntry) {
        entry.setCompleted(!entry.isCompleted)
        saveChanges()
    }

    private func duplicateList() {
        guard let closet = clothingList.closet else { return }
        let copy = ClothingList(
            context: modelContext,
            closet: closet,
            name: "\(clothingList.name) Copy",
            notes: clothingList.notes
        )
        for entry in entries {
            guard let item = entry.item else { continue }
            _ = ClothingListEntry(context: modelContext, list: copy, item: item)
        }
        saveChanges()
    }

    private func archiveList() {
        clothingList.archivedAt = Date()
        clothingList.markUpdated()
        if saveChanges() { dismiss() }
    }

    private func reopenList() {
        clothingList.archivedAt = nil
        clothingList.markUpdated()
        if saveChanges() { dismiss() }
    }

    private func deleteList() {
        modelContext.delete(clothingList)
        if saveChanges() { dismiss() }
    }

    @discardableResult
    private func saveChanges() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }
}

private struct ClothingListEntryRow: View {
    @ObservedObject var entry: ClothingListEntry
    let toggle: () -> Void

    private var item: ClothingItem? { entry.item }

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 13) {
                SelectableCheckmark(isSelected: entry.isCompleted)

                StoredPhotoView(data: item?.thumbnailData, relativePath: item?.thumbnailPath)
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(item?.type.rawValue ?? "Unavailable Item")
                        .font(.headline)
                        .strikethrough(entry.isCompleted)
                    Text("\(item?.owner?.name ?? "No owner") · Size \(item?.sizeLabel ?? "—")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label(item?.location?.name ?? "No location", systemImage: item?.location?.iconName ?? "archivebox")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
            }
            .padding(.vertical, 4)
            .opacity(entry.isCompleted ? 0.62 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item?.type.rawValue ?? "Unavailable item"), size \(item?.sizeLabel ?? "unknown"), \(item?.owner?.name ?? "no owner")")
        .accessibilityValue(entry.isCompleted ? "Complete" : "Incomplete")
        .accessibilityHint(entry.isCompleted ? "Marks this item incomplete" : "Marks this item complete")
        .accessibilityIdentifier("listEntry-\(item?.type.rawValue ?? "Unavailable")-\(item?.owner?.name ?? "NoOwner")")
    }
}

private struct EditClothingListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var modelContext
    @ObservedObject var clothingList: ClothingList

    @State private var name: String
    @State private var notes: String
    @State private var saveError: String?

    init(clothingList: ClothingList) {
        self.clothingList = clothingList
        _name = State(initialValue: clothingList.name)
        _notes = State(initialValue: clothingList.notes ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("List") {
                    TextField("List Name", text: $name)
                    TextField("Note (Optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .alert("Couldn’t save the list", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
    }

    private func save() {
        clothingList.name = trimmedName
        clothingList.notes = notes.nilIfBlank
        clothingList.markUpdated()
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct ClothingListItemPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var modelContext
    @ObservedObject var clothingList: ClothingList
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \ClothingItem.createdAt, ascending: false)])
    private var allItems: FetchedResults<ClothingItem>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Person.name, ascending: true)])
    private var allPeople: FetchedResults<Person>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \StorageLocation.name, ascending: true)])
    private var allLocations: FetchedResults<StorageLocation>

    @State private var filter = InventoryFilter()
    @State private var selectedIDs: Set<UUID>
    @State private var saveError: String?

    init(clothingList: ClothingList) {
        self.clothingList = clothingList
        _selectedIDs = State(initialValue: Set((clothingList.entries ?? []).compactMap { $0.item?.id }))
    }

    private var closetID: UUID? { clothingList.closet?.id }
    private var items: [ClothingItem] {
        allItems.filter { $0.closet?.id == closetID && $0.archivedAt == nil }
    }
    private var people: [Person] {
        allPeople.filter { $0.closet?.id == closetID }
    }
    private var locations: [StorageLocation] {
        allLocations.filter { $0.closet?.id == closetID }
    }
    private var visibleItems: [ClothingItem] {
        items.filter { filter.matches($0) }
    }
    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 14)]

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Clothes to Add",
                        systemImage: "tshirt",
                        description: Text("Add clothes to this closet first, then return to the list.")
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            filters

                            if visibleItems.isEmpty {
                                ContentUnavailableView.search(text: filter.query)
                                    .padding(.top, 52)
                            } else {
                                LazyVGrid(columns: columns, spacing: 14) {
                                    ForEach(visibleItems) { item in
                                        Button {
                                            toggle(item)
                                        } label: {
                                            ZStack(alignment: .topTrailing) {
                                                ItemCard(item: item)
                                                    .overlay {
                                                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                                                            .stroke(selectedIDs.contains(item.id) ? PCColor.primary : .clear, lineWidth: 3)
                                                    }

                                                SelectableCheckmark(isSelected: selectedIDs.contains(item.id))
                                                    .padding(8)
                                                    .background(.regularMaterial, in: Circle())
                                                    .padding(7)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityElement(children: .ignore)
                                        .accessibilityLabel("\(item.type.rawValue), size \(item.sizeLabel), \(item.owner?.name ?? "no owner")")
                                        .accessibilityValue(selectedIDs.contains(item.id) ? "Selected" : "Not selected")
                                        .accessibilityAddTraits(selectedIDs.contains(item.id) ? .isSelected : [])
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("Add Clothes")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $filter.query, prompt: "Search clothes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: saveSelection)
                        .accessibilityLabel("Save \(selectedIDs.count) selected clothes")
                        .accessibilityIdentifier("saveListItemsButton")
                }
            }
            .alert("Couldn’t update the list", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                FilterChip(title: "All", isActive: filter.ownerID == nil && filter.type == nil && filter.locationID == nil) {
                    filter.ownerID = nil
                    filter.type = nil
                    filter.locationID = nil
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

                Menu {
                    Button("Any Type") { filter.type = nil }
                    ForEach(ClothingType.allCases) { type in
                        Button(type.rawValue) { filter.type = type }
                    }
                } label: {
                    ListFilterPill(
                        title: filter.type?.rawValue ?? "Type",
                        iconName: "tshirt",
                        isActive: filter.type != nil
                    )
                }

                Menu {
                    Button("Any Location") { filter.locationID = nil }
                    ForEach(locations) { location in
                        Button(location.name) { filter.locationID = location.id }
                    }
                } label: {
                    ListFilterPill(
                        title: locations.first(where: { $0.id == filter.locationID })?.name ?? "Location",
                        iconName: "archivebox",
                        isActive: filter.locationID != nil
                    )
                }
            }
        }
    }

    private func toggle(_ item: ClothingItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    private func saveSelection() {
        let existingEntries = clothingList.entries ?? []
        let existingIDs = Set(existingEntries.compactMap { $0.item?.id })

        for entry in existingEntries where entry.item.map({ !selectedIDs.contains($0.id) }) ?? true {
            modelContext.delete(entry)
        }

        for item in items where selectedIDs.contains(item.id) && !existingIDs.contains(item.id) {
            _ = ClothingListEntry(context: modelContext, list: clothingList, item: item)
        }

        clothingList.markUpdated()
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct ListFilterPill: View {
    let title: String
    let iconName: String
    let isActive: Bool

    var body: some View {
        Label(title, systemImage: iconName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(isActive ? PCColor.primary : Color(.secondarySystemGroupedBackground), in: Capsule())
            .overlay {
                if !isActive {
                    Capsule().stroke(Color(.separator).opacity(0.45), lineWidth: 1)
                }
            }
    }
}
