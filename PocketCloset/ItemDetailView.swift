import SwiftData
import SwiftUI

struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: ClothingItem
    @State private var confirmArchive = false
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                StoredPhotoView(relativePath: item.photoPath, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 300)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
                    }

                metadata
                actions
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(item.type.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("Edit") {
                    ItemEditView(item: item)
                }
            }
        }
        .confirmationDialog("Archive this item?", isPresented: $confirmArchive, titleVisibility: .visible) {
            Button("Archive", role: .destructive, action: archive)
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete this item permanently?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the saved photo and inventory record.")
        }
    }

    private var metadata: some View {
        VStack(spacing: 0) {
            MetadataRow(iconName: "person", title: "Owner", value: item.owner?.name ?? "No owner")
            Divider().padding(.leading, 40)
            MetadataRow(iconName: item.type.iconName, title: "Type", value: item.type.rawValue)
            Divider().padding(.leading, 40)
            MetadataRow(iconName: "ruler", title: "Size", value: "\(item.sizeLabel) · \(item.sizeSystem.rawValue)")
            Divider().padding(.leading, 40)
            MetadataRow(iconName: item.location?.iconName ?? "archivebox", title: "Location", value: item.location?.name ?? "No location")
            Divider().padding(.leading, 40)
            MetadataRow(iconName: item.status.iconName, title: "Status", value: item.status.rawValue, accent: item.status.accent)

            if let season = item.season {
                Divider().padding(.leading, 40)
                MetadataRow(iconName: "sun.max", title: "Season", value: season.rawValue, accent: PCColor.yellow)
            }

            if let brand = item.brand {
                Divider().padding(.leading, 40)
                MetadataRow(iconName: "tag", title: "Brand", value: brand)
            }

            if let colorName = item.colorName {
                Divider().padding(.leading, 40)
                MetadataRow(iconName: "paintpalette", title: "Color", value: colorName)
            }

            if let notes = item.notes {
                Divider().padding(.leading, 40)
                MetadataRow(iconName: "note.text", title: "Notes", value: notes)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                item.status = .donate
                item.markUpdated()
                try? modelContext.save()
            } label: {
                Label("Mark for Donate", systemImage: "heart")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(PCColor.red)

            Button {
                item.status = .inCloset
                item.markUpdated()
                try? modelContext.save()
            } label: {
                Label("Move to Closet", systemImage: "hanger")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(PCColor.primary)

            Button {
                confirmArchive = true
            } label: {
                Label("Archive", systemImage: "tray")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func archive() {
        item.status = .archived
        item.archivedAt = Date()
        item.markUpdated()
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        ImageStore.delete(relativePath: item.photoPath)
        ImageStore.delete(relativePath: item.thumbnailPath)
        modelContext.delete(item)
        try? modelContext.save()
        dismiss()
    }
}

struct ItemEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: ClothingItem
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]

    var body: some View {
        Form {
            Section("Required") {
                Picker("Owner", selection: ownerBinding) {
                    Text("No owner").tag(Optional<UUID>.none)
                    ForEach(people) { person in
                        Text(person.name).tag(Optional(person.id))
                    }
                }

                Picker("Type", selection: typeBinding) {
                    ForEach(ClothingType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                Picker("Size", selection: sizeBinding) {
                    ForEach(SizeCatalog.allOptions) { size in
                        Text("\(size.label) · \(size.system.rawValue)").tag(size.id)
                    }
                }

                Picker("Location", selection: locationBinding) {
                    Text("No location").tag(Optional<UUID>.none)
                    ForEach(locations) { location in
                        Text(location.name).tag(Optional(location.id))
                    }
                }

                Picker("Status", selection: statusBinding) {
                    ForEach(ItemStatus.allCases) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
            }

            Section("Optional") {
                Picker("Season", selection: seasonBinding) {
                    Text("None").tag(Optional<ClothingSeason>.none)
                    ForEach(ClothingSeason.allCases) { season in
                        Text(season.rawValue).tag(Optional(season))
                    }
                }

                TextField("Brand", text: brandBinding)
                    .textInputAutocapitalization(.words)

                TextField("Color", text: colorBinding)
                    .textInputAutocapitalization(.words)

                TextField("Notes", text: notesBinding, axis: .vertical)
                    .lineLimit(2...5)
            }
        }
        .navigationTitle("Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    item.markUpdated()
                    try? modelContext.save()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }

    private var ownerBinding: Binding<UUID?> {
        Binding {
            item.owner?.id
        } set: { id in
            item.owner = id.flatMap { id in people.first { $0.id == id } }
            item.markUpdated()
        }
    }

    private var locationBinding: Binding<UUID?> {
        Binding {
            item.location?.id
        } set: { id in
            item.location = id.flatMap { id in locations.first { $0.id == id } }
            item.markUpdated()
        }
    }

    private var typeBinding: Binding<ClothingType> {
        Binding {
            item.type
        } set: { type in
            item.type = type
            if type == .shoes, item.sizeSystem != .shoes, let firstShoeSize = SizeCatalog.shoeGroups.first?.options.first {
                item.sizeOption = firstShoeSize
            }
            item.markUpdated()
        }
    }

    private var sizeBinding: Binding<String> {
        Binding {
            item.sizeOption.id
        } set: { id in
            if let size = SizeCatalog.allOptions.first(where: { $0.id == id }) {
                item.sizeOption = size
                item.markUpdated()
            }
        }
    }

    private var statusBinding: Binding<ItemStatus> {
        Binding {
            item.status
        } set: { status in
            item.status = status
            item.markUpdated()
        }
    }

    private var seasonBinding: Binding<ClothingSeason?> {
        Binding {
            item.season
        } set: { season in
            item.season = season
            item.markUpdated()
        }
    }

    private var brandBinding: Binding<String> {
        Binding {
            item.brand ?? ""
        } set: { value in
            item.brand = value.nilIfBlank
            item.markUpdated()
        }
    }

    private var colorBinding: Binding<String> {
        Binding {
            item.colorName ?? ""
        } set: { value in
            item.colorName = value.nilIfBlank
            item.markUpdated()
        }
    }

    private var notesBinding: Binding<String> {
        Binding {
            item.notes ?? ""
        } set: { value in
            item.notes = value.nilIfBlank
            item.markUpdated()
        }
    }
}
