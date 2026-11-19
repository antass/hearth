import SwiftUI
import SwiftData

/// Longer-interval home maintenance, laid out as a timeline by month.
struct UpkeepView: View {
    @Query(sort: \Chore.dueDate) private var chores: [Chore]
    @State private var editing: Chore?
    @State private var adding = false

    private var upkeep: [Chore] { chores.filter { $0.kind == .maintenance && !$0.isPaused } }

    private var byMonth: [(String, [Chore])] {
        let cal = Calendar.current
        let thisMonth = cal.dateInterval(of: .month, for: .now)?.start ?? .now
        let groups = Dictionary(grouping: upkeep.filter { $0.status != .overdue }) { c in
            cal.dateInterval(of: .month, for: c.dueDate)?.start ?? c.dueDate
        }
        return groups.keys.sorted().map { month in
            let label = month == thisMonth ? "This month" : month.formatted(.dateTime.month(.wide).year())
            return (label, groups[month] ?? [])
        }
    }

    var body: some View {
        List {
            let overdue = upkeep.filter { $0.status == .overdue }
            if !overdue.isEmpty {
                Section("Overdue") {
                    ForEach(overdue) { c in UpkeepRow(chore: c) { editing = c } }
                }
            }
            ForEach(byMonth, id: \.0) { label, items in
                Section(label) {
                    ForEach(items) { c in UpkeepRow(chore: c) { editing = c } }
                }
            }
            if upkeep.isEmpty {
                ContentUnavailableView("No upkeep tasks", systemImage: "wrench.and.screwdriver",
                                       description: Text("Filters, detectors, gutters — the stuff that's easy to forget."))
            }
        }
        .navigationTitle("Upkeep")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { adding = true } label: { Label("Add upkeep task", systemImage: "plus") }
            }
        }
        .sheet(item: $editing) { ChoreEditor(chore: $0).sheetFrame() }
        .sheet(isPresented: $adding) { ChoreEditor(defaultKind: .maintenance).sheetFrame() }
    }
}

struct UpkeepRow: View {
    let chore: Chore
    var onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ChoreRow(chore: chore, onEdit: onEdit)
            HStack(spacing: 10) {
                if let last = chore.lastDone {
                    Text("Last done \(last.formatted(.relative(presentation: .named)))")
                } else {
                    Text("Never logged")
                }
                if !chore.notes.isEmpty {
                    Text("· \(chore.notes)").lineLimit(1)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.leading, 40)
        }
    }
}
