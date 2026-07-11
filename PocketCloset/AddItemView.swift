import PhotosUI
import SwiftData
import SwiftUI
import UIKit

private enum AddItemSheet: Identifiable {
    case camera
    case owner
    case type
    case size
    case location
    case status
    case season

    var id: String {
        switch self {
        case .camera: "camera"
        case .owner: "owner"
        case .type: "type"
        case .size: "size"
        case .location: "location"
        case .status: "status"
        case .season: "season"
        }
    }
}

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]

    @AppStorage("lastOwnerID") private var lastOwnerID = ""
    @AppStorage("lastLocationID") private var lastLocationID = ""
    @AppStorage("lastStatusRaw") private var lastStatusRaw = ItemStatus.inStorage.rawValue

    @State private var selectedImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedOwner: Person?
    @State private var selectedType: ClothingType = .top
    @State private var selectedSize: SizeOption?
    @State private var selectedLocation: StorageLocation?
    @State private var selectedStatus: ItemStatus = .inStorage
    @State private var selectedSeason: ClothingSeason?
    @State private var brand = ""
    @State private var colorName = ""
    @State private var notes = ""
    @State private var activeSheet: AddItemSheet?
    @State private var errorMessage: String?
    @State private var showSavedBanner = false

    private var canSave: Bool {
        ItemValidation.canSave(
            hasPhoto: selectedImage != nil,
            owner: selectedOwner,
            size: selectedSize,
            location: selectedLocation
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                photoSection
                requiredSection
                optionalSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 96)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Add Item")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            PrimaryStickyButton(title: "Save", systemImage: "checkmark", isDisabled: !canSave, action: save)
        }
        .overlay(alignment: .top) {
            if showSavedBanner {
                Text("Saved. Ready for the next item.")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(PCColor.primary, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .camera:
                CameraCaptureView(
                    onImage: { image in
                        selectedImage = image
                        activeSheet = nil
                    },
                    onCancel: {
                        activeSheet = nil
                    }
                )
                .ignoresSafeArea()
            case .owner:
                OwnerPickerView(selectedOwner: $selectedOwner)
            case .type:
                TypePickerView(selectedType: $selectedType)
            case .size:
                SizePickerView(type: selectedType, selectedSize: $selectedSize)
            case .location:
                LocationPickerView(selectedLocation: $selectedLocation)
            case .status:
                StatusPickerView(selectedStatus: $selectedStatus)
            case .season:
                SeasonPickerView(selectedSeason: $selectedSeason)
            }
        }
        .alert("Save failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Something went wrong.")
        }
        .onAppear(perform: hydrateDefaults)
        .onChange(of: people.map(\.id)) { _, _ in hydrateDefaults() }
        .onChange(of: locations.map(\.id)) { _, _ in hydrateDefaults() }
        .onChange(of: selectedType) { _, newType in
            validateSize(for: newType)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            loadPhoto(from: newItem)
        }
    }

    private var photoSection: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 280)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "camera")
                                .font(.system(size: 48, weight: .regular))
                                .foregroundStyle(PCColor.primary)
                            Text("Add a clothing photo")
                                .font(.headline)
                            Text("Use the camera or choose one from your library.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 320)
                        .background(Color(.secondarySystemGroupedBackground))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
                }

                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        activeSheet = .camera
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(PCColor.primary)
                            .frame(width: 58, height: 58)
                            .background(Color(.systemBackground), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(16)
                    .accessibilityLabel("Take photo")
                }
            }

            HStack(spacing: 12) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        activeSheet = .camera
                    } label: {
                        Label("Camera", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .tint(PCColor.primary)
        }
    }

    private var requiredSection: some View {
        VStack(spacing: 0) {
            Button { activeSheet = .owner } label: {
                PickerRow(
                    iconName: "person",
                    title: "Owner",
                    value: selectedOwner?.name ?? "Choose",
                    isRequiredMissing: selectedOwner == nil
                )
            }
            Divider().padding(.leading, 56)

            Button { activeSheet = .type } label: {
                PickerRow(iconName: selectedType.iconName, title: "Type", value: selectedType.rawValue)
            }
            Divider().padding(.leading, 56)

            Button { activeSheet = .size } label: {
                PickerRow(
                    iconName: "ruler",
                    title: "Size",
                    value: selectedSize?.label ?? "Choose",
                    isRequiredMissing: selectedSize == nil
                )
            }
            Divider().padding(.leading, 56)

            Button { activeSheet = .location } label: {
                PickerRow(
                    iconName: selectedLocation?.iconName ?? "archivebox",
                    title: "Location",
                    value: selectedLocation?.name ?? "Choose",
                    accent: selectedLocation.map { PCColor.token($0.colorToken) } ?? PCColor.primary,
                    isRequiredMissing: selectedLocation == nil
                )
            }
            Divider().padding(.leading, 56)

            Button { activeSheet = .status } label: {
                PickerRow(
                    iconName: selectedStatus.iconName,
                    title: "Status",
                    value: selectedStatus.rawValue,
                    accent: selectedStatus.accent
                )
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var optionalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Optional")
                .font(.headline)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                Button { activeSheet = .season } label: {
                    PickerRow(
                        iconName: "sun.max",
                        title: "Season",
                        value: selectedSeason?.rawValue ?? "None",
                        accent: PCColor.yellow
                    )
                }
                Divider().padding(.leading, 56)

                TextField("Brand", text: $brand)
                    .textInputAutocapitalization(.words)
                    .padding(.vertical, 14)
                Divider()

                TextField("Color", text: $colorName)
                    .textInputAutocapitalization(.words)
                    .padding(.vertical, 14)
                Divider()

                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(2...5)
                    .padding(.vertical, 14)
            }
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func hydrateDefaults() {
        if selectedOwner == nil, let lastID = UUID(uuidString: lastOwnerID) {
            selectedOwner = people.first { $0.id == lastID }
        }

        if selectedLocation == nil {
            if let lastID = UUID(uuidString: lastLocationID), let match = locations.first(where: { $0.id == lastID }) {
                selectedLocation = match
            } else {
                selectedLocation = locations.first { $0.kind == .storageBin } ?? locations.first
            }
        }

        selectedStatus = ItemStatus(rawValue: lastStatusRaw) ?? .inStorage
    }

    private func validateSize(for type: ClothingType) {
        guard let selectedSize, !SizeCatalog.isValid(selectedSize, for: type) else { return }
        self.selectedSize = nil
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                }
            }
        }
    }

    private func save() {
        guard let selectedImage, let selectedOwner, let selectedSize, let selectedLocation else { return }

        do {
            let paths = try ImageStore.save(image: selectedImage)
            let item = ClothingItem(
                photoPath: paths.photoPath,
                thumbnailPath: paths.thumbnailPath,
                owner: selectedOwner,
                type: selectedType,
                size: selectedSize,
                location: selectedLocation,
                status: selectedStatus,
                season: selectedSeason,
                brand: brand.nilIfBlank,
                colorName: colorName.nilIfBlank,
                notes: notes.nilIfBlank
            )
            modelContext.insert(item)
            try modelContext.save()

            lastOwnerID = selectedOwner.id.uuidString
            lastLocationID = selectedLocation.id.uuidString
            lastStatusRaw = selectedStatus.rawValue
            resetAfterSave()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetAfterSave() {
        selectedImage = nil
        selectedPhotoItem = nil
        selectedSize = nil
        selectedSeason = nil
        brand = ""
        colorName = ""
        notes = ""

        withAnimation(.easeOut(duration: 0.18)) {
            showSavedBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.easeOut(duration: 0.18)) {
                showSavedBanner = false
            }
        }
    }
}

