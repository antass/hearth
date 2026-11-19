import SwiftUI

struct ChoreRow: View {
    let chore: Chore
    var showRoom = true
    var onEdit: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) {
                    if chore.isDoneToday { chore.undoToday() } else { chore.complete() }
                }
            } label: {
                Image(systemName: chore.isDoneToday ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(chore.isDoneToday ? Color.green : chore.status.color)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(chore.isDoneToday ? "Undo" : "Mark done")

            VStack(alignment: .leading, spacing: 3) {
                Text(chore.title)
                    .strikethrough(chore.isDoneToday, color: .secondary)
                    .foregroundStyle(chore.isDoneToday ? .secondary : .primary)
                ViewThatFits(in: .horizontal) {
                    meta(room: true, minutes: true)
                    meta(room: true, minutes: false)
                    meta(room: false, minutes: false)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let member = chore.assignee {
                Text(member.emoji)
                    .font(.callout)
                    .frame(width: 28, height: 28)
                    .background(member.color.opacity(0.2), in: Circle())
                    .accessibilityLabel(member.name)
            }
            if !chore.isDoneToday {
                Text(chore.dueText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(chore.status.color)
                    .frame(minWidth: 56, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing) {
            if !chore.isDoneToday {
                Button { withAnimation { chore.snooze() } } label: {
                    Label("Tomorrow", systemImage: "moon.zzz")
                }
                .tint(.indigo)
            }
            if let onEdit {
                Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
                    .tint(.gray)
            }
        }
        .contextMenu {
            if !chore.isDoneToday {
                Button { withAnimation { chore.complete() } } label: { Label("Mark done", systemImage: "checkmark") }
                Button { withAnimation { chore.snooze() } } label: { Label("Snooze a day", systemImage: "moon.zzz") }
                Button { withAnimation { chore.snooze(days: 7) } } label: { Label("Snooze a week", systemImage: "calendar") }
            } else {
                Button { withAnimation { chore.undoToday() } } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
            }
            if let onEdit {
                Divider()
                Button(action: onEdit) { Label("Edit…", systemImage: "pencil") }
            }
        }
    }
}

extension ChoreRow {
    func meta(room showsRoom: Bool, minutes showsMinutes: Bool) -> some View {
        HStack(spacing: 8) {
            if showRoom, showsRoom, let room = chore.room {
                Label(room.name, systemImage: room.icon)
            }
            Label(chore.repeatText, systemImage: "repeat")
            if showsMinutes, chore.minutes > 0 {
                Label("\(chore.minutes)m", systemImage: "clock")
            }
        }
        .lineLimit(1)
        .fixedSize()
        .labelStyle(CompactLabelStyle())
    }
}

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}
