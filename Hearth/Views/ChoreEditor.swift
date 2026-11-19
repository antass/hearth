import SwiftUI
import SwiftData

struct ChoreEditor: View {
    let chore: Chore?

    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Room.sortOrder) private var rooms: [Room]
    @Query(sort: \Member.sortOrder) private var members: [Member]

    @State private var title: String
    @State private var notes: String
    @State private var kind: ChoreKind
    @State private var room: Room?
    @State private var assignee: Member?
    @State private var every: Int
    @State private var unit: RepeatUnit
    @State private var due: Date
    @State private var minutes: Int
    @State private var stars: Int
    @State private var paused: Bool
    @State private var confirmDelete = false

    init(chore: Chore? = nil, defaultRoom: Room? = nil, defaultKind: ChoreKind = .cleaning, defaultAssignee: Member? = nil) {
        self.chore = chore
        _title = State(initialValue: chore?.title ?? "")
        _notes = State(initialValue: chore?.notes ?? "")
        _kind = State(initialValue: chore?.kind ?? defaultKind)
        _room = State(initialValue: chore?.room ?? defaultRoom)
        _assignee = State(initialValue: chore?.assignee ?? defaultAssignee)
        _every = State(initialValue: chore?.everyCount ?? 1)
        _unit = State(initialValue: chore?.unit ?? (defaultKind == .maintenance ? .month : .week))
        _due = State(initialValue: chore?.dueDate ?? Calendar.current.startOfDay(for: .now))
        _minutes = State(initialValue: chore?.minutes ?? 10)
        _stars = State(initialValue: chore?.stars ?? 1)
        _paused = State(initialValue: chore?.isPaused ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What needs doing?", text: $title)
                    Picker("Type", selection: $kind) {
                        ForEach(ChoreKind.allCases) { Label($0.label, systemImage: $0.icon).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Where & who") {
                    Picker("Room", selection: $room) {
                        Text("No room").tag(Room?.none)
                        ForEach(rooms) { r in Label(r.name, systemImage: r.icon).tag(Optional(r)) }
                    }
                    Picker("Assigned to", selection: $assignee) {
                        Text("Anyone").tag(Member?.none)
                        ForEach(members) { m in Text("\(m.emoji) \(m.name)").tag(Optional(m)) }
                    }
                    if assignee?.isKid == true {
                        Stepper(value: $stars, in: 1...5) {
                            LabeledContent("Stars earned", value: String(repeating: "⭐", count: stars))
                        }
                    }
                }

                Section("Schedule") {
                    Stepper(value: $every, in: 1...365) {
                        LabeledContent("Repeat every", value: "\(every)")
                    }
                    Picker("Unit", selection: $unit) {
                        ForEach(RepeatUnit.allCases) { Text(every == 1 ? $0.rawValue : $0.rawValue + "s").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Next due", selection: $due, displayedComponents: .date)
                    Stepper(value: $minutes, in: 0...480, step: 5) {
                        LabeledContent("Takes about", value: "\(minutes) min")
                    }
                    Toggle("Paused", isOn: $paused)
                }

                Section(kind == .maintenance ? "Notes — parts, sizes, providers" : "Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                if let chore, let history = chore.completions, !history.isEmpty {
                    Section("History") {
                        ForEach(history.sorted { $0.date > $1.date }.prefix(8)) { c in
                            HStack {
                                Text(c.date.formatted(date: .abbreviated, time: .shortened))
                                Spacer()
                                if let m = c.member { Text("\(m.emoji) \(m.name)").foregroundStyle(.secondary) }
                            }
                            .font(.callout)
                        }
                    }
                }

                if chore != nil {
                    Section {
                        Button("Delete chore", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(chore == nil ? "New chore" : "Edit chore")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete this chore and its history?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) {
                    if let chore { ctx.delete(chore) }
                    dismiss()
                }
            }
        }
    }

    private func save() {
        let target = chore ?? Chore(title: "")
        if chore == nil { ctx.insert(target) }
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.notes = notes
        target.kind = kind
        target.room = room
        target.assignee = assignee
        target.everyCount = every
        target.unit = unit
        target.dueDate = Calendar.current.startOfDay(for: due)
        target.minutes = minutes
        target.stars = stars
        target.isPaused = paused
        try? ctx.save()
        dismiss()
    }
}
