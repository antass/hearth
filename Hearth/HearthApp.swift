import SwiftUI
import SwiftData

@main
struct HearthApp: App {
    let container: ModelContainer = Self.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
        #if os(macOS)
        .defaultSize(width: 1000, height: 700)
        #endif
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Member.self, Room.self, Chore.self, Completion.self])
        let args = ProcessInfo.processInfo.arguments

        // `-demo` runs against a throwaway in-memory store filled with sample data.
        if args.contains("-demo") {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            let container = try! ModelContainer(for: schema, configurations: config)
            DemoData.load(into: container.mainContext)
            return container
        }

        // Syncs through the user's iCloud when the app is signed with the CloudKit
        // entitlement; otherwise falls back to a local-only store.
        do {
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: config)
        }
    }
}

enum DemoData {
    @MainActor
    static func load(into ctx: ModelContext) {
        let members = [
            Member(name: "Me", emoji: "🌻", colorName: "orange", sortOrder: 0),
            Member(name: "Partner", emoji: "🦊", colorName: "teal", sortOrder: 1),
            Member(name: "Kid 1", emoji: "🦄", colorName: "pink", isKid: true, sortOrder: 2),
            Member(name: "Kid 2", emoji: "🦖", colorName: "green", isKid: true, sortOrder: 3),
        ]
        members.forEach(ctx.insert)
        StarterSet.seed(into: ctx, cleaning: true, maintenance: true, kidChores: true)
        let chores = (try? ctx.fetch(FetchDescriptor<Chore>())) ?? []
        // Push a few into the past so overdue states show up.
        for chore in chores.prefix(3) {
            chore.dueDate = Calendar.current.date(byAdding: .day, value: -2, to: chore.dueDate) ?? chore.dueDate
        }
        for (i, chore) in chores.enumerated() where chore.kind == .cleaning && chore.assignee == nil {
            chore.assignee = members[i % 2]
        }
        try? ctx.save()
    }
}
