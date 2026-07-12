import CloudKit
import CoreData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

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
    @Environment(\.managedObjectContext) private var modelContext
    @Environment(\.persistenceController) private var persistenceController
    @EnvironmentObject private var closetSession: ClosetSession
    @EnvironmentObject private var shareAcceptance: ShareAcceptanceCoordinator
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Closet.createdAt, ascending: true)]) private var closets: FetchedResults<Closet>
    @State private var selectedTab: AppTab = .closet
    @State private var startupError: String?
    @State private var shareAcceptanceError: String?

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
            bootstrapPersistence()
        }
        .onChange(of: closets.map(\.id)) { _, _ in
            closetSession.ensureSelection(in: Array(closets))
        }
        .onChange(of: shareAcceptance.state) { _, state in
            switch state {
            case .accepted(let closetID):
                closetSession.selectedClosetID = closetID
                selectedTab = .closet
                shareAcceptance.reset()
            case .failed(let message):
                shareAcceptanceError = message
                shareAcceptance.reset()
            case .idle, .accepting:
                break
            }
        }
        .overlay {
            if shareAcceptance.state == .accepting {
                ZStack {
                    Color.black.opacity(0.18).ignoresSafeArea()
                    ProgressView("Joining shared closet…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
        .alert("Couldn’t migrate your closet", isPresented: Binding(
            get: { startupError != nil },
            set: { if !$0 { startupError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(startupError ?? "Your existing data is still safe and has not been removed.")
        }
        .alert("Couldn’t join the shared closet", isPresented: Binding(
            get: { shareAcceptanceError != nil },
            set: { if !$0 { shareAcceptanceError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shareAcceptanceError ?? "Please check your iCloud connection and try the invitation again.")
        }
    }

    private func bootstrapPersistence() {
        do {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("INITIALIZE_CLOUDKIT_SCHEMA") {
                try persistenceController.initializeDevelopmentCloudKitSchema()
            }
            #endif
            _ = try LegacyStoreMigrator.migrateIfNeeded(
                into: modelContext,
                privateStore: persistenceController.privateStore
            )
            let closet = DefaultDataSeeder.seedDefaultsIfNeeded(
                in: modelContext,
                privateStore: persistenceController.privateStore
            )
            closetSession.ensureSelection(in: Array(closets) + [closet].compactMap { $0 })
            if ProcessInfo.processInfo.arguments.contains("UITEST_SEED_DATA") {
                DefaultDataSeeder.seedUITestDataIfNeeded(in: modelContext, closet: closet)
            }
        } catch {
            startupError = error.localizedDescription
        }
    }
}

@MainActor
enum DefaultDataSeeder {
    @discardableResult
    static func seedDefaultsIfNeeded(
        in context: NSManagedObjectContext,
        privateStore: NSPersistentStore
    ) -> Closet? {
        let closetRequest = Closet.fetchRequest()
        closetRequest.affectedStores = [privateStore]
        closetRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Closet.createdAt, ascending: true)]
        if let existing = try? context.fetch(closetRequest).first {
            return existing
        }

        let closet = Closet(context: context, name: "Our Closet")
        context.assign(closet, to: privateStore)

        let defaults: [(String, LocationKind, String)] = [
            ("Closet", .closet, "green"),
            ("Dresser", .dresser, "blue"),
            ("Storage Bin", .storageBin, "aqua"),
            ("Garage", .garage, "purple"),
            ("Donate Bag", .donateBag, "red"),
            ("Laundry/Unknown", .laundryUnknown, "yellow")
        ]

        for location in defaults {
            _ = StorageLocation(context: context, closet: closet, name: location.0, kind: location.1, colorToken: location.2)
        }

        try? context.save()
        return closet
    }

    static func seedUITestDataIfNeeded(in context: NSManagedObjectContext, closet: Closet?) {
        guard let closet else { return }
        let itemRequest = ClothingItem.fetchRequest()
        itemRequest.fetchLimit = 1
        itemRequest.predicate = NSPredicate(format: "brand == %@", "UITestSeed")
        guard ((try? context.count(for: itemRequest)) ?? 0) == 0 else { return }

        let emma = Person(context: context, closet: closet, name: "Emma", colorToken: "pink")
        let theo = Person(context: context, closet: closet, name: "Theo", colorToken: "blue")
        let me = Person(context: context, closet: closet, name: "Me", colorToken: "green")

        let locationRequest = StorageLocation.fetchRequest()
        let locations = (try? context.fetch(locationRequest))?.filter { $0.closet == closet } ?? []
        let storage = locations.first { $0.kind == .storageBin } ?? StorageLocation(context: context, closet: closet, name: "Storage Bin", kind: .storageBin)
        let closetLocation = locations.first { $0.kind == .closet } ?? StorageLocation(context: context, closet: closet, name: "Closet", kind: .closet)

        let seed: [(Person, ClothingType, SizeOption, StorageLocation, ItemStatus, UIColor)] = [
            (emma, .top, SizeCatalog.toddler[2], storage, .inStorage, UIColor(red: 0.76, green: 0.86, blue: 0.76, alpha: 1)),
            (theo, .outerwear, SizeCatalog.kidsNumeric[3], closetLocation, .inCloset, UIColor(red: 0.44, green: 0.50, blue: 0.33, alpha: 1)),
            (me, .top, SizeCatalog.adultAlpha[2], closetLocation, .needsReview, UIColor(red: 0.42, green: 0.58, blue: 0.78, alpha: 1)),
            (emma, .bottom, SizeCatalog.kidsNumeric[4], storage, .donate, UIColor(red: 0.70, green: 0.58, blue: 0.41, alpha: 1))
        ]

        for entry in seed {
            let image = ImageStore.makePlaceholderImage(color: entry.5, symbolName: entry.1.iconName)
            if let paths = try? ImageStore.save(image: image) {
                context.insert(ClothingItem(
                    context: context,
                    closet: closet,
                    photoPath: paths.photoPath,
                    thumbnailPath: paths.thumbnailPath,
                    photoData: paths.photoData,
                    thumbnailData: paths.thumbnailData,
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

struct ClosetSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var modelContext
    @Environment(\.persistenceController) private var persistenceController
    @EnvironmentObject private var closetSession: ClosetSession
    @ObservedObject var closet: Closet

    @State private var share: CKShare?
    @State private var hasLoadedShare = false
    @State private var isShowingSharingController = false
    @State private var sharingError: String?
    @State private var isPreparingShare = false

    private var isParticipant: Bool {
        persistenceController.store(for: closet) == persistenceController.sharedStore
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Closet") {
                    TextField("Name", text: $closet.name)
                        .onSubmit(saveName)

                    LabeledContent("Sync", value: "iCloud")
                    LabeledContent("Access", value: accessDescription)
                }

                Section("Family Sharing") {
                    if !hasLoadedShare {
                        HStack {
                            ProgressView()
                            Text("Checking sharing status…")
                                .foregroundStyle(.secondary)
                        }
                    } else if isParticipant {
                        Button {
                            isShowingSharingController = true
                        } label: {
                            Label("Manage Access", systemImage: "person.2")
                        }
                    } else {
                        Button(action: shareCloset) {
                            if isPreparingShare {
                                HStack {
                                    ProgressView()
                                    Text("Preparing invitation…")
                                }
                            } else {
                                Label(
                                    share == nil ? "Share Closet" : "Send Invitation",
                                    systemImage: share == nil ? "person.2.badge.plus" : "message"
                                )
                            }
                        }
                        .disabled(isPreparingShare)

                        if share != nil {
                            Button {
                                isShowingSharingController = true
                            } label: {
                                Label("Manage Access", systemImage: "person.2")
                            }
                            .disabled(isPreparingShare)
                        }
                    }

                    Text(sharingHelpText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Closet Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveName()
                        dismiss()
                    }
                }
            }
            .task { loadShare() }
            .sheet(isPresented: $isShowingSharingController) {
                if let share {
                    CloudSharingControllerView(
                        title: closet.name,
                        share: share,
                        onError: { error in
                            sharingError = error.localizedDescription
                        }
                    )
                    .ignoresSafeArea()
                }
            }
            .alert("Sharing Failed", isPresented: Binding(
                get: { sharingError != nil },
                set: { if !$0 { sharingError = nil } }
            )) {
                Button("OK", role: .cancel) { sharingError = nil }
            } message: {
                Text(sharingError ?? "Pocket Closet couldn't update this share.")
            }
        }
    }

    private var accessDescription: String {
        if isParticipant { return "Shared with you" }
        if share != nil { return "Shared by you" }
        return "Private"
    }

    private var sharingHelpText: String {
        if isParticipant {
            return "Changes you make are synced with everyone in this closet. Use Manage Access to leave."
        }
        return share == nil
            ? "Invite someone using Messages or another app. They can view and edit everything in this closet."
            : "Send another private invitation or manage who can view and edit this closet."
    }

    private func saveName() {
        closet.name = closet.name.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? "Our Closet"
        closet.updatedAt = Date()
        try? modelContext.save()
    }

    private func loadShare() {
        persistenceController.fetchShare(for: closet) { fetchedShare in
            Task { @MainActor in
                share = fetchedShare
                hasLoadedShare = true
            }
        }
    }

    private func shareCloset() {
        saveName()
        isPreparingShare = true
        Task {
            do {
                let invitationShare = try await invitationShare()
                await MainActor.run {
                    share = invitationShare
                    isPreparingShare = false
                    isShowingSharingController = true
                }
            } catch {
                await MainActor.run {
                    isPreparingShare = false
                    sharingError = "Pocket Closet couldn't prepare the invitation. Your closet is unchanged. \(error.localizedDescription)"
                }
            }
        }
    }

    private func invitationShare() async throws -> CKShare {
        guard let share else {
            return try await persistenceController.createShare(
                for: closet.objectID,
                title: closet.name
            )
        }

        if share.url != nil {
            return share
        }

        do {
            return try await persistenceController.fetchServerShare(share, databaseScope: .private)
        } catch {
            let nsError = error as NSError
            guard nsError.domain == CKErrorDomain,
                  nsError.code == CKError.unknownItem.rawValue else {
                throw error
            }

            let result = try await persistenceController.recoverMissingShare(
                for: closet.objectID,
                staleShare: share,
                title: closet.name
            )
            await MainActor.run {
                if let replacement = try? modelContext.existingObject(with: result.replacementClosetID) as? Closet {
                    closetSession.select(replacement)
                }
                if let cleanupWarning = result.cleanupWarning {
                    sharingError = "The invitation is ready, but Pocket Closet could not remove an older unused copy: \(cleanupWarning.localizedDescription)"
                }
            }
            return result.share
        }
    }
}

struct ClosetManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.persistenceController) private var persistenceController
    @EnvironmentObject private var closetSession: ClosetSession
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Closet.createdAt, ascending: true)]) private var closets: FetchedResults<Closet>

    @State private var sharesByClosetID: [UUID: CKShare] = [:]
    @State private var closetToDelete: Closet?
    @State private var closetToRename: Closet?
    @State private var renameText = ""
    @State private var deletionError: String?
    @State private var isDeleting = false

    private var ownedClosets: [Closet] {
        closets.filter { persistenceController.store(for: $0) == persistenceController.privateStore }
    }

    private var sharedClosets: [Closet] {
        closets.filter { persistenceController.store(for: $0) == persistenceController.sharedStore }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(ownedClosets) { closet in
                        closetRow(closet, ownership: sharesByClosetID[closet.id] == nil ? "Private" : "Shared by you")
                    }
                } header: {
                    Text("My Closets")
                } footer: {
                    Text("Deleting a closet removes all of its people, items, and locations. If it is shared, it is also removed for everyone you invited.")
                }

                if !sharedClosets.isEmpty {
                    Section("Shared with Me") {
                        ForEach(sharedClosets) { closet in
                            closetRow(closet, ownership: "Shared with you")
                        }
                    }
                }
            }
            .navigationTitle("Manage Closets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: closets.map(\.id)) {
                loadShares()
            }
            .confirmationDialog(
                "Delete \(closetToDelete?.name ?? "this closet")?",
                isPresented: Binding(
                    get: { closetToDelete != nil },
                    set: { if !$0 { closetToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete Closet", role: .destructive) {
                    if let closetToDelete {
                        delete(closetToDelete)
                    }
                }
                Button("Cancel", role: .cancel) { closetToDelete = nil }
            } message: {
                if let closetToDelete, sharesByClosetID[closetToDelete.id] != nil {
                    Text("This closet is shared by you. Deleting it removes the closet and its contents for every participant. This cannot be undone.")
                } else {
                    Text("The closet and all of its contents will be permanently deleted. This cannot be undone.")
                }
            }
            .alert("Rename Closet", isPresented: Binding(
                get: { closetToRename != nil },
                set: { if !$0 { closetToRename = nil } }
            )) {
                TextField("Closet name", text: $renameText)
                Button("Save") { saveRename() }
                Button("Cancel", role: .cancel) { closetToRename = nil }
            }
            .alert("Couldn’t delete the closet", isPresented: Binding(
                get: { deletionError != nil },
                set: { if !$0 { deletionError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deletionError ?? "Your closet was left unchanged.")
            }
            .overlay {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        ProgressView("Deleting closet…")
                            .padding(24)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
            }
        }
    }

    private func closetRow(_ closet: Closet, ownership: String) -> some View {
        HStack(spacing: 12) {
            Button {
                closetSession.select(closet)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                Image(systemName: closet.id == closetSession.selectedClosetID ? "checkmark.circle.fill" : "cabinet")
                    .font(.title3)
                    .foregroundStyle(closet.id == closetSession.selectedClosetID ? PCColor.primary : .secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(closet.name)
                        .foregroundStyle(.primary)
                    Text("\(closet.items?.count ?? 0) items · \(ownership)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if persistenceController.store(for: closet) == persistenceController.privateStore {
                Menu {
                    Button {
                        renameText = closet.name
                        closetToRename = closet
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        closetToDelete = closet
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Actions for \(closet.name)")
            }
        }
        .disabled(isDeleting)
    }

    private func loadShares() {
        let owned = ownedClosets
        guard !owned.isEmpty else {
            sharesByClosetID = [:]
            return
        }
        do {
            let shares = try persistenceController.container.fetchShares(matching: owned.map(\.objectID))
            sharesByClosetID = Dictionary(uniqueKeysWithValues: owned.compactMap { closet in
                shares[closet.objectID].map { (closet.id, $0) }
            })
        } catch {
            sharesByClosetID = [:]
        }
    }

    private func saveRename() {
        guard let closet = closetToRename else { return }
        closet.name = renameText.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank ?? "Our Closet"
        closet.updatedAt = Date()
        try? closet.managedObjectContext?.save()
        closetToRename = nil
    }

    private func delete(_ closet: Closet) {
        let objectID = closet.objectID
        let closetID = closet.id
        closetToDelete = nil
        isDeleting = true
        Task {
            do {
                try await persistenceController.deleteOwnedCloset(objectID)
                if closetSession.selectedClosetID == closetID {
                    closetSession.selectedClosetID = nil
                }
            } catch {
                deletionError = error.localizedDescription
            }
            isDeleting = false
        }
    }
}

private struct CloudSharingControllerView: UIViewControllerRepresentable {
    let title: String
    let share: CKShare
    let onError: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(title: title, onError: onError)
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let cloudContainer = CKContainer(identifier: cloudKitContainerIdentifier)
        let controller = UICloudSharingController(share: share, container: cloudContainer)

        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let title: String
        let onError: (Error) -> Void

        init(title: String, onError: @escaping (Error) -> Void) {
            self.title = title
            self.onError = onError
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            title
        }

        func itemType(for csc: UICloudSharingController) -> String? {
            UTType.data.identifier
        }

        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: Error
        ) {
            Task { @MainActor in
                onError(error)
            }
        }
    }
}
