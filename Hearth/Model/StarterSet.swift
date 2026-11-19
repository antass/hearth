import Foundation
import SwiftData

/// Sensible starting chores. Seeding is always user-triggered (never automatic on launch)
/// so a second device syncing from iCloud doesn't create duplicates.
enum StarterSet {
    struct Item {
        let title: String
        let room: String
        let every: Int
        let unit: RepeatUnit
        let minutes: Int
        var kind: ChoreKind = .cleaning
        var notes: String = ""
    }

    static let rooms: [(String, String)] = [
        ("Kitchen", "fork.knife"), ("Bathrooms", "shower"), ("Bedrooms", "bed.double"),
        ("Living Room", "sofa"), ("Laundry", "washer"), ("Whole House", "house"), ("Outside", "tree"),
    ]

    static let cleaning: [Item] = [
        .init(title: "Wipe counters & stove", room: "Kitchen", every: 1, unit: .day, minutes: 5),
        .init(title: "Run / empty dishwasher", room: "Kitchen", every: 1, unit: .day, minutes: 10),
        .init(title: "Take out trash & recycling", room: "Kitchen", every: 1, unit: .week, minutes: 5),
        .init(title: "Clean microwave", room: "Kitchen", every: 1, unit: .week, minutes: 5),
        .init(title: "Toss old fridge food", room: "Kitchen", every: 1, unit: .week, minutes: 10),
        .init(title: "Mop kitchen floor", room: "Kitchen", every: 1, unit: .week, minutes: 15),
        .init(title: "Deep clean fridge", room: "Kitchen", every: 3, unit: .month, minutes: 30),
        .init(title: "Clean toilets", room: "Bathrooms", every: 1, unit: .week, minutes: 10),
        .init(title: "Wipe sinks & mirrors", room: "Bathrooms", every: 1, unit: .week, minutes: 10),
        .init(title: "Scrub shower / tub", room: "Bathrooms", every: 1, unit: .week, minutes: 15),
        .init(title: "Swap towels", room: "Bathrooms", every: 1, unit: .week, minutes: 5),
        .init(title: "Wash bath mats", room: "Bathrooms", every: 1, unit: .month, minutes: 5),
        .init(title: "Change sheets", room: "Bedrooms", every: 1, unit: .week, minutes: 15),
        .init(title: "Vacuum bedrooms", room: "Bedrooms", every: 1, unit: .week, minutes: 15),
        .init(title: "Wash pillows & duvets", room: "Bedrooms", every: 6, unit: .month, minutes: 20),
        .init(title: "Rotate mattresses", room: "Bedrooms", every: 6, unit: .month, minutes: 10),
        .init(title: "Evening tidy & reset", room: "Living Room", every: 1, unit: .day, minutes: 10),
        .init(title: "Vacuum living room", room: "Living Room", every: 1, unit: .week, minutes: 20),
        .init(title: "Dust surfaces", room: "Living Room", every: 2, unit: .week, minutes: 15),
        .init(title: "Vacuum couch cushions", room: "Living Room", every: 1, unit: .month, minutes: 10),
        .init(title: "Laundry load", room: "Laundry", every: 3, unit: .day, minutes: 15),
        .init(title: "Run washer cleaning cycle", room: "Laundry", every: 1, unit: .month, minutes: 5),
        .init(title: "Wipe switches & door handles", room: "Whole House", every: 2, unit: .week, minutes: 10),
        .init(title: "Wash windows", room: "Whole House", every: 3, unit: .month, minutes: 45),
    ]

    static let maintenance: [Item] = [
        .init(title: "Replace HVAC filter", room: "Whole House", every: 3, unit: .month, minutes: 10, kind: .maintenance, notes: "Filter size: "),
        .init(title: "Test smoke & CO detectors", room: "Whole House", every: 1, unit: .month, minutes: 5, kind: .maintenance),
        .init(title: "Replace detector batteries", room: "Whole House", every: 1, unit: .year, minutes: 20, kind: .maintenance),
        .init(title: "Check fire extinguisher", room: "Whole House", every: 1, unit: .year, minutes: 5, kind: .maintenance),
        .init(title: "Service furnace / AC", room: "Whole House", every: 1, unit: .year, minutes: 60, kind: .maintenance, notes: "Provider: "),
        .init(title: "Flush water heater", room: "Whole House", every: 1, unit: .year, minutes: 45, kind: .maintenance),
        .init(title: "Clean dishwasher filter", room: "Kitchen", every: 1, unit: .month, minutes: 10, kind: .maintenance),
        .init(title: "Clean range hood filter", room: "Kitchen", every: 3, unit: .month, minutes: 15, kind: .maintenance),
        .init(title: "Vacuum fridge coils", room: "Kitchen", every: 6, unit: .month, minutes: 15, kind: .maintenance),
        .init(title: "Replace water filter", room: "Kitchen", every: 6, unit: .month, minutes: 5, kind: .maintenance, notes: "Filter model: "),
        .init(title: "Clean dryer vent duct", room: "Laundry", every: 1, unit: .year, minutes: 30, kind: .maintenance),
        .init(title: "Clean gutters", room: "Outside", every: 6, unit: .month, minutes: 90, kind: .maintenance),
    ]

    static let kids: [Item] = [
        .init(title: "Make your bed", room: "Bedrooms", every: 1, unit: .day, minutes: 3),
        .init(title: "Put toys away", room: "Living Room", every: 1, unit: .day, minutes: 10),
        .init(title: "Clothes in the hamper", room: "Bedrooms", every: 1, unit: .day, minutes: 2),
        .init(title: "Set the table", room: "Kitchen", every: 1, unit: .day, minutes: 5),
        .init(title: "Water the plants", room: "Whole House", every: 1, unit: .week, minutes: 5),
    ]

    static func seed(into ctx: ModelContext, cleaning: Bool, maintenance: Bool, kidChores: Bool) {
        var roomsByName: [String: Room] = [:]
        let existing = (try? ctx.fetch(FetchDescriptor<Room>())) ?? []
        for room in existing { roomsByName[room.name] = room }
        for (i, (name, icon)) in rooms.enumerated() where roomsByName[name] == nil {
            let room = Room(name: name, icon: icon, sortOrder: existing.count + i)
            ctx.insert(room)
            roomsByName[name] = room
        }

        var items: [Item] = []
        if cleaning { items += StarterSet.cleaning }
        if maintenance { items += StarterSet.maintenance }
        let today = Calendar.current.startOfDay(for: .now)

        // Stagger first due dates so day one isn't a wall of 30 chores.
        for (i, item) in items.enumerated() {
            let days = item.every * item.unit.approxDays
            let span = item.kind == .maintenance ? min(days, 45) : min(days, days >= 30 ? 30 : 7)
            let offset = span <= 1 ? 0 : i % span
            let due = Calendar.current.date(byAdding: .day, value: offset, to: today) ?? today
            ctx.insert(Chore(title: item.title, kind: item.kind, every: item.every, unit: item.unit,
                             due: due, minutes: item.minutes, room: roomsByName[item.room], notes: item.notes))
        }

        if kidChores {
            let kids = ((try? ctx.fetch(FetchDescriptor<Member>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []).filter(\.isKid)
            for kid in kids {
                for item in StarterSet.kids {
                    let chore = Chore(title: item.title, every: item.every, unit: item.unit, due: today,
                                      minutes: item.minutes, room: roomsByName[item.room], assignee: kid)
                    ctx.insert(chore)
                }
            }
        }
        try? ctx.save()
    }

}
