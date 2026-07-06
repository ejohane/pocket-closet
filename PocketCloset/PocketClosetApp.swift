import SwiftData
import SwiftUI

@main
struct PocketClosetApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            Person.self,
            StorageLocation.self,
            ClothingItem.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create Pocket Closet model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppShell()
        }
        .modelContainer(modelContainer)
    }
}
