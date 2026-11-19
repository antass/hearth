import SwiftUI
import SwiftData

/// First-run setup: who lives here, and which starter chores to add.
struct SetupView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    struct Draft: Identifiable {
        let id = UUID()
        var name: String
        var emoji: String
        var colorName: String
        var isKid: Bool
    }

    @State private var people: [Draft] = [
        Draft(name: "Me", emoji: "🌻", colorName: "orange", isKid: false),
    ]
    @State private var cleaning = true
    @State private var maintenance = true
    @State private var kidChores = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($people) { $p in
                        HStack {
                            Menu {
                                ForEach(MemberEditor.emojiChoices, id: \.self) { e in
                                    Button(e) { p.emoji = e }
                                }
                            } label: {
                                Text(p.emoji).font(.title2)
                            }
                            .menuStyle(.button)
                            .buttonStyle(.plain)
                            TextField("Name", text: $p.name)
                            Toggle("Kid", isOn: $p.isKid)
                                .fixedSize()
                        }
                    }
                    .onDelete { people.remove(atOffsets: $0) }
                    Button {
                        let i = people.count
                        people.append(Draft(name: "", emoji: MemberEditor.emojiChoices[(i + 2) % MemberEditor.emojiChoices.count],
                                            colorName: Palette.names[(i + 1) % Palette.names.count], isKid: true))
                    } label: {
                        Label("Add person", systemImage: "plus")
                    }
                } header: {
                    Text("Who lives here?")
                } footer: {
                    Text("Kids get their own big-button Kid Mode and earn stars.")
                }

                Section("Starter list") {
                    Toggle("Everyday cleaning (24 chores)", isOn: $cleaning)
                    Toggle("Home upkeep (12 tasks)", isOn: $maintenance)
                    Toggle("Kid chores (5 per kid)", isOn: $kidChores)
                        .disabled(!people.contains(where: \.isKid))
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Set up your home")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Get started", action: finish) }
            }
        }
    }

    private func finish() {
        for (i, p) in people.enumerated() {
            let name = p.name.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            ctx.insert(Member(name: name, emoji: p.emoji, colorName: p.colorName, isKid: p.isKid, sortOrder: i))
        }
        try? ctx.save()
        StarterSet.seed(into: ctx, cleaning: cleaning, maintenance: maintenance,
                        kidChores: kidChores && people.contains(where: \.isKid))
        dismiss()
    }
}
