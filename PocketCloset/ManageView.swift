import SwiftData
import SwiftUI

struct ManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClothingItem.createdAt, order: .reverse) private var items: [ClothingItem]
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]

    @State private var selectedStatus: ItemStatus?
    @State private var selectionMode = false
    @State private var selectedIDs = Set<UUID>()
    @State private var selectedItemID: UUID?

    private let bucketStatuses: [ItemStatus] = [.inCloset, .inStorage, .needsReview, .donate, .sell]

    private var activeItems: [ClothingItem] {
        items.filter { $0.archivedAt == nil }
    }

    private var reviewItems: [ClothingItem] {
        if selectedStatus == .archived {
            return items.filter { $0.archivedAt != nil }
        }

        return activeItems.filter { item in
            selectedStatus == nil || item.status == selectedStatus
        }
    }

    private var counts: [ItemStatus: Int] {
        InventoryMetrics.statusCounts(items: activeItems)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                summaryBuckets

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(selectedStatus?.rawValue ?? "Review")
                            .font(.title2.weight(.bold))
                        Spacer()
                        if selectionMode {
                            Text("\(selectedIDs.count) selected")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if reviewItems.isEmpty {
                        EmptyStateView(
                            iconName: selectedStatus?.iconName ?? "tray.full",
                            title: "Nothing to review",
                            message: selectedStatus == nil ? "Captured items will appear here for quick moves and cleanup." : "No items are currently marked \(selectedStatus?.rawValue ?? "")."
                        )
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(reviewItems) { item in
                                ManageItemRow(
                                    item: item,
                                    isSelectionMode: selectionMode,
                                    isSelected: selectedIDs.contains(item.id),
                                    onToggleSelected: { toggleSelection(for: item) },
                                    onOpen: { selectedItemID = item.id },
                                    onSetStatus: { status in setStatus(status, for: [item]) }
                                )

                                if item.id != reviewItems.last?.id {
                                    Divider().padding(.leading, selectionMode ? 150 : 118)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 110)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Manage")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button("All Active Items") { applyFilter(nil) }
                    Divider()
                    Button("Archived") { applyFilter(.archived) }
                } label: {
                    Label("Filter", systemImage: "line.3.horizontal.decrease")
                }

                if selectionMode {
                    bulkMenu
                }
                Button(selectionMode ? "Done" : "Select") {
                    withAnimation(.easeOut(duration: 0.18)) {
                        selectionMode.toggle()
                        if !selectionMode { selectedIDs.removeAll() }
                    }
                }
            }
        }
        .navigationDestination(item: $selectedItemID) { id in
            if let item = items.first(where: { $0.id == id }) {
                ItemDetailView(item: item)
            } else {
                ContentUnavailableView("Item Not Found", systemImage: "tshirt")
            }
        }
    }

    private var summaryBuckets: some View {
        VStack(spacing: 12) {
            ForEach(bucketStatuses) { status in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        selectedStatus = selectedStatus == status ? nil : status
                        selectedIDs.removeAll()
                    }
                } label: {
                    StatusBucketRow(
                        status: status,
                        count: counts[status, default: 0],
                        isSelected: selectedStatus == status
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bulkMenu: some View {
        Menu {
            Section("Set Status") {
                ForEach(ItemStatus.allCases.filter { $0 != .archived }) { status in
                    Button(status.rawValue) {
                        bulkSetStatus(status)
                    }
                }
            }

            Section("Move Location") {
                ForEach(locations) { location in
                    Button(location.name) {
                        bulkSetLocation(location)
                    }
                }
            }
        } label: {
            Label("Bulk", systemImage: "square.stack.3d.up")
        }
        .disabled(selectedIDs.isEmpty)
    }

    private var selectedItems: [ClothingItem] {
        items.filter { selectedIDs.contains($0.id) }
    }

    private func toggleSelection(for item: ClothingItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    private func setStatus(_ status: ItemStatus, for items: [ClothingItem]) {
        for item in items {
            item.status = status
            item.markUpdated()
        }
        try? modelContext.save()
    }

    private func setLocation(_ location: StorageLocation, for items: [ClothingItem]) {
        for item in items {
            item.location = location
            item.markUpdated()
        }
        try? modelContext.save()
    }

    private func bulkSetStatus(_ status: ItemStatus) {
        setStatus(status, for: selectedItems)
        finishBulkUpdate()
    }

    private func bulkSetLocation(_ location: StorageLocation) {
        setLocation(location, for: selectedItems)
        finishBulkUpdate()
    }

    private func finishBulkUpdate() {
        selectedIDs.removeAll()
        selectionMode = false
    }

    private func applyFilter(_ status: ItemStatus?) {
        selectedStatus = status
        selectedIDs.removeAll()
    }
}

private struct ManageItemRow: View {
    let item: ClothingItem
    let isSelectionMode: Bool
    let isSelected: Bool
    let onToggleSelected: () -> Void
    let onOpen: () -> Void
    let onSetStatus: (ItemStatus) -> Void

    var body: some View {
        Group {
            if isSelectionMode {
                Button(action: onToggleSelected) {
                    rowContent(showsStatusMenu: false)
                }
                .buttonStyle(.plain)
            } else {
                rowContent(showsStatusMenu: true)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onOpen)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.type.rawValue), size \(item.sizeLabel), \(item.owner?.name ?? "no owner")")
        .accessibilityValue(isSelectionMode ? (isSelected ? "Selected" : "Not selected") : item.status.rawValue)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelectionMode && isSelected ? .isSelected : [])
        .accessibilityAction {
            if isSelectionMode {
                onToggleSelected()
            } else {
                onOpen()
            }
        }
    }

    private func rowContent(showsStatusMenu: Bool) -> some View {
        HStack(spacing: 14) {
            if isSelectionMode {
                SelectableCheckmark(isSelected: isSelected)
            }

            StoredPhotoView(relativePath: item.thumbnailPath)
                .frame(width: 74, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.type.rawValue)
                    .font(.headline)
                    .lineLimit(1)
                Text("Size \(item.sizeLabel)")
                    .font(.subheadline)
                Text(item.owner?.name ?? "No owner")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if showsStatusMenu {
                Menu {
                    ForEach(ItemStatus.allCases.filter { $0 != .archived }) { status in
                        Button(status.rawValue) {
                            onSetStatus(status)
                        }
                    }
                } label: {
                    Text(item.status == .donate ? "Donate" : "Move")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(item.status == .donate ? PCColor.red : PCColor.primary)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .overlay {
                            Capsule()
                                .stroke(item.status == .donate ? PCColor.red : PCColor.primary, lineWidth: 1)
                        }
                }
            }
        }
        .padding(.vertical, 12)
    }
}
