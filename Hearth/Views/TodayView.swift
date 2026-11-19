import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \Chore.dueDate) private var chores: [Chore]
    @Query(sort: \Member.sortOrder) private var members: [Member]
    @Query private var rooms: [Room]

    @State private var who: Member?
    @State private var editing: Chore?
    @State private var adding = false
    @State private var settingUp = false

    @State private var kidMode = false

    /// With no filter, kids' chores are summarised per kid instead of listed one by one.
    private var active: [Chore] {
        chores.filter { c in
            guard !c.isPaused else { return false }
            if let who { return c.assignee == who }
            return c.assignee?.isKid != true
        }
    }
    private var kids: [Member] { members.filter(\.isKid) }
    private var overdue: [Chore] { active.filter { $0.status == .overdue } }
    private var dueToday: [Chore] { active.filter { $0.status == .today } }
    private var doneToday: [Chore] { active.filter(\.isDoneToday) }
    private var comingUp: [Chore] { active.filter { $0.status == .soon && !$0.isDoneToday } }
    private var minutesLeft: Int { (overdue + dueToday).reduce(0) { $0 + $1.minutes } }

    var body: some View {
        List {
            if chores.isEmpty && rooms.isEmpty {
                EmptyHome { settingUp = true }
                    .listRowBackground(Color.clear)
            } else {
                summary
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))

                section("Overdue", overdue)
                section("Today", dueToday)
                if overdue.isEmpty && dueToday.isEmpty {
                    Section {
                        Label("All caught up for today", systemImage: "checkmark.seal")
                            .foregroundStyle(.green)
                    }
                }
                if who == nil && !kids.isEmpty {
                    Section("Kids") {
                        ForEach(kids) { kid in
                            Button { kidMode = true } label: { KidProgressRow(kid: kid) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                section("Done today", doneToday)
                section("Next 7 days", comingUp)
            }
        }
        .navigationTitle("Today")
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-kidmode") { kidMode = true }
            #endif
        }
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("Show", selection: $who) {
                        Text("Everyone").tag(Member?.none)
                        ForEach(members) { m in
                            Text("\(m.emoji) \(m.name)").tag(Optional(m))
                        }
                    }
                } label: {
                    Label("Filter", systemImage: who == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { adding = true } label: { Label("Add chore", systemImage: "plus") }
                    .keyboardShortcut("n")
            }
        }
        .sheet(item: $editing) { ChoreEditor(chore: $0).sheetFrame() }
        .sheet(isPresented: $adding) { ChoreEditor(defaultAssignee: who).sheetFrame() }
        .sheet(isPresented: $settingUp) { SetupView().sheetFrame() }
        #if os(iOS)
        .fullScreenCover(isPresented: $kidMode) { KidModeView() }
        #else
        .sheet(isPresented: $kidMode) { KidModeView().frame(minWidth: 820, minHeight: 620) }
        #endif
    }

    private var summary: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(overdue.count + dueToday.count)", label: "to do", color: .orange)
            StatTile(value: "\(minutesLeft)m", label: "est. time", color: .blue)
            StatTile(value: "\(doneToday.count)", label: "done", color: .green)
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [Chore]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { chore in
                    ChoreRow(chore: chore) { editing = chore }
                }
            }
        }
    }
}

struct KidProgressRow: View {
    let kid: Member

    var body: some View {
        let today = (kid.chores ?? []).filter { !$0.isPaused && ($0.status <= .today || $0.isDoneToday) }
        let done = today.filter(\.isDoneToday).count
        HStack(spacing: 12) {
            Avatar(member: kid, size: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(kid.name)
                ProgressView(value: Double(done), total: Double(max(today.count, 1)))
                    .tint(kid.color)
            }
            Text("\(done)/\(today.count)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Text("⭐ \(kid.weekStars)").font(.callout.monospacedDigit())
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.weight(.semibold).monospacedDigit()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct EmptyHome: View {
    var start: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "house.lodge")
                .font(.system(size: 54))
                .foregroundStyle(.tint)
            Text("Welcome to Hearth").font(.title2.bold())
            Text("Add your family and a starter list of chores and home upkeep. You can edit everything afterwards.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Set up my home", action: start)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