struct OwnerPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.name) private var people: [Person]
    @Binding var selectedOwner: Person?
    @State private var showingNewOwner = false
    @State private var newOwnerName = ""

    var body: some View {
        NavigationStack {
            List {
                if people.isEmpty {
                    ContentUnavailableView("No Owners Yet", systemImage: "person", description: Text("Add the first household member to keep capturing."))
                }

                ForEach(people) { person in
                    Button {
                        selectedOwner = person
                        dismiss()
                    } label: {
                        HStack {
                            Circle()
                                .fill(PCColor.token(person.colorToken).opacity(0.18))
                                .overlay {
                                    Text(person.name.prefix(1).uppercased())
                                        .font(.headline)
                                        .foregroundStyle(PCColor.token(person.colorToken))
                                }
                                .frame(width: 36, height: 36)
                            Text(person.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedOwner?.id == person.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(PCColor.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Owner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewOwner = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add owner")
                }
            }
            .alert("New Owner", isPresented: $showingNewOwner) {
                TextField("Name", text: $newOwnerName)
                Button("Add", action: addOwner)
                Button("Cancel", role: .cancel) { newOwnerName = "" }
            }
        }
    }

    private func addOwner() {
        guard let name = newOwnerName.nilIfBlank else { return }
        let color = PCColor.tokenCycle[people.count % PCColor.tokenCycle.count]
        let person = Person(name: name, colorToken: color)
        modelContext.insert(person)
        try? modelContext.save()
        selectedOwner = person
        newOwnerName = ""
        dismiss()
    }
}

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StorageLocation.name) private var locations: [StorageLocation]
    @Binding var selectedLocation: StorageLocation?
    @State private var showingNewLocation = false
    @State private var newLocationName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(locations) { location in
                    Button {
                        selectedLocation = location
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: location.iconName)
                                .foregroundStyle(PCColor.token(location.colorToken))
                                .frame(width: 36, height: 36)
                                .background(PCColor.token(location.colorToken).opacity(0.12), in: Circle())
                            Text(location.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedLocation?.id == location.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(PCColor.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewLocation = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add location")
                }
            }
            .alert("New Location", isPresented: $showingNewLocation) {
                TextField("Name", text: $newLocationName)
                Button("Add", action: addLocation)
                Button("Cancel", role: .cancel) { newLocationName = "" }
            }
        }
    }

    private func addLocation() {
        guard let name = newLocationName.nilIfBlank else { return }
        let color = PCColor.tokenCycle[locations.count % PCColor.tokenCycle.count]
        let location = StorageLocation(name: name, kind: .custom, colorToken: color)
        modelContext.insert(location)
        try? modelContext.save()
        selectedLocation = location
        newLocationName = ""
        dismiss()
    }
}

