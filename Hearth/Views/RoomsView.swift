import SwiftUI
import SwiftData

struct RoomsView: View {
    @Query(sort: \Room.sortOrder) private var rooms: [Room]
    @State private var addingRoom = false

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(rooms) { room in
                    NavigationLink(value: room) { RoomCard(room: room) }
                        .buttonStyle(.plain)
                }
            }
            .padding()
            if rooms.isEmpty {
                ContentUnavailableView("No rooms yet", systemImage: "square.grid.2x2",
                                       description: Text("Add rooms to group chores by where they happen."))
            }
        }
        .navigationTitle("Rooms")
        .navigationDestination(for: Room.self) { RoomDetailView(room: $0) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { addingRoom = true } label: { Label("Add room", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $addingRoom) { RoomEditor(room: nil).sheetFrame() }
    }
}

struct RoomCard: View {
    let room: Room

    var body: some View {
        let due = room.dueCount
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: room.icon)
                    .font(.title2)
                    .foregroundStyle(.tint)
                Spacer()
                if due > 0 {
                    Text("\(due) due")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.orange.opacity(0.18), in: Capsule())
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            Text(room.name).font(.headline)
            Text("\(room.activeChores.count) chores").font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct RoomDetailView: View {
    let room: Room
    @State private var editing: Chore?
    @State private var adding = false
    @State private var editingRoom = false

    var body: some View {
        let chores = (room.chores ?? []).sorted { $0.dueDate < $1.dueDate }
        List {
            let cleaning = chores.filter { $0.kind == .cleaning }
            let upkeep = chores.filter { $0.kind == .maintenance }
            if !cleaning.isEmpty {
                Section("Cleaning") {
                    ForEach(cleaning) { c in ChoreRow(chore: c, showRoom: false) { editing = c } }
                }
            }
            if !upkeep.isEmpty {
                Section("Upkeep") {
                    ForEach(upkeep) { c in ChoreRow(chore: c, showRoom: false) { editing = c } }
                }
            }
            if chores.isEmpty {
                Text("No chores in this room yet.").foregroundStyle(.secondary)
            }
        }
        .navigationTitle(room.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { adding = true } label: { Label("Add chore", systemImage: "plus") }
            }
            ToolbarItem {
                Button { editingRoom = true } label: { Label("Edit room", systemImage: "pencil") }
            }
        }
        .sheet(item: $editing) { ChoreEditor(chore: $0).sheetFrame() }
        .sheet(isPresented: $adding) { ChoreEditor(defaultRoom: room).sheetFrame() }
        .sheet(isPresented: $editingRoom) { RoomEditor(room: room).sheetFrame() }
    }
}

struct RoomEditor: View {
    let room: Room?
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query private var rooms: [Room]
    @State private var name: String
    @State private var icon: String
    @State private var confirmDelete = false

    init(room: Room?) {
        self.room = room
        _name = State(initialValue: room?.name ?? "")
        _icon = State(initialValue: room?.icon ?? "house")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Room name", text: $name)
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                        ForEach(Palette.roomIcons, id: \.self) { symbol in
                            Button { icon = symbol } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(icon == symbol ? Color.accentColor.opacity(0.25) : .clear,
                                                in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                if room != nil {
                    Section {
                        Button("Delete room", role: .destructive) { confirmDelete = true }
                    } footer: {
                        Text("Chores in this room are kept and become room-less.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(room == nil ? "New room" : "Edit room")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let target = room ?? Room(name: "", icon: icon, sortOrder: rooms.count)
                        if room == nil { ctx.insert(target) }
                        target.name = name.trimmingCharacters(in: .whitespaces)
                        target.icon = icon
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Delete this room?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) {
                    if let room { ctx.delete(room) }
                    dismiss()
                }
            }
        }
    }
}
