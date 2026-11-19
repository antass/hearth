import Foundation
import SwiftData
import SwiftUI

// All properties have defaults and all relationships are optional so the
// schema stays compatible with CloudKit sync.

enum ChoreKind: String, Codable, CaseIterable, Identifiable {
    case cleaning, maintenance
    var id: String { rawValue }
    var label: String { self == .cleaning ? "Cleaning" : "Upkeep" }
    var icon: String { self == .cleaning ? "sparkles" : "wrench.and.screwdriver" }
}

enum RepeatUnit: String, Codable, CaseIterable, Identifiable {
    case day, week, month, year
    var id: String { rawValue }
    var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }
    /// Rough length in days, used for staggering and sorting.
    var approxDays: Int {
        switch self {
        case .day: 1
        case .week: 7
        case .month: 30
        case .year: 365
        }
    }
}

@Model
final class Member {
    var name: String = ""
    var emoji: String = "🙂"
    var colorName: String = "blue"
    var isKid: Bool = false
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Chore.assignee)
    var chores: [Chore]? = []
    @Relationship(deleteRule: .nullify, inverse: \Completion.member)
    var completions: [Completion]? = []

    init(name: String, emoji: String, colorName: String = "blue", isKid: Bool = false, sortOrder: Int = 0) {
        self.name = name
        self.emoji = emoji
        self.colorName = colorName
        self.isKid = isKid
        self.sortOrder = sortOrder
    }

    var color: Color { Palette.color(colorName) }
    var totalStars: Int { (completions ?? []).reduce(0) { $0 + $1.stars } }
    var weekStars: Int {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .distantPast
        return (completions ?? []).filter { $0.date >= start }.reduce(0) { $0 + $1.stars }
    }
}

@Model
final class Room {
    var name: String = ""
    var icon: String = "house"
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \Chore.room)
    var chores: [Chore]? = []

    init(name: String, icon: String, sortOrder: Int = 0) {
        self.name = name
        self.icon = icon
        self.sortOrder = sortOrder
    }

    var activeChores: [Chore] { (chores ?? []).filter { !$0.isPaused }.sorted { $0.dueDate < $1.dueDate } }
    var dueCount: Int { activeChores.filter { $0.status <= .today }.count }
}

@Model
final class Chore {
    var title: String = ""
    var notes: String = ""
    var kindRaw: String = ChoreKind.cleaning.rawValue
    var everyCount: Int = 1
    var unitRaw: String = RepeatUnit.week.rawValue
    var dueDate: Date = Date()
    var previousDue: Date?
    var lastDone: Date?
    var minutes: Int = 10
    var stars: Int = 1
    var isPaused: Bool = false
    var createdAt: Date = Date()

    var room: Room?
    var assignee: Member?
    @Relationship(deleteRule: .cascade, inverse: \Completion.chore)
    var completions: [Completion]? = []

    init(title: String, kind: ChoreKind = .cleaning, every: Int = 1, unit: RepeatUnit = .week,
         due: Date = .now, minutes: Int = 10, room: Room? = nil, assignee: Member? = nil, notes: String = "") {
        self.title = title
        self.kindRaw = kind.rawValue
        self.everyCount = every
        self.unitRaw = unit.rawValue
        self.dueDate = Calendar.current.startOfDay(for: due)
        self.minutes = minutes
        self.room = room
        self.assignee = assignee
        self.notes = notes
    }

    var kind: ChoreKind {
        get { ChoreKind(rawValue: kindRaw) ?? .cleaning }
        set { kindRaw = newValue.rawValue }
    }
    var unit: RepeatUnit {
        get { RepeatUnit(rawValue: unitRaw) ?? .week }
        set { unitRaw = newValue.rawValue }
    }
}

@Model
final class Completion {
    var date: Date = Date()
    var stars: Int = 0
    var chore: Chore?
    var member: Member?

    init(date: Date = .now, stars: Int, chore: Chore?, member: Member?) {
        self.date = date
        self.stars = stars
        self.chore = chore
        self.member = member
    }
}

// MARK: - Scheduling

enum DueStatus: Int, Comparable {
    case overdue, today, soon, later
    static func < (a: DueStatus, b: DueStatus) -> Bool { a.rawValue < b.rawValue }
    var color: Color {
        switch self {
        case .overdue: .red
        case .today: .orange
        case .soon: .blue
        case .later: .secondary
        }
    }
}

extension Chore {
    var status: DueStatus {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let due = cal.startOfDay(for: dueDate)
        if due < today { return .overdue }
        if due == today { return .today }
        let days = cal.dateComponents([.day], from: today, to: due).day ?? 0
        return days <= 7 ? .soon : .later
    }

    var isDoneToday: Bool {
        guard let lastDone else { return false }
        return Calendar.current.isDateInToday(lastDone)
    }

    var repeatText: String {
        let unitName = unit.rawValue
        if everyCount == 1 {
            return unit == .day ? "Daily" : "Every \(unitName)"
        }
        return "Every \(everyCount) \(unitName)s"
    }

    var dueText: String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let due = cal.startOfDay(for: dueDate)
        let days = cal.dateComponents([.day], from: today, to: due).day ?? 0
        switch days {
        case ..<(-1): return "\(-days)d late"
        case -1: return "1d late"
        case 0: return "Today"
        case 1: return "Tomorrow"
        case 2...6: return due.formatted(.dateTime.weekday(.abbreviated))
        default: return due.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    func nextDue(after date: Date) -> Date {
        let start = Calendar.current.startOfDay(for: date)
        return Calendar.current.date(byAdding: unit.component, value: max(everyCount, 1), to: start) ?? start
    }

    /// Marks the chore done now, credits `member` (or the assignee) and reschedules it.
    func complete(by member: Member? = nil) {
        let who = member ?? assignee
        let record = Completion(stars: who?.isKid == true ? stars : 0, chore: self, member: who)
        modelContext?.insert(record)
        previousDue = dueDate
        lastDone = .now
        dueDate = nextDue(after: .now)
    }

    /// Reverts today's most recent completion.
    func undoToday() {
        let todays = (completions ?? [])
            .filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
        guard let last = todays.first else { return }
        let remaining = (completions ?? []).filter { $0 !== last }
        modelContext?.delete(last)
        dueDate = previousDue ?? Calendar.current.startOfDay(for: .now)
        lastDone = remaining.map(\.date).max()
    }

    func snooze(days: Int = 1) {
        let base = max(Calendar.current.startOfDay(for: .now), dueDate)
        dueDate = Calendar.current.date(byAdding: .day, value: days, to: base) ?? base
    }
}

// MARK: - Palette

enum Palette {
    static let names = ["blue", "green", "orange", "pink", "purple", "red", "teal", "yellow", "indigo", "mint"]
    static func color(_ name: String) -> Color {
        switch name {
        case "green": .green
        case "orange": .orange
        case "pink": .pink
        case "purple": .purple
        case "red": .red
        case "teal": .teal
        case "yellow": .yellow
        case "indigo": .indigo
        case "mint": .mint
        default: .blue
        }
    }
    static let roomIcons = [
        "fork.knife", "shower", "bathtub", "toilet", "bed.double", "sofa", "tv", "washer",
        "house", "tree", "leaf", "car", "door.garage.closed", "stairs", "lamp.desk",
        "desktopcomputer", "pawprint", "figure.and.child.holdinghands", "shippingbox", "sun.max",
    ]
}
