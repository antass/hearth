import SwiftUI
import SwiftData
import UserNotifications

struct FamilyView: View {
    @Query(sort: \Member.sortOrder) private var members: [Member]
    @State private var editing: Member?
    @State private var adding = false
    @State private var kidMode = false
    @State private var confirmStarter = false
    @Environment(\.modelContext) private var ctx

    @AppStorage("reminderOn") private var reminderOn = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 8 * 60

    private var adults: [Member] { members.filter { !$0.isKid } }
    private var kids: [Member] { members.filter(\.isKid) }

    var body: some View {
        List {
            if !kids.isEmpty {
                Section {
                    Button { kidMode = true } label: {
                        Label("Start Kid Mode", systemImage: "star.circle.fill")
                            .font(.headline)
                    }
                } footer: {
                    Text("Big, tappable chore cards for the kids. Hold the exit button to leave.")
                }
            }

            memberSection("Grown-ups", adults)
            memberSection("Kids", kids)

            Section("Reminders") {
                Toggle("Daily nudge", isOn: $reminderOn)
                if reminderOn {
                    DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                }
            }
            .onChange(of: reminderOn) { Reminders.update(on: reminderOn, minutes: reminderMinutes) }
            .onChange(of: reminderMinutes) { Reminders.update(on: reminderOn, minutes: reminderMinutes) }

            Section {
                Button("Add starter chores…") { confirmStarter = true }
            } footer: {
                Text("Adds the default cleaning, upkeep and kid chores. Existing chores are untouched.")
            }
        }
        .navigationTitle("Family")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { adding = true } label: { Label("Add person", systemImage: "person.badge.plus") }
            }
        }
        .sheet(item: $editing) { MemberEditor(member: $0).sheetFrame() }
        .sheet(isPresented: $adding) { MemberEditor(member: nil).sheetFrame() }
        .confirmationDialog("Add the starter set?", isPresented: $confirmStarter) {
            Button("Cleaning + upkeep + kid chores") {
                StarterSet.seed(into: ctx, cleaning: true, maintenance: true, kidChores: true)
            }
            Button("Upkeep only") {
                StarterSet.seed(into: ctx, cleaning: false, maintenance: true, kidChores: false)
            }
            Button("Kid chores only") {
                StarterSet.seed(into: ctx, cleaning: false, maintenance: false, kidChores: true)
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $kidMode) { KidModeView() }
        #else
        .sheet(isPresented: $kidMode) { KidModeView().frame(minWidth: 820, minHeight: 620) }
        #endif
    }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminderMinutes = (c.hour ?? 8) * 60 + (c.minute ?? 0)
        }
    }

    @ViewBuilder
    private func memberSection(_ title: String, _ list: [Member]) -> some View {
        if !list.isEmpty {
            Section(title) {
                ForEach(list) { m in
                    Button { editing = m } label: { MemberRow(member: m) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

struct MemberRow: View {
    let member: Member

    var body: some View {
        HStack(spacing: 12) {
            Avatar(member: member, size: 40)
            VStack(alignment: .leading) {
                Text(member.name).font(.headline)
                let due = (member.chores ?? []).filter { !$0.isPaused && $0.status <= .today }.count
                Text(due == 0 ? "Nothing due" : "\(due) due today")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if member.isKid {
                VStack(alignment: .trailing) {
                    Text("⭐ \(member.weekStars)").font(.headline.monospacedDigit())
                    Text("this week · \(member.totalStars) total").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

struct Avatar: View {
    let member: Member
    var size: CGFloat = 40

    var body: some View {
        Text(member.emoji)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(member.color.opacity(0.22), in: Circle())
            .overlay(Circle().strokeBorder(member.color.opacity(0.6), lineWidth: 2))
    }
}

struct MemberEditor: View {
    let member: Member?
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @Query private var members: [Member]
    @State private var name: String
    @State private var emoji: String
    @State private var colorName: String
    @State private var isKid: Bool
    @State private var confirmDelete = false

    static let emojiChoices = ["🌻", "🦊", "🐻", "🦄", "🦖", "🐙", "🐝", "🐸", "🦁", "🐼", "🚀", "⚽️", "🎨", "🌈", "🍓", "🐢"]

    init(member: Member?) {
        self.member = member
        _name = State(initialValue: member?.name ?? "")
        _emoji = State(initialValue: member?.emoji ?? "🌻")
        _colorName = State(initialValue: member?.colorName ?? "blue")
        _isKid = State(initialValue: member?.isKid ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Toggle("Kid (earns stars, appears in Kid Mode)", isOn: $isKid)
                Section("Emoji") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                        ForEach(Self.emojiChoices, id: \.self) { e in
                            Button { emoji = e } label: {
                                Text(e).font(.title2).frame(width: 44, height: 44)
                                    .background(emoji == e ? Palette.color(colorName).opacity(0.3) : .clear, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section("Color") {
                    HStack {
                        ForEach(Palette.names, id: \.self) { c in
                            Circle().fill(Palette.color(c))
                                .frame(width: 26, height: 26)
                                .overlay(Circle().strokeBorder(.primary, lineWidth: colorName == c ? 2 : 0))
                                .onTapGesture { colorName = c }
                        }
                    }
                }
                if member != nil {
                    Section {
                        Button("Remove from family", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(member == nil ? "Add person" : "Edit person")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let target = member ?? Member(name: "", emoji: emoji, sortOrder: members.count)
                        if member == nil { ctx.insert(target) }
                        target.name = name.trimmingCharacters(in: .whitespaces)
                        target.emoji = emoji
                        target.colorName = colorName
                        target.isKid = isKid
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Remove this person? Their chores become unassigned.", isPresented: $confirmDelete) {
                Button("Remove", role: .destructive) {
                    if let member { ctx.delete(member) }
                    dismiss()
                }
            }
        }
    }
}

enum Reminders {
    static func update(on: Bool, minutes: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily"])
        guard on else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Hearth"
            content.body = "Take a look at today's chores."
            var when = DateComponents()
            when.hour = minutes / 60
            when.minute = minutes % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
            center.add(UNNotificationRequest(identifier: "daily", content: content, trigger: trigger))
        }
    }
}