struct TypePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedType: ClothingType

    var body: some View {
        NavigationStack {
            List(ClothingType.allCases) { type in
                Button {
                    selectedType = type
                    dismiss()
                } label: {
                    HStack {
                        Label(type.rawValue, systemImage: type.iconName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedType == type {
                            Image(systemName: "checkmark")
                                .foregroundStyle(PCColor.primary)
                        }
                    }
                }
            }
            .navigationTitle("Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct SizePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let type: ClothingType
    @Binding var selectedSize: SizeOption?

    var body: some View {
        NavigationStack {
            List {
                ForEach(SizeCatalog.groups(for: type)) { group in
                    Section(group.title) {
                        ForEach(group.options) { size in
                            Button {
                                selectedSize = size
                                dismiss()
                            } label: {
                                HStack {
                                    Text(size.label)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(size.system.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if selectedSize == size {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(PCColor.primary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Size")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct StatusPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedStatus: ItemStatus

    var body: some View {
        NavigationStack {
            List(ItemStatus.allCases.filter { $0 != .archived }) { status in
                Button {
                    selectedStatus = status
                    dismiss()
                } label: {
                    HStack {
                        Label(status.rawValue, systemImage: status.iconName)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedStatus == status {
                            Image(systemName: "checkmark")
                                .foregroundStyle(PCColor.primary)
                        }
                    }
                }
            }
            .navigationTitle("Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct SeasonPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSeason: ClothingSeason?

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedSeason = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("None")
                            .foregroundStyle(.primary)
                        Spacer()
                        if selectedSeason == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(PCColor.primary)
                        }
                    }
                }

                ForEach(ClothingSeason.allCases) { season in
                    Button {
                        selectedSeason = season
                        dismiss()
                    } label: {
                        HStack {
                            Text(season.rawValue)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedSeason == season {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(PCColor.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Season")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct CameraCaptureView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
